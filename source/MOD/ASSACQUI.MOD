IMPLEMENTATION MODULE AssAcquire;



    (*
        Ass Acquire - Acquire an assignment record

            This module, given "columns" of information, attempts to find
            an existing assignment record or create a new record with
            appropriate defaults.


        Procedure Overview:

            ResetAssignments()

                    Prepares a task to receive edits to its assignments.

            AnalyzeAssColumn()

                    Look at each column being read in from a file to see if
                    we have the columns needed to determine if the record
                    exists.

            AcquireAss()

                    Once "AnalyzeAssColumn" is called for each available
                    column, this is used to actually create or find an
                    assignment.

            ResetDefaultAssColumns()

                    Resets the user-defined default columns.  When a record
                    is created, SYSTEM defaults are applied, then any user-
                    defined columns are applied.

            DefaultAssColumn()

                    Set a default assignment column.  The next time an
                    assignment record is created, all default columns are
                    applied first, and then the assignment is ready for
                    changes.


        Handling Errors:

            There is a client-supplied error handler, which is called whenever
            an error is detected.  Errors come in different severities and
            types, and the error handler is responsible for logging the errors
            and deciding the TRUE severity of the error (for example, you may
            want to ignore some warning errors).


        Undo:

            This module uses Undo to add and change records.  It does not begin
            or end the undo transaction.  The intent is that clients will:

                Begin Undo Transaction
                    Call AssAquire to get    the assignment
                    Call AssChange to change the assignment
                End Undo Transaction.


        Modification History:


         20-Feb-89  RSC  First version.
          4-Jun-89  EGK  Changed NotifyUndo call into SendNotices call.
         13-Jul-89  MWP  Removed import of TaskID.
          9-Aug-89  MWP  If resource is not found, do not attempt to create
                         one. Just log the error.
         10-Aug-89  MWP  Acquire a baseline assignment record only if we are
                         allowing baseline alterations.
         21-Aug-89  RSC  Check ExtStatus before allocating Ext memory.
         24-Aug-89  MWP  Check if we have actually seen, and are allowed to
                         edit baseline data before actually acquiring and
                         editing the baseline record.
          6-Sep-89  MWP  Added proc to test whether a column is needed
                         for editing. Does not grab the column value.
         11-Sep-89  MWP  Changed method for editing baseline assignment data.
         13-Sep-89  MWP  Re-worked acquiring and editing baseline records
                         to make it ( hopefully ) more clear.
         25-Sep-89  MWP  Change some defaults of Baseline assignment record.
          2-Oct-89  MWP  Changed defaults for MaxRatePercent and PercentageEach
                         in default Baseline assignment record.
          6-Oct-89  MWP  When analyzing data for control column information,
                         log the results into WhatWeveSeen, not WhatWeveGot.
                         This caused a fatal error!
         16-Oct-89 MWP   Implemented faster searching for finding an existing
                         task to edit.
         16-Nov-89 MWP   When we find a key column, do not force it to upper
                         case.
         30-May-90 AJL   Import InitAssignment from Assignme.
         7-Oct-91 TGS   Initialize the MaxRatePercent and PercentageEach
                        fields in the DefaultAss records. This makes it 
                        "more likely" that the NumberAt and Percent fields
                        will import correctly. We think.
                        Also moved a couple of the compiler optimization
                        directives; a couple of the array dereferences were
                        not within their scope. Can't hurt...
    *)

FROM Allocs         IMPORT
    (* TYPE *)              ATaskPtr,
    (* VAR  *)              TaskTree;

FROM AssChange      IMPORT
    (* TYPE *)              AnAssEditContext,
    (* VAR  *)              DefaultBsLnAssignmentRecord,
                            TaskName,
                            ResourceNm,
    (* PROC *)              ChangeAssRecord;

FROM Assignments    IMPORT
    (* TYPE *)              AnAssignmentRecord,    AnAssignmentArray,
                            AnAssignmentAttribute, AnAssignmentAttributeSet,
    (* PROC *)              ForEachAssignment, InitAssignment;

FROM Captions       IMPORT
    (* TYPE *)              AColumnDataRecord;

FROM EditCommon     IMPORT
    (* PROC *)              FindTaskWithWBS;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorHandlerProc, AnErrorSeverity, AKindOfError;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle, AnExtStoragePreference,
                            AnExtStatus,
    (* PROC *)              LockObjectArray, ReleaseUnchangedObject,
                            ReleaseObject,   CreateExtObjectWithSize,
                            SetExtSize,      GetExtStatus;

FROM ImPorTable     IMPORT
    (* TYPE *)              AImportTable,
    (* PROC *)              AskAlterBaseline;                       (* 24-Aug-89 MWP *)

FROM LStrings       IMPORT
    (* PROCS *)             TrimFront,    TrimRear, Copy, SetLengthOf, LengthOf,
                            StringsEqual, Upshift,  SetString, ConcatLS;

FROM   MagicNum     IMPORT
    (* CONST *)             AssModuleNumber,   AssTaskName,
                            AssResourceName,   AssBillable,   AssNumberAt,
                            AssPercentEach,    AssTotalHours, AssCompletedHours,
                            AssYTGHours,       AssTotalTime,  AssCompletedTime,
                            AssYTGTime,        AssTimeUnits,  AssTotalUnits,
                            AssCompletedUnits, AssYTGUnits,   AssTotalCost,
                            AssCompletedCost,  AssYTGoCost,   AssTaskWBS,
                            AssLastColumn,
                            BsLnBillable,      BsLnYTGoCost,
                            RsrcName;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;

FROM RsrcMod        IMPORT
    (* TYPE *)              AResourcePointer, AResourceType,
    (* VAR  *)              ResourceTree,
    (* PROC *)              FindResourceByName;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR, TSIZE;

FROM TaskDictionary IMPORT
                            IsInDict, DictionaryInUse;

FROM Timei          IMPORT
    (* TYPE *)              ADurationUnit;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder;

FROM Undo           IMPORT
    (* TYPE *)              AnUndoableObject, AnUndoAction,
    (* PROC *)              NotifyUndo;




TYPE
    AnIdentifyingColumn      = ( TaskWBS, ResourceName );

    ASetOfIdentifyingColumns = SET OF AnIdentifyingColumn;

    AnLString                = ARRAY [0..99] OF CHAR;




VAR
    DefaultAssignmentRecord     : AnAssignmentRecord;  (* For setting defaults *)
    AssEditContext              : AnAssEditContext;

    WhatWeveGot                 : ASetOfIdentifyingColumns;
    WhatWeveSeen                : ASetOfIdentifyingColumns;
    KeyValues                   : ARRAY AnIdentifyingColumn OF AnLString;

    NilString                   : ARRAY [0..1] OF CHAR;

    BaselineData                : BOOLEAN;

(*
    Reset Edit Bit - Helper routine for "ResetAssignments", called via
                     "ForEachAssignment".  Our job is to reset the "Edit"
                     bit in the assignment record.

*)
PROCEDURE ResetEditBit( VAR Assignment : AnAssignmentRecord;
                            Junkola    : ADDRESS ) : BOOLEAN;
BEGIN
    EXCL( Assignment.Attributes, RTempFlag1 ); (* TempFlag1 is the "Edit" bit. *)
    RETURN TRUE;
END ResetEditBit;



(*
    Reset Assignments

        Sets up for creating or changing assignment records.

        As assignment records are not identified by a record number or any
        other unique value, ordering is very important.  If changes come in
        to some task for an assignment of, say, "BOB", any existing record
        with that resource is changed.  If no assignment has that resource,
        then a new assignment is created.  If two or more assignments have
        that resource, then the FIRST assignment edited is the FIRST one with
        the name, and the SECOND edits the SECOND existing record, and so on.
        If there are five incoming assignments for "BOB" and only three
        existing records, the three are updated and two new records are added.

        This is not needed if you use "AcquireAss" to get the assignment
        record.  It is only for clients who do not use "AcquireAss".


        Preconditions
                        > TaskNode is a tree node for a task that COULD have
                          its assignments edited.  It is a VAR to satisfy
                          "TraverseTree".  The TaskNode is not altered.

                        > JunkAddress is a placeholder so that "TraverseTree"
                          can call this procedure.  It should be NIL.

        Postconditions
                        > Task is ready to have assignments edited.
*)
PROCEDURE ResetAssignments( VAR TaskNode    : ATreeNode;
                                JunkAddress : ADDRESS    );
VAR
    TaskPtr    : ATaskPtr;
BEGIN

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    ForEachAssignment( TaskPtr^.Plan.Assignments, ResetEditBit, NIL );

    ForEachAssignment( TaskPtr^.BaseLine.Assignments, ResetEditBit, NIL ); (* 9-Aug-89 MWP *)

    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );


END ResetAssignments;


PROCEDURE ResetAllAssignments();
VAR
    TaskNode                : ATreeNode;
BEGIN

    TaskTree^.Methods^.TraverseTree( TaskTree,
                                     ParentBeforeChild,
                                     999,
                                     ResetAssignments,
                                     ADR(TaskNode) );
END ResetAllAssignments;



(*
    Analyze Ass Column

        Preconditions
                        > ColumnID is within range for an assignment column.
                        > ColumnData contains the data to be changed.

        Postconditions
                        > The data has been analized for usability in
                          defining an assignment record to edit.
*)
PROCEDURE AnalyzeAssColumn(     ColumnID    : CARDINAL;
                            VAR ColumnData  : AColumnDataRecord );


    PROCEDURE GrabIt( WhatItIs   : AnIdentifyingColumn;
                      IsTaskName : BOOLEAN );
    BEGIN
        WITH ColumnData DO
            TrimFront( StringValue );
            TrimRear(  StringValue );
            IF ( LengthOf ( StringValue ) > 0 ) THEN
               IF ( IsTaskName ) THEN
                  Copy ( StringValue, TaskName );
               ELSE
                  Copy ( StringValue, ResourceNm );
               END;
(***
               Upshift(   StringValue );
**)
               INCL( WhatWeveGot, WhatItIs );
               Copy( StringValue, KeyValues[ WhatItIs ] );
            END;
        END;
    END GrabIt;


BEGIN
    CASE ColumnID OF
        AssResourceName :
            GrabIt( ResourceName, FALSE );

      | AssTaskWBS :

            GrabIt( TaskWBS, TRUE );

      | BsLnBillable..BsLnYTGoCost   :
            BaselineData := TRUE;
    ELSE
    END;

END AnalyzeAssColumn;


PROCEDURE IsControllingColumn ( ColumnID    : CARDINAL ) : BOOLEAN;  (* 6-Sep-89 MWP *)
VAR
    ok : BOOLEAN;
BEGIN

    ok := FALSE;

    CASE ColumnID OF
        AssResourceName :
               INCL( WhatWeveSeen, ResourceName );
               ok := TRUE;
     |  AssTaskWBS      :
               INCL( WhatWeveSeen, TaskWBS );
               ok := TRUE;
      | BsLnBillable..BsLnYTGoCost   :
               BaselineData := TRUE;
    ELSE
    END;

    RETURN ( ok );

END IsControllingColumn;

PROCEDURE AreAllControlsPresent () : BOOLEAN;
BEGIN

    RETURN ( WhatWeveSeen = ASetOfIdentifyingColumns{TaskWBS, ResourceName} );

END AreAllControlsPresent;


(*
    Create Or Find Ass - Create or find an assignment record to edit.
                         This is a helper to "AcquireAss".

    Here, we have a resource and a task node.  Find the appropriate
    assignment, or create one.  If we find an assignment with the same
    resource, see if it has already been edited.  If so, skip it.
    If not, use it.  If ALL have been edited, or there are no resources
    with this resource, create one.  Use the defaults to fill in the
    record if created.
*)
PROCEDURE CreateOrFindAss(     TaskNode,
                               RsrcNode        : ATreeNode;
                           VAR AssignmentEntry : CARDINAL;
                               Method          : CARDINAL ) : BOOLEAN;
CONST
    Plan     =  0;
    Baseline = 1;
VAR
    TaskPtr          : ATaskPtr;
    AssignmentHandle : AnExtHandle;
    AssignmentArray  : AnAssignmentArray;
    ResourcePointer  : AResourcePointer;
    NewSize,
    Count            : CARDINAL;
    ok               : BOOLEAN;

BEGIN

    ok := TRUE;

    SendNotices (ChangeATask, BeforeActing, TaskNode);       (* 6/4/89 EGK *)

    ResourcePointer := RsrcNode^.Methods^.GetDataObject( RsrcNode );

        (* 7-Oct-91 TGS initialize MaxRatePercent/PercentageEach *)
    IF ( Method = Plan ) THEN
        WITH DefaultAssignmentRecord DO
            Resource := ResourcePointer;
            EXCL( Attributes, AllowLevel );
            MaxRatePercent := 100;
            PercentageEach := 100C;
        END;
    ELSE
        WITH DefaultBsLnAssignmentRecord DO
            Resource := ResourcePointer;
            EXCL( Attributes, AllowLevel );
            MaxRatePercent := 100;
            PercentageEach := 100C;
        END;
    END;


    IF (ResourcePointer^.Type = Employable) THEN
        IF ( Method = Plan ) THEN
            INCL( DefaultAssignmentRecord.Attributes, AllowLevel );
        ELSE
            INCL( DefaultBsLnAssignmentRecord.Attributes, AllowLevel );
        END;
    END;

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    IF ( Method = Plan ) THEN
       AssignmentHandle := TaskPtr^.Plan.Assignments;
    ELSE
       AssignmentHandle := TaskPtr^.BaseLine.Assignments;
    END;

    IF ( AssignmentHandle = AnExtHandle(NIL) ) THEN
        IF ( Method = Plan ) THEN
        (*
          If this is plan data, go ahead and create a new assignment record
          entry, and add the default record.
          If it is baseline data, don't create anything. At the end of
          record import we will decide whether we want to store the
          default baseline assignment record or not.
        *)

            ok := (GetExtStatus() = ExtGood) AND
                  (CreateExtObjectWithSize( AssignmentHandle,
                                            ExtMedium,
                                            TSIZE(AnAssignmentRecord)));

            IF (ok) THEN
               TaskPtr^.Plan.Assignments     := AssignmentHandle;
            END;

            TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

            IF (ok) THEN
                Count := LockObjectArray( AssignmentHandle,
                                          AssignmentArray,
                                          TSIZE(AnAssignmentRecord));
(*$O-*)
                AssignmentArray^[0] := DefaultAssignmentRecord;
                INCL( AssignmentArray^[ 0 ].Attributes, RTempFlag1 );  (* 7-Sep-89 MWP *)
(*$O=*)

                ReleaseObject( AssignmentHandle );
            END;
        ELSE
            TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
        END;
    ELSE
        (*
         Assignments exist for this task. Run through the ass records and
         if we are updating an existing assignment record or not. If not, we
         add on an assignment record to the end of the list, and assign
         default entry.
         Note: If this is baseline assignments we are working with,
               if we find an existing record, we have to copy it's
               data to the default baseline ass record. If none
               exist, don't create another entry to the task ass list.
        *)

        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

        Count := LockObjectArray( AssignmentHandle,
                                  AssignmentArray,
                                  TSIZE(AnAssignmentRecord));

(*$O-*)  (* Pointers to arrays of records sometimes confuse the optimizer *)
         (* "The force has a strong influance on the weak minded" - ObeWan *)

         (* TempFlag1 is the bit we use to say "we edited this already". *)

        AssignmentEntry := 0;
        WHILE (AssignmentEntry < Count) AND
             ((AssignmentArray^[ AssignmentEntry ].Resource <> ResourcePointer) OR
              (RTempFlag1 IN AssignmentArray^[ AssignmentEntry ].Attributes)) DO
            INC( AssignmentEntry );
        END;
(*$O=*)

        IF (AssignmentEntry < Count) THEN   (* Found one! *)
(*$O-*)
            IF ( Method = Plan ) THEN
                INCL( AssignmentArray^[ AssignmentEntry ].Attributes, RTempFlag1 );
            ELSE
                DefaultBsLnAssignmentRecord := AssignmentArray^[AssignmentEntry];
            END;
(*$O=*)
            ReleaseObject( AssignmentHandle );
        ELSE
            ReleaseUnchangedObject( AssignmentHandle );

            IF ( Method = Plan ) THEN
                NewSize := TSIZE(AnAssignmentRecord);
                IF (ODD(NewSize)) THEN
                    INC(NewSize);
                END;
                ok := SetExtSize( AssignmentHandle,
                                  (( AssignmentEntry + 1 )* NewSize));

                IF (ok) THEN
                    Count := LockObjectArray( AssignmentHandle,
                                              AssignmentArray,
                                              TSIZE(AnAssignmentRecord));
(*$O-*)
                    AssignmentArray^[AssignmentEntry] := DefaultAssignmentRecord;
(*$O=*)
                    ReleaseObject( AssignmentHandle );

                    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

                    TaskPtr^.Plan.Assignments := AssignmentHandle;

                    TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
                END;
            END;
        END;
    END;

    RETURN ok;

END CreateOrFindAss;



(*
    Acquire Ass

        Preconditions
                        > All columns have been passed through
                          "AnalyzeAssColumn"

        Postconditions
                        > If TRUE is returned, TaskNode is the task's
                          node, and AssignmentEntry is the specific
                          assignment record for that task.

                        > If there was a system error, or if the Task
                          could not be found, then the ErrorHandler
                          is called, and FALSE is returned.

                        > Undo is called to notify it of the Add or Change.
                          The client must start and end the Undo transaction.
*)
PROCEDURE AcquireAss( VAR TaskNode            : ATreeNode;
                      VAR AssignmentEntry     : CARDINAL;
                      VAR BaseLineEntry       : CARDINAL;
                          PImportContext      : ADDRESS;            (* 9-Aug-89 MWP *)
                          ErrorHandler        : AnErrorHandlerProc;
                          HandlersContext     : ADDRESS          )  : BOOLEAN;
CONST
    Plan     =  0;
    Baseline =  1;
VAR
    RsrcNode  : ATreeNode;
    Junk,
    ok        : BOOLEAN;
    PImport   : POINTER TO AImportTable;                            (* 9-Aug-89 MWP *)
BEGIN

    PImport         := PImportContext;                              (* 9-Aug-89 MWP *)
    TaskNode        := NIL;
    AssignmentEntry := 0;
    BaseLineEntry   := 0;

    ok := (WhatWeveGot = ASetOfIdentifyingColumns{TaskWBS, ResourceName} );

    IF (NOT ok) THEN
        IF (NOT (TaskWBS IN WhatWeveGot)) THEN
            Junk := ErrorHandler( ConnectionError,
                                  MissingTaskID,
                                  0,
                                  NilString,
                                  HandlersContext );
        END;

        IF (NOT (ResourceName IN WhatWeveGot)) THEN
            Junk := ErrorHandler( ConnectionError,
                                  MissingRsrcID,
                                  0,
                                  NilString,
                                  HandlersContext );
        END;
    ELSE
        (* Step 1:  Find the task record by WBS *)

        IF ( DictionaryInUse ) THEN                                 (* 16-Oct-89 MWP *)
           ok := IsInDict ( KeyValues[ TaskWBS ], TaskNode );
        ELSE
           FindTaskWithWBS( KeyValues[ TaskWBS ], TaskNode );
        END;

        ok := (TaskNode <> NIL);

        IF (NOT ok) THEN
            Junk := ErrorHandler( ConnectionError,
                                  TaskNotFound,
                                  0,
                                  NilString,
                                  HandlersContext );
        ELSE

            (* Step 2:  Find the resource record by name.
                        Not found?  Well, the error handler can direct
                        us to create a new one.
            *)

            RsrcNode := FindResourceByName( KeyValues[ ResourceName ] );
            ok       := (RsrcNode <> NIL);

            IF (NOT ok) THEN
                IF (ErrorHandler( ConnectionError,
                                  ResourceNotFound,
                                  0,
                                  NilString,
                                  HandlersContext )) THEN
                END;
            END;
        END;
    END;

 (* Here, if "ok", we have a resource AND a task.  Find the appropriate
    assignment, or create one.  If we find an assignment with the same
    resource, see if it has already been edited.  If so, skip it.
    If not, use it.  If ALL have been edited, or there are no resources
    with this resource, create one.
 *)


    IF (ok AND (NOT CreateOrFindAss( TaskNode,
                                     RsrcNode,
                                     AssignmentEntry,
                                     Plan ) ) ) THEN

        Junk := ErrorHandler( ConnectionError,
                              RecCannotBeCreated,
                              0,
                              NilString,
                              HandlersContext );
        ok   := FALSE;
    END;

    IF (ok AND (NOT CreateOrFindAss( TaskNode,
                                     RsrcNode,
                                     BaseLineEntry,
                                     Baseline ) ) ) THEN

        Junk := ErrorHandler( ConnectionError,
                              RecCannotBeCreated,
                              0,
                              NilString,
                              HandlersContext );
        ok   := FALSE;
    END;

 (* Reset what we know about the assignment record. *)

    WhatWeveGot   := ASetOfIdentifyingColumns{};
    WhatWeveSeen   := ASetOfIdentifyingColumns{};

    BaselineData  := FALSE;

    RETURN ok;

END AcquireAss;







(*
    Reset Default Ass Columns

        Reset the default values for assignment columns.

        Preconditions
                        > none.

        Postconditions
                        > The next assignment that is created will have all
                          of its fields set to the system defaults, not
                          any client defaults.
*)
PROCEDURE ResetDefaultAssColumns();
CONST
    Zero = 0.0;
BEGIN
        (* Initialize the defaults for the assignment records to some
           plausible values.  Note from AJL: I suspect that something
           is structurally wrong with this module.  Why is one of these
           records declared in this module and one in AssChange?  Why are
           we using global copies of things anyway, rather than initializing
           them on the fly using this InitAssignment procedure? *)
    InitAssignment(NIL,DefaultAssignmentRecord);
    InitAssignment(NIL,DefaultBsLnAssignmentRecord);

    WITH AssEditContext DO
        ErrorHandler      := ErrorHandlerProc;
        HandlersContext   := NIL;
        YTGValue          := Zero;
        ActualValue       := Zero;
        AssYTGTimeSeen    := FALSE;
        AssActualTimeSeen := FALSE;
        TimeUnits         := Hours;

        BsLn_YTGValue          := Zero;
        BsLn_ActualValue       := Zero;
        BsLn_AssYTGTimeSeen    := FALSE;
        BsLn_AssActualTimeSeen := FALSE;
        BsLn_TimeUnits         := Hours;
    END;

END ResetDefaultAssColumns;





(*
    Error Handler

        An error handler for the "Default" setting operations.  Fix anything
        possible.
*)
PROCEDURE ErrorHandlerProc( Severity        : AnErrorSeverity;
                            ErrorKind       : AKindOfError;
                            ColumnID        : CARDINAL;
                        VAR ErrorText       : ARRAY OF CHAR;
                            MyContext       : ADDRESS
                        ) : BOOLEAN;         (* Continue?         *)
BEGIN
    RETURN TRUE;  (* Fix it if you can. *)
END ErrorHandlerProc;





(*
    Default Ass Column

        Sets up defaults for assignment columns.  These defaults are used
        whenever creating a new assignment.

        Preconditions
                        > Column ID is within range

                        > ColumnData is properly formatted for the column
                          being defined.

        Postconditions
                        > Any assignment that is created has values applied
                          in this order:

                                System defaults
                                Client defaults, defined with this procedure
                                Any edits given to AssEdit.

                        > Reset this action with "ResetDefaultAssColumns"
*)

PROCEDURE DefaultAssColumn(     ColumnID    : CARDINAL;
                            VAR ColumnData  : AColumnDataRecord ) : BOOLEAN;
BEGIN
    RETURN ChangeAssRecord( ColumnID,   DefaultAssignmentRecord,
                            ColumnData, AssEditContext );
END DefaultAssColumn;


BEGIN

    WhatWeveGot  := ASetOfIdentifyingColumns{};
    WhatWeveSeen := ASetOfIdentifyingColumns{};
    BaselineData  := FALSE;
    SetLengthOf( NilString, 0 );
    ResetDefaultAssColumns();

END AssAcquire.

