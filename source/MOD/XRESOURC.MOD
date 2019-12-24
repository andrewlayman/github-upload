IMPLEMENTATION MODULE XResource;

(*  =========================================================================
    Last Edit : October 26, 1990 3:40PM by CL
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Save resources into a schedule file.

        Save Resource Assignments into a schedule file.


    MODIFICATION HISTORY:

         5-Sep-90 RSC  From TLXTL45, which had too many identifiers.
                       Save varying assignment lists, "Actuals" date, and
                       resource residual profiles.
        10-Sep-90 RSC  Oops.  I was LOCKING the assignment array, rather
                       than making a HEAP COPY, and so changes made to
                       the array to set the resource pointer to a resource
                       ID caused permanent damage to the assignment records.
		18-Oct-90 CL   Changed import of Storage module to Space.
        24-Oct-90 CL   Modified SaveProfile to use the head cell as a
                       boundary for searching thru the list.
        25-Oct-90 CL   Modified SaveProfile so that nothing will be done
                       if the availability list does not exist.
        26-Oct-90 CL   Modified SaveProfile to save file in the reverse
                       chronological order so that AddInterval can be used
                       to load profile later.
        10-Jan-91 AJL  Changed the record types for texts, because the format
                       is new.
         7-Feb-91 AJL -Modify the SaveOneAssignmentArray procedure so it doesn't
                       deallocate the a heap item unless it actually created
                       one.
      14-Feb-91 AJL  - Rename EndOf ActualDate to EndOfSpentDate.
      26-Apr-91 AJL  - Added count of number of resources saved to
                       SaveResources.
      30-Jan-92 LAA  - In SaveVaryingAssignments, we now put out both the
                       old format (CARDINAL) of the assignment records, and
                       the new format.  They must be put out in this order
                       so that versions 5.0.0 and 5.0.1 will be able to
                       read the old format stuff without choking on the new
                       format records.
      10-Feb-92 LAA  - Well, unfortunately the older code wouldn't read the
                       new format without error, so I'm trying again.
      25-Feb-92 AJL  - When converting dates to big times for storage into
                       the file, do not treat end dates specially.  Treat
                       them as start dates (parameter to CalendarTimeToBigTime)
                       so that the end date format is independent of the format
                       setting on the calendar settings form.

    =========================================================================
*)

FROM Assignments    IMPORT
    (* TYPE *)          AnAssignmentRecord, AnAssignmentArray;

FROM BigTimeU       IMPORT
    (* TYPE *)          ABigTime;

FROM DateLists      IMPORT
    (* TYPE *)          ADateListIndex,
    (* PROC *)          StoreDateList, GetDateListEntry;

FROM Dialog         IMPORT
    (* PROC *)          FatalError, Message;

FROM Expenses       IMPORT
    (* PROC *)          StoreExpenses;

FROM FileAux        IMPORT
    (* PROCS *)         PrepareForIO, CheckIO;

FROM FileSystem     IMPORT
    (* TYPE *)          File, Response;

FROM FlexStor       IMPORT
    (* TYPE *)          AnExtHandle,
    (* PROC *)          LockObject, ReleaseUnchangedObject, NumberOfElements,
                        MakeHeapCopy;

FROM RateLists      IMPORT
    (* TYPE *)          ARateList,
    (* PROC *)          StoreRateList;

FROM RecordIO       IMPORT
    (* PROC *)          WriteRecord;

FROM ResCal         IMPORT
    (* TYPE *)          AnAvailabilityCell, AnAvailabilityCellPointer;

FROM ResCalUI       IMPORT
    (* TYPE *)          AResourceCalendarPointer, ACalendarEntry;

FROM RsrcMod        IMPORT
    (* TYPE  *)         AResourcePointer, AResourceType,
    (* PROC *)          CheckResourceValid;

FROM SaveCommon     IMPORT
    (* PROCS *)         WriteText, WriteNodeInfo;

FROM Space          IMPORT
    (* PROC *)          DEALLOCATE;

FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS,
    (* PROC *)          ADR, SIZE, TSIZE;

FROM Subfiles       IMPORT
    (* PROCS *)         StartSubfileOutput, EndSubfileOutput;

FROM TimeXlate      IMPORT
    (* PROC *)          CalendarTimeToBigTime;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeNodeAttribute, ATreeOrder,
    (* PROC *)          ValidateTreeNode, ValidateTree;

FROM VaryAssgnment  IMPORT
    (* TYPE *)          AVaryingAssgnList,
    (* PROC *)          StoreVaryingAssgnList, StoreVaryingAssgnListOldFormat;







(* This is duplicated from TLXTL45.
*)
PROCEDURE IsIncluded  (   Node    : ATreeNode ) : BOOLEAN;
CONST
    SaveThisOne     = TempFlag2;
BEGIN
    RETURN Node^.Methods^.TestAttributeBit (Node, SaveThisOne);
END IsIncluded;






    (* SaveRecordToFile, and its associated context data type are 
       used together with the Filing.ASaveProc type of procedure
       to allow data modules to save data without our knowing anything
       about the insides of the data type, or the module knowing  
       anything about filing.
    *)



TYPE
    ARecordSavingContext = RECORD 
                               TheFile          : POINTER TO File;
                               NumSaved         : LONGINT;
                               TheType          : CARDINAL;
                               EvenNullRecords  : BOOLEAN;
                           END; 
    ARecordSavingContextPointer = POINTER TO ARecordSavingContext;


PROCEDURE SaveRecordToFile (  Data      : ADDRESS;
                              Size      : CARDINAL; 
                              Context   : ADDRESS );
VAR 
   Ctx : ARecordSavingContextPointer;   
BEGIN 
   Ctx := Context;
   WITH Ctx^ DO 
       IF (Size > 0) OR (EvenNullRecords) THEN
           WriteRecord(TheFile^,TheType,Data,Size);
       END; 
   END; 
END SaveRecordToFile; 















(* Save a resource calendar.

    BaseType is the type to start saving with.
    On return, BaseType is the NEXT AVAILABLE number (after this cal).
*)
PROCEDURE SaveCalendar( VAR f          : File;
                            Calendar   : AResourceCalendarPointer;
                        VAR BaseType   : CARDINAL );
VAR
    Ctx               : ARecordSavingContext;
BEGIN
    IF (Calendar <> NIL) THEN
        WriteRecord(f,BaseType,Calendar,SIZE(Calendar^));
        INC(BaseType);
        WITH Calendar^ DO
            WriteText(f, Notes,  BaseType);
            INC(BaseType);
            WriteText(f, Extras, BaseType);
            INC(BaseType);
            Ctx.TheFile         := ADR(f); (* 17-Aug-90 RSC *)
            Ctx.NumSaved        := 0L;
            Ctx.TheType         := BaseType;
            Ctx.EvenNullRecords := FALSE; 
            StoreDateList(CalendarIntervals,SaveRecordToFile,ADR(Ctx)); 
            INC(BaseType);
        END;
    ELSE
        INC(BaseType,4);
    END;

END SaveCalendar;







PROCEDURE SaveProfile( VAR f             : File;
                           AvailProfile  : AnExtHandle;
                       VAR Type          : CARDINAL );
TYPE
    ASavedAvailabilityCell =
        RECORD
            StartDate,
            EndDate             : ABigTime;
            AmountAvailable     : LONGINT;
            ThisIsAVacation     : BOOLEAN;
            ThisIsTheEnd        : BOOLEAN;
        END;
VAR
    CellHandle,
    PrevHandle       : AnExtHandle;
    SavedCell        : ASavedAvailabilityCell;
    Cell             : AnAvailabilityCellPointer;
    First, 
    BackToHeadCell   : BOOLEAN;
BEGIN
    IF AvailProfile <> AnExtHandle(NIL) THEN
        CellHandle := AvailProfile;
        First          := TRUE;
        BackToHeadCell := FALSE;
        REPEAT
            IF (LockObject(CellHandle, Cell) <> TSIZE(AnAvailabilityCell)) THEN
                FatalError();
            END;
    
            IF ( Cell^.IsHeadCell AND (NOT First) ) THEN  
                ReleaseUnchangedObject( CellHandle );
                Cell := NIL;
                BackToHeadCell := TRUE;
            ELSE
                WITH Cell^ DO
                    PrevHandle := PrevCell;
                    IF (NOT IsHeadCell) THEN
                        CalendarTimeToBigTime( StartDate, TRUE,  SavedCell.StartDate );
                        CalendarTimeToBigTime( EndDate,   TRUE,  SavedCell.EndDate   );
                        SavedCell.AmountAvailable := AmountAvailable;
                        SavedCell.ThisIsAVacation := ThisIsAVacation;
                        IF (PrevHandle = AvailProfile) THEN
                            SavedCell.ThisIsTheEnd := TRUE;
                        ELSE
                            SavedCell.ThisIsTheEnd := FALSE;
                        END;
                        WriteRecord( f, Type, ADR(SavedCell), SIZE(SavedCell));
                    END;
                END;
                ReleaseUnchangedObject( CellHandle );
                Cell := NIL;
                CellHandle := PrevHandle;
            END;
            First := FALSE;
        UNTIL BackToHeadCell;
    
        INC(Type);

    END;
END SaveProfile;








PROCEDURE SaveOneResource(VAR ResourceNode : ATreeNode;
                              ContextPtr   : ADDRESS );
VAR
    BaseType          : CARDINAL;
    Resource          : AResourcePointer;
    Ctx               : ARecordSavingContextPointer;   
    NumberSaved       : LONGINT;
BEGIN

    Ctx      := ContextPtr;
    BaseType := Ctx^.TheType;

    IF (CheckIO(Ctx^.TheFile^) = done) THEN

        ValidateTreeNode(ResourceNode);

        IF (NOT IsIncluded (ResourceNode)) THEN           (* 3/17/89 EGK *)
            RETURN;
        END;

        Resource := ResourceNode^.Methods^.GetDataObject(ResourceNode);

        CheckResourceValid(Resource);

        Message(Resource^.Name);

        INC(Ctx^.NumSaved);

        WriteNodeInfo( Ctx^.TheFile^, ResourceNode, 0, 0);
        WriteRecord(   Ctx^.TheFile^, Ctx^.TheType, Resource, SIZE(Resource^));

        WITH Resource^ DO

            WriteText(Ctx^.TheFile^, Notes, 102);
            WriteText(Ctx^.TheFile^, Extras, 103);

              (* Save rates, using our data-independent file saving. *) 

            INC(Ctx^.TheType);
            StoreRateList(ActualRates,SaveRecordToFile,Ctx); 

            INC(Ctx^.TheType);
            StoreRateList(BaseLineRates,SaveRecordToFile,Ctx); 

            INC(Ctx^.TheType);
            StoreDateList(Availability,SaveRecordToFile,Ctx); 

            INC(Ctx^.TheType);
            StoreDateList(BaselineAvailability,SaveRecordToFile,Ctx); 

            INC(Ctx^.TheType);
            SaveCalendar(Ctx^.TheFile^, Calendar,         Ctx^.TheType );
            SaveCalendar(Ctx^.TheFile^, BaselineCalendar, Ctx^.TheType );

            SaveProfile( Ctx^.TheFile^, ResidueAvailProfile, Ctx^.TheType );
        END;
    END;

    Ctx^.TheType := BaseType; (* Restore the type before exit!! *)

END SaveOneResource;












PROCEDURE SaveResources( VAR F              : File;
                             ResourceTree   : ATree;
                             Type,
                             VersionNumber  : CARDINAL;
                         VAR NumberSaved    : LONGINT );
VAR
    Context : ARecordSavingContext;
BEGIN

    StartSubfileOutput( F, Type, VersionNumber );

    ValidateTree(ResourceTree);

    WITH Context DO
        TheFile         := ADR(F);
        NumSaved        := 0L;
        TheType         := Type;
        EvenNullRecords := FALSE; 
    END;

    ResourceTree^.Methods^.TraverseTree(ResourceTree,ParentBeforeChild,
                                        9999,SaveOneResource,ADR( Context ));

    IF (CheckIO(F) = done) THEN
        EndSubfileOutput(F,Type);
    END;

    NumberSaved := Context.NumSaved;

END SaveResources;





PROCEDURE SaveOneExpenseArray( VAR f              : File;
                                   ExpenseHandle  : AnExtHandle;
                                   Type           : CARDINAL;
                                   SequenceNumber : CARDINAL );
VAR
    Ctx            : ARecordSavingContext;   
BEGIN
        (* Save a preface record, giving the sequence number of this
           expense record. *)
    WriteRecord(f,Type,ADR(SequenceNumber),SIZE(SequenceNumber));

        (* Save expenses, using our data-independent file saving. *) 
    WITH Ctx DO
        TheFile := ADR(f); 
        NumSaved := 0L;
        TheType := Type+1;      (* Parms to SaveRecordToFile. *)
        EvenNullRecords := FALSE; 
    END;
    StoreExpenses(ExpenseHandle,SaveRecordToFile,ADR(Ctx)); 

END SaveOneExpenseArray;



PROCEDURE SaveVaryingAssignments( VAR f              : File;
                                      Handle         : AVaryingAssgnList;
                                      Type           : CARDINAL;
                                      SequenceNumber : CARDINAL );
VAR
    Ctx            : ARecordSavingContext;   
BEGIN

        (* Save a preface record, giving the sequence number of this
           assignment record. *)
    WriteRecord(f,Type,ADR(SequenceNumber),SIZE(SequenceNumber));

    WITH Ctx DO
        TheFile := ADR(f); 
        NumSaved := 0L;
        TheType := Type+4;      (* Parms to SaveRecordToFile. *)
        EvenNullRecords := FALSE; 
    END;
    StoreVaryingAssgnList( Handle, SaveRecordToFile, ADR(Ctx) );

END SaveVaryingAssignments;




PROCEDURE SaveVaryingAssignmentsOldFormat( VAR f              : File;
                                               Handle         : AVaryingAssgnList;
                                               Type           : CARDINAL;
                                               SequenceNumber : CARDINAL );
VAR
    Ctx            : ARecordSavingContext;   
BEGIN

        (* Save a preface record, giving the sequence number of this
           assignment record. *)
    WriteRecord(f,Type,ADR(SequenceNumber),SIZE(SequenceNumber));

        (* Save expenses, using our data-independent file saving. *) 

    WITH Ctx DO
        TheFile := ADR(f); 
        NumSaved := 0L;
        TheType := Type+1;      (* Parms to SaveRecordToFile. *)
        EvenNullRecords := FALSE; 
    END;
    StoreVaryingAssgnListOldFormat( Handle, SaveRecordToFile, ADR(Ctx) );

END SaveVaryingAssignmentsOldFormat;



PROCEDURE SaveOneAssignmentArray( VAR f      : File;
                                      Handle : AnExtHandle;
                                      Type   : CARDINAL );
VAR
    AssignmentArray         : AnAssignmentArray;
    ExtrasCount,
    VaryingAssgnCount,
    i                       : CARDINAL;
    AssignmentCount         : CARDINAL;
    ResourcePointer         : AResourcePointer;
    AssignmentSize          : CARDINAL;
    BigTime                 : ABigTime;
    AddressTrick            : RECORD
        CASE BOOLEAN OF
            TRUE :  P   : ATreeNode;
          | FALSE:  C   : RECORD
                            A, B : CARDINAL;
                          END;
        END;
    END;
BEGIN
    AddressTrick.C.B := 0;      (* Make high order byte 0 *)
    IF (ADDRESS(Handle) <> NIL) AND
       (MakeHeapCopy(Handle, AssignmentArray, AssignmentSize)) THEN
        AssignmentCount := NumberOfElements( AssignmentSize, TSIZE(AnAssignmentRecord) );
        IF AssignmentCount > 0 THEN
            ExtrasCount       := 0;
            VaryingAssgnCount := 0;
                (* Substitute the Resource ID's into the record. *)
            FOR i := 0 TO AssignmentCount - 1 DO
(*$O-*)
                WITH AssignmentArray^[i] DO
                    ResourcePointer := Resource;
                    AddressTrick.C.A := ResourcePointer^.ID;
                    Resource := AResourcePointer(AddressTrick.P);
                    IF (Expenses <> AnExtHandle(NIL)) THEN
                        INC(ExtrasCount);
                    END;
                    IF (VaryingAssignment <> AVaryingAssgnList(NIL)) THEN
                        INC(VaryingAssgnCount);
                    END;
                END;
(*$O=*)
            END;

            INC( ExtrasCount, VaryingAssgnCount );

                (* Write out the modified copy of the array. *)
            WriteRecord(f,Type,AssignmentArray,AssignmentSize);
            WriteRecord(f,Type+1,ADR(ExtrasCount),SIZE(ExtrasCount));

                (* Write out each of the expenses and varying
                   assignment lists.
                *)
            FOR i := 0 TO AssignmentCount - 1 DO
(*$O-*)
                WITH AssignmentArray^[i] DO
                    IF (Expenses <> AnExtHandle(NIL)) THEN
                        SaveOneExpenseArray(f, Expenses, Type+2, i);
                    END;

                    IF (VaryingAssignment <> AVaryingAssgnList(NIL)) THEN
                        SaveVaryingAssignmentsOldFormat(f, VaryingAssignment, 
                                                        Type+4, i);
                        CalendarTimeToBigTime(EndOfSpentDate,TRUE,BigTime );
                        WriteRecord(f,Type+6,ADR(BigTime),SIZE(BigTime));
                    END;
                END;
(*$O=*)
            END;

            WriteRecord(f,Type+7,ADR(VaryingAssgnCount),SIZE(VaryingAssgnCount));

            FOR i := 0 TO AssignmentCount - 1 DO
(*$O-*)
                WITH AssignmentArray^[i] DO
                    IF (VaryingAssignment <> AVaryingAssgnList(NIL)) THEN
                        SaveVaryingAssignments(f,VaryingAssignment,Type+4,i);
                    END;
                END;
(*$O=*)
            END;

            DEALLOCATE( AssignmentArray, AssignmentSize ); (* 10-Sep-90 RSC *)
        END;
    END;
END SaveOneAssignmentArray;








END XResource.


