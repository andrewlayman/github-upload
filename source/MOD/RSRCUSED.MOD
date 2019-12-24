IMPLEMENTATION MODULE RsrcUsed;


    (*  Used to be part of Changer.MOD; moved here 8/11/89 EGK  *)

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr,
    (* VAR *)                   TaskTree,
    (* PROC *)                  CheckTaskValid;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentRecord, AnAssignmentArray;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle,
    (* PROC *)                  LockObjectArray, ReleaseUnchangedObject;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion,
    (* PROC *)                  Permission;

FROM RsrcMod                IMPORT
    (* TYPE *)                  AResourcePointer;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder;



VAR
    LocalResource           : AResourcePointer;
    Used                    : BOOLEAN;




PROCEDURE TaskUsesResource(VAR TaskNode : ATreeNode;
                               Resource : AResourcePointer):BOOLEAN;
VAR Task : ATaskPtr;
    Plan,
    Base : AnExtHandle;


  PROCEDURE CheckOneHandle( Handle : AnExtHandle ) : BOOLEAN;
  VAR Count           : CARDINAL;
      AssignmentArray : AnAssignmentArray;
  BEGIN
    Count := 0;
    IF (ADDRESS(Handle) <> NIL) THEN
        Count := LockObjectArray(Handle,
                            AssignmentArray,
                            TSIZE( AnAssignmentRecord ) );
                             
        WHILE (Count > 0) AND
              (AssignmentArray^[Count-1].Resource <> Resource) DO
            DEC(Count);
        END;

        ReleaseUnchangedObject( Handle );
    END;
    RETURN (Count <> 0);
  END CheckOneHandle;    
    
BEGIN
    CheckTaskValid(TaskNode);
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    Plan := Task^.Plan.Assignments;
    Base := Task^.BaseLine.Assignments;
    TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
    RETURN (CheckOneHandle( Plan )  OR
            CheckOneHandle( Base ));
END TaskUsesResource;






PROCEDURE CheckIfResourceUsed(VAR TaskNode : ATreeNode; Context : ADDRESS);

BEGIN                       (* CheckIfResourceUsed *)

    Used := (Used OR TaskUsesResource(TaskNode, LocalResource)); (* RSC 5/1/89 *)

END CheckIfResourceUsed;




PROCEDURE ResourceIsUsed ( Node : ATreeNode ) : BOOLEAN;
VAR
    i : CARDINAL;
BEGIN

    Used          := FALSE;
    LocalResource := Node^.Methods^.GetDataObject (Node);

    TaskTree^.Methods^.TraverseTree(TaskTree, ParentBeforeChild, 999, 
                                    CheckIfResourceUsed, NIL);
    IF (NOT Used) THEN
        Used := (NOT (Permission( DeleteAResource, Node))); (* RSC 5/1/89 *)
    END;

    RETURN Used;

END ResourceIsUsed;



BEGIN
END RsrcUsed.


