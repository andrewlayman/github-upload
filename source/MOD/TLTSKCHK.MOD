MODULE TLTskChk;

    (* Modification History:
        25-Jun-90 AJL Added testing of the Expenses and VaryingAssignment
                      handles in the task records.

    *)



FROM Allocs      IMPORT ATaskPtr,
                        CheckTaskValid;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentRecord, AnAssignmentArray;

FROM Dialog      IMPORT FatalError;
 
FROM Edges       IMPORT AnEdgePtr,
                        CheckEdgeValid;

FROM FlexStor      IMPORT
                        AnExtHandle,
                        LockObject, LockObjectArray, ReleaseUnchangedObject;

FROM Kbio          IMPORT
                        avidmode; 

FROM Lights        IMPORT
    (* TYPE *)         ALight,
    (* VAR *)          ActiveLightRegion,
    (* PROC *)         InstallLight, DisplayLight;

FROM LStrings      IMPORT
                        SetString;

FROM Overlays      IMPORT
    (* TYPE *)          AnOverlayID,  
    (* PROC *)          ImALockedOverlay, InstallNewProcedure;

FROM OvTree        IMPORT
    (* TYPE *)          AnOverlayProc;


FROM RsrcMod         IMPORT
   (* TYPES *)           AResourcePointer,
   (* PROCS *)           CheckResourceValid;


FROM SYSTEM        IMPORT
                        ADR, TSIZE, ADDRESS;


FROM TreeObjects   IMPORT
                        ATreeNode,
                        ValidateTreeNode;

FROM VaryAssgnment IMPORT
    (* PROC *)          CheckAssgnListValid;



CONST
    TaskRecTag = 111; (* Code confirms that this is a task record. *)
    EdgeRecTag = 233; (* Code confirms that this is an edge record. *)


VAR
    OverlayID            : AnOverlayID;
    Light                : ALight;
    OldCheckTaskValid,
    OldCheckEdgeValid    : PROC;
    CheckDepth           : CARDINAL; 


PROCEDURE CheckAssignmentsValid( Assignments : AnExtHandle );
VAR
    Count, i, j : CARDINAL;
    AssignmentArray     : AnAssignmentArray;
    Resource            : AResourcePointer;
    A : ADDRESS;
BEGIN
    INC(CheckDepth);
    IF (Assignments = AnExtHandle(NIL)) THEN RETURN; END;
    Count := LockObjectArray(Assignments, AssignmentArray, TSIZE(AnAssignmentRecord));
    IF (Count > 0) THEN
        FOR i := 0 TO Count-1 DO
            WITH AssignmentArray^[i] DO
                CheckResourceValid(Resource); 
                IF (Expenses <> AnExtHandle(NIL)) THEN
                    j := LockObject(Expenses,A);  ReleaseUnchangedObject(Expenses);
                END;
                CheckAssgnListValid(VaryingAssignment);
            END;
        END;
    END;
    ReleaseUnchangedObject(Assignments);
    DEC(CheckDepth);
    
END CheckAssignmentsValid;



PROCEDURE XCheckTaskValid(TaskNode:ATreeNode);

VAR
    Task                    : ATaskPtr;
    Edge                    : AnEdgePtr;
BEGIN
    IF (TaskNode = NIL) THEN FatalError(); END;
    ValidateTreeNode(TaskNode);
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    IF (Task^.rectag <> TaskRecTag) THEN FatalError END;


        (* Debugging 2/2/88 AJL  *)
    INC(CheckDepth);
    IF (CheckDepth <= 1) THEN
        Edge := Task^.desctasks;
        LOOP
            IF (Edge = NIL) THEN
                EXIT;
            ELSE
                IF (Edge^.headtask <> TaskNode) THEN FatalError(); END;
            END;
            Edge := Edge^.headlink;
        END;
        Edge := Task^.antetasks;
        LOOP
            IF (Edge = NIL) THEN
                EXIT;
            ELSE
                IF (Edge^.tailtask <> TaskNode) THEN FatalError(); END;
            END;
            Edge := Edge^.taillink;
        END;
        CheckAssignmentsValid(Task^.Plan.Assignments);
        CheckAssignmentsValid(Task^.BaseLine.Assignments);
    END;

    DEC(CheckDepth);



    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);       (* 11-Jan-88 LAA *)
END XCheckTaskValid;





PROCEDURE XCheckEdgeValid(Edge:AnEdgePtr);
BEGIN
    IF (Edge = NIL)                 OR
       (Edge^.rectag <> EdgeRecTag) THEN
        FatalError();
    END;

    INC(CheckDepth);
    IF (CheckDepth <= 1) THEN
        CheckTaskValid(Edge^.tailtask);
        CheckTaskValid(Edge^.headtask);
    END;
    DEC(CheckDepth);
END XCheckEdgeValid;







PROCEDURE Init();
VAR
    S : ARRAY [0..21] OF CHAR;
BEGIN
    InstallNewProcedure(ADR(CheckTaskValid),PROC(XCheckTaskValid), ADR(OldCheckTaskValid));
    InstallNewProcedure(ADR(CheckEdgeValid),PROC(XCheckEdgeValid), ADR(OldCheckEdgeValid));
    InstallLight(ActiveLightRegion, 0, 6, 6, Light);
    SetString(S,"TskChk");
    DisplayLight(Light, S, videowarning);
    CheckDepth := 0;
END Init;


PROCEDURE ShutDown();
BEGIN
END ShutDown;


BEGIN

    Init();  (* Initialize. *)

    OverlayID := ImALockedOverlay( AnOverlayProc(NIL), ShutDown );

END TLTskChk.

