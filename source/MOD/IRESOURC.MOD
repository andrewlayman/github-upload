IMPLEMENTATION MODULE IResource;

(*  =========================================================================
    Last Edit : May 29, 1991 4:36PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Save resources into a schedule file.

        Save Resource Assignments into a schedule file.
        

    MODIFICATION HISTORY:

         5-Sep-90 RSC  From TLITL45, which had too many identifiers.
                       Load varying assignment lists, "Actuals" date, and
                       resource residual profiles.

        12-Sep-90 RSC  Made the version number 2.
        13-Sep-90 RSC  Store the old ID number in the WorkSpace field,
                       so the TLLnkSum can determine the old ID's, even
                       for resources combined in and ignored.  This allows
                       us to not FlushUndos, and yet doesn't require a
                       dictionary.
        17-Sep-90 RSC  Oops.  Had made a <> where it should be =.
        26-Oct-90 CL/AJL   Modifiy LoadProfile to make the availability
                           list a doubly linked list with a head cell.
        11-Nov-90 AJL  Set LateResidueAvailProfile to NIL when reading 
                       in a resource.
        10-Jan-91 AJL  Read in new format Text lines.
        14-Feb-91 AJL  Rename EndOf ActualDate to EndOfSpentDate.
        11-Apr-91 AJL  Display a progress thermometer while reading resources.
        17-Apr-91 RSC  Dissavow duplicate resource assignments.
        18-Apr-91 RSC  Fixed infinite loop in above fix.
         7-May-91 RSC  Return the DuplicateAssignments flag, rather than
                       acting on it.
        29-May-91 RSC  Zero out Overtime in existing schedules, so as to not
                       hurt later calculations.  This is temporary until
                       we re-instate overtime, or REALLY remove it.
        25-Sep-91 AJL -On some cases of File I/O errors we were not unlocking
                       handles.
                      -Add more i/o error checking.
                      -Add BOOLEAN return value to ReadAssignmentArray.
        26-Sep-91 AJL -Clear the DuplicateResources flag earlier in above.
        30-Jan-92 LAA -In ReadAssignmentArray, we must now read both old 
                       and new formats of the varying assignments.  The old
                       formats have been written out first, so that previous
                       versions of this code can read them and then not even
                       try to read the new formats ('cause that would cause
                       an error message).
        10-Feb-92 LAA -Well, unfortunately the older code wouldn't read the
                       new format without error, so I'm trying again.
        26-Feb-92 AJL -If old-style, limited accuracy varying assignment 
                       records are found, set the state to Unscheduled so that
                       a recalc will occur.
        19-Mar-92 LAA -Added a global boolean to indicate whether a new
                       varying assignment record format was found, so that if
                       not we can set up recalc correctly.  This is a hack!
                       If this wasn't the last version of Time Line, I'd NEVER
                       put in such a kludge!  Sorry.
    =========================================================================
*)

FROM Assignments    IMPORT
    (* TYPE *)          AnAssignmentAttribute, AnAssignmentAttributeSet,
                        AnAssignmentRecord, AnAssignmentArray;

FROM BigTimeU       IMPORT
    (* TYPE *)          ABigTime;

FROM ChartControl IMPORT  AChartState, UnSetState;

FROM DateLists      IMPORT
    (* TYPE *)          ADateList, ADateListIndex,
    (* PROC *)          LoadDateList, DisposeDateList, GetDateListEntry;
                          
FROM Dialog         IMPORT
    (* PROC *)          Message, Error, FatalError, ErrorPhrase;

FROM Expenses       IMPORT
    (* PROC *)          LoadExpenses;

FROM FileAux        IMPORT
    (* PROC *)          CheckIO, FileResultMeans;

FROM FileSystem     IMPORT
    (* TYPE *)          File, Response,
    (* PROC *)          GetPos, SetPos;

FROM FlexStor       IMPORT
    (* TYPE *)          AnExtHandle, AnExtStatus, AnExtStoragePreference,
    (* PROC *)          LockObjectArray, GetExtStatus, ReleaseObject,
                        CreateExtObjectWithSize, SetExtSize, ArraySize,
                        LockObject, DiscardExtObject;

FROM Kbio           IMPORT
    (* PROC *)          BreakRequested;

FROM LoadCommon     IMPORT
    (* TYPE *)          ErrorFlag,
    (* PROC *)          SkipRecordBody, ReadTextLine, ReadOldFormatTextLine;

FROM LStrings       IMPORT
    (* PROC *)          Copy;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage;

FROM Progress               IMPORT
    (* TYPE *)                      AThermometer,
    (* PROC *)                      CreateThermometer, UpdateThermometer, 
                                    DiscardThermometer;
FROM RateLists      IMPORT
    (* TYPE *)          ARateList,
    (* PROC *)          LoadRateList, DisposeRateList;
                          
FROM RecordIO       IMPORT
    (* PROC *)          ReadRecordPreface, ReadRecordBody, ReadRecord;

FROM ResCal         IMPORT
    (* TYPE *)          AnAvailabilityCellPointer, AResAvailability,
    (* PROC *)          CreateNewCell, DisposeResAvailabilities;

FROM ResCalMG       IMPORT
    (* PROC *)          AddInterval;

FROM ResCalUI       IMPORT
    (* PROC *)          ACalendarEntry,
                        CreateCalendar, DisposeCalendar;

FROM RsrcMod        IMPORT
    (* TYPE  *)         AResourcePointer, AResource,
    (* VAR   *)         ResourceTree,
    (* PROC  *)         FindResourceByNumber, CheckResourceValid,
                        CreateResource, ChangedResource,
                        FindResourceByName, AddResource;

FROM Space          IMPORT
    (* PROC *)          HeapAvailable;

FROM Subfiles       IMPORT
    (* PROC *)          StartFileInput, StartSubfileInput;

FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS,
    (* PROC *)          ADR, SIZE, TSIZE;

FROM Text           IMPORT
    (* TYPE *)          AText,
    (* PROC *)          DiscardText, Compress;

FROM Timei          IMPORT
    (* TYPE  *)         ADate;

FROM TimeXlate      IMPORT
    (* PROC *)          BigTimeToCalendarTime;

FROM Transfer       IMPORT
    (* TYPE *)          AHeaderRecord;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeOrder,
    (* PROC *)          CreateTreeNode, ValidateTree, ValidateTreeNode;

FROM VaryAssgnment  IMPORT
    (* TYPE *)          AVaryingAssgnList,
    (* PROC *)          LoadVaryingAssgnList, LoadVaryingAssgnListOldFormat;





CONST
	 ModuleNumber = 29900;			  (* for phrases *)

     HeaderType                  = 0; (* Record type of a node header, which
                                         contains visibility information  *)
     ResourceType                = 5;
     ResourceFileVersionNumber   = 2;

     ProfileRecordType           = ResourceType + 13;








    (* SaveRecordToFile, and its associated context data type are 
       used together with the Filing.ASaveProc type of procedure
       to allow data modules to save data without our knowing anything
       about the insides of the data type, or the module knowing  
       anything about filing. *)


TYPE
    ARecordLoadingContextPointer = POINTER TO ARecordLoadingContext; 
    ARecordLoadingContext = RECORD
                               TheFile : POINTER TO File;
                               TheSize : CARDINAL;
                               TheType : CARDINAL;
                           END; 





PROCEDURE PredictRecordSize( Context : ADDRESS ) : CARDINAL; 
VAR 
   Ctx : ARecordLoadingContextPointer;    
BEGIN 
   Ctx := Context;
   RETURN Ctx^.TheSize; 
END PredictRecordSize;




PROCEDURE LoadRecordFromFile (     Data       : ADDRESS;
                                   MaxSize    : CARDINAL; 
                               VAR ActualSize : CARDINAL;
                                   Context    : ADDRESS );
VAR 
   Ctx : ARecordLoadingContextPointer;    
BEGIN 
   Ctx := Context;
   WITH Ctx^ DO 
        ReadRecordBody(TheFile^,MaxSize,Data,ActualSize);
   END; 
END LoadRecordFromFile; 


PROCEDURE ReadNextRecordFromFile (Context   : ADDRESS ):BOOLEAN;
VAR 
   Ctx : ARecordLoadingContextPointer;    
BEGIN 
   Ctx := Context;

   WITH Ctx^ DO 
       ReadRecordPreface(TheFile^,TheType,TheSize);
       RETURN (CheckIO(TheFile^) = done);
   END; 

END ReadNextRecordFromFile; 









PROCEDURE ReadAssignmentArray  (VAR f                   : File;
                                    Length              : CARDINAL;
                                VAR Handle              : AnExtHandle;
                                VAR BadAssignmentCount  : CARDINAL;
                                VAR DuplicateAssignments: BOOLEAN ):BOOLEAN;
CONST
    PlanType        = 70;
    BaselineType    = 80;

VAR
    AssignmentArray         : AnAssignmentArray;
    Node                    : ATreeNode;
    SequenceNumber,
    ExtrasCount,
    BaseType,
    Type,
    i, j                    : CARDINAL;
    AssignmentSize          : CARDINAL;
    AssignmentCount         : CARDINAL;
    BigTime                 : ABigTime;
    Ctx                     : ARecordLoadingContext;
    AddressTrick            : RECORD
        CASE BOOLEAN OF
            TRUE :  P   : ADDRESS;
          | FALSE:  C   : RECORD
                            A, B : CARDINAL;
                          END;
        END;
    END;
    Len2                    : CARDINAL;
    High, Low               : CARDINAL;
    Found,
    FoundNewStyleVaryingAssignments,
    ok                      : BOOLEAN;


    PROCEDURE SquishArray();
    VAR
        j   : CARDINAL;
    BEGIN
        IF (i+1 < AssignmentCount) THEN
              (* Squash out this record by moving all the higher ones
                 one position lower and decrementing the count.       *)
            FOR j := i+1 TO AssignmentCount-1 DO
                AssignmentArray^[j-1] := AssignmentArray^[j];
            END;
        END;
        DEC (AssignmentCount);
    END SquishArray;


BEGIN
    Len2 := Length;
    IF (Len2 < TSIZE(AnAssignmentRecord)) THEN
        Len2 := TSIZE(AnAssignmentRecord);
    END;

    DuplicateAssignments := FALSE;
    FoundNewStyleVaryingAssignments := FALSE;

    IF (GetExtStatus() <> ExtGood) OR
       (NOT CreateExtObjectWithSize(Handle, ExtMedium, Len2)) THEN
        SkipRecordBody(f,Length);
        Handle := AnExtHandle(NIL);
        RETURN FALSE;
    END;

    AssignmentCount := LockObjectArray( Handle, AssignmentArray, TSIZE (AnAssignmentRecord));
    AssignmentSize  := Len2;
    IF (AssignmentSize <> ArraySize( AssignmentCount, TSIZE(AnAssignmentRecord))) THEN
        FatalError();
    END;

    ReadRecordBody( f, Length, AssignmentArray, AssignmentSize);
    IF (CheckIO(f) <> done) THEN
        ReleaseObject( Handle );
        RETURN FALSE;
    END;

    (* The BaseType is returned, and indicates the assignment type+1
        so its either 71 or 81.
    *)
    ReadRecord( f, BaseType, ADR(ExtrasCount), SIZE(ExtrasCount) );
    IF (CheckIO(f) <> done) THEN
        ReleaseObject( Handle );
        RETURN FALSE;
    END;
    IF (BaseType = PlanType + 1) THEN
        BaseType := PlanType;
    ELSIF (BaseType = BaselineType + 1) THEN    (* 17-Sep-90 RSC oops.  was <> *)
        BaseType := BaselineType;
    ELSE
        ErrorPhrase(0);
        ReleaseObject( Handle );
        RETURN FALSE;
    END;

(*$O-*)
        (* Clear out the expenses and varying assignment handles.
        *)
    i := 0;
    WHILE (i < AssignmentCount) DO
        WITH AssignmentArray^[i] DO
            Expenses             := AnExtHandle (NIL);
            VaryingAssignment    := AnExtHandle (NIL);

            OvertimeHours        := 0L;     (* 29-May-91 RSC *)
            YetToGoOvertimeHours := 0L;     (* 29-May-91 RSC *)
        END;
        INC(i);
    END;

        (* Now read in the saved expenses and varying assignments.
        *)
    Ctx.TheFile := ADR(f);
    FOR i := 1 TO ExtrasCount DO
        ReadRecord( f, Type, ADR(SequenceNumber), SIZE(SequenceNumber));
        ReadRecordPreface( f, Type, Length );
        Ctx.TheType := Type;
        Ctx.TheSize := Length;
        ok := FALSE;
        IF (CheckIO(f) <> done) THEN
        ELSIF (Type = BaseType + 3) THEN
            ok := LoadExpenses( AssignmentArray^[SequenceNumber].Expenses, ExtSlow,
                                PredictRecordSize,
                                LoadRecordFromFile,
                                ReadNextRecordFromFile,
                                ADR(Ctx) );
        ELSIF (Type = BaseType + 5) THEN
            ok := LoadVaryingAssgnListOldFormat( AssignmentArray^[SequenceNumber].VaryingAssignment, ExtMedium,
                                                 PredictRecordSize,
                                                 LoadRecordFromFile,
                                                 ReadNextRecordFromFile,
                                                 ADR(Ctx) );
            ReadRecord( f, Length, ADR(BigTime), SIZE(BigTime) );
            AssignmentArray^[SequenceNumber].EndOfSpentDate := BigTimeToCalendarTime( BigTime );
        ELSE
            ErrorPhrase(0);
        END;

        IF (NOT ok) THEN
            ReleaseObject( Handle );
            RETURN FALSE;
        END;
    END;


    (*  Read in the new format of VaryingAssignmentArray records.  These
        are saved at this place in the file so that old file reading code
        (in 5.0.0 and 5.0.1) can still read the new format files.
    *)

    GetPos( f, High, Low );
    ReadRecordPreface( f, Type, Length );
    IF (Type = BaseType + 7) THEN
        ReadRecordBody( f, Length, ADR(ExtrasCount), SIZE(ExtrasCount) );
        FOR i := 1 TO ExtrasCount DO
            ReadRecord( f, Type, ADR(SequenceNumber), SIZE(SequenceNumber));
            ReadRecordPreface( f, Type, Length );
            Ctx.TheType := Type;
            Ctx.TheSize := Length;
            ok := FALSE;
            IF (CheckIO(f) <> done) THEN
            ELSIF (Type = BaseType + 8) THEN
                IF (AssignmentArray^[SequenceNumber].VaryingAssignment <> AnExtHandle(NIL)) THEN
                    DiscardExtObject( AssignmentArray^[SequenceNumber].VaryingAssignment );
                END;
                ok := LoadVaryingAssgnList( AssignmentArray^[SequenceNumber].VaryingAssignment, ExtMedium,
                                            PredictRecordSize,
                                            LoadRecordFromFile,
                                            ReadNextRecordFromFile,
                                            ADR(Ctx) );
                NewVaryingAssgnFormatFound := TRUE;            (* 19-Mar-92 *)
            ELSE
                ErrorPhrase(0);
            END;
    
            IF (NOT ok) THEN
                ReleaseObject( Handle );
                RETURN FALSE;
            END;
        END;
        FoundNewStyleVaryingAssignments := TRUE;
    ELSE
        SetPos( f, High, Low );
    END;

    i := 0;
    LOOP
        IF (i+1 > AssignmentCount) THEN
            EXIT;
        END;
        WITH AssignmentArray^[i] DO
            AddressTrick.P := ADDRESS (Resource);
        END;
        Node := FindResourceByNumber (AddressTrick.C.A);
        IF (Node = NIL) THEN
            INC (BadAssignmentCount);
            SquishArray();
        ELSE
                (* RSC 17-Apr-91: Do not allow duplicate assignments.
                *)
            WITH AssignmentArray^[i] DO
                Resource := Node^.Methods^.GetDataObject (Node);
                Found    := FALSE;
                j        := 0;
                WHILE (j < i) AND (NOT Found) DO
                    Found := (AssignmentArray^[j].Resource = Resource);
                    INC(j); (* 18-Apr-91 RSC  *)
                END;
            END;
            IF (Found) THEN
                DuplicateAssignments := TRUE;
                SquishArray();
            ELSE
                INC (i);
            END;
        END;
    END;
(*$O=*)

    ReleaseObject( Handle );
    AssignmentSize := ArraySize (AssignmentCount, TSIZE(AnAssignmentRecord));
    ok := SetExtSize (Handle, AssignmentSize);

        (* After reading an old-style assignment list, unless we also
           find a new style one, set the recalc needed flag.  The new
           arrays have more accuracy. *)
    IF (NOT FoundNewStyleVaryingAssignments) THEN
        UnSetState(Scheduled);
    END;

    RETURN ok;
END ReadAssignmentArray;





PROCEDURE RenumberTheResource  (VAR Node    : ATreeNode;
                                    Context : ADDRESS   );
VAR
    Resource        : AResourcePointer;
BEGIN
    Resource                   := Node^.Methods^.GetDataObject (Node);
    Resource^.WorkSpace.OFFSET := Resource^.ID;
    Resource^.ID               := -Resource^.ID;
END RenumberTheResource;






PROCEDURE LoadProfile( VAR f             : File;
                       VAR AvailProfile  : AnExtHandle;
                           Length        : CARDINAL );
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
    SavedCell   : ASavedAvailabilityCell;
    Amount      : LONGINT;
    Start, 
    Thru        : ADate;
    Type, 
    Size        : CARDINAL;
    Vacation,
    Okay,
    Finished    : BOOLEAN;
BEGIN

    Okay     := TRUE;
    Finished := FALSE;
    REPEAT
        ReadRecordBody (f, Length, ADR(SavedCell), SIZE(SavedCell));
        IF (CheckIO(f) <> done)  THEN
            Finished := TRUE;
        ELSE
            Start     := BigTimeToCalendarTime( SavedCell.StartDate );
            Thru      := BigTimeToCalendarTime( SavedCell.EndDate   );
            Vacation  := SavedCell.ThisIsAVacation;
            Amount    := SavedCell.AmountAvailable;
            AddInterval ( Start, Thru, Amount, Vacation, AvailProfile, Okay );
            IF (SavedCell.ThisIsTheEnd) OR (NOT Okay) THEN
                Finished:= TRUE;	     
            ELSE
                ReadRecordPreface(f,Type,Size);
                IF (CheckIO(f) <> done) OR
                   (Type <> ProfileRecordType) THEN
					ErrorPhrase(ModuleNumber+1);
                    SkipRecordBody(f,Size);
                    Finished:= TRUE;
                END;
            END;
        END;
    UNTIL Finished;

END LoadProfile;






    (* ----------------------------------------------------------

    GetResources:

        f: the file to read from.
        GetDuplicateAction : tells what to do with duplicates.
        Count              : input: how many resources are expected.

    --------------------------------------------------------------- *)

PROCEDURE GetResources(VAR f                  : File;
                           GetDuplicateAction : AGetDupeActionProc;
                           Count : CARDINAL 
                           ) : BOOLEAN;
VAR
    Resource      : AResourcePointer;
    LocalResource : AResource;
    Node          : ATreeNode;
    Version       : CARDINAL;
    Length        : CARDINAL;
    Type          : CARDINAL;
    NumberRead    : CARDINAL;
    Thermometer   : AThermometer;
    Header        : AHeaderRecord;
    s             : ARRAY [0..81] OF CHAR;



    PROCEDURE AddRates( VAR RateList : ARateList ) : BOOLEAN;
    VAR 
        Context :  ARecordLoadingContext; 
    BEGIN
            (* Use the abstract procedures in RateLists to load 
               the data record.
            *)
        Context.TheFile := ADR(f); 
        Context.TheSize := Length;
        RETURN LoadRateList (  RateList, ExtSlow, PredictRecordSize,
                                 LoadRecordFromFile, ReadNextRecordFromFile,
                                 ADR(Context)
                            );
    END AddRates;


    PROCEDURE LoadADateList( VAR DateList : ADateList;
                                 Speed    : AnExtStoragePreference) : BOOLEAN;
    VAR 
        Context :  ARecordLoadingContext; 
    BEGIN
            (* Use the abstract procedures in DateLists to load 
               the data record.
            *)
        Context.TheFile := ADR(f); 
        Context.TheSize := Length;
        RETURN LoadDateList (  DateList, Speed, PredictRecordSize,
                                LoadRecordFromFile, ReadNextRecordFromFile,
                                ADR(Context)
                            );
    END LoadADateList;

BEGIN
    IF (NOT StartSubfileInput(f,ResourceType,Version)) THEN
        RETURN FALSE;
    END;

    IF (NOT HeapAvailable()) THEN                                 (* 02-Feb-88 LAA *)
        RETURN FALSE;
    END;

    NewVaryingAssgnFormatFound := FALSE;                       (* 19-Mar-92 *)
    Resource := NIL;

    (* If we are doing a file combine, we need to clear out the IDs of any
       existing resources before loading in the new ones.  *)

    ResourceTree^.Methods^.TraverseTree (ResourceTree, ParentBeforeChild,
                9999, RenumberTheResource, NIL);

    NumberRead := 0;
        (* Prepare to display progress. *)
    GetMessage(12426,s);
    IF (NOT CreateThermometer(Thermometer,0,0,s,Count)) THEN
        Thermometer := AThermometer(NIL);
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF ((CheckIO(f) <> done) OR BreakRequested() OR ErrorFlag) THEN
            EXIT;
        END;
        IF (Resource = NIL)       AND
           (Type > ResourceType)  AND
           (Type < 0FFH)          THEN
            SkipRecordBody(f, Length);
        ELSE
            CASE Type OF
                HeaderType  :

                    ReadRecordBody (f, Length, ADR(Header), SIZE(Header));

              | ResourceType:
                               (* Compress the notes of the previous
                                  resource. *)
                               (* Compress the extras of the previous
                                  resource.    July 27, 89 KKC *)
                    IF Resource <> NIL THEN
                        Compress(Resource^.Notes);
                        Compress(Resource^.Extras);
                    END;

                    ReadRecordBody(f,Length,ADR(LocalResource),SIZE(LocalResource));

                    WITH LocalResource DO
                        Notes                    := AText(NIL); (* 12/02/86 LAA *)
                        Extras                   := AText(NIL); (* 26-Jul-89 KKC *)
                        ActualRates              := ARateList(NIL);
                        BaseLineRates            := ARateList(NIL);
                        Availability             := ADateList(NIL);
                        BaselineAvailability     := ADateList(NIL);
                        Calendar                 := NIL;
                        BaselineCalendar         := NIL;
                        ResidueAvailProfile      := AResAvailability(NIL);
                        LateResidueAvailProfile  := AResAvailability(NIL);
                        Copy( Name, s );
                        WorkSpace                := NIL;
                        WorkSpace.OFFSET         := 0; (* No ID. *)
                    END;

                    INC(NumberRead);
                    UpdateThermometer(Thermometer,NumberRead);

                    Node     := FindResourceByName(s);
                    Resource := NIL;
                    IF (Node <> NIL) THEN
                        Resource := Node^.Methods^.GetDataObject (Node);
                        IF (GetDuplicateAction(Resource^.Name)=Override) THEN
                            WITH Resource^ DO
                                IF (ADDRESS(Notes) <> NIL) THEN
                                    DiscardText (Notes);
                                END;
                                IF (ADDRESS(Extras) <> NIL) THEN
                                    DiscardText (Extras);
                                END;
                                IF (ADDRESS(ActualRates) <> NIL) THEN
                                    DisposeRateList(ActualRates);
                                END;
                                IF (ADDRESS(BaseLineRates) <> NIL) THEN
                                    DisposeRateList(BaseLineRates);
                                END;
                                IF (Availability <> ADateList(NIL)) THEN
                                    DisposeDateList(Availability);
                                END;
                                IF (BaselineAvailability <> ADateList(NIL)) THEN
                                    DisposeDateList(BaselineAvailability);
                                END;
                                IF (Calendar <> NIL) THEN
                                    DisposeCalendar( Calendar );
                                END;
                                IF (BaselineCalendar <> NIL) THEN
                                    DisposeCalendar( BaselineCalendar );
                                END;
                                IF (ResidueAvailProfile <> AResAvailability(NIL)) THEN
                                    DisposeResAvailabilities( ResidueAvailProfile );
                                END;
                            END;

                            Resource^ := LocalResource;
                            ChangedResource (Node);
                        ELSE
                            Resource^.ID := LocalResource.ID;
                            Resource := NIL;  (* RSC 10/5/87 *)
                        END;

                    ELSE

                        IF (CreateResource (Node)) THEN
                            Resource  := Node^.Methods^.GetDataObject (Node);
                            Resource^ := LocalResource;
                            AddResource (Node, NIL, NIL);
                            ChangedResource (Node);
                        ELSE (* Probably out of heap space. *)
                            EXIT;
                        END;
                    END;

              | ResourceType + 1 :
                    IF (NOT AddRates( Resource^.ActualRates )) THEN
                        EXIT;
                    END;

              | ResourceType + 2 :
                    IF (NOT AddRates( Resource^.BaseLineRates )) THEN
                        EXIT;
                    END;

              | ResourceType + 3 :
                    IF (NOT LoadADateList( Resource^.Availability, ExtMedium )) THEN
                        EXIT;
                    END;

              | ResourceType + 4 :
                    IF (NOT LoadADateList( Resource^.BaselineAvailability, ExtSlow )) THEN
                        EXIT;
                    END;

              | ResourceType + 5 :
                    WITH Resource^ DO
                        Calendar := CreateCalendar();
                        IF (Calendar <> NIL) THEN
                            ReadRecordBody(f,Length,Calendar,SIZE(Calendar^));
                            Calendar^.Notes  := AText(NIL);
                            Calendar^.Extras := AText(NIL);
                            Calendar^.CalendarIntervals := ADateList(NIL);
                        ELSE
                            SkipRecordBody(f,Length);
                        END;
                    END;

              | ResourceType + 5 + 1 :
                    WITH Resource^ DO
                        IF (Calendar <> NIL) THEN
                            ReadTextLine(f, Length, Calendar^.Notes);
                        END;
                    END;

              | ResourceType + 5 + 2 :
                    WITH Resource^ DO
                        IF (Calendar <> NIL) THEN
                            ReadTextLine(f, Length, Calendar^.Extras);
                        END;
                    END;

              | ResourceType + 5 + 3 :
                    WITH Resource^ DO
                        IF (Calendar <> NIL) THEN
                            IF (NOT LoadADateList( Calendar^.CalendarIntervals, ExtMedium )) THEN
                                EXIT;
                            END;
                        END;
                    END;

              | ResourceType + 9 :
                    WITH Resource^ DO
                        BaselineCalendar := CreateCalendar();
                        IF (BaselineCalendar <> NIL) THEN
                            ReadRecordBody(f,Length,BaselineCalendar,SIZE(BaselineCalendar^));
                            BaselineCalendar^.Notes  := AText(NIL);
                            BaselineCalendar^.Extras := AText(NIL);
                            BaselineCalendar^.CalendarIntervals := ADateList(NIL);
                        END;
                    END;

              | ResourceType + 9 + 1 :
                    WITH Resource^ DO
                        IF (BaselineCalendar <> NIL) THEN
                            ReadTextLine(f, Length, BaselineCalendar^.Notes);
                        END;
                    END;

              | ResourceType + 9 + 2 :
                    WITH Resource^ DO
                        IF (BaselineCalendar <> NIL) THEN
                            ReadTextLine(f, Length, BaselineCalendar^.Extras);
                        END;
                    END;

              | ResourceType + 9 + 3 :
                    WITH Resource^ DO
                        IF (BaselineCalendar <> NIL) THEN
                            IF (NOT LoadADateList( BaselineCalendar^.CalendarIntervals, ExtSlow )) THEN
                                EXIT;
                            END;
                        END;
                    END;

              | ProfileRecordType :
                    LoadProfile(f, Resource^.ResidueAvailProfile, Length );

              | 100 :
                    ReadOldFormatTextLine(f, Length, Resource^.Notes);

              | 101 :
                    ReadOldFormatTextLine(f, Length, Resource^.Extras);

              | 102 :
                    ReadTextLine(f, Length, Resource^.Notes);

              | 103 :
                    ReadTextLine(f, Length, Resource^.Extras);

              | 0FFH:
                    EXIT;
            ELSE
                SkipRecordBody(f,Length);
            END;
        END;
    END;

    IF (Resource <> NIL) THEN
        Compress(Resource^.Notes);
        Compress(Resource^.Extras);
    END;

    IF (Thermometer <> AThermometer(NIL)) THEN
        DiscardThermometer(Thermometer);
    END;

    RETURN (CheckIO(f) = done);

END GetResources;





BEGIN

    NewVaryingAssgnFormatFound := FALSE;                       (* 19-Mar-92 *)

END IResource.


