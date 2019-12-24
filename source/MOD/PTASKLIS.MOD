IMPLEMENTATION MODULE PTaskList;

    (*V1=PRODUCTION  *)
    (*V2=KILL pointers on unlock of FlexStor object. *)

    (* MODIFICATION HISTORY

       Dec. 10, 87  AJL - Added FlexStor.
       11-Jan-88    AJL - Use ReleaseUnchangedObject.
       8-Feb-88     AJL - CountDown during sorting.
       22-Feb-88    AJL - Turned off the KILL toggle.
        1-Jun-88    RSC - Minor speed improvements.  Added PCache.
        6-Jun-88    AJL - Modified the CompareProc used by sorting so
                          that it gets task handles instead of task
                          records.  This allows us to avoid some locks
                          if the CompareProc can locate his information
                          in the cache.
       20-Sep-88    RSC - Ajusted several "ReleaseObject"s to be
                          "ReleaseUnchangedObject"s.
       20-Apr-89    AJL - Use XX instead of X from the task record.
       21-Apr-89    AJL - Use Temp3 instead of X from the task record.
       12-May-89    JES - Removed use of PCache, since resource levelling
                          no longer searches through task lists and the
                          PCache procedures now just create extra overhead.
       26-Jun-89    JES - Removed dunzel CheckResourceUsageOnList.
       22-Sep-89    AJL - Don't FatalError on failure to create list.
       30-Mar-90    RSC   Made Timeu to Timei/TimeForm conversions.
       Aug 15, 90   AJL - Added ComputeEdgeDelta.
       Oct 12, 90 - JES - Moved AddLowDate from ResBumpt to here.
       Nov 28, 90 - AJL - Added MaybeCountDown.
       Jan 21  91 - AJL - Modified ComputeEdgeDelta so that it uses the
                          actual end date and start date of the task instead
                          of using the duration (which, because of splitting
                          or contouring, may not properly represent the
                          duration after scheduling.)
    *)

    (*<KILL  (*$R+*) (*$T+*) KILL>*)

FROM Allocs        IMPORT
    (* TYPE *)         ATask, ATaskPtr,
    (* PROC *)         CreateTask;

FROM Assignments   IMPORT
    (* TYPE *)         AnAssignmentAttribute, AnAssignmentRecord,
                       AnAssignmentArray;

FROM Dialog         IMPORT
    (* PROC *)         Error, FatalError, NotYetImplemented;

FROM Edges          IMPORT
    (* TYPE *)         AnEdge, AnEdgePtr;

FROM FlexStor       IMPORT
    (* TYPE *)     AnExtHandle, AnExtStoragePreference,
    (* PROC *)     InitExtStorage, TerminateExtStorage,
                   CreateExtObject, SetExtData, GetExtData,
                   CreateExtObjectWithSize, SetExtSize, GetExtSize,
                   DiscardExtObject,
                   HandleIsValid, ObjectsAreSame,
                   SaveHeapCopy, MakeHeapCopy,
                   LockObject, LockObjectArray, ReleaseObject,
                   ReleaseUnchangedObject,
                   ArraySize, NumberOfElements,
                   CopyExtObject;

FROM Kbio      IMPORT   PutString, BreakRequested,
                        avidmode, maxrow, maxcol;

FROM LStrings  IMPORT   SetString, ConcatS, ConcatLS, CtoS, Compare,
                        SubStr, Fill, TrimFront, Copy, Procustes, RJust;

FROM MsgFile   IMPORT
    (* PROC *)          GetMessage, ConcatMessage;

FROM ResWarnings  IMPORT
    (* TYPE *)          AWarning,
    (* PROC *)          IssueWarning; 

FROM RsrcMod   IMPORT
    (* TYPE *)          AResourcePointer, AResourceType;

FROM Timei          IMPORT
    (* CONST*)          NoDuration, MaxDate,
    (* TYPE *)          ADate;

FROM SYSTEM         IMPORT
    (* PROC *)          ADR, ADDRESS, SIZE, TSIZE;

CONST
    Zero     = 0.0;
    HowOften = 32;
    ModuleNumber    = 3800;        (* Same as TLPLAN *)





    (*$S+*)

PROCEDURE CountDown(phrase:CARDINAL; Total, ToGo : CARDINAL);
CONST
    ThermometerSize = 20;           (* must be <= maxcardinal div max tasks *)
    DoneChar        = 333C;
    ToGoChar        = 260C; 
    SortingPhrase   = 3917;
VAR
    i  : CARDINAL;
    s : ARRAY [0..maxcol+1] OF CHAR;
    s2 : ARRAY [0..ThermometerSize] OF CHAR;
BEGIN
    IF (Total > ThermometerSize) THEN   (* Avoid very small potatoes. *)
        i := ToGo * ThermometerSize DIV Total;
        Fill(s,DoneChar,ThermometerSize-i);
        Fill(s2,ToGoChar,i);
        ConcatLS(s,s2);
        CtoS(Total-ToGo,s2);
        Procustes(s2,5);
        RJust(s2);
        ConcatLS(s,s2);
        ConcatS(s,"/");
        CtoS(Total,s2);
        ConcatLS(s,s2); 
        ConcatS(s,"  ");
        ConcatMessage(s,phrase);
        Procustes(s,maxcol+1);             (* Erase any previous message. *)
        PutString(s,0,0,videomessage);
    END;
END CountDown;







PROCEDURE MaybeCountDown(phrase:CARDINAL; ToGo : CARDINAL);

BEGIN
    IF (TaskCount >= 50) THEN
        CountDown(phrase,TaskCount,ToGo);
    END;
END MaybeCountDown;





    (*$S=*)


    (* Compute the effect of the partial join between the tasks in terms
       of an bias that would have to be applied to an end-to-start
       dependency in order to make it have equivalent effect.  Return an
       edge record that has been updated to have its Delta field contain
       this bias, and return the implied start date of the Descendant
       task.
     *)



PROCEDURE ComputeEdgeDelta( Antecedant : ATaskPtr;
                            Descendant : ATaskPtr;
                            Edge       : AnEdgePtr ) : ADate;
VAR
    k : INTEGER;
    EdgeDate : ADate;

BEGIN
    k := 0;
        (*  Partial join from. *)
    WITH Edge^.FromOffset DO
        IF (Start) THEN
            WITH Antecedant^.Plan.Dates DO
                DEC(k, (EarlyEnd - EarlyStart));
            END;
        END;
        IF (Plus) THEN
            INC(k,Dur);
        ELSE
            DEC(k,Dur);
        END;
    END;
        (*  Partial join to. *)
    WITH Edge^.ToOffset DO
        IF (NOT Start) THEN
            WITH Descendant^.Plan.Dates DO
                DEC(k, (EarlyEnd - EarlyStart));
            END;
        END;
    END;
    EdgeDate := Antecedant^.Plan.Dates.EarlyEnd;    
    Edge^.Delta := k;

    IF (k >= 0) THEN
        IF (EdgeDate > MaxDate-CARDINAL(k)) THEN
            IssueWarning(PastEndOfCalendar,Antecedant);
            EdgeDate := MaxDate;
        ELSE
            INC(EdgeDate,k);
        END;
    ELSIF (EdgeDate > CARDINAL(-k)) THEN    (* k < 0, EdgeDate + k > 0 *)
            (* No warning if EdgeDate + k < 0 so that summary starts
               can be scheduled at day 0, and have dependencies with 
               -Deltas (x to end) without triggering a warning. *) 
            (*$R-*) (*$T-*)   (* Don't want no range checking. *)
        INC(EdgeDate,k);
            (*$R=*) (*$T=*)   (* Don't want no range checking. *)
    END; 

    RETURN EdgeDate;

END ComputeEdgeDelta;








    (* ListInit -- Initialize a list.  The pointer passed to us will
                   be converted into the head node of an empty list
                   by allocating space for it and setting its forward
                   and reverse links to itself. *)

PROCEDURE ListInit (VAR List:AnExtHandle) : BOOLEAN;
VAR
    ListTask : ATaskPtr;
    i        : CARDINAL;
    S : ARRAY [0..101] OF CHAR;
BEGIN
    IF ( CreateExtObjectWithSize(List,ExtSlow,TSIZE(ATask)) ) THEN
       IF ( LockObject(List,ListTask) <> 0) THEN
           ListTask^.Nextlink := List;
           ListTask^.Prevlink := List;
           ReleaseObject(List);           (*<KILL ListTask := NIL;  KILL>*)
       ELSE
           FatalError();
       END;
    ELSE
        GetMessage(ModuleNumber+33,S);      (* Ran out of memory . . . *)
        Error(S);
        RETURN FALSE;
    END;
    RETURN TRUE;
END ListInit;




    (* AddBefore -- Add a new task to the list before the BeforeNode. *)

PROCEDURE AddBefore (BeforeNode, NewNode : AnExtHandle);
VAR
    NewTask, BeforeTask, AfterTask : ATaskPtr;
    AfterNode : AnExtHandle;
BEGIN
    IF ( LockObject(NewNode,NewTask) <> 0 ) AND
       ( LockObject(BeforeNode,BeforeTask) <> 0 ) THEN
        AfterNode := BeforeTask^.Prevlink;
        NewTask^.Prevlink := AfterNode;
        NewTask^.Nextlink := BeforeNode;
        BeforeTask^.Prevlink := NewNode;
        ReleaseObject(BeforeNode);     (*<KILL BeforeTask := NIL;  KILL>*)
        ReleaseObject(NewNode);        (*<KILL NewTask := NIL; KILL>*)
        IF ( LockObject(AfterNode,AfterTask) <> 0 ) THEN
            AfterTask^.Nextlink := NewNode;
            ReleaseObject(AfterNode);       (*<KILL AfterTask := NIL; KILL>*)
            RETURN;
        END;
    END;
    FatalError();
END AddBefore;



    (* DeList -- Remove the task from whichever circular list it is on. *)

PROCEDURE DeList ( TaskHandle: AnExtHandle);
VAR
    BeforeNode, AfterNode : AnExtHandle;
    Task, BeforeTask, AfterTask : ATaskPtr;
BEGIN
    IF (NOT ObjectsAreSame(TaskHandle,PrivateTaskList)) AND
       ( LockObject(TaskHandle,Task) <> 0 ) THEN
        BeforeNode := Task^.Prevlink;
        AfterNode := Task^.Nextlink;
            (* Debugging *)
        Task^.Nextlink := TaskHandle;
        Task^.Prevlink := TaskHandle;
        ReleaseObject(TaskHandle);       (*<KILL Task := NIL; KILL>*)

        IF (LockObject(BeforeNode,BeforeTask)<>0) THEN
            BeforeTask^.Nextlink := AfterNode;
            ReleaseObject(BeforeNode);   (*<KILL BeforeTask := NIL; KILL>*)
            IF (LockObject(AfterNode,AfterTask)<>0) THEN
                AfterTask^.Prevlink := BeforeNode;
                ReleaseObject(AfterNode);  (*<KILL AfterTask := NIL; KILL>*)
                RETURN;
            END;
        END;
    END;

    FatalError();

END DeList;


    (* Move list -- Move all of the tasks from the source list to the
                    target list, at the end.  *)

PROCEDURE MoveList(TargetList, SourceList : AnExtHandle);
VAR
    TopHandle, EndHandle, TargetEndHandle : AnExtHandle;
    TopTask, EndTask, SourceTask, TargetTask, TargetEndTask : ATaskPtr;
BEGIN
    IF (LockObject(SourceList,SourceTask) > 0) THEN
        EndHandle := SourceTask^.Prevlink;
        TopHandle := SourceTask^.Nextlink;
        IF (ObjectsAreSame(TopHandle,SourceList)) THEN
                (* Empty source list. *)
            ReleaseUnchangedObject(SourceList); (* RSC 9/20/88 was "ReleaseObject" *)
                (*<KILL SourceTask := NIL; KILL>*)
            RETURN;
        ELSE
            SourceTask^.Nextlink := SourceList;
            SourceTask^.Prevlink := SourceList;
            ReleaseObject(SourceList);    (*<KILL SourceTask := NIL; KILL>*)

            IF (LockObject(EndHandle,EndTask) > 0) THEN
                EndTask^.Nextlink := TargetList;
                ReleaseObject(EndHandle);    (*<KILL EndTask := NIL; KILL>*)
                IF (LockObject(TargetList,TargetTask) > 0) THEN
                    TargetEndHandle := TargetTask^.Prevlink;
                    TargetTask^.Prevlink := EndHandle;
                    ReleaseObject(TargetList);   (*<KILL TargetTask := NIL; KILL>*)
                    IF (LockObject(TopHandle,TopTask) > 0) THEN
                        TopTask^.Prevlink := TargetEndHandle;
                        ReleaseObject(TopHandle);   (*<KILL TopTask := NIL; KILL>*)
                        IF (LockObject(TargetEndHandle,TargetEndTask) > 0) THEN
                            TargetEndTask^.Nextlink := TopHandle;
                            ReleaseObject(TargetEndHandle);  (*<KILL TargetEndTask := NIL; KILL>*)
                            RETURN;
                        END;
                    END;
                END;
            END;
            FatalError();
        END;
        FatalError();
    END;
END MoveList;













    (* TaskResourceAmount -- Compute the amount of the resource
                             used by the task. *)


PROCEDURE TaskResourceAmount(    Task     : ATaskPtr;
                                 Resource : AResourcePointer;
                             VAR Amount   : REAL );
VAR
    Count       : CARDINAL;
    Assignments : AnAssignmentArray;
BEGIN
    Amount := Zero;

    IF (Task^.Plan.Dates.EarlyStart = Task^.Plan.Dates.EarlyEnd) OR 
         (Task^.duration = NoDuration) THEN
        RETURN; 
    END;

        (* Check that this task uses the resource. *)

    Count := LockObjectArray(Task^.Plan.Assignments,
                             Assignments, TSIZE(AnAssignmentRecord));
    WHILE (Count > 0) DO
        DEC(Count);
        IF (Assignments^[Count].Resource = Resource) THEN
            Amount := Amount + FLOAT(Assignments^[Count].MaxRatePercent);
        END;
    END;

    ReleaseUnchangedObject(Task^.Plan.Assignments);  (*<KILL Assignments := NIL; KILL>*)

END TaskResourceAmount;
(*------AddLowDate-----------------------------------------------*)


PROCEDURE AddLowDate (HeadNode, TaskHandle : AnExtHandle; Task : ATaskPtr );
VAR
    OtherTaskHandle, NextHandle : AnExtHandle;
    OtherTask : ATaskPtr;
BEGIN
    IF (LockObject(HeadNode,OtherTask)=0) THEN FatalError(); END;
    OtherTaskHandle := OtherTask^.Nextlink;
    ReleaseUnchangedObject(HeadNode);               (*<KILL OtherTask := NIL; KILL>*)

    LOOP
        IF (LockObject(OtherTaskHandle,OtherTask)=0) THEN FatalError(); END;

        IF (ObjectsAreSame(OtherTaskHandle,HeadNode)) THEN
    EXIT;
        ELSIF (OtherTask^.Plan.Dates.EarlyStart > Task^.Plan.Dates.EarlyStart) THEN
    EXIT;
        ELSIF (OtherTask^.Plan.Dates.EarlyStart < Task^.Plan.Dates.EarlyStart) THEN
        ELSIF (OtherTask^.duration > Task^.duration) THEN
    EXIT;
        END;

        NextHandle := OtherTask^.Nextlink;
        ReleaseUnchangedObject(OtherTaskHandle);     (*<KILL OtherTask := NIL; KILL>*)
        OtherTaskHandle := NextHandle;
    END;

    ReleaseUnchangedObject(OtherTaskHandle);
    AddBefore(OtherTaskHandle,TaskHandle);
END AddLowDate;


END PTaskList.

