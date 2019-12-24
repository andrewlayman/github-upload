IMPLEMENTATION MODULE EdgeInfo;

(*V1=DEBUG Debugging traces. *)

    (* General procedures giving information about edges.   *)

    (*  MODIFICATION HISTORY --

            6/19/89 EGK    -Changed EdgeIsCritical so that it doesn't
                            consider whether or not the antecedant task
                            is on the critical path.
            8/30/89 AJL    -Rewrote part of EdgeIsControlling to still
                            give correct answers even if the tasks 
                            overlap more than the Edge^.Delta says they
                            should.  
                           -Removed conversions of CARDINALS to INTEGERS
                            within EdgeIsControlling.   
                           -Make some adjustments to help the network view.  
                            We want to treat dependencies from summary tasks 
                            to their children specially.    
                           -Added an additional parameter to the EdgeIsCritical
                            and EdgeIsControlling to support the PERT View.
            30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
            22-Jan-91 RSC   Import NameScale from LongDuration rather than
                            from TimeFormat.
    *)
                            

FROM Allocs                 IMPORT
    (* PROC *)                  ATaskStatus, ATaskStatusSet, ATaskPtr;
(*<DEBUG
FROM Dialog                 IMPORT 
                                Error;
DEBUG>*)


FROM CalShift               IMPORT
    (* VAR  *)                  TimeSheet;

FROM Duration               IMPORT
    (* PROC *)                  FindDuration;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr, AnEdgeAttribute,
    (* PROC *)                  CheckEdgeValid;

FROM LongDuration           IMPORT
    (* PROC *)                  NameScale;

FROM LStrings               IMPORT
    (* PROC *)                  ConcatS, ConcatLS, CtoS, Copy;

FROM Menus                  IMPORT
    (* PROC *)                  WordNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Timei                  IMPORT
    (* CONST*)                  NoDuration,
    (* TYPE *)                  ADate, ADuration, ADurationUnit,
    (* PROC *)                  DurationToReal, RealToDuration;

FROM Timeu                  IMPORT
    (* PROC *)                  DownScale;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree;

CONST
    ModuleNumber            = 29100;

    OneHundred              = 100.0;



PROCEDURE DescribeEdge  (    Edge        : AnEdgePtr;
                             Long        : BOOLEAN;
                         VAR s           : ARRAY OF CHAR );
VAR
    s2                  : ARRAY [0..20] OF CHAR;

    PROCEDURE AddSpace ( VAR s      : ARRAY OF CHAR );
    BEGIN
        IF (Long) THEN
            ConcatS (s, " ");
        END;
    END AddSpace;


    PROCEDURE GetMessageWord (      PhraseNo    : CARDINAL;
                                VAR s           : ARRAY OF CHAR  );
    VAR
        s2              : ARRAY [0..40] OF CHAR;
    BEGIN
        GetMessage (PhraseNo, s2);
        WordNumber (s2, 2-ORD(Long), s);
    END GetMessageWord;


    PROCEDURE ConcatMessageWord (  VAR s            : ARRAY OF CHAR;
                                       PhraseNo     : CARDINAL      );
    VAR
        s2              : ARRAY [0..40] OF CHAR;
    BEGIN
        GetMessageWord (PhraseNo, s2);
        ConcatLS (s, s2);
    END ConcatMessageWord;


    PROCEDURE ShortNameScale  (    N        : ADuration;
                                   TimeUnit : ADurationUnit;
                               VAR s        : ARRAY OF CHAR );
    VAR
        Number              : CARDINAL;
        s2, s3              : ARRAY [0..30] OF CHAR;
    BEGIN
        Number := DownScale (N, TimeUnit);
        CtoS (Number, s);
        GetMessage (ModuleNumber+5, s2);
        WordNumber (s2, 1+ORD(TimeUnit), s3);
        ConcatLS (s, s3);
    END ShortNameScale;



BEGIN
    CheckEdgeValid (Edge);

    WITH Edge^ DO

        IF (FromOffset.Start) THEN
            GetMessageWord (ModuleNumber, s);   (* "Start" *)
        ELSE
            GetMessageWord (ModuleNumber+1, s); (* "End" *)
        END;
        AddSpace (s);

        IF (FromOffset.Dur <> NoDuration) THEN
            IF (FromOffset.Plus) THEN
                ConcatMessageWord (s, ModuleNumber+2);      (* "plus" *)
            ELSE
                ConcatMessageWord (s, ModuleNumber+3);      (* "minus" *)
            END;
            AddSpace (s);

            IF (Long) THEN
                NameScale (FromOffset.Dur, FromOffset.Scale, s2);
            ELSE
                ShortNameScale (FromOffset.Dur, FromOffset.Scale, s2);
            END;
            ConcatLS (s, s2);
            AddSpace (s);
        END;

        ConcatMessageWord (s, ModuleNumber+4);      (* "ÄÄ" *)
        AddSpace (s);

        IF (ToOffset.Start) THEN
            ConcatMessageWord (s, ModuleNumber);    (* "Start" *)
        ELSE
            ConcatMessageWord (s, ModuleNumber+1);  (* "End" *)
        END;
    END;
END DescribeEdge;



PROCEDURE EdgeIsNormal  ( Edge     : AnEdgePtr ) : BOOLEAN;

BEGIN
    CheckEdgeValid (Edge);

    RETURN (Edge^.FromOffset.Dur = NoDuration)   AND
           (NOT Edge^.FromOffset.Start) AND
           (Edge^.ToOffset.Start);

END EdgeIsNormal;





PROCEDURE EdgeIsCritical ( Edge      : AnEdgePtr;
                           TreatSummaryAsMilestone : BOOLEAN
                             ) : BOOLEAN;
VAR
    Task                : ATaskPtr;
    SuccStatus          : ATaskStatusSet;

BEGIN
    CheckEdgeValid (Edge);

    WITH Edge^ DO
        Task := tailtask^.Methods^.LockFlexStorDataObject (tailtask);
        SuccStatus := Task^.TaskStatusSet;
        tailtask^.Methods^.UnlockUnchangedDataObject (tailtask);
    END;

    RETURN (Critical IN SuccStatus) AND
           (EdgeIsControlling (Edge, 0, TreatSummaryAsMilestone));

END EdgeIsCritical;



(*<DEBUG
PROCEDURE Report( Edge : AnEdgePtr; Is : BOOLEAN );
VAR
    S : ARRAY [0..255] OF CHAR;
    S2 : ARRAY [0..10] OF CHAR;
    TaskPtr         : ATaskPtr;
BEGIN
    WITH Edge^ DO
        TaskPtr := headtask^.Methods^.LockFlexStorDataObject (headtask);
        Copy(TaskPtr^.taskname,S);
        headtask^.Methods^.UnlockUnchangedDataObject (headtask);
        ConcatS(S," --> ");
        TaskPtr := tailtask^.Methods^.LockFlexStorDataObject (tailtask);
        ConcatLS(S,TaskPtr^.taskname);
        tailtask^.Methods^.UnlockUnchangedDataObject (tailtask);
        IF (Is) THEN
            ConcatS(S," CONTROLLING ");
        ELSE 
            ConcatS(S," Non-CONTROLLING ");
        END;
        Error(S);
    END;
END Report;
DEBUG>*)



(*----------------------------------------------------------------------------
    EdgeIsControlling --

    Indicate whether or not this edge is controlling (has no slack).
    The tolerance parameter allows dependencies that are within a
    certain percentage of being controlling to also be identified.

    Input:  Edge :: the edge to check.
            Tolerance :: How close to controlling it must be before
                         we call it controlling.
            TreatSummaryAsMilestone :: If TRUE, all summary tasks are
                treated as milestones, regardless of their actual
                duration.  (This is for the PERT view.)    

    Preconditions:
        The edge passed must be a pointer to a valid edge record.  The
        tolerance must be a cardinal in the range 0-100.

    Postconditions:
        Iff the dependency is within the specified percentage of being
        controlling (i.e., if the dependency's "slack" is less than or
        equal to the percentage times the duration of the predecessor
        task), TRUE will be returned.
----------------------------------------------------------------------------*)


PROCEDURE EdgeIsControlling ( Edge      : AnEdgePtr;
                              Tolerance : CARDINAL;
                              TreatSummaryAsMilestone : BOOLEAN
                             ) : BOOLEAN;

VAR
    DescStart, DescEnd : ADate;
    AnteStart, AnteEnd : ADate;
    AnteDur         : ADuration;
    Slack           : ADuration;
    TaskPtr         : ATaskPtr;
    IsIt            : BOOLEAN;

BEGIN
    WITH Edge^ DO

           (* Get dates of the predecessor task. *)

        TaskPtr := headtask^.Methods^.LockFlexStorDataObject (headtask);
        AnteStart := TaskPtr^.Plan.Dates.EarlyStart;
            (* If we are treating summary tasks like milestones, and this 
               is a summary task, force the end date to be the start date.
               Else, get the real end date and duration. *) 
        IF (TreatSummaryAsMilestone) AND
           (headtask^.Methods^.GetSubtree(headtask) <> ATree(NIL)) THEN
            AnteDur := NoDuration;
            AnteEnd := AnteStart;
        ELSE
            AnteEnd := TaskPtr^.Plan.Dates.EarlyEnd;
            AnteDur := TaskPtr^.duration;
        END;

           (* Get dates of the successor task. *)

        headtask^.Methods^.UnlockUnchangedDataObject (headtask);
        TaskPtr := tailtask^.Methods^.LockFlexStorDataObject (tailtask);
        DescStart := TaskPtr^.Plan.Dates.EarlyStart;
            (* If we are treating summary tasks like milestones, and this 
               is a summary task, force the end date to be the start date.
               Else, get the real end date and duration. *) 
        IF (TreatSummaryAsMilestone) AND
           (tailtask^.Methods^.GetSubtree(tailtask) <> ATree(NIL)) THEN
            DescEnd := DescStart;
        ELSE
            DescEnd := TaskPtr^.Plan.Dates.EarlyEnd;
        END;
        tailtask^.Methods^.UnlockUnchangedDataObject (tailtask);
    END;

        (* Move the apparent start of end dates of the tasks to compensate
           for a partial dependency.  I am not checking here for overflows
           because I presume that any task/dependency situation close enough
           to the end of the calendar to cause overflows would probably
           have been disallowed elsewhere, and in any case, must be wrong
           enough that our giving a wrong answer is the least of our 
           worries. *) 

    IF (Edge^.Delta < 0) THEN
        INC(DescStart, VAL(CARDINAL,-Edge^.Delta));
    ELSE
        INC(AnteEnd, CARDINAL(Edge^.Delta));
    END;

        (* If the antecedant ends after the descendant starts, for some reason
           that wasn't fully reflected in the Edge^.Delta, then we will
           certainly have a controlling dependency.  *)


    IF (AnteEnd > DescStart) THEN        (* More than critical?  A summary task or phantom? *)
        (*<DEBUG  Report(Edge,TRUE);  DEBUG>*)
        RETURN TRUE;
    END;

        (* Compute the actual slack, then the percentage that is of the 
           antecedant's duration. *)

    Slack := FindDuration( AnteEnd, DescStart, TimeSheet );

    IsIt := (
                Slack 
                <= 
                RealToDuration
                (
                    ( FLOAT(Tolerance) / OneHundred ) 
                    * 
                    DurationToReal(AnteDur) 
                )
            );

    (*<DEBUG  Report(Edge,IsIt);  DEBUG>*)
    
    RETURN IsIt;

END EdgeIsControlling;



END EdgeInfo.
