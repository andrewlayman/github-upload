 IMPLEMENTATION MODULE AssForms;


(*  =========================================================================
    Last Edit : June 18, 1991 9:32AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        
        AssForms - Handle the Assignment Forms, Cost Forms, Histories, and
                   other miscellanious Assignment/Cost record facilities.

    MODIFICATION HISTORY

      RSC  5/21/87 - Initial version.
      RSC  7/28/87 - revamped for new costing schemes.
      RSC  9/ 3/87 - Made simple version of form work.
      AJL 11/ 9/87 - Added ACursorAttribute to HighlightField.
      RSC 14/10/87 - Use Resource's Minimums for defaults in initting assgnment record.
      RSC 20/10/87 - Use Tasks effort scale to set initial assignment scale.
      RSC 26/10/87 - Catch all changes via SetFormChanges for task form.
                     Add procedure to determine what resources are on the form.
      RSC 12/08/87 - Convert tasks to EMS, modify EMS calls.
      RSC  1/26/88 - Made bucks fields into strings, not reals.  Worked on
                     cost calcs.
      RSC  1/31/88 - 1) Ajusted temp for a bug in FormatAs: AmountToReal, where
                        we need a TrimRear() before the call.  This can be changed
                        later, as I also changed AmountToReal.
                     2) Ajusted editing of ActualBucksField to support input
                        of bucks on the TRAS form.
      RSC  2/03/88 - 1) Removed temp fix in (1), above.
                     2) For var costs, if the actual goes greater than total,
                        treat like a resource.
                        Also set up vc the same as a resource (calc wise).
                     3) When SF8 is pressed and a resource exists, position
                        to the proper resource node.
      RSC  2/18/88 - Added new form for variable costs.   Arrrrrrrrghhhhhhh!
      RSC  2/24/88 - 1) Phrase changes for summary tasks (def change!)
                     2) Made titles longer, now that we have the new
                        "Title Interpreter" in Time Line's dialog boxes.
                     3) In "Is there work to go?", ignore negative numbers,
                        as they will be cought later in life by the assignment
                        form's exit checker.  (Shorten the task duration to be
                        too short, and some assignments' "ToGo" may go negative.)
                     4) Failed AddOne() calls reset the (bad) resource name.  This
                        fixes the case where you slightly alter an existing good name,
                        like hit a DEL, and POOF! the name dissapeared as a result of
                        the DeleteOne(); AddOne(); calls.
      EGK  10/31/88  Fixed AddOne so that it blanks the field if you refuse to
                     allow a duplicate assignment.
      RSC  11/23/88  Fix "too long" error.
      LAA  21-Dec-88 Changed imports for Laslo reorganization.
      RSC  2-Jan-89  Changed references to Compare() to StringsEqual().
      RSC  10-Jan-89 Changed Storage to Space    .
      EGK  07-Mar-89 Changed MapAssignmentForm to handle TotalAsTime as
                     a real-valued field (not a string), ActualUnitsField
                     as a display-only string field, and the new
                     TotalUnits field as a choice field.  Also changed
                     CheckAssignmentForm to use "TotalUnits" instead of
                     "ActualUnitsField".
      EGK  08-Mar-89 Changed SaveField to handle enterable total effort
                     field.  This also changed the code for handling
                     NumberField and PercentageField.
      EGK  09-Mar-89 Added "MakeAssignmentsRateDriven" procedure.
      EGK  12-Mar-89 Added "FindAssignmentErrors" procedure.
      EGK  21-Mar-89 Bumped up "MaxStringFieldsOnForm" to 10, to handle
                     the "mode indicators" on the assignment forms.
                     Allow percentages greater than UpperLimit if the
                     task is done.
      EGK  27-Mar-89 Change assignment to rate-driven if small task form.
      EGK  30-Mar-89 Changed to use FSMUPH instead of FLOAT(SMUPH).
      EGK  11-Apr-89 Changed SaveField to do more checking if the time
                     unit field is changed.
      RSC  25-Apr-89 Support for new SpreadSheetView stuff; "TaskIsOnTaskForm"
                     is now a notice.
                     Moved all code that actually runs an assignment form
                     to "TaskAssForm".
                     Removed "ZeroAssignmentWork" and "IsThereAssignmentWork".
                     Also "FindAssignmentErrors".
      RSC   1-Jun-89 Support new AssUtilities module.  Moved AssignmentPointer
                     to Assignments.Def
       EGK 4-Jun-89  Changed "ResourceDeleted" to "DeleteAResource" (big deal)
      RSC  13-Jun-89 Fixed bug where summary tasks recomputed incorrectly.
                     (bug # 466).
      RSC  26-Jun-89 Because assignment lists are no longer sorted, I had
                     to beef up the kluge where we manage the assignment
                     list in relation to the screen fields.
                     Also, fixed bug #584, SF8+ESC still brought up the
                     form.
      RSC   3-Aug-89 Found a case where we were not flagging changes back
                     to the task form: when one assignment was edited but
                     there were no other changes, recalc was not being set.
                     Added standard header to the module.
      RSC  10-Nov-89 When a resource is entered onto the task form (without
                     going through the forms), any error caused the field
                     to be blanked out.  I changed this so that if there
                     was an error, we don't recompute or resynch the task
                     form.
      KKC  21-Feb-90 Remove import of Timeu.
      RSC  28-Aug-90 Ajust for lack of assignment records in the
                     assignment tree.  This makes the code much simpler
                     and more direct.
      RSC  23-Sep-90 Provide a function for the task form to determine
                     if there are any kind of resources on the form,
                     not just costs.
      RSC  30-Nov-90 Fixed bug in ResourcesAssignedToTask where it was
                     treating the tree as containing pointers to assignment
                     records rather than indexes into the assignment array
                     in the task.
      AJL   7-Jan-90 When the percent achieved is entered, and not doing
                     cost tracking, update all spent efforts on the task.

      22-Jan-91 RSC  Removed spurious import of TimeFormat.
       8-Feb-91 RSC  Removed other unneeded imports.
       7-May-91 RSC  Removed unused strings and their GetMessage calls.
                     When no item on the resource section of the task form,
                     put up the default message.  Made "MyContext" a
                     heap item rather than global memory.
      11-Jun-91 RSC  Moved in a local display proc, the one used in V4.0,
                     because the generic one in AssList wasn't doing a
                     good job.  Also allow processing for CheckFieldExit.
      17-Jun-91 RSC  Bug # 4295.  Removed the assignment tree alltogeather,
                     it did little for us.  It was a nice idea, but cost
                     a lot for little return.  Removed the ASSLIST module.
                     This had the side effect of fixing the bug.
      12-Aug-91 AJL  In RecomputeTaskOnForm, Compute the task node costs,
                     possibly redistributing the efforts, BEFORE updating
                     the efforts to match the percents achieved.
    19-Aug-91 TGS   Run RecomputeTaskOnForm only when assignments have 
                    changed, not when we're just looking ([F2] on existing
                    assignment).
    30-Aug-91 TGS   Don't do a RecomputeTask on (Task) FormExit unless
                    an assignment really changed. (bug 5008)
    19-Sep-91 TGS   Move the CheckStatusChange check to TLChange.FormWrapUp.
    08-Oct-91 LAA   In RecomputeTaskOnForm, we were updating the effort for
                    percent complete, then unlocking UNCHANGED the task
                    record!  Tsk, tsk.  I guess we just got lucky that it
                    didn't screw things up - or maybe we would have found
                    it after shipping, like we did with the cross-tab bug
                    in version 4.0.  So I fixed it.
    29-Jan-92 TGS   Format the NumberOf resources/varycosts as a real.
    =========================================================================
*)

FROM Allocs                     IMPORT
      (* TYPES *)                  AFixType, ATaskPtr, ATask, ADurationMethod,
                                   AStartStatus, AnAssignmentSummary,
                                   ARollupStatus;

FROM AsOf                       IMPORT
      (* VAR   *)                  AsOfDate;

FROM Assignments                IMPORT
      (* TYPES *)                  AnAssignmentAttribute,
                                   AnAssignmentAttributeSet,
                                   AnAssignmentRecord,
                                   AnAssignmentArray,
                                   AnAssignmentProc,
                                   AnAssignmentPointer,
      (* VAR   *)                  AssTree,
      (* PROCS *)                  ForEachAssignment,
                                   InitAssignment,         
                                   DisposeOneAssignmentRecordContents,
                                   RemoveAssignmentsAndExpenses;

FROM Changer                    IMPORT
      (* TYPE *)                   AnAssignmentField,
                                   AFormMappingRecord,
                                   AnAssignmentForm,
      (* VAR  *)                   FormMappingRecords,
                                   UsesCostTracking;


FROM Dialog                     IMPORT
      (* PROCS *)                  Error, FatalError, Message;

FROM EffDone                    IMPORT
    (* PROC *)                     UpdateEffortToMatchRatio;

FROM FlexStor                   IMPORT
      (* TYPE *)                   AnExtHandle,
                                   AnExtStoragePreference,
      (* PROC *)                   GetExtSize, GetExtData, SetExtData,
                                   CreateExtObjectWithSize, DiscardExtObject,
                                   HandleIsValid, CopyExtObject, SetExtSize,
                                   ArraySize, LockObjectArray, ReleaseObject,
                                   ReleaseUnchangedObject, NumberOfElements;

FROM RealFormat                 IMPORT
    (* VAR  *)                      DefaultCurrencyFormat, DefaultAmountFormat,
    (* PROC *)                      FormatAsCurrency, FormatAsAmount;

FROM Forms                      IMPORT
      (* TYPES *)                  AFieldValue, AStringValue, AForm,
                                   ACheckReason, ACursorAttribute,
      (* PROCS *)                  DoForm, HighlightField,
                                   SetFormChange,
                                   SetFieldProtection, ShowValue;

FROM FormCon                    IMPORT
      (* TYPES *)                  AFieldNo;

FROM Keys                       IMPORT
      (* CONST *)                  DoIt, EditKey, ResourceFormKey, ExitKey;

FROM LStrings                   IMPORT
      (* PROCS *)                  RJust, Fill, SetString, ConcatS, ConcatLS,
                                   LJust, SubStr, TrimRear, Upshift, CtoS,
                                   LengthOf, SetLengthOf, Procustes,
                                   StringsEqual, TrimFront, Copy;

FROM MsgFile                    IMPORT
      (* PROCS *)                  GetMessage, ConcatMessage, DisplayMessage;

FROM Paranoia                   IMPORT
      (* TYPE *)                   AnAnxietyLevel,
      (* VAR  *)                   AnxietyLevel;

FROM RsrcCalc                   IMPORT
    (* TYPE *)                     AnAssignmentCostType,
                                   AnAssignmentCostTypeSet,
    (* PROCS *)                    ComputeTaskNodeCosts, AssignmentCost;

FROM RsrcEdit                   IMPORT
      (* PROCS *)                  SelectResource;

FROM RsrcMod                    IMPORT
      (* TYPE *)                   AResourcePointer, ACostStyle,
                                   AResourceType, 
      (* VARS *)                   ResourceTree,
      (* PROC *)                   FindResourceByName, AverageResourceRate;

FROM TaskAssForms               IMPORT
    (* PROC *)                      DoAssignmentForm;

FROM Timei                      IMPORT
    (* TYPE *)                     ADate, ADurationUnit;

FROM TreeObjects                IMPORT
      (* TYPE *)                   ATree, ATreeNode,
      (* PROC *)                   CreateTree;

FROM Space                      IMPORT
    (* PROC *)                      HeapAvailable, ALLOCATE, DEALLOCATE,
                                    Available;

(*  19-Sep-91 TGS
FROM StatusChange               IMPORT
    (* PROC *)                      CheckStatusChange,
                                    DefaultStatusDialogProc;
*)

FROM SYSTEM                     IMPORT
      (* THING *)                  ADDRESS, ADR, SIZE, TSIZE;





CONST
    ModuleNumber = 17800; (* MODULE NUMBER SHARED WITH TASKASSFORMS *)
    AssListModuleNumber = 4900; (* AssList.Mod's number *)


    ResourcesOnTaskForm = 24; (* As Of 8/10/87 *)

    Zero         = 0.0;
    Point5       = 0.5;
    OneHundred   = 100.0;
    MAXCARDINAL  = 65535;
    FMAXCARDINAL  = 65535.0; (* FLOAT(MAXCARDINAL) *)

    ResourceNameSize = 10;   (* Size of a resource field *)

    PositionEmpty = MAXCARDINAL; (* for PositionOnForm *)




TYPE
  (* Save heap space be allocating only the bytes needed for the fields. *)

    AResourceFieldPair = RECORD
        ConflictField    : ARRAY [0..1] OF CHAR;  (* One byte field     *)
        NameField        : ARRAY [0..ResourceNameSize] OF CHAR;
    END;



    (* Form local context.  Not yet supported by FORMS. *)

    ALocalFormContext = RECORD

        TaskOnForm          : ATreeNode;

        TaskStartDate,
        TaskEndDate         : ADate;

            (* 17-Jun-91 RSC The handle to the assignment records.
            *)
        AssignmentHandle    : AnExtHandle;

            (* 17-Jun-91 RSC Was TreePositionOnForm, now is the index
                             into the assignment array.  This allows the
                             array to be in one order, and the form to
                             have a different order.
                             Also made it 0-based, like the form values
                             passed in to procedures.
            *)
        PositionOnForm      : ARRAY [0..ResourcesOnTaskForm-1] OF CARDINAL;

            (* Form string fields, non pointer, for speed of allocation *)

        LastFormValueField  : CARDINAL;
        FormFields          : ARRAY [1..ResourcesOnTaskForm] OF AResourceFieldPair;

        GlobalScale         : ADurationUnit;

        PressF2Phrase,
        PercentAssignedPhrase : ARRAY [0..39] OF CHAR;
        F2toAddPhrase         : ARRAY [0..79] OF CHAR;

        FormFieldChanges,
        EverAnyAssignments,
        F10WithChanges        : BOOLEAN;  (* FormFieldChanges=TRUE when F10 hit *)
    END;


VAR
    MyContext           : POINTER TO ALocalFormContext;  (* Simulated Form Context *)









(* Resources Assigned To Task

        Are there any resources (not costs) assigned to this task?

        Preconditions - "MyContext" must be set up already.

        Postconditions - none.

        Input - none

        Output - RETURNs TRUE iff there are resources assigned to the task.
*)
PROCEDURE ResourcesAssignedToTask() : BOOLEAN;
VAR
    Assignments     : AnAssignmentArray;
    Count           : CARDINAL;
    Found           : BOOLEAN;
BEGIN
    IF (MyContext = NIL) THEN
        RETURN FALSE;
    END;

    Count := LockObjectArray( MyContext^.AssignmentHandle, Assignments, TSIZE( AnAssignmentRecord ));
    Found := FALSE;
    WHILE (Count > 0) AND (NOT Found) DO
        DEC(Count);
(*$O-*)
        Found := (Assignments^[Count].Resource^.Type = Employable);
(*$O=*)
    END;
    ReleaseUnchangedObject( MyContext^.AssignmentHandle );

    RETURN Found;

END ResourcesAssignedToTask;






 (* MakeAssignmentsRateDriven - Set the calculation mode on all the
                                resource assignments so that the
                                rate is the controlling factor
                                (i.e., NOT the total effort).

        Preconditions  - SetupTaskForm has been called, and we have our
                         assignment work array set up.

        Postconditions - Task form's assignments will now calculate based
                         on the rate (number and percentage each).

  *)

PROCEDURE MakeAssignmentsRateDriven ();
VAR
    Assignments : AnAssignmentArray;
    Count       : CARDINAL;
BEGIN
    IF (MyContext = NIL) THEN
        RETURN;
    END;

    WITH MyContext^ DO
        Count := LockObjectArray( AssignmentHandle, Assignments, TSIZE( AnAssignmentRecord ) );
        WHILE (Count > 0) DO
            DEC(Count);
(*$O-*)
            EXCL (Assignments^[Count].Attributes, ComputeByHours);
(*$O=*)
        END;
        ReleaseObject( AssignmentHandle );
    END;
END MakeAssignmentsRateDriven;







(* Assignment Tree To Task Form

        Map the assignment tree to the task form values array.

    Preconditions
                    Setup       Position the records sequentially?
                    FormValue   the form values array.  We fill in the
                                "StartWith" to last positions.  All
                                CharValue pointers are filled in.
                    StartWith   Where to start filling in the array.

    Postconditions
                    FormValue
*)
PROCEDURE AssignmentsToTaskForm( VAR FormValue : ARRAY OF AFieldValue;
                                        StartWith : CARDINAL );
CONST
    ConflictCharacter = 20C;
VAR
    Assignments : AnAssignmentArray;
    Count,
    Position,
    Loop        : CARDINAL;
    Index       : CARDINAL;
BEGIN
    FOR Loop := StartWith TO MyContext^.LastFormValueField DO
        FormValue[ Loop ].CharValue^[0] := 0C;
    END;
    IF (MyContext = NIL) THEN
        RETURN;
    END;

    WITH MyContext^ DO
        Count := LockObjectArray( AssignmentHandle, Assignments, TSIZE( AnAssignmentRecord ) );
        FOR Loop := 0 TO HIGH(PositionOnForm) DO
            Index := PositionOnForm[Loop];
            IF (Index <> PositionEmpty) THEN
(*$O-*)
                WITH Assignments^[Index] DO
                    Position   := StartWith + (Loop * 2);
                    IF (Overloaded IN Attributes) THEN
                        Fill(FormValue[ Position ].CharValue^,ConflictCharacter,1);
                    END;
                    Copy( Resource^.Name, FormValue[ Position + 1 ].CharValue^ );
                END;
            END;
        END;
(*$O=*)
        ReleaseUnchangedObject( AssignmentHandle );
    END;

END AssignmentsToTaskForm;








  (* Setup Task Form Assignments - We are about to enter the task form, so
                we need to get a copy of the real world.  We need a COPY,
                because they can hit <Escape> on the form and we need to
                NOT save everything.

          Preconditions - Task pointer must be valid.  FormValue is a big 
                   array, and we start dealing with it at position
                   "FirstResourceField".  WE initialize it and such.

          Postconditions - FormValue is ready to be passed to DoForm for 
                    our fields.  StoreTaskFormAssignments MUST be called
                    upon exit from the form.
  *)

PROCEDURE SetupTaskFormAssignments(     LocalTaskNode      : ATreeNode;
                                    VAR FormValue          : ARRAY OF AFieldValue;
                                        FirstResourceField : CARDINAL );
VAR
    Loop,
    i       : CARDINAL;
    Task    : ATaskPtr;
    Node    : ATreeNode;
BEGIN
    IF (Available(TSIZE(ALocalFormContext))) THEN
        NEW(MyContext);
    ELSE
        MyContext := NIL;
        i := FirstResourceField;
        FOR Loop := 1 TO ResourcesOnTaskForm * 2 DO
            FormValue[ i ].CharValue := NIL;
            INC(i);
        END;
        RETURN;
    END;


    i := FirstResourceField;
    FOR Loop := 1 TO ResourcesOnTaskForm DO
        FormValue[ i ].CharValue     := ADR( MyContext^.FormFields[ Loop ].ConflictField );
        FormValue[ i ].CharValue^[0] := 0C;
        FormValue[ i ].CardValue     := Loop;
        INC(i);
        FormValue[ i ].CharValue     := ADR( MyContext^.FormFields[ Loop ].NameField );
        FormValue[ i ].CharValue^[0] := 0C;
        FormValue[ i ].CardValue     := Loop;
        INC(i);
    END;
    (* DEBUGGING *) IF (i <> (HIGH(FormValue) + 1)) THEN FatalError(); END;

    WITH MyContext^ DO

        TaskOnForm         := LocalTaskNode;

        LastFormValueField := HIGH(FormValue);
        GetMessage(ModuleNumber+1,PercentAssignedPhrase);  (* "assigned at" *)
        GetMessage(ModuleNumber+3,PressF2Phrase);      (* "Press F2 for details" *)
        GetMessage(ModuleNumber+32,F2toAddPhrase);     (* "Press F2 to add assignment" *)
        F10WithChanges := FALSE;

        (* Create the assignment PositionOnForm array.
           Store the assignment handle.
           Save the task dates.
        *)

        Task  := LocalTaskNode^.Methods^.LockFlexStorDataObject(LocalTaskNode);
        WITH Task^.Plan DO
            TaskStartDate    := Dates.EarlyStart;
            TaskEndDate      := Dates.EarlyEnd;
            AssignmentHandle := Assignments;
            GlobalScale      := Task^.EffortScale;
        END;
        LocalTaskNode^.Methods^.UnlockUnchangedDataObject(LocalTaskNode);

        FOR Loop := 0 TO HIGH(PositionOnForm) DO
            PositionOnForm[Loop] := PositionEmpty;
        END;

        i := NumberOfElements( GetExtSize( AssignmentHandle ), TSIZE(AnAssignmentRecord));

        EverAnyAssignments := (i > 0);

        IF (EverAnyAssignments) THEN
            FOR Loop := 0 TO i-1 DO
                PositionOnForm[Loop] := Loop;
            END;
        END;

        AssignmentsToTaskForm( FormValue, FirstResourceField );
    END;

END SetupTaskFormAssignments;








  (* Store Task Form Assignments - The task form is exiting.

          Preconditions - Task node must be valid.

          Postconditions - Task is set appropriately.
                    RETURN is TRUE  if changes were made and saved.
                              FALSE if no changes made and saved.

                    StoreTaskFormAssignments MUST be called
                    upon exit from the task form.

  *)

PROCEDURE StoreTaskFormAssignments(     TaskNode : ATreeNode ) : BOOLEAN;
VAR
    LocalF10WithChanges : BOOLEAN;
BEGIN

    IF (MyContext = NIL) THEN
        LocalF10WithChanges := FALSE;
    ELSE
        LocalF10WithChanges := MyContext^.F10WithChanges;
        DISPOSE(MyContext);
    END;

    RETURN LocalF10WithChanges;

END StoreTaskFormAssignments;






(* Recompute Task On Form - recompute the task that is currently on the
                            task form.
*)
PROCEDURE RecomputeTaskOnForm(     TaskNode           : ATreeNode );
VAR
   LCompletedSummary,
   LToGoSummary         : AnAssignmentSummary;
   Task                 : ATaskPtr;
   Assignment           : AnAssignmentRecord;
BEGIN
    IF (MyContext = NIL) THEN
        RETURN;
    END;

    WITH MyContext^ DO
        (* If there were never any assignments on this task form,
           preserve the completed and to go summaries.  This allows
           someone on the task form to enter an effort and then
           later add assignments.

           RSC 13-Jun-89  Oh, yes, summary tasks cannot have effort
                          entered, so avoid this, as it produces
                          strange results (Effort on summary task
                          clicks up when no resources on summary,
                          but on kids).
        *)
        IF (NOT EverAnyAssignments) AND
           (TaskNode^.Methods^.FirstChild(TaskNode) = NIL) THEN
            Task  := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
            WITH Task^ DO
                LCompletedSummary    := CompletedSummary;
                LToGoSummary         := ToGoSummary;
            END;
            TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);

            ComputeTaskNodeCosts( TaskNode );

            Task  := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
            WITH Task^ DO
                IF (rollupstatus = NotRollup) THEN
                    CompletedSummary    := LCompletedSummary;
                    ToGoSummary         := LToGoSummary;
                END;
                TaskStartDate := Plan.Dates.EarlyStart;
                TaskEndDate   := Plan.Dates.EarlyEnd;
            END;
            TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
        ELSE
            ComputeTaskNodeCosts( TaskNode );

            Task  := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
            WITH Task^.Plan DO
                TaskStartDate := Dates.EarlyStart;
                TaskEndDate   := Dates.EarlyEnd;
            END;
            IF (NOT UsesCostTracking) THEN
                (* Unless cost tracking is on, update the task so that
                   the Percent Achieved causes a proportional amount of
                   the effort to be recorded as spent. *)

                UpdateEffortToMatchRatio(Task^, FLOAT(Task^.PercentComplete)/OneHundred);
                TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);         (* 08-Oct-91 *)
            ELSE
                TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
            END;
        END;

    END;

END RecomputeTaskOnForm;











 (* HandleTaskFormFieldChange - see if a field has changed, and, if so,
                    handle that change.

        Preconditions  - A Value from the form.
                         "Edit" = "Was the EDIT key pressed?".

        Postconditions - Form value is ajusted if needed, and
                         an assignment may have been created/deleted.
                         Returns TRUE if everything is OK.  Returns
                         FALSE if we should fuss at the customer
                         with complaint <module> + "Fuss".
                         Change means "Did we change the resource list?".
 *)

PROCEDURE HandleTaskFormFieldChange ( VAR Value     : AFieldValue;
                                          FormEntry : CARDINAL;
                                          Edit      : BOOLEAN;
                                          Code      : CARDINAL;
                                          Form      : AForm;
                                      VAR NeedCompute : BOOLEAN
                                    ) : BOOLEAN;
VAR 
    Resource            : ATreeNode;
    ResourcePtr         : AResourcePointer;
    Count               : CARDINAL;
    CursorIndex         : CARDINAL;
    Assignments         : AnAssignmentArray;
    EnteredName,
    AssignmentName      : ARRAY [0..ResourceNameSize] OF CHAR;
    Ok                  : BOOLEAN;


  (* Game Plan -
         1) If the field was blank, and is still blank (we hope this
            is the 90% case), no problem.
         2) If the field was blank, and is not now, add a resource.
         3) If the field was NOT blank, and is now, delete the resource.
         4) If the field was NOT blank, and is still not blank, see if
            they are the same.  If not, delete the old and add the new.

     Notes:
         1) The field was blank before IFF the resource is NIL
            (This was set up by FillInTaskFormValues).
         2) The field is blank now IFF the length of the char value, after
            trimming, is 0.
         3) If a resource assignment has expense records, then the assignment
            CANNOT BE DELETED (They have to manually delete all expenses).
         4) If a resource name does not exist, then we force them onto the
            "Pick a resource name" form if they press <Edit>.  Otherwise
            we fuss.
  *)


    (* Add one assignment record to the end of the assignment list.
    *)
    PROCEDURE AddADefaultAssignment(     RsrcPtr    : AResourcePointer;
                                     VAR AddedEntry : CARDINAL ) : BOOLEAN;
    VAR
        Task        : ATaskPtr;
        i,
        Count       : CARDINAL;
        Assignments : AnAssignmentArray;
        AssignmentRecord : AnAssignmentRecord;
        s           : ARRAY [0..255] OF CHAR;
        Same        : BOOLEAN;
    BEGIN
            (* 17-Jun-91 RSC Code borrowed from AssList.Mod
            *)
            (* 5-Feb-91 RSC Logic was wrong here, fixed bug # 4103.
            *)
        Same  := FALSE;
        Count := LockObjectArray( MyContext^.AssignmentHandle, Assignments, TSIZE( AnAssignmentRecord ) );
        i     := Count;

        WHILE (i > 0) AND (NOT Same) DO
            DEC(i);
(*$O-*)
            Same := ( RsrcPtr = Assignments^[i].Resource );
(*$O=*)
        END;

        ReleaseUnchangedObject( MyContext^.AssignmentHandle );

        IF (Same) THEN
                (* 29-Jan-91 TGS disallow duplicate assignments *)
            GetMessage(AssListModuleNumber+11,s); (* "Duplicate assignment not allowed" *)
            Error(s);
        ELSE
            InitAssignment(ResourcePtr,AssignmentRecord);
            AssignmentRecord.ActualTimeUnits := MyContext^.GlobalScale;
            INC(Count);
            IF (Count = 1) THEN
                (* Creating the FIRST assignment record.
                *)
                IF (NOT CreateExtObjectWithSize( MyContext^.AssignmentHandle, ExtMedium, TSIZE(AnAssignmentRecord) )) THEN
                    RETURN FALSE;
                END;
                    (* Fill in the task record, so that the resource
                       cannot be deleted.
                    *)
                WITH MyContext^ DO
                    Task := TaskOnForm^.Methods^.LockFlexStorDataObject(TaskOnForm);
                    Task^.Plan.Assignments := AssignmentHandle;
                    TaskOnForm^.Methods^.UnlockFlexStorDataObject(TaskOnForm);
                END;
            ELSE
                IF (NOT SetExtSize(MyContext^.AssignmentHandle, ArraySize( Count, TSIZE(AnAssignmentRecord)))) THEN
                    RETURN FALSE;
                END;
            END;
            Count := LockObjectArray( MyContext^.AssignmentHandle,
                                      Assignments,
                                      TSIZE( AnAssignmentRecord ) );
            AddedEntry               := Count - 1;
(*$O-*)
            Assignments^[AddedEntry] := AssignmentRecord; (* Last one! *)
(*$O=*)
            ReleaseObject( MyContext^.AssignmentHandle );
        END;

        RETURN (NOT Same);

    END AddADefaultAssignment;



    (* The logic to Add.
    *)
    PROCEDURE AddOne() : BOOLEAN;
    VAR
        NewEntry    : CARDINAL;
    BEGIN
      (* See if the resource exists now.  If not, if they hit the edit key
         and they pick a resource, great, else fuss. *)

        Copy( EnteredName, Value.CharValue^ );  (* RSC 2/24/88 as a first cut, make it this... *)

        Resource := FindResourceByName( EnteredName );
        IF Resource = NIL THEN
            IF (NOT (Edit AND SelectResource(Resource) AND (Resource <> NIL))) THEN
                DisplayMessage( ModuleNumber + 4 ); (* "You can see a list of resources by [F2]" *)
                RETURN FALSE;
            END;
        END;

        SetFormChange( Form );
        ResourcePtr := Resource^.Methods^.GetDataObject( Resource );

        IF (AddADefaultAssignment( ResourcePtr, NewEntry )) THEN
            MyContext^.EverAnyAssignments := TRUE;
            Copy(ResourcePtr^.Name, Value.CharValue^);
            MyContext^.PositionOnForm[FormEntry] := NewEntry;
        ELSE
            SetLengthOf (Value.CharValue^, 0);            (* 10/31/88 EGK *)
            RETURN FALSE;
        END;

        MyContext^.F10WithChanges := TRUE; (* Well, they added a new assignment. *)

        RETURN TRUE;
       
    END AddOne;



    PROCEDURE DisposeOfAssignmentNodeAndData( Index : CARDINAL );
    VAR
        Task        : ATaskPtr;
        i,
        Count       : CARDINAL;
        Assignments : AnAssignmentArray;
        ok          : BOOLEAN;
    BEGIN

            (* Remove any trace of this assignment record (including
               any var assignment records and such).  Crush the
               assignment array down to size, copying records after
               the one being deleted down by one slot.
            *)
        WITH MyContext^ DO
            Count := LockObjectArray( AssignmentHandle,
                                      Assignments,
                                      TSIZE( AnAssignmentRecord ));
(*$O-*)
            DisposeOneAssignmentRecordContents(Assignments^[Index]);
            i := Index;
            IF (Count > 1) THEN
                WHILE (i < (Count - 1)) DO      (* 26-Sep-90 PFG *)
                    Assignments^[i] := Assignments^[i+1];
                    INC(i);
                END;
            END;
(*$O=*)
            ReleaseObject( AssignmentHandle );

                (* If there was only one assignment, discard the handle,
                   removing the assignments entirely.  If there were more
                   than one, lower the size by one record.  Since we have
                   already copied records down, we won't lose anything.
                *)
            IF (Count = 1) THEN
                DiscardExtObject( AssignmentHandle );
                AssignmentHandle := AnExtHandle(NIL);
                    (* Fill in the task record, so that the resource
                       cannot be deleted.
                    *)
                Task := TaskOnForm^.Methods^.LockFlexStorDataObject(TaskOnForm);
                Task^.Plan.Assignments := AssignmentHandle;
                TaskOnForm^.Methods^.UnlockFlexStorDataObject(TaskOnForm);
        
            ELSE
                (* Since we are shrinking the handle, don't wory about errors...
                *)
                ok := SetExtSize( AssignmentHandle, ArraySize( Count-1, TSIZE( AnAssignmentRecord )));
                IF (NOT ok) THEN
                    FatalError();
                END;
            END;

                (* Reflect in the indexes the fact that this one has
                   vanished.
                *)
            FOR i := 0 TO HIGH(PositionOnForm) DO
                IF (PositionOnForm[i] >  Index) AND
                   (PositionOnForm[i] <> PositionEmpty) THEN
                    DEC(PositionOnForm[i]);
                END;
            END;
        END;

    END DisposeOfAssignmentNodeAndData;



    (* Next, the logic to delete. *)

    PROCEDURE DeleteOne() : BOOLEAN;
    BEGIN
        WITH MyContext^ DO
            Value.CharValue^[0] := 0C;
            F10WithChanges := TRUE; (* Well, they deleted an assignment. *)
            SetFormChange( Form );
            DisposeOfAssignmentNodeAndData(PositionOnForm[FormEntry]);
            PositionOnForm[FormEntry] := PositionEmpty;
        END;

        RETURN TRUE;

    END DeleteOne;


    (* Given a resource pointer, find its node.  This could be slow. *)

    PROCEDURE FindResource( ResourcePtr  : AResourcePointer ) : ATreeNode;
    VAR
        ResourceNode : ATreeNode;
    BEGIN
        ResourceNode := ResourceTree^.Methods^.GetFirst( ResourceTree );
        WHILE (ResourceNode <> NIL) DO
            IF (ResourcePtr = ResourceNode^.Methods^.GetDataObject( ResourceNode )) THEN
                RETURN ResourceNode; (* We found the proper resource node! *)
            END;
            ResourceNode := ResourceNode^.Methods^.GetNext( ResourceNode );
        END;

        RETURN ResourceNode;

    END FindResource;


BEGIN  (* MAIN for HandleTaskFormFieldChange *) 

  (* Set "EnteredName" as a copy of the char value, all trimmed and upshifted. *)

    Copy( Value.CharValue^, EnteredName );
    TrimFront(EnteredName);
    TrimRear(EnteredName);
    Upshift(EnteredName);

    CursorIndex := MyContext^.PositionOnForm[FormEntry];

  (* Was it blank before? *)

    IF (CursorIndex = PositionEmpty) THEN

    (* Is it blank now? Did we want to edit it? *)

        IF (NOT Edit) AND (LengthOf(EnteredName) = 0) THEN
            RETURN TRUE;   (* No Edit, Is blank, was blank.  My kinda guy. *)
        END;

        RETURN AddOne();   (* Was blank.  Wants a new assignment. *)

    ELSE

    (* It was filled in before. *)    

        Count := LockObjectArray( MyContext^.AssignmentHandle, Assignments, TSIZE( AnAssignmentRecord ));
(*$O-*)
        Copy( Assignments^[CursorIndex].Resource^.Name , AssignmentName );
(*$O=*)

        (* It was filled in, 
               IF they hit <ResourceFormKey> (not <Edit>),
                   Bring up the resource list and let them select a name.
                   If they do, then make it into a change. (del & add)
        *)
           
        IF (Edit AND (Code = ResourceFormKey)) THEN
(*$O-*)
            Resource := FindResource( Assignments^[CursorIndex].Resource );
(*$O=*)
            IF (SelectResource(Resource) AND (Resource <> NIL)) THEN
                ResourcePtr := Resource^.Methods^.GetDataObject(Resource);
                Copy(ResourcePtr^.Name,EnteredName);
                TrimFront(EnteredName);
                TrimRear(EnteredName);
                Upshift(EnteredName);
            ELSE
                ReleaseUnchangedObject( MyContext^.AssignmentHandle );
                RETURN FALSE;   (* RSC 26-Jun-89 *)
            END;
        END;

        ReleaseUnchangedObject( MyContext^.AssignmentHandle );

        IF (LengthOf(EnteredName) = 0) THEN   (* Was filled in, is now blank. *)
            Ok := DeleteOne();
            IF Edit THEN 
                Ok := (Ok AND AddOne());
            END;
            RETURN Ok;
        END;

    (* It was filled in.  It is now filled in.  Did it change? *)

        TrimFront(AssignmentName);
        TrimRear(AssignmentName);
        Upshift(AssignmentName);
        IF (StringsEqual( EnteredName, AssignmentName )) THEN
            NeedCompute := FALSE; (* 19-Aug-91 TGS *)
            RETURN TRUE;  (* It did NOT change. *)
        END;

        RETURN (DeleteOne() AND AddOne()); (* Did change. *)

    END;

END HandleTaskFormFieldChange;













PROCEDURE IdentifyResource( VAR Assignment   : AnAssignmentRecord;
                            VAR s            : ARRAY OF CHAR );
VAR
    R                   : REAL;
    P                   : CARDINAL;
    s1                  : ARRAY [0..19]  OF CHAR;
BEGIN

    SetLengthOf(s,0);

    WITH Assignment DO
        CASE Resource^.CostStyle OF
          CAmount:
                ConcatLS(s,Resource^.Name);
                ConcatS(  s, ": " );
                R := (ActualQuantity + YetToGoQuantity);
                FormatAsCurrency( R,  DefaultCurrencyFormat,
                                  s1, HIGH(s1),
                                  FALSE,   (* Right Justify? *)
                                  TRUE,    (* Show fractions? *)
                                  TRUE  ); (* Show Dollar Sign? *)
                TrimRear(s1);
                ConcatLS(s,s1);
        | CAmountRate:
                ConcatLS( s,Resource^.Name);
                ConcatS(  s, ": " );
                R := (ActualQuantity + YetToGoQuantity);
                FormatAsAmount( R,
                                DefaultAmountFormat, 
                                s1, HIGH(s1), 0, 4, FALSE );                   
                TrimRear(s1);
                ConcatLS(s,s1);
                ConcatS(  s, " " );
                ConcatLS(s,Resource^.UnitOfMeasure);
                TrimRear(s);
                ConcatS(  s, ", " );
                R := AssignmentCost( Assignment,
                                     MyContext^.TaskStartDate,
                                     MyContext^.TaskEndDate,
                                     AnAssignmentCostTypeSet{
                                            IncludeSpent,
                                            IncludeToGo,
                                            IncludeExtras,
                                            IncludeOvertime} );

                FormatAsCurrency( R,  DefaultCurrencyFormat,
                                  s1, HIGH(s1),
                                  FALSE,   (* Right Justify? *)
                                  TRUE,    (* Show fractions? *)
                                  TRUE  ); (* Show Dollar Sign? *)
                TrimRear(s1);
                ConcatLS(s,s1);
        | CAmountRateTime:
                P := ORD(PercentageEach);
                IF (MaxRatePercent <> P) AND (P <> 0) THEN
                    FormatAsAmount( FLOAT(MaxRatePercent)/FLOAT(P),
                                    DefaultAmountFormat, s1,
                                    HIGH(s1), 0, 4, FALSE);
                    ConcatLS( s, s1 );
                    ConcatS(  s, " " );
                END;
                ConcatLS( s, Resource^.Name );              (* Plumbers *)
                ConcatS(  s, " " );
                ConcatLS( s, MyContext^.PercentAssignedPhrase );       (* "Assigned At" *)
                ConcatS(  s, " " );
                CtoS( P, s1 );                              (* 20 *)
                ConcatLS( s, s1 );
                ConcatS(  s, "%" );
        ELSE
            FatalError();
        END;
        ConcatLS(s,MyContext^.PressF2Phrase);
    END;

    Message(s);

END IdentifyResource;









  (* ResynchTaskForm - reset up the names on the task form to match reality.

      Preconditions  - The form information (Form, FormValue, First rsrc field)
      Postconditions - Names have been reset on the task form and redisplayed.

    The customer has gone onto the dreaded RESOURCE LIST, from whence many
    changes can be made, including changing the name of a resource.  Here we
    want to refresh the names to reflect the latest info on the rsrc tree.
  *)

PROCEDURE ResynchTaskForm( Form               : AForm;
                       VAR FormValue          : ARRAY OF AFieldValue;
                           FirstResourceField : CARDINAL );
VAR
    Loop    : CARDINAL;
    FieldNo : AFieldNo;
BEGIN

    AssignmentsToTaskForm( FormValue, FirstResourceField );

    FOR FieldNo := FirstResourceField TO MyContext^.LastFormValueField DO
        ShowValue( Form, FieldNo, FormValue );
    END;

END ResynchTaskForm;









 (* CheckTaskFormResources - Handle the resource fields on the task form.
                 
       Preconditions - We must be in the TaskForm procedure, and he must
                       have called us when DoForm passed the check proc
                       an event.  It can be any of the valid CheckReasons.
                       SetupTaskFormAssignments MUST have been called at
                       some time in the recent past.
                       Additional fields over CheckProc fields:
                       TaskDuration - the current duration from the task form
                       TaskScale    - The current time scale from the task form
                       TaskMethod   - The current task duration method from the form.

       Postconditions - Anything nescessary for handling resources has been
                       done.  Do not attempt to manipulate the FormValues for
                       resources in the caller module, as this could be
                       disasterous!
 *)

PROCEDURE CheckTaskFormResources( Form               : AForm;
                                  FieldNo            : AFieldNo;
                                  FirstResourceField : CARDINAL;
                              VAR FormValue          : ARRAY OF AFieldValue;
                                  CheckReason        : ACheckReason;
                              VAR Code               : CARDINAL;
                                  LocalTaskNode      : ATreeNode
                              ) : BOOLEAN;
VAR
    TaskPtr             : ATaskPtr;
    FormEntry,
    LCode               : CARDINAL;
    CursorAttribute     : ACursorAttribute;
    Ok, NeedToRecompute : BOOLEAN;



    PROCEDURE EditCursorAssignment( CursorIndex : CARDINAL ) : BOOLEAN;
    VAR
        Assignments     : AnAssignmentArray;
        Assignment      : AnAssignmentPointer;
        Count           : CARDINAL;
        ok              : BOOLEAN;
    BEGIN
        ok := (CursorIndex <> PositionEmpty);

        IF (ok) THEN
            WITH MyContext^ DO
                Count := LockObjectArray( AssignmentHandle, Assignments, TSIZE( AnAssignmentRecord ));
(*$O-*)
                Assignment := ADR(Assignments^[CursorIndex]);
(*$O=*)
                ok    := DoAssignmentForm( LocalTaskNode, Assignment );
                F10WithChanges := (F10WithChanges OR ok);
                ReleaseUnchangedObject( AssignmentHandle );
            END;
        END;

        RETURN ok;

    END EditCursorAssignment;



    PROCEDURE DisplayAssignmentHelp( Index : CARDINAL );
    VAR
        Assignments     : AnAssignmentArray;
        Count           : CARDINAL;
        s               : ARRAY [0..(80 * 2)] OF CHAR;
    BEGIN
        IF (Index <> PositionEmpty) THEN
            WITH MyContext^ DO
                Count := LockObjectArray( AssignmentHandle, Assignments, TSIZE( AnAssignmentRecord ));
(*$O-*)
                IdentifyResource( Assignments^[Index], s );  (* 11-Jun-91 RSC  *)
(*$O=*)
                ReleaseUnchangedObject( AssignmentHandle );
            END;
        ELSE
            Copy(MyContext^.F2toAddPhrase,s); (* 7-May-91 RSC rather than a 0 lengthed string. *)
        END;

        Message(s);

    END DisplayAssignmentHelp;



BEGIN (* CheckTaskFormResources *)
    NeedToRecompute := TRUE; (* 19-Aug-91 TGS *)
    IF (MyContext = NIL) THEN
        DisplayMessage(ModuleNumber+13); (* "Not enough memory to bring up the assignment form" *)
        RETURN TRUE;
    END;

    LCode := Code; (* For detecting <Edit> as opposed to <RsrcList> *)
    Code  := 0; (* No code. *)

    FormEntry := ( (FieldNo - FirstResourceField) DIV 2 );

    CASE CheckReason OF

        CheckFormExit   :
        
            WITH MyContext^ DO
                IF F10WithChanges THEN (* 30-Aug-91 TGS *)
                    RecomputeTaskOnForm(      LocalTaskNode );
                    RETURN TRUE;    (* 19-Sep-91 TGS *)
                ELSE
                    RETURN TRUE;
                END;
            END;

      | CheckFormEntry  :
(*        CheckFieldExit  :*)   (* 11-Jun-91 RSC  *)

                RETURN TRUE;  (* Nothin to do. *)

      | CheckFieldEntry :

                DisplayAssignmentHelp(MyContext^.PositionOnForm[FormEntry]);
                RETURN TRUE;

    ELSE  (* Edit the field we are now on. *)

        IF (CheckReason = CheckFieldKey) THEN
            CursorAttribute := CursorResting;
        ELSE
            CursorAttribute := CursorOff;
        END;

        HighlightField(Form,FormValue,FieldNo, CursorAttribute );
        Ok := HandleTaskFormFieldChange ( FormValue[ FieldNo ],
                                          FormEntry,
                                          (CheckReason = CheckFieldKey),
                                          LCode, Form, NeedToRecompute );

    (* 10-Nov-89 RSC If simple edit failed, don't recompute or resynch
                     the task form, so the bad resource sticks around.
    *)
        IF (Ok) THEN
            IF NeedToRecompute THEN (* 19-Aug-91 TGS *)
                RecomputeTaskOnForm( LocalTaskNode );
            END;
            IF (CheckReason = CheckFieldKey) THEN
                HighlightField(Form,FormValue,FieldNo, CursorResting );

                (* Right now, EDIT is the only allowed key .... *)

                Ok := EditCursorAssignment(MyContext^.PositionOnForm[FormEntry]);

                IF (Ok) THEN
                    SetFormChange( Form );
                    Code := DoIt + CARDINAL({13}); (* Go on to next field *)
                ELSE
                    Code := 0;
                END;
            END;
            ResynchTaskForm( Form, FormValue, FirstResourceField );
            DisplayAssignmentHelp( MyContext^.PositionOnForm[FormEntry] );
        END;
        HighlightField(Form,FormValue,FieldNo, CursorOff );

        RETURN Ok;

    END;

END CheckTaskFormResources;




BEGIN
    MyContext := NIL;

    (* GLOBAL INITIALIZATION HAPPENS IN TLSTART!!!  LOOK FOR
       "InitAssForms"
    *)

END AssForms.


