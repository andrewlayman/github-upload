MODULE TLMkBase;

(*  =========================================================================
    Last Edit : September 5, 1991 3:47PM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        TL Make Base - Make the baseline.  Overlay.

    MODIFICATION HISTORY:

        June 16 1987  RSC  First Version.
        Oct  14 1987  RSC  Added call to Rollups.Rollup
        Feb  22 1988  RSC  Fixed up DEBUGGING for shipment.
        Mar   5 1988  EGK  Set baseline for kids of cursor task (option 4).
        Nov  09 1988  LAA  Don't allow baseline to be set if there was a calc
                           error.
        Aug  10 1989  KKC  Add copyright message.
        07-Jun-90 AJL    - Updated to use the RateLists module.
                         - Rearranged the procedures which traverse resources
                           and tasks looking for baselines so that all of their
                           outputs are in explicit parameters.
         6-Aug-90 RSC      removed reference to the old "TempTaskFlag4".
         7-Aug-90 RSC      Added the new structures from the resource
                           record.
        24-Sep-90 DSL    - Changed call from Rollups.Rollup to
                           Rollups.RollupBaseline and Rollups.RollupPlan.
         2-Oct-90 RSC    - Remove the baseline assignment's varying
                           assignments and expences.
        14-Oct-90 AJL    - Remove RollupBaseline.
                         - Added choice to reset costs, dates, or both.J2
         9-Nov-90 PFG   Added 4.0.3 changes:
                        Sep  23 1990  LAA  
                            Set ScheduleSaved to FALSE when a baseline is made,
                            so the user will be warned to save his/her 
                            schedule file before exiting.  Bug #1976.
                        End of 4.0.3 changes.
        25-Apr-91 AJL    - Setting a baseline forces invalidates any filtering
                           in effect, forcing new filtering.
         5-Sep-91 EGK      Undid part of the 2-Oct-90 "fix", in which the
                           baseline varying assignment list was removed.
                           This made it impossible for cross-tab reports to
                           show any baseline data, since they depend on the
                           baseline's varying assignment list.  Here we
                           use the list copied from the actual assignment,
                           and adjust the EndOfSpent date to correspond to
                           our moving the spent quantity back to "to-go".
        26-Sep-91 AJL    - Make the default for copying of assignments "yes".
         4-Oct-91 AJL    - After setting a baseline, recompute the detail
                           task fields that depend on baseline data.
        30-Jan-92 TGS   AVaryingAssgnList now contains REAL Rates. Changed
                        local variable to match this. The Rate is not used
                        here, so no range checking is necessary.
    =========================================================================
*)



FROM Allocs          IMPORT
   (* TYPES *)           ATaskFlag, ATaskPtr, AStartStatus,
   (* VARS  *)           TaskTree;

FROM AsOf            IMPORT
   (* VAR *)             AsOfDate;

FROM Assignments     IMPORT
   (* TYPE *)            AnAssignmentArray, AnAssignmentRecord,
   (* PROC *)            RemoveAssignmentsAndExpenses,
                         CopyOneAssignmentWithSpeed;

FROM Chart           IMPORT
   (* VAR *)             CursorTask;

FROM ChartControl    IMPORT
   (* TYPES *)           AChartState,
   (* VARS  *)           ChartState,
   (* PROC *)            UnSetState;

FROM DateLists       IMPORT 
    (* TYPE *)           ADateList,
    (* PROC *)           CopyDateList, DisposeDateList;

FROM Dialog          IMPORT
      (* TYPES *)        ADialogOption,
      (* PROCS *)        ContinuationBox, WarningBox, MultipleChoiceBox,
                         Message, Burp, Error, FatalError;

FROM Expenses        IMPORT
    (* PROC *)           DisposeExpenseArrayHandle;

FROM FlexStor        IMPORT
   (* TYPES *)           AnExtHandle,      AnExtStoragePreference,
   (* PROCS *)           LockObjectArray,  LockObject,
                         ReleaseObject,    ReleaseUnchangedObject,
                         DiscardExtObject, CopyExtObject;

FROM LStrings        IMPORT
   (* PROCS *)           SetString, SetLengthOf;

FROM Menus           IMPORT
      (* PROCS *)        NoYes;

FROM MsgFile         IMPORT
      (* PROCS *)        DisplayMessage, GetMessage;

FROM Planner         IMPORT
    (* VAR *)            ScheduleComputedOk;

FROM RateLists       IMPORT
    (* TYPE *)           ARateList,
    (* PROC *)           RateListsAreEqual, CopyRateList, DisposeRateList;

FROM ResCalUI        IMPORT
    (* PROC *)           DisposeCalendar, CopyCalendar;

FROM Rollups         IMPORT
   (* PROCS *)           RollupPlan;

FROM RsrcMod         IMPORT
      (* TYPES *)        AResourcePointer, 
      (* VARS *)         ResourceTree;

FROM Schedule        IMPORT 
    (* VAR *)            ScheduleSaved; 

FROM SYSTEM          IMPORT
   (* THING *)           ADR, ADDRESS, TSIZE;

FROM Timei           IMPORT
    (* TYPE *)           ADate;

FROM TreeObjects     IMPORT
    (* TYPE *)           ATreeNode, ATreeOrder, ATree,
    (* PROC *)           ValidateTreeNode, ValidateTree;

FROM VaryAssgnment   IMPORT
    (* TYPE *)           AVaryingAssgnList,
    (* PROC *)           DisposeVaryingAssgnList,
                         GetVaryingAssgnListEntry;





CONST ModuleNumber = 18800;  (* Same as GanttOutline *)
      
      NeedsCalcMessage            =  0;
      NeedsCalcTitle              =  1;

      BaseLineExistsMessage       =  2;
      BaseLineMenuText            =  6;
      BaseLineExistsTitle         =  3;
      BaseLineErasedMessage       =  7;
      BaseLineSetMessage          =  8;

      OutOfMemoryMessage          =  4;
      OutOfMemoryTitle            =  5;
      PartialBaseline             =  9;
      ResourcesWithDifferingRates = 10;
      WhatToCopyTitle             = 11; 
      WhatToCopyText              = 12; 
      WhatToCopyMenuText          = 13;
      CopyAssignmentsTitle        = 14; 
      CopyAssignmentsText         = 15; 
      CopyAssignmentsMenuText     = 16;


      MaxLevels                 = 65535; (* Deepest outline level *)

      Zero                      = 0.0;
      OneHundred                = 100.0;


TYPE
    ABaselineCheckContext = RECORD
                                Exists : BOOLEAN;
                                DifferentBaselines : BOOLEAN;
                            END;

VAR
    CopyAssignments,
    TransferDates,
    TransferCosts  : BOOLEAN;



  (* CheckBaseLineForResource - see if this resource has a BaseLine.

      Outputs        - BaselineCheckContext^.Exists is set to true
                       if any resource has a baseline.  Else it is
                       unchanged.

                     - BaselineCheckContext^.DifferentBaselines is set to 
                       true if any resource has a baseline rate which differs
                       from its actual rate.  Else it is unchanged.


      Preconditions  - This procedure is called from within TraverseTree
                       within MakePlanIntoBaseLine.  Specificly, RsrcNode
                       is a valid TreeNode.
                       Context is a pointer to a structure,
                       ABaselineCheckContext.

      Postconditions - As noted above under outputs.


  *)

PROCEDURE CheckBaseLineForResource( VAR RsrcNode : ATreeNode;
                                        ContextA : ADDRESS );
VAR RsrcPtr            : AResourcePointer;
    Count              : CARDINAL;
    Context            : POINTER TO ABaselineCheckContext;
BEGIN
    Context := ContextA;

  (*<DEBUGGING

    ValidateTreeNode( RsrcNode );  (* Is this a valid tree node object? *)

    DEBUGGING>*)

    RsrcPtr := RsrcNode^.Methods^.GetDataObject(RsrcNode);

    WITH RsrcPtr^ DO
        IF (BaseLineRates <> ARateList(NIL)) THEN
            Context^.Exists := TRUE;
            IF (ActualRates = ARateList(NIL)) OR
               (NOT RateListsAreEqual(BaseLineRates,ActualRates)) THEN
                Context^.DifferentBaselines := TRUE;
            END;
        END;
        IF (BaselineAvailability <> ADateList(NIL)) THEN
            Context^.Exists := TRUE;
        END;
        IF (BaselineCalendar <> NIL) THEN
            Context^.Exists := TRUE;
        END;
    END;

END CheckBaseLineForResource;






  (* CheckBaseLineForTask - see if this task has a BaseLine.

      Preconditions  - This procedure is called from within TraverseTree
                       within MakePlanIntoBaseLine.  Specificly, TaskNode
                       is a valid TreeNode.
                       Context is a pointer to a boolean "AnyBaselines?"

      Postconditions - If the task has a baseline, Sets the context boolean.
  *)

PROCEDURE CheckBaseLineForTask( VAR TaskNode : ATreeNode;
                                    ContextA : ADDRESS );
VAR TaskPtr : ATaskPtr;
    Context : POINTER TO BOOLEAN;
BEGIN
    Context := ContextA;
    IF (Context^) THEN  (* Already found baseline. *)
        RETURN;
    END;

  (*<DEBUGGING  

    ValidateTreeNode( TaskNode );  (* Is this a valid tree node object? *)

    DEBUGGING>*)

    TaskPtr  := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    Context^ := (BaseLineExists IN TaskPtr^.TaskFlags);
    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);


END CheckBaseLineForTask;




  (* DelBaseLineForResource - Delete any BaseLine for this resource node.
                        This is to save as much memory room as possible
                        before the new allocations, and to avoid possible
                        memory/extended-memory fragmentation.

      Preconditions  - This procedure is called from within TraverseTree
                       within MakePlanIntoBaseLine.  Specificly, RsrcNode
                       is a valid TreeNode.
                       Context is ignored.

      Postconditions - If the task had a baseline, it is gone.
  *)

PROCEDURE DelBaseLineForResource( VAR RsrcNode : ATreeNode;
                                      ContextA : ADDRESS );
VAR RsrcPtr : AResourcePointer;
BEGIN

    RsrcPtr := RsrcNode^.Methods^.GetDataObject(RsrcNode);

    WITH RsrcPtr^ DO
        IF (BaseLineRates <> ARateList(NIL)) THEN
            DisposeRateList( BaseLineRates );
        END;
        IF (BaselineAvailability <> ADateList(NIL)) THEN
            DisposeDateList( BaselineAvailability );
        END;
        IF (BaselineCalendar <> NIL) THEN
            DisposeCalendar( BaselineCalendar );
        END;
    END;

END DelBaseLineForResource;






  (* DelBaseLineForTask - Delete any BaseLine for this task node.
                        This is to save as much memory room as possible
                        before the new allocations, and to avoid possible
                        memory/extended-memory fragmentation.

      Preconditions  - This procedure is called from within TraverseTree
                       within MakePlanIntoBaseLine.  Specificly, TaskNode
                       is a valid TreeNode.
                       Context is ignored.

      Postconditions - If the task had a baseline, it is gone.
  *)

PROCEDURE DelBaseLineForTask( VAR TaskNode : ATreeNode;
                                  ContextA : ADDRESS );
VAR TaskPtr : ATaskPtr;
BEGIN

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);

    WITH TaskPtr^ DO
        IF (BaseLineExists IN TaskFlags) THEN
            RemoveAssignmentsAndExpenses( BaseLine.Assignments );
            EXCL( TaskFlags, BaseLineExists );
        END;
    END;
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);

END DelBaseLineForTask;





PROCEDURE DelAndMakeForTask (   VAR Node        : ATreeNode;
                                    Context     : ADDRESS   );
BEGIN
    IF (TransferCosts) THEN
        DelBaseLineForTask (Node, Context);
    END;
    MakeBaseLineForTask (Node, Context);
END DelAndMakeForTask;




  (* BaseBaseLineForResource - Set up the BaseLine values for one RsrcNode.

      Preconditions  - This procedure is called from within TraverseTree
                       within MakePlanIntoBaseLine.  Specificly, RsrcNode
                       is a valid TreeNode, and Context is a boolean
                       telling if there are memory pressure problems.

      Postconditions - Plan is copied to BaseLine.
   *)

PROCEDURE MakeBaseLineForResource( VAR RsrcNode : ATreeNode; ContextA : ADDRESS);
VAR RsrcPtr : AResourcePointer;
    Context : POINTER TO BOOLEAN;
BEGIN
    Context := ContextA;

    RsrcPtr := RsrcNode^.Methods^.GetDataObject(RsrcNode);

    Message( RsrcPtr^.Name );

    WITH RsrcPtr^ DO
        IF (ActualRates <> ARateList(NIL)) THEN
            CopyRateList( BaseLineRates, ActualRates, ExtSlow );
            IF (BaseLineRates = ARateList(NIL)) THEN
                Context^ := FALSE;
            END;
        END;
        IF (Availability <> ADateList(NIL)) THEN
            CopyDateList( BaselineAvailability, Availability, ExtSlow );
            IF (Availability = ADateList(NIL)) THEN
                Context^ := FALSE;
            END;
        END;
        IF (Calendar <> NIL) THEN
            CopyCalendar( BaselineCalendar, Calendar );
            IF (Calendar = NIL) THEN
                Context^ := FALSE;
            END;
        END;
    END;

END MakeBaseLineForResource;







  (* BaseBaseLineForTask - Set up the BaseLine values for one TaskNode.

      Preconditions  - This procedure is called from within TraverseTree
                       within MakePlanIntoBaseLine.  Specificly, TaskNode
                       is a valid TreeNode, and Context is a boolean
                       telling if there are memory pressure problems.

      Postconditions - Plan is copied to BaseLine.
   *)

PROCEDURE MakeBaseLineForTask( VAR TaskNode : ATreeNode; AContext : ADDRESS);
VAR TaskPtr     : ATaskPtr;
    Context     : POINTER TO BOOLEAN;
    PA, BA      : AnExtHandle;
    Count       : CARDINAL;
    Assignments : AnAssignmentArray;
    StartDate,
    EndDate     : ADate;
    Rate        : REAL;

BEGIN

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);

    WITH TaskPtr^ DO
        Message( taskname );
        INCL(TaskFlags,BaseLineExists);

        IF (TransferDates) THEN
            BaseLine.Dates := Plan.Dates;
        END;

        (* 6-Aug-90 RSC removed EXCL of TempTaskFlag3. *)

        IF (TransferCosts) THEN
            BaseLineSummary.Time   := ToGoSummary.Time   + CompletedSummary.Time;
            BaseLineSummary.Amount := ToGoSummary.Amount + CompletedSummary.Amount;
            PA                     := Plan.Assignments;
            BA                     := AnExtHandle( NIL );
            BaseLine.Assignments   := BA;
        END;
    END;

    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);

    IF (TransferCosts) AND (ADDRESS(PA) <> NIL) THEN
        IF (CopyAssignments) THEN
            CopyOneAssignmentWithSpeed( PA, BA, ExtSlow );

            IF (ADDRESS(BA) = NIL) THEN
                Context  := AContext;
                Context^ := FALSE;
            ELSE
                    (* Make all effort in the future, AS IF this was yet-to-be-done.
                       This is depended on by Rollups and maybe others.  Ugh.
                    *)
                Count := LockObjectArray( BA, Assignments, TSIZE( AnAssignmentRecord ) );
                WHILE (Count > 0) DO
                    DEC(Count);
                    WITH Assignments^[Count] DO
                        YetToGoQuantity := YetToGoQuantity + ActualQuantity;
                        ActualQuantity  := Zero;
    
                        (* 2-Oct-90 RSC Zero out the varying assignment
                                        and expences, which we do not, at
                                        this time, want to copy.
    
                                        Otherwise, we should have used
                                        CopyAssignments.
                        *)
                        (* 14-Oct-90 AJL Dispose of these objects before making
                                         them NIL *)
                        IF (Expenses <> AnExtHandle(NIL)) THEN
                            DisposeExpenseArrayHandle(Expenses);
                        END;

                        (*  Commented out by EGK 9/5/91
                        IF (VaryingAssignment <> AnExtHandle(NIL)) THEN
                            DisposeVaryingAssgnList(VaryingAssignment);
                        END;
                        *)
                            (* Since we turn all the spent quantity into
                               to-go, we also need to turn back the
                               EndOfSpentDate to reflect this.  Here we use
                               the start date of the varying assignment
                               list.    -- EGK 9/5/91
                            *)

                        IF (VaryingAssignment <> AnExtHandle(NIL)) THEN
                            IF (GetVaryingAssgnListEntry
                                    (VaryingAssignment, 1,
                                     StartDate, EndDate, Rate)) THEN
                                EndOfSpentDate := StartDate;
                            END;
                        END;
                    END;
                END;
                ReleaseObject( BA );
            END;
        ELSE
            BA := AnExtHandle(NIL);
        END;

        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        TaskPtr^.BaseLine.Assignments := BA;
        TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);

    END;

END MakeBaseLineForTask;





PROCEDURE NotDoneBaseLine( VAR TaskNode : ATreeNode; AContext : ADDRESS);
VAR TaskPtr : ATaskPtr;
    NotDone : BOOLEAN;
BEGIN

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    NotDone := (TaskPtr^.StartStatus <> DoneS);
    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);

    IF (NotDone) THEN
        DelAndMakeForTask( TaskNode, AContext );
    END;

END NotDoneBaseLine;



PROCEDURE NoBaseLine( VAR TaskNode : ATreeNode; AContext : ADDRESS);
VAR TaskPtr : ATaskPtr;
    NoBase  : BOOLEAN;
BEGIN

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    NoBase  := NOT (BaseLineExists IN TaskPtr^.TaskFlags);
    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);

    IF (NoBase) THEN
        MakeBaseLineForTask( TaskNode, AContext );
    END;

END NoBaseLine;



PROCEDURE AskWhatToCopy(VAR TransferCosts, TransferDates : BOOLEAN);
VAR
    Text : ARRAY [0..255] OF CHAR;
    Menu : ARRAY [0..81] OF CHAR;
    Title: ARRAY [0..81] OF CHAR;
    Prefix : ARRAY [0..0] OF CHAR;
    Choice : CARDINAL;
BEGIN
    TransferDates := FALSE;
    TransferCosts := FALSE;

    GetMessage(ModuleNumber+WhatToCopyTitle,Title);
    GetMessage(ModuleNumber+WhatToCopyText,Text);
    GetMessage(ModuleNumber+WhatToCopyMenuText,Menu);
    SetLengthOf(Prefix,0);
    Choice := 1;
    IF NOT (MultipleChoiceBox(Text,Title,NoHelp,Prefix,Menu,Choice)) THEN
        RETURN;
    END;

    CASE Choice OF
        1 : 
            TransferCosts := TRUE;
      | 2 :
            TransferDates := TRUE;
      | 3 :
            TransferCosts := TRUE;
            TransferDates := TRUE;

        ELSE FatalError();
    END;

END AskWhatToCopy;



PROCEDURE AskAboutAssignments(      TransferCosts   : BOOLEAN;
                                VAR CopyAssignments : BOOLEAN);
VAR
    Text : ARRAY [0..255] OF CHAR;
    Menu : ARRAY [0..81] OF CHAR;
    Title: ARRAY [0..81] OF CHAR;
    Prefix : ARRAY [0..0] OF CHAR;
    Choice : CARDINAL;
BEGIN
    CopyAssignments := FALSE;

    IF (NOT TransferCosts) THEN
        RETURN;
    END;
 

    GetMessage(ModuleNumber+CopyAssignmentsTitle,Title);
    GetMessage(ModuleNumber+CopyAssignmentsText,Text);
    GetMessage(ModuleNumber+CopyAssignmentsMenuText,Menu);
    SetLengthOf(Prefix,0);
    Choice := 2;  (* Yes *)
    IF NOT (MultipleChoiceBox(Text,Title,NoHelp,Prefix,Menu,Choice)) THEN
        RETURN;
    END;

    CopyAssignments := ( Choice = 2 );

END AskAboutAssignments;











    (* CostToDate -- Compute the proportion of the Amount linearly
                     distributed from TaskStart to TaskEnd as of the 
                     AsOfDate. *)
PROCEDURE CostToDate(     Amount         : REAL;
                          TaskStart,
                          TaskEnd        : ADate   ) : REAL;
BEGIN
    IF (AsOfDate <= TaskStart) THEN
        RETURN Zero;
    ELSIF (TaskEnd <= AsOfDate) THEN
        RETURN Amount;
    ELSE
        RETURN ( FLOAT(AsOfDate-TaskStart) / FLOAT(TaskEnd-TaskStart) ) * Amount;
    END;
END CostToDate;


(* -------- ComputeDetailCostMeasures ---------------------------------

    A.  Compute the BCWS of each DETAIL task.   (RollupPlan will compute
        the BCWS of the summary tasks).

    B.  Compute the BCWP also.

*)



PROCEDURE ComputeDCostMeasures( VAR TaskNode : ATreeNode;           (* Created 9/13/89 AJL *)
                                    Context  : ADDRESS  );
VAR
    Task : ATaskPtr;
    Child : ATreeNode;
BEGIN
        (* Process only detail tasks. *)

    Child := TaskNode^.Methods^.FirstChild(TaskNode);

    IF (Child = NIL) THEN  (* A Summary Task *)

        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    
            (* Compute the BCWS and BCWP of each detail task. *)
    
        WITH Task^ DO
            IF (BaseLineExists IN Task^.TaskFlags) THEN
                BCWSDollars :=  CostToDate(BaseLineSummary.Amount,
                                           BaseLine.Dates.EarlyStart,
                                           BaseLine.Dates.EarlyEnd);
                BCWP  := FLOAT(PercentComplete)/OneHundred * BaseLineSummary.Amount;
            ELSE
                BCWSDollars := Zero;
                BCWP        := Zero;
            END;
        END;
    
        TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
    END;
END ComputeDCostMeasures;


PROCEDURE ComputeDetailCostMeasures();
BEGIN
    TaskTree^.Methods^.TraverseTree(TaskTree,ParentBeforeChild,
                    MAX(CARDINAL),ComputeDCostMeasures,
                    NIL   );
END ComputeDetailCostMeasures;







  (* MakePlanIntoBaseLine - Turn the "Planned" dates and assignments into
                            the "BaseLine" dates and Assignments.

     Preconditions  - The TaskTree is ready to go with 0 or more Tasks.
                      The task records were initialized such that the
                      BaseLine assignment handles are valid or NIL
                      (but not garbage).
                      Simularly the resource tree is valid.

     Postconditions - Any old BaseLine has been destroyed.
                      Planned has moved into BaseLine.
                      The "BaseLine Exists" flag is set in each task.
                      BaseLineRates is set up in each resource record.
   *)

PROCEDURE MakePlanIntoBaseLine();
VAR 
    Choice          : CARDINAL;
    Menu,
    Text            : ARRAY [0..255] OF CHAR;
    Title           : ARRAY [0..29]  OF CHAR;
    Prefix          : ARRAY [0..1]   OF CHAR;

    ResourceBaselineCheckContext,
    TaskBaselineCheckContext     : ABaselineCheckContext;
    MemoryTrouble   : BOOLEAN;
    Subtree         : ATree;
    Copyright       : ARRAY[0..50] OF CHAR;


    PROCEDURE EraseBaseLine();
    BEGIN
        ResourceTree^.Methods^.TraverseTree(ResourceTree, ParentBeforeChild, MaxLevels,
                                        DelBaseLineForResource, ADR(MemoryTrouble));
        TaskTree^.Methods^.TraverseTree(TaskTree, ParentBeforeChild, MaxLevels, 
                                        DelBaseLineForTask, ADR(MemoryTrouble));
    END EraseBaseLine;

    PROCEDURE MakeFullBaseLine();
    BEGIN
        ResourceTree^.Methods^.TraverseTree(ResourceTree, ParentBeforeChild, MaxLevels, 
                                        MakeBaseLineForResource, ADR(MemoryTrouble));
        TaskTree^.Methods^.TraverseTree(TaskTree, ParentBeforeChild, MaxLevels, 
                                        MakeBaseLineForTask, ADR(MemoryTrouble));
    END MakeFullBaseLine;


    PROCEDURE MakeStartedAndFuture();
    BEGIN
        TaskTree^.Methods^.TraverseTree(TaskTree, ParentBeforeChild, MaxLevels, 
                                        NotDoneBaseLine, ADR(MemoryTrouble));
    END MakeStartedAndFuture;


    PROCEDURE MakeNonBaseLine();
    BEGIN
        TaskTree^.Methods^.TraverseTree(TaskTree, ParentBeforeChild, MaxLevels, 
                                        NoBaseLine, ADR(MemoryTrouble));
    END MakeNonBaseLine;

    PROCEDURE BitchAtThem() : BOOLEAN;
    BEGIN
        IF (TransferCosts) THEN
            Title[0] := 0C;
            GetMessage(ModuleNumber+PartialBaseline,Text);
            IF (NOT ContinuationBox( Text, Title, NoHelp )) THEN
                RETURN FALSE;
            END;
            IF (ResourceBaselineCheckContext.DifferentBaselines) THEN
                GetMessage(ModuleNumber+ResourcesWithDifferingRates,Text);
                RETURN ContinuationBox( Text, Title, NoHelp );
            END;
        END;
        RETURN TRUE;
    END BitchAtThem;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    MemoryTrouble                   := FALSE;

    CopyAssignments := TRUE;
    TransferDates  := TRUE;
    TransferCosts  := TRUE;

    IF ((NOT (Scheduled IN ChartState)) OR (NOT ScheduleComputedOk)) THEN  (* 09-Nov-88 LAA *)
        GetMessage(ModuleNumber+NeedsCalcMessage,Text);
        GetMessage(ModuleNumber+NeedsCalcTitle  ,Title);
        WarningBox(Text,Title,OfferHelp);
        RETURN;
    END;

  (*<DEBUGGING  

    ValidateTree( TaskTree );  (* Is this a valid tree object? *)

    DEBUGGING>*)

    (* First pass is to see if any task or resource already HAS a baseline. *)

    WITH ResourceBaselineCheckContext DO
        Exists := FALSE;
        DifferentBaselines := FALSE;
    END;
    ResourceTree^.Methods^.TraverseTree(ResourceTree, ParentBeforeChild, MaxLevels, 
                                        CheckBaseLineForResource, 
                                        ADR(ResourceBaselineCheckContext) );
    IF (NOT ResourceBaselineCheckContext.Exists) THEN
        WITH TaskBaselineCheckContext DO
            Exists := FALSE;
            DifferentBaselines := FALSE;
        END;
        TaskTree^.Methods^.TraverseTree(TaskTree, ParentBeforeChild, MaxLevels, 
                                        CheckBaseLineForTask, ADR(TaskBaselineCheckContext) );
    END;

    IF (ResourceBaselineCheckContext.Exists) OR
       (TaskBaselineCheckContext.Exists) THEN
        GetMessage(ModuleNumber+BaseLineExistsMessage,Text);
        GetMessage(ModuleNumber+BaseLineMenuText     ,Menu);
        GetMessage(ModuleNumber+BaseLineExistsTitle  ,Title);
        SetLengthOf(Prefix,0);
        Choice := 1;
        IF NOT (MultipleChoiceBox(Text,Title,OfferHelp,Prefix,Menu,Choice)) THEN
            RETURN;
        END;

        CASE Choice OF

       (* Make whole new base line. *)

            1: EraseBaseLine();    (* Make whole new baseline *)
               DisplayMessage(ModuleNumber+BaseLineErasedMessage);
               AskAboutAssignments( TransferCosts, CopyAssignments );
               MakeFullBaseLine();
               DisplayMessage(ModuleNumber+BaseLineSetMessage);

       (* Started and future only *)

          | 2: 
               AskWhatToCopy(TransferCosts,TransferDates);
               IF (BitchAtThem()) THEN
                   AskAboutAssignments( TransferCosts, CopyAssignments );
                   MakeStartedAndFuture();
                   DisplayMessage(ModuleNumber+BaseLineSetMessage);
               END;

       (* Tasks and resources without baselines. *)

          | 3: 
               IF (BitchAtThem()) THEN
                   AskAboutAssignments( TransferCosts, CopyAssignments );
                   MakeNonBaseLine();
                   DisplayMessage(ModuleNumber+BaseLineSetMessage);
               END;

       (* Make baseline for cursor task only. *)

          | 4: 
               AskWhatToCopy(TransferCosts,TransferDates);
               IF (BitchAtThem()) THEN
                   AskAboutAssignments( TransferCosts, CopyAssignments );
                   DelAndMakeForTask (CursorTask, ADR(MemoryTrouble));
                   Subtree := CursorTask^.Methods^.GetSubtree (CursorTask);
                   IF (Subtree <> NIL) THEN
                       Subtree^.Methods^.TraverseTree (Subtree,
                                ParentBeforeChild, 9999, DelAndMakeForTask,
                                ADR(MemoryTrouble));
                   END;
                   DisplayMessage(ModuleNumber+BaseLineSetMessage);
               END;

       (* Reset all resources' baselines. *)

          | 5: 
               ResourceTree^.Methods^.TraverseTree(ResourceTree, ParentBeforeChild, MaxLevels,
                                        DelBaseLineForResource, ADR(MemoryTrouble));
               ResourceTree^.Methods^.TraverseTree(ResourceTree, ParentBeforeChild, MaxLevels, 
                                        MakeBaseLineForResource, ADR(MemoryTrouble));


       (* Erase all baselines. *)

          | 6: EraseBaseLine();  (* Erase all baselines *)
               DisplayMessage(ModuleNumber+BaseLineErasedMessage);

        ELSE
            FatalError(); (* unknown menu choice. *)
        END;

    ELSE
        AskAboutAssignments( TransferCosts, CopyAssignments );
        MakeFullBaseLine(); (* No prior baseline?  make a full one. *)
        DisplayMessage(ModuleNumber+BaseLineSetMessage);
    END;

        (* Recompute and rollup the task fields that rely on baseline
           information. *)

    ComputeDetailCostMeasures();

    RollupPlan(); (* Rollup actual   costs and %Achieved. *)
  
    IF (MemoryTrouble) THEN
        GetMessage(ModuleNumber+OutOfMemoryMessage,Text);
        GetMessage(ModuleNumber+OutOfMemoryTitle  ,Title);
        WarningBox(Text,Title,OfferHelp);
    END;

    ScheduleSaved := FALSE;                                    (* 23-Sep-90 *)

    UnSetState(Filtered);         (* Some filters reflect baseline info. *)

END MakePlanIntoBaseLine;


BEGIN

    MakePlanIntoBaseLine();

END TLMkBase.


