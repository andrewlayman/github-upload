IMPLEMENTATION MODULE Assignments;

(*V1=TRACE *)


(*  =========================================================================
    Last Edit : February 21, 1991 6:35PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 

            Module created 5/6/87 by RSC.

            Assignments - Manage Assignment and Expense records.

      This module defines and maintains the cost related records.
      These records are kept in extended storage.  The Task record
      points to arrays of AnAssignmentRecord, which each can point
      to an array of AnExpenseRecord.

      AssignmentRecords tie resources to tasks.  A task can have many
      resources, each requiring exactly one AssignmentRecord.

      ExpenseRecords tie a specific line item cost to a resource for
      this task.  A resource can have many ExpenseRecords.

      Spike Limitations:  In SPIKE, A task can have 0-18 resources.
         Each resource can have 0-13 expenses, although the screens
         wont allow expences for anything but Actuals (not BaseLine
         or Planned).

      MODIFICATION HISTORY:

        RSC 05/06/87 - First version, based on Andrew's 5/4/87 costs
                       document.
        09-Dec-87 LAA  Substituted use of LockObjectArray for LockObject.
        25-Jan-88 LAA  Turned optimization off around a "dangerous" piece of
                       code.
        19-Jun-90 AJL  RemoveAssignmentsAndExpenses now removes expenses and
                       varying assignments, too.  Uses a WITH statement.
        27-Jun-90 AJL  CopyAssignment now copies the VaryingAssignment
                       structure (rather than just making a duplicate handle).
        JES  7-Aug-90 - Added and then removed fields "ComputedStartDate"
                        and "ComputedEndDate" from assignment record. (They
                        were to replace varying assignment structure but
                        it turns out we still need that.)
        05-Nov-90 PFG   Initialized OvertimeTimeUnits so it can be used on
                        the Assignment form.
        RSC 22-Jan-91 - Removed VaryAssignment import to save 4KB from the
                        root.

                        PLEASE NOTE THAT THE "VaryingAssignment" is REALLY
                        a VaryAssignment type.

                        DANGER!! Two VaryAssignment procedures were
                                 duplicated here to save the import.
                                 This is only for EVE and should not carry
                                 further (to MARILYN).

        RSC 14-Feb-91 - Moved the notice catcher here from AssForms to get
                        it out of the TLAssgn overlay.
        RSC 21-Feb-91 - Oops, had the order of the SEGMENT, OFFSET in the
                        AddressTrick backwards.
        18-Sep-91 TGS   Initialize EndOfSpentDate in InitAssignment.
    =========================================================================
*)


FROM Expenses           IMPORT
    (* PROC *)              DisposeExpenseArrayHandle, CopyExpenseArrayHandle;

FROM FlexStor           IMPORT
     (* TYPES *)            AnExtHandle, AnExtStoragePreference,
     (* PROCS *)            LockObjectArray, ReleaseObject, DiscardExtObject,
                            CopyExtObject, HandleIsValid;

FROM Notices            IMPORT
    (* TYPE *)              AStep, AnOccasion,
    (* PROC *)              RegisterForNotices;

FROM RsrcMod            IMPORT
    (* TYPE *)              AResourcePointer, AResourceType;

FROM SYSTEM             IMPORT
     (* TYPES *)           ADDRESS, TSIZE;

FROM Timei              IMPORT
     (* TYPE *)            ADuration, ADurationUnit;   

FROM Timeu              IMPORT
    (* VAR *)              FSMUPH;

FROM TreeObjects        IMPORT
    (* TYPE *)              ATree, ATreeNode;

(*FROM VaryAssgnment IMPORT*)
(*    (* TYPE *)          AVaryingAssgnList, *)
(*    (* PROC *)          CopyVaryingAssgnList, DisposeVaryingAssgnList;*)

(*<TRACE
FROM Codes  IMPORT    ACode, ASetOfCodes;
FROM Dialog IMPORT NotYetImplemented, MessageBox, FatalError;
FROM Kbio   IMPORT KeyPress, GetAnyCode;
FROM LStrings IMPORT SetString, ConcatS, ConcatLS, CtoS;
FROM FlexDisp IMPORT HandleToString;
TRACE>*)


 CONST
           ModuleNumber      =  16300;  (* For GetMessage *)
           OneHundred        =  100.0;
           Zero              = 0.0;



PROCEDURE InitAssignment(     ResourcePtr      : AResourcePointer;
                          VAR AssignmentRecord : AnAssignmentRecord );
VAR
    PE          : CARDINAL;
BEGIN
    WITH AssignmentRecord DO
        Resource            := ResourcePtr;
        Attributes          := AnAssignmentAttributeSet{Billable};
        ActualTimeUnits     := Days;
        MaxRateUnits        := 0;  (* PLANNER USE ONLY *)
        Expenses            := AnExtHandle(NIL);
        ActualQuantity      := Zero;
        YetToGoQuantity     := Zero;
        OvertimeHours       := 0L;
        YetToGoOvertimeHours:= 0L;
        ExtraCosts          := Zero;
        VaryingAssignment   := AnExtHandle(NIL);
        EndOfSpentDate      := 0;                   (* 18-Sep-91 TGS *)
        Spare               := {};
        Roles               := ASetOfRoles{};
        OvertimeTimeUnits   := Days;                (* 5-Nov-90 PFG *)

        IF (ResourcePtr <> NIL) THEN
            WITH ResourcePtr^ DO
                IF (Limit > 65535.0) THEN
                    MaxRatePercent := 65000;
                ELSE
                    MaxRatePercent := TRUNC(Limit);
                END;
                IF (ResourcePtr^.Percent > 250) THEN
                    PE  := 250;
                ELSE
                    PE  := ResourcePtr^.Percent;
                END;
                IF (PE = 0) THEN
                    MaxRatePercent := 0;
                ELSE
                    MaxRatePercent := (MaxRatePercent DIV PE)
                                              * PE; (* Normalize *)
                END;
                PercentageEach := CHR(PE);
                IF (Type = Employable) THEN
                    INCL(Attributes,AllowLevel); (* A Resource *)
                END;
            END;
        END;
    END;
END InitAssignment;



  (*  ForEachAssignment - Call a routine for each assignment record.

      Preconditions  - Must have a valid assignment handle.
                       Must provide a procedure to be called for each
                       assignment record.
                       Context is user context and not used by this procedure.
                       use it to pass any data you want between levels.

      Postconditions - your procedure will have been called once for
                       each found assignment.  If there were no assignment
                       records, then it will never have been called.
  *)

(*$O-*)     (*  Because the AssignmentArray^[Loop] construct may screw up  25-Jan-88 LAA
                when optimization is on.  *)

PROCEDURE ForEachAssignment( AssignmentHandle : AnExtHandle;
                             CalledEachTime   : AnAssignmentProc;
                             Context          : ADDRESS );
VAR AssignmentArray   : AnAssignmentArray;
    Loop, Count       : CARDINAL;
BEGIN

    Count := LockObjectArray(AssignmentHandle,AssignmentArray,TSIZE(AnAssignmentRecord));
    IF Count > 0  THEN
        FOR Loop := 0 TO Count - 1 DO
            IF CalledEachTime( AssignmentArray^[Loop], Context ) = FALSE THEN
                ReleaseObject( AssignmentHandle );
                RETURN;
            END;
        END;
    END;
    ReleaseObject( AssignmentHandle );


END ForEachAssignment;

(*$O=*)



    (*----------------------------------------------------------------------

     DisposeOneAssignmentRecordContents

     Deep dispose any subrecords of a single assignment record.

     ----------------------------------------------------------------------*)



PROCEDURE DisposeOneAssignmentRecordContents( VAR R : AnAssignmentRecord );
BEGIN
    WITH R DO
        DisposeExpenseArrayHandle( Expenses );
(*!!!!    DisposeVaryingAssgnList(VaryingAssignment);*)
(* 22-Jan-91 RSC DANGER!!  EVE Size optimization only!! *)
        DiscardExtObject( VaryingAssignment );
    END;
END DisposeOneAssignmentRecordContents;





  (* RemoveAssignmentsAndExpenses - remove all references to this
             Assignment record and its expenses, if any.

         Preconditions - Handle to AnAssignmentRecord.
                         (Can be a bad handle (NIL))

         Postconditions - Assignment record and its expenses removed.
   *)

PROCEDURE RemoveAssignmentsAndExpenses( VAR Handle : AnExtHandle );
VAR
    Count           : CARDINAL;
    Loop            : CARDINAL;
    AssignmentArray : AnAssignmentArray;
    (*<TRACE
    S, S2 : ARRAY [0..80] OF CHAR;
    C     : ACode;
    TRACE>*)
BEGIN
       (*<TRACE
    SetString(S,"Remove Assignment and Exp "); HandleToString(Handle,S2); ConcatLS(S,S2);
    MessageBox(S,S2);
    C := GetAnyCode();
    IF (Handle <> AnExtHandle(NIL)) AND
       NOT (HandleIsValid(Handle)) THEN
        FatalError;
    END;
       TRACE>*)


    IF (Handle <> AnExtHandle(NIL)) THEN
        Count := LockObjectArray( Handle, AssignmentArray, TSIZE(AnAssignmentRecord));
        IF Count > 0 THEN
            FOR Loop := 0 TO Count - 1 DO
                DisposeOneAssignmentRecordContents( AssignmentArray^[ Loop ] );
            END;
        END;
        ReleaseObject(Handle);
        DiscardExtObject(Handle);
    END;
END RemoveAssignmentsAndExpenses;


    (* ------------------------------------------------------------------

       CopyAssignmentSubfields

       Make each subfield pointer or handle in the assignment record into
       a pointer or handle to a copy of the original.

   -------------------------------------------------------------------- *)


PROCEDURE CopyAssignmentSubfields( VAR Assignment : AnAssignmentRecord;
                                      Speed      : AnExtStoragePreference);
VAR
    TempHandle              : AnExtHandle; 

    (*<TRACE
    S, S2 : ARRAY [0..80] OF CHAR;
    C     : ACode;
    TRACE>*)

BEGIN
    (* Copy the subrecords. *)

    WITH Assignment DO
        TempHandle := Expenses;
        IF (TempHandle <> AnExtHandle(NIL))THEN 
            CopyExpenseArrayHandle(Expenses,TempHandle,Speed);
        END;
           (*<TRACE
        SetString(S,"ASSG: Copy varying assignment handle "); HandleToString(VaryingAssignment,S2); ConcatLS(S,S2);
        MessageBox(S,S2);
        C := GetAnyCode();
        IF (VaryingAssignment <> AnExtHandle(NIL)) AND
           NOT (HandleIsValid(VaryingAssignment)) THEN
            FatalError;
        END;
           TRACE>*)
        TempHandle := VaryingAssignment;
        IF (TempHandle <> AnExtHandle(NIL)) THEN 
(*!!!!!!    CopyVaryingAssgnList(VaryingAssignment,TempHandle,Speed);*)
(* 22-Jan-91 RSC DANGER!!  EVE Size optimization only!! *)
            IF (NOT CopyExtObject( TempHandle, Speed, VaryingAssignment )) THEN
                VaryingAssignment := AnExtHandle(NIL);
            END;
        END;
           (*<TRACE
        ConcatS(S," to "); HandleToString(VaryingAssignment,S2); ConcatLS(S,S2);
        MessageBox(S,S2);
        C := GetAnyCode();
        IF (VaryingAssignment <> AnExtHandle(NIL)) AND
           NOT (HandleIsValid(VaryingAssignment)) THEN
            FatalError;
        END;
           TRACE>*)
    END;
END CopyAssignmentSubfields;



    (*----------------------------------------------------------------------

     CopyOneAssignmentRecord

     Deep copy a single assignment record.

     ----------------------------------------------------------------------*)

PROCEDURE CopyOneAssignmentRecord ( VAR Target : AnAssignmentRecord;
                                        Source : AnAssignmentRecord;
                                        Speed      : AnExtStoragePreference);

BEGIN
    Target := Source;     (* Copy the basic fields. *)
    CopyAssignmentSubfields(Target,Speed);
END CopyOneAssignmentRecord;









    (* CopyOneAssignmentWithSpeed - Copy one assignment handle to another,
                        including any expenses.

          Preconditions  - FromHandle is the valid (though possibly NIL)
                               assignment handle from a Task record.
                           ToHandle is the destination handle.  It is
                               created by this procedure.
                           Speed is the new speed for the copy.  It is 
                               here because BaseLine may be very slow, while
                               Actual may be medium or fast.

          Postconditions - ToHandle has a COPY of the assignment records,
                           and each assignment record contains a COPY of
                           its expense record.  They may be NIL.

                           IF FromHandle is NOT NIL but ToHandle IS, then
                           the copy failed (probably for lack of memory).
     *)

PROCEDURE CopyOneAssignmentWithSpeed( FromHandle : AnExtHandle;
                                VAR   ToHandle   : AnExtHandle;
                                      Speed      : AnExtStoragePreference);

VAR Count, i                : CARDINAL;
    AssignmentArray         : AnAssignmentArray;
    TempHandle              : AnExtHandle; 

    (*<TRACE
    S, S2 : ARRAY [0..80] OF CHAR;
    C     : ACode;
    TRACE>*)

BEGIN
       (*<TRACE
    SetString(S,"ASSG: CopyOneAssignmentWithSpeed "); HandleToString(FromHandle,S2); ConcatLS(S,S2);
    MessageBox(S,S2);
    C := GetAnyCode();
    IF (FromHandle <> AnExtHandle(NIL)) AND
       NOT (HandleIsValid(FromHandle)) THEN
        FatalError;
    END;
       TRACE>*)

    IF (ADDRESS(FromHandle) = NIL) THEN
        ToHandle := AnExtHandle(NIL);
        RETURN;
    END;

    IF (CopyExtObject( FromHandle, Speed, ToHandle ) ) THEN
        Count := LockObjectArray( ToHandle,
                            AssignmentArray,
                            TSIZE(AnAssignmentRecord));
    
            (* Replace each expense record handle with a handle 
                   to a COPY of the original. *)

        IF Count > 0 THEN
            FOR i := 0 TO Count-1 DO
                CopyAssignmentSubfields(AssignmentArray^[i],Speed);
            END;
        END;
        ReleaseObject( ToHandle );
    ELSE
        ToHandle := AnExtHandle(NIL);
    END;

       (*<TRACE
    SetString(S,"ASSG: CopyOneAssignmentWithSpeed "); HandleToString(FromHandle,S2); ConcatLS(S,S2);
    ConcatS(S," to ");  HandleToString(ToHandle,S2); ConcatLS(S,S2);
    MessageBox(S,S2);
    C := GetAnyCode();
    IF (ToHandle <> AnExtHandle(NIL)) AND
       NOT (HandleIsValid(ToHandle)) THEN
        FatalError;
    END;
       TRACE>*)

END CopyOneAssignmentWithSpeed;




    (*----------------------------------------------------------------------

    DurationOf

    Return the minimum duration that could be used be the assignment record,
    given its percentage assigned and effort hours.

    This uses the formula "Duration = Effort/NumberOfPeople" and does conversions
    to the current calendar precision.


    ------------------------------------------------------------------------*)

PROCEDURE DurationOf ( NumberOfPeople : CARDINAL;
                       EffortHours    : REAL      ) : ADuration;
VAR
    Ticks         : CARDINAL;
BEGIN
    Ticks := TRUNC( FSMUPH * EffortHours * OneHundred  / FLOAT(NumberOfPeople) );
    RETURN VAL(ADuration,Ticks);
END DurationOf;




(* When a resource is deleted, see if the resource is in use on a form.
   This would happen if an assignment on a form refers to this resource,
   and the assignment is in the assignment tree managed by the AssTree
   module and used by AssForms and AssList.
*)
PROCEDURE NoticeResourceDeletion(     Occasion : AnOccasion;
                                      Step     : AStep;
                                      Context  : ADDRESS    ) : BOOLEAN;
VAR
    ResourcePtr     : AResourcePointer;
    AssgnNode,
    RsrcNode        : ATreeNode;

    AddressTrick    : RECORD
        CASE BOOLEAN OF
            TRUE    : A : ADDRESS;
          | FALSE   : Position, ID : INTEGER;   (* 21-Feb-91 RSC swapped order *)
        END;
    END;
BEGIN
    IF (Step = RequestPermission) AND
       (AssTree <> ATree(NIL))    THEN
        RsrcNode    := ATreeNode(Context);
        ResourcePtr := RsrcNode^.Methods^.GetDataObject (RsrcNode);

        AssgnNode   := AssTree^.Methods^.GetFirstVisible(AssTree);

        WHILE (AssgnNode <> NIL) DO
            AddressTrick.A := AssgnNode^.Methods^.GetDataObject( AssgnNode );
            IF (AddressTrick.ID = ResourcePtr^.ID) THEN
                RETURN FALSE;
            END;
            AssgnNode := AssgnNode^.Methods^.NextForDisplay(AssgnNode);
        END;
    END;
        
    RETURN TRUE;

END NoticeResourceDeletion;



(* Initialize the assignments module.  Called once in TimeLine.mod
*)
PROCEDURE InitializeAssignments();
BEGIN
    RegisterForNotices( DeleteAResource, NoticeResourceDeletion );
END InitializeAssignments;


BEGIN
    AssTree := ATree(NIL);
END Assignments.

