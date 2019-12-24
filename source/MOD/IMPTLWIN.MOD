IMPLEMENTATION MODULE ImpTLWindows;

(* MODIFICATION HISTORY

     3-Mar-92 TGS   Pulled this out of TLLnkTW1 so we could share code between
                    linker and importer.
                    Also, we weren't doing an "ANSIToOEM" on the resource
                    string fields. Tsk, tsk.
    06-Mar-92 TGS   A "Cost Only" TLWin resource could be a variable cost, or
                    it could be a unit cost.  Depends on whether the billing
                    units field is >0 or not.  We were assuming that all
                    "cost only" TLWin resources were unit costs, but weren't
                    bothering to pick up the "unit" name.
    10-Mar-92 LAA   Incorporated use of the CorTable module for keeping the
                    correlation between id and resource node.
    12-Mar-92 LAA   Put in GetAssignments for reading the resource
                    assignments in from the file.
    13-Mar-92 LAA   Pass the count of number of resource assignments to
                    GetAssignments, so we can put up a thermometer.
    17-Mar-92 LAA   Correct the resource cost rate for SMUPH.  Added special
                    handling for OnTarget files so that the DefaultUsage is
                    correct.
    18-Mar-92 TGS   Add parameter to GetResources for "MaxIDNumber".  This
                    is so the ResourceTable is initialized and valid over
                    the entire range of ID numbers used.  "Count" is still
                    needed to create a thermometer of proper size.
    19-Mar-92 TGS   If the Count parameter to GetResources() is MAXCARDINAL,
                    don't create a thermometer.  This is so the TLWin linker,
                    which doesn't want one, doesn't get one.
    19-Mar-92 LAA   Added a FixedCostNode parameter to GetResources.  This
                    will be returned to point to a resource implicitly created
                    so we can turn costs which are on a task in Rocky into
                    assignments to a fixed cost.
                    Also put more info into the assignment so it'll be closer
                    to correct before a recalc.
    26-Mar-92 LAA   Oops.  My "fix" of 17-Mar-92 was exactly reversed:  I
                    multiplied the denominatior rather than the numerator
                    by SMUPH.
                    To correct bug #5469, I had to limit the length of the
                    string from the phrases file being passed into 
                    FindResourceByName to the ResourceNameLength, and also
                    do a TrimRear on the name put into the name field of
                    the resource record when creating a new one.
    27-Mar-92 TGS   Don't set "levelling limit" on variable costs. Bug 5467.
    16-Apr-92 LAA   Corrected a phrase number.
                    Fixed bug #5553.  We hadn't accounted for the fact that
                    the size of OnTarget resource links is different from
                    the size for Rocky.
                    In GetResources, tasks don't necessarily follow resources
                    in OnTarget, only in Rocky.  This was also a part of
                    bug #5553.
                    And adjusted for the difference in record lengths of
                    resources in OnTarget.
    21-Apr-92 LAA   Change the name of the implicit fixed cost created by
                    this import to "OT Manual Cost" when importing from
                    OnTarget.
*)

FROM Allocs         IMPORT
    (* TYPE *)          ATaskPtr, AStartStatus;

FROM Assignments    IMPORT
    (* TYPE *)          AnAssignmentRecord, AnAssignmentArray, 
                        AnAssignmentAttribute, ARole,
    (* PROC *)          InitAssignment;

FROM BigTimeU       IMPORT
    (* CONST *)         MINBIGTIME;

FROM CorTable       IMPORT
    (* TYPE *)          ACorrelationTable,
    (* PROC *)          CreateCorrelationTable, AddTableEntry, FindEntryByID;

FROM DateLists      IMPORT
    (* PROC *)          CreateDateList;   

FROM Dialog         IMPORT
                        Error, ErrorPhrase, FatalError;

FROM FileAux        IMPORT 
    (* PROC *)          PrepareForIO, CheckIO, DisplayFileError;

FROM FileSystem     IMPORT
    (* TYPE *)          File, Response,
    (* PROC *)          Reset, SetRead;

FROM FlexStor       IMPORT
    (* TYPE *)          AnExtStoragePreference,
    (* PROC *)          LockObjectArray, ReleaseObject, 
                        ReleaseUnchangedObject, CreateExtObjectWithSize,
                        SetExtSize, ArraySize;

FROM LinkSupport    IMPORT
    (* PROC *)          NewPercent, Convert4ByteReal;

FROM LongConvert    IMPORT
    (* PROC *)          LongToReal;

FROM LStrings       IMPORT
    (* PROC *)          ConcatLS, Copy, LengthOf, LJust, SetLengthOf,
                        SubStr, TrimRear, TStringToLString, Upshift;

FROM MsgFile        IMPORT
                        GetMessage;

FROM ObjectID       IMPORT
    (* PROC *)          NewID;

FROM Progress       IMPORT
    (* TYPE *)          AThermometer,
    (* PROC *)          CreateThermometer, UpdateThermometer, 
                        DiscardThermometer;

FROM RateLists      IMPORT
    (* PROC *)          CreateRateList;

FROM ResCalUI       IMPORT 
    (* TYPE *)          AnAvailabilityRate;

FROM RsrcMod        IMPORT
    (* TYPE *)          AResourcePointer, ACostStyle,
                        AResourceType,
    (* CONST *)         ResourceNameLength,
    (* PROC *)          AddResource, CreateResource,
                        FindResourceByName,
    (* VAR *)           ChangedResource;

FROM Space          IMPORT
                        Available, HeapAvailable, ALLOCATE, DEALLOCATE;

FROM SYSTEM         IMPORT
                        SIZE, TSIZE, ADDRESS;

FROM Text           IMPORT
                        Compress, AppendLine;

FROM Timei          IMPORT
    (* TYPE *)          ADate, ADurationUnit, ATimeInfo,
    (* PROC *)          DayOfWeek, TtoAbsTimeU;

FROM TimeFormat     IMPORT 
    (* VAR  *)          DefaultDateFormat,
    (* PROC *)          TimeToString;

FROM Timeu          IMPORT
    (* VAR  *)          TimeTable, FSMUPH,
    (* PROC *)          UpScale;

FROM TLW1File       IMPORT
    (* TYPE *)          ATLWinResource, ATLWinAssignment, AKindOfFile,
    (* PROC *)          ReadRecordPreface, ReadRecordBody, ReadStringBody,
                        SkipRecordBody, KindOfFile;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATreeNode;

CONST
     FMAXCARDINAL          = 65535.0;
     MAXCARDINAL           = 65535;
     OneHundred            = 100.0;
     Ten                   = 10.0;
     ModuleNumber = 30600;    (* For GetMessage, shared with TLVUTW1 and TLW1FILE *)
     

VAR
    ComplainedAboutDate     : BOOLEAN;


PROCEDURE Complain( N : CARDINAL );
VAR 
    S : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(N,S);
    Error(S);
END Complain;

PROCEDURE FileComplaint(VAR f:File);
VAR
   s  : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,s);    (* "Time Line Windows file " *)
    DisplayFileError( f, s );        (* RSC 2/19/88    *)
END FileComplaint;


PROCEDURE AddToNote( VAR Line               : ARRAY OF CHAR;
                         Context            : ADDRESS       );

VAR
    Resource                : AResourcePointer;

BEGIN                       (* AddToNote *)

    Resource := Context;
    IF (AppendLine( Line, Resource^.Notes )) THEN END;

END AddToNote;



    (* ----------------------------------------------------------

    GetResources:

        F: the file to read from.
        ResourceTable: correlates id to resource node.
        Count              : input: how many resources are expected.
                             if this is MAXCARDINAL, then no thermometer
                             (this is for clients, i.e. schedule 
                              linker, that don't want one.)
        FixedCostNode      : returns a pointer to a resource node which is
                             the implicitly created resource for doing fixed
                             costs.  This resource didn't come from the Rocky
                             or OT file.
    --------------------------------------------------------------- *)

PROCEDURE GetResources(VAR F                  : File;
                       VAR ResourceTable      : ACorrelationTable;
                           MaxIDNumber,
                           Count              : CARDINAL;
                       VAR FixedCostNode      : ATreeNode         ) : BOOLEAN;

VAR
    Resource      : AResourcePointer;
    TLWin1Resource : ATLWinResource;
    Node          : ATreeNode;
    LocalID,
    LastID        : CARDINAL;
    Length        : LONGINT;
    Expected      : LONGINT;
    LocalType     : CARDINAL;
    NumberRead    : CARDINAL;
    Thermometer   : AThermometer;
    S             : ARRAY [0..255] OF CHAR;
    ResourceName  : ARRAY [0..31] OF CHAR;
    ResourceText2 : ARRAY [0..31] OF CHAR;
    ResourceUnits : ARRAY [0..31] OF CHAR;
    ResourceNote  : ARRAY [0..512] OF CHAR;
    RecordPending,
    NamePending   : BOOLEAN;




    PROCEDURE FindOrMakeResource(VAR TLWin1Resource : ATLWinResource;
                                 VAR ResourceName   : ARRAY OF CHAR;
                                 VAR Node     : ATreeNode;   
                                 VAR Resource : AResourcePointer );
    CONST
        PotOverload = 0;   (* Resource flags *)
        Overload    = 1;
        CostOnly    = 2;
        NoLevel     = 3;
    VAR
       Avail         : AnAvailabilityRate;
       R    : REAL;
       NullName        : ARRAY [0..1] OF CHAR;
       n, p            : CARDINAL;
       i, j : CARDINAL;
    BEGIN
        LJust(ResourceName);
        TrimRear(ResourceName);
        Copy(ResourceName,S);
        Upshift(S);
        Node     := FindResourceByName(S);

        Resource := NIL;
        IF (Node <> NIL) THEN
            Resource := Node^.Methods^.GetDataObject (Node);
            RETURN;
        END;

            (* The resource named here does not yet exist.  Create one. *)
        
        IF (CreateResource (Node)) THEN
            Resource  := Node^.Methods^.GetDataObject (Node);
            AddResource (Node, NIL, NIL);   (* Add to resource tree. *)
        ELSE (* Probably out of heap space. *)
            RETURN;
        END;
        
            (* Convert from TLW1 format resource. *)

        WITH Resource^ DO
            ID                     := NewID();  (* Newly created resource. *)
            LJust( ResourceName );
            Copy( ResourceName, Name );                           
            Copy( ResourceName, LongName );
            LJust( ResourceText2 );
            Copy( ResourceText2, Keyword );

            ForEachLine( ResourceNote, 65, AddToNote, Resource );
            Compress( Notes );

            IF (TLWin1Resource.BillingUnits = 0 )    THEN
                    (* A "unit" cost *)
                IF (LengthOf(ResourceUnits) > 0) THEN
                    LJust( ResourceUnits );
                    Copy( ResourceUnits, UnitOfMeasure );
                END;
                CostStyle       := CAmountRate;
                Type            := AccountingOnly;
            ELSE  (* a "resource" or "variable" cost .. *)
                CostStyle          := CAmountRateTime;
                IF (CostOnly IN TLWin1Resource.Status) THEN
                    (* variable cost *)
                    Type    := AccountingOnly;
                ELSE
                    (* resource *)
                    Type    := Employable;
                END;
                    (* Default amounts. *)
                R := Convert4ByteReal( TLWin1Resource.DefaultUsage );
                IF (KindOfFile() = OnTargetFile) THEN          (* 17-Mar-92 *)
                    R := 1.0;               (*  Didn't exist in OT *) 
                END;
                SetLengthOf( NullName, 0 );
                NewPercent( NullName, ResourceName,
                            R,               (* Availablity in TLWin. *)
                            FMAXCARDINAL,    (* UpperLimit *)
                            0.01,            (* LowerLimit *)
                            650,             (* Max n *)
                            250,             (* Max % *)
                            n, p );
                Limit              := R * OneHundred;
                Percent            := p;
                UpperPercent       := Percent;
                UpperLimit         := Limit;
            END;
                (* Billing rate and units. *)

            R := Convert4ByteReal( TLWin1Resource.Rate );
            i := TLWin1Resource.BillingUnits;
                (* TLWin has H,D,W,M,Q,Y, while TLDOS has M,H,D,W,M,Y. *)
            IF (i > 0) THEN
                j := ((i-1) MOD 6);
                IF (j = 4) THEN (* Quarters.  Convert to monthly rate. *)
                    j := 3; (* Month *)
                    R := R / 3.0;
                END;
                IF (j = 5) THEN
                    Units := Years;
                ELSE
                    Units := VAL( ADurationUnit, j  + ORD(Hours) );
                END;
                R := (R * FSMUPH) / FLOAT( UpScale(1,Units));  (* Make rate hourly. *)
            ELSE
                (* TLWindows supports "per use" costs.  TL5 doesn't. *)
                (*  true; but they aren't resource records, they're a
                   part of the task record.  If BillingUnit=0, it means
                   this is a "unit" cost, not per-time, so no conversion
                   is needed. There are no "fixed" resources in TLWin/OT.
                   - 6-Mar-92 TGS *)
            END;

           
                (* Create the rate list, showing what we charge. *)
            ActualRates := CreateRateList( R, MINBIGTIME );

            LevelThisResource  := NOT (NoLevel IN TLWin1Resource.Status);

                (* Create the availability list, showing how many of this resource
                   there are. *)
            IF (Type <> AccountingOnly)      AND (* 27-Mar-92 TGS *)
               (CostStyle = CAmountRateTime) THEN
                R   := Convert4ByteReal( TLWin1Resource.Capacity );
                    (* Convert the single availability amount to a two-part
                       n at p% *)
                SetLengthOf( NullName, 0 );
                NewPercent( NullName, ResourceName,
                            R,               (* Availablity in TLWin. *)
                            FMAXCARDINAL,    (* UpperLimit *)
                            0.01,            (* LowerLimit *)
                            650,             (* Max n *)
                            250,             (* Max % *)
                            n, p );
                Avail.Amount  := n;
                Avail.Percent := p;
                Availability  := CreateDateList (Avail, MINBIGTIME);
            END;
        END;

        ChangedResource (Node);   (* Note that it is changed.  Sort it. *)


            (* Tighten up the memory allocation for text. *)
        
        IF (Resource <> NIL) THEN
            Compress(Resource^.Notes);
            Compress(Resource^.Extras);
        END;

    END FindOrMakeResource;




        (* If we have enough information to create a new resource, and
           haven't already, make it. *)

    PROCEDURE MaybeMakeResource( IDNumber : CARDINAL ):BOOLEAN;
    BEGIN
            (* Time Line does not have a "resource 0" which summarizes
               other resources. *)
        IF (IDNumber > 0) THEN
            FindOrMakeResource(TLWin1Resource, ResourceName, Node, Resource );
                (* Add entry to the table correlating TLW resource IDs
                   with our structures. *)
            IF ((Resource = NIL) OR
               (NOT AddTableEntry( ResourceTable, IDNumber, Node ))) THEN
                ErrorPhrase(ModuleNumber+19);   (* Couldn't create resource. *)
                RETURN FALSE;  (* Failure *)
            END;
        END;
        RETURN TRUE;
    END MaybeMakeResource;


    PROCEDURE MakeImplicitFixedCost( VAR RsrcNode : ATreeNode ) : BOOLEAN;

    VAR
        S                   : ARRAY [0..31] OF CHAR;
        Resource            : AResourcePointer;
        i                   : CARDINAL;

    BEGIN                   (* MakeImplicitFixedCost *)


        IF (KindOfFile() = OnTargetFile) THEN
            i := ModuleNumber + 25;
        ELSE
            i := ModuleNumber + 24;
        END;

        GetMessage( i, S );   (* Fixed cost name *)
        SetLengthOf( S, ResourceNameLength );                  (* 26-Mar-92 *)
        TrimRear( S );
        RsrcNode := FindResourceByName(S);

        IF (RsrcNode <> NIL) THEN
            RETURN TRUE;
        END;

            (* The resource named here does not yet exist.  Create one. *)
        
        IF (CreateResource (RsrcNode)) THEN
            Resource  := RsrcNode^.Methods^.GetDataObject (RsrcNode);
            AddResource (RsrcNode, NIL, NIL);   (* Add to resource tree. *)
            WITH Resource^ DO
                ID := NewID();  (* Newly created resource. *)
                Copy( S, Name );                           
                GetMessage( ModuleNumber + 24, S );   (* Fixed cost name *)
                Copy( S, LongName );
                CostStyle := CAmount;
                Type      := AccountingOnly;
            END;
            ChangedResource (RsrcNode);   (* Note that it is changed.  Sort it. *)
        ELSE (* Probably out of heap space. *)
            RsrcNode := NIL;
        END;

        RETURN (RsrcNode <> NIL);

    END MakeImplicitFixedCost;

BEGIN
    IF (NOT HeapAvailable()) THEN                                 (* 02-Feb-88 LAA *)
        RETURN FALSE;
    END;

    Resource := NIL;


    (* Reset to the beginning of the file and read records, looking
       for resources.  Each resource has a main resource record followed
       by some string and other supporting records.  Assemble each of
       these into LocalResource.  Since we don't know which records follow,
       we accumulate information about each resource until we encounter
       the next resource or the end of all resources. 
       *)

    PrepareForIO(F);
    Reset(F);
    SetRead(F);

    IF (CheckIO(F) <> done) THEN
        FileComplaint(F);
        RETURN FALSE;
    END;

    ResourceTable := CreateCorrelationTable( MaxIDNumber + 1 );
    IF (ResourceTable = ACorrelationTable(NIL)) THEN
        ErrorPhrase( ModuleNumber + 19);    (*  Insufficient memory *)
        RETURN FALSE;
    END;

        (* No resource data yet in Resource. *)
    RecordPending := FALSE;
    NamePending   := FALSE;
    LocalID       := 0;
    LastID        := 0;

    NumberRead := 0;
        (* Prepare to display progress. *)
    GetMessage(ModuleNumber + 22,S);        (* Resources *)
    IF (Count = MAXCARDINAL) OR 
       (NOT CreateThermometer(Thermometer,0,0,S,Count)) THEN
        Thermometer := AThermometer(NIL);
    END;

        (* Read records and build resources.  Our structure assumes that
           the resource record precedes any of the string records. *)

    LOOP
        ReadRecordPreface (F,LocalType,LocalID,Length);
        IF (CheckIO(F) <> done) THEN
            FileComplaint(F);
            EXIT;
        END;

            (* When we hit the end of file, or records which go with
               a different resource or object, build a resource from
               the accumulated pieces. *)

        IF (RecordPending) AND
           ((LocalID <> LastID) OR (LocalType = 0)) THEN
            IF NOT MaybeMakeResource( LastID ) THEN
                EXIT;
            END;
            RecordPending := FALSE;
        END;

            (* We have read a record which should either be part of 
               the currently accumulating resource (or starting a new
               one) or not relevant to any resource field. *)

        CASE LocalType OF
            0 :  (* File Ender *)
                EXIT;

          | 1 : (* A Task.  Tasks follow resources. *)
                IF (KindOfFile() <> OnTargetFile) THEN         (* 16-Apr-92 *)
                    EXIT;
                END;
                SkipRecordBody(F,Length);

          | 2 : (* A Resource record *)

                IF (RecordPending) THEN
                    ErrorPhrase(ModuleNumber+20);     (* How could we have two records in row w/ same ID? *)
                END;

                SetLengthOf(ResourceName,0);
                SetLengthOf(ResourceText2,0);
                SetLengthOf(ResourceUnits,0);
                NamePending := FALSE;

                ReadRecordBody (F,Length,TLWin1Resource);
                INC(NumberRead);
                UpdateThermometer(Thermometer,NumberRead);

                Expected := VAL(LONGINT,SIZE(TLWin1Resource)); (* 16-Apr-92 *)
                IF (KindOfFile() = OnTargetFile) THEN
                    Expected := Expected - 8L;
                END;

                IF (Length <> Expected) THEN
                    Complain(ModuleNumber+12);
                END;


                    (* Note that
                       we have one waiting, accumulating any strings
                       attached to it. Save its ID. *)
                RecordPending := TRUE;
                LastID  := LocalID;

          | 31: (* Resource Text 1 *)

                ReadStringBody( F, Length, S );

          | 37: (* Resource Name *)

                    (* Should have resource record before name, and also
                       not have two names for same task. *)
                IF (NamePending) OR (NOT RecordPending) THEN
                    ErrorPhrase(ModuleNumber+20);
                END;

                ReadStringBody( F, Length, ResourceName );
                NamePending := TRUE;

          | 34: (* Resource Keyword *)

                ReadStringBody( F, Length, ResourceText2 );

          | 40: (* Resource Note *)

                ReadStringBody( F, Length, ResourceNote );

          | 42: (* Resource Units *)

                ReadStringBody( F, Length, ResourceUnits );

          | 48: (* Resource Aux field *)

                ReadStringBody( F, Length, S );


        ELSE
            SkipRecordBody(F,Length);
        END;

    END;
    

    IF (MakeImplicitFixedCost( FixedCostNode )) THEN END;

    IF (Thermometer <> AThermometer(NIL)) THEN
        DiscardThermometer(Thermometer);
    END;

    RETURN (CheckIO(F) = done);

END GetResources;



    (*  GetAssignments --
        Read the input file an extract all resource assignments.  Create the
        Time Line equivalents, and hook up tasks and resources using the
        two tables.  Return TRUE if everything goes well, FALSE otherwise.
    *)

PROCEDURE GetAssignments( VAR F             : File;
                              TaskTable     : ACorrelationTable;
                              ResourceTable : ACorrelationTable;
                              Count         : CARDINAL           ) : BOOLEAN;

VAR
    TLWin1Assignment        : ATLWinAssignment;
    LocalType               : CARDINAL;
    LocalID                 : CARDINAL;
    Length                  : LONGINT;
    Expected                : LONGINT;
    TaskNode                : ATreeNode;
    ResourceNode            : ATreeNode;
    NumberRead              : CARDINAL;
    Thermometer             : AThermometer;
    S                       : ARRAY [0..255] OF CHAR;



    (* Add one assignment record to the end of the assignment list.
    *)
    PROCEDURE AddADefaultAssignment(     TaskPtr    : ATaskPtr;
                                         RsrcPtr    : AResourcePointer;
                                     VAR AddedEntry : CARDINAL         )
                                                                    : BOOLEAN;
    VAR
        i,
        Count       : CARDINAL;
        Assignments : AnAssignmentArray;
        AssignmentRecord : AnAssignmentRecord;
        Same        : BOOLEAN;

    BEGIN

        Same  := FALSE;
        Count := LockObjectArray( TaskPtr^.Plan.Assignments, Assignments, TSIZE( AnAssignmentRecord ) );
        i     := Count;

        WHILE (i > 0) AND (NOT Same) DO
            DEC(i);
(*$O-*)
            Same := ( RsrcPtr = Assignments^[i].Resource );
(*$O=*)
        END;

        ReleaseUnchangedObject( TaskPtr^.Plan.Assignments );

        IF (Same) THEN
            Complain( ModuleNumber + 51 ); (* "Duplicate assignment not allowed" *)
        ELSE
            InitAssignment(RsrcPtr,AssignmentRecord);
            INC(Count);
            IF (Count = 1) THEN
                (* Creating the FIRST assignment record.
                *)
                IF (NOT CreateExtObjectWithSize( TaskPtr^.Plan.Assignments, 
                                         ExtMedium, 
                                         TSIZE(AnAssignmentRecord) )) THEN
                    RETURN FALSE;
                END;
            ELSE
                IF (NOT SetExtSize(TaskPtr^.Plan.Assignments, 
                            ArraySize(Count, TSIZE(AnAssignmentRecord)))) THEN
                    RETURN FALSE;
                END;
            END;
            Count := LockObjectArray( TaskPtr^.Plan.Assignments,
                                      Assignments,
                                      TSIZE( AnAssignmentRecord ) );
            AddedEntry               := Count - 1;
(*$O-*)
            Assignments^[AddedEntry] := AssignmentRecord; (* Last one! *)
(*$O=*)
            ReleaseObject( TaskPtr^.Plan.Assignments );
        END;

        RETURN (NOT Same);

    END AddADefaultAssignment;



    PROCEDURE AddAssignment() : BOOLEAN;

    VAR
        TaskPtr             : ATaskPtr;
        ResPtr              : AResourcePointer;
        i                   : CARDINAL;
        AssignmentArray     : AnAssignmentArray;
        Count               : CARDINAL;
        R                   : REAL;
        n, p                : CARDINAL;
        NullName            : ARRAY [0..10] OF CHAR;

    BEGIN                   (* AddAssignment *)

        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        ResPtr  := ResourceNode^.Methods^.GetDataObject( ResourceNode );

        IF (AddADefaultAssignment( TaskPtr, ResPtr, i )) THEN
            Count := LockObjectArray( TaskPtr^.Plan.Assignments, 
                                      AssignmentArray, 
                                      TSIZE( AnAssignmentRecord ) );
            WITH AssignmentArray^[i] DO
                IF (ResPtr^.CostStyle = CAmountRate) THEN
                    IF (TaskPtr^.StartStatus = DoneS) THEN
                        ActualQuantity := Convert4ByteReal( TLWin1Assignment.UtilizationRate );
                    ELSE
                        YetToGoQuantity := Convert4ByteReal( TLWin1Assignment.UtilizationRate );
                    END;
                ELSIF (ResPtr^.CostStyle = CAmountRateTime) THEN
                    IF (2 IN TLWin1Assignment.Status) THEN  (* Effort amount *)
                        INCL( Attributes, ComputeByHours );
                    ELSE
                        EXCL( Attributes, ComputeByHours );
                        R := Convert4ByteReal( TLWin1Assignment.UtilizationRate );
                            (* Convert the single availability amount to a two-part
                               n at p% *)
                        SetLengthOf( NullName, 0 );
                        NewPercent( NullName, Resource^.Name,
                                    R,               (* Availablity in TLWin. *)
                                    FMAXCARDINAL,    (* UpperLimit *)
                                    0.01,            (* LowerLimit *)
                                    650,             (* Max n *)
                                    250,             (* Max % *)
                                    n, p );
                        MaxRatePercent := n * p;
                        PercentageEach := CHR( p );
                    END;
                    R := LongToReal( TLWin1Assignment.Effort ) / Ten;
                    ActualQuantity := R * FLOAT(TaskPtr^.PercentComplete) / OneHundred;
                    YetToGoQuantity := R - ActualQuantity;
                END;
                IF (TLWin1Assignment.Role = 1) THEN
                    INCL( Roles, RoleResponsible );
                END;
            END;

            ReleaseObject( TaskPtr^.Plan.Assignments );
            TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

            RETURN TRUE;
        END;

        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

        RETURN FALSE;

    END AddAssignment;


BEGIN                       (* GetAssignments *)

    IF (NOT HeapAvailable()) THEN
        RETURN FALSE;
    END;

    (* Reset to the beginning of the file and read records, looking
       for assignments.  
    *)

    PrepareForIO(F);
    Reset(F);
    SetRead(F);

    IF (CheckIO(F) <> done) THEN
        FileComplaint(F);
        RETURN FALSE;
    END;

    GetMessage(ModuleNumber + 23,S);        (* Resource Assignments *)
    IF (NOT CreateThermometer(Thermometer,0,0,S,Count)) THEN
        Thermometer := AThermometer(NIL);
    END;

    NumberRead := 0;

    LOOP
        ReadRecordPreface (F,LocalType,LocalID,Length);
        IF (CheckIO(F) <> done) THEN
            FileComplaint(F);
            EXIT;
        END;

        CASE LocalType OF
            0 : (* File Ender *)
                EXIT;
        |   6 : (* Assignment Record *)
                ReadRecordBody(F, Length, TLWin1Assignment);

                INC(NumberRead);
                UpdateThermometer(Thermometer,NumberRead);

                Expected := VAL(LONGINT,SIZE(TLWin1Assignment));  (* 16-Apr-92 *)
                IF (KindOfFile() = OnTargetFile) THEN
                    Expected := Expected - 4L;
                    TLWin1Assignment.Effort := 0L;
                END;

                IF (Length <> Expected) THEN
                    Complain(ModuleNumber+12);
                    EXIT;
                END;

                WITH TLWin1Assignment DO
                    IF (FindEntryByID( TaskTable, TaskID, TaskNode) AND
                       FindEntryByID( ResourceTable, ResourceID, ResourceNode)) THEN
                        IF (NOT AddAssignment()) THEN
                            Complain( ModuleNumber + 52 );  (* Can't add assignment *)
                        END;
                    ELSE
                        Complain( ModuleNumber + 53 );  (*  Can't find task or resource for assignment *)
                    END;
                END;
        ELSE
            SkipRecordBody(F,Length);
        END;

    END;
    
    IF (Thermometer <> AThermometer(NIL)) THEN
        DiscardThermometer(Thermometer);
    END;

    RETURN (CheckIO(F) = done);

END GetAssignments;



    (* KDate1968 -- Given the number of days beginning March 1, 1968
                    as 0, return the Year, Month and Day.
                    See the Timei module for further documentation.
                    *)


PROCEDURE KDate1968(K: LONGINT; VAR Year, Month, Day: CARDINAL);

VAR
    LYear : LONGINT;

BEGIN
    (* 16-Aug-90 RSC OLD FORMULA:

        Year := ((4 * k) -1) DIV 1461;
        Day  := 4 * k - 1 - 1461 * Year;

       NEW FORMULA:
    *)



    K := K * 4L;
    LYear := (K - 1L) DIV 1461L;
    Year  := VAL(CARDINAL,LYear);

    Day   := VAL(CARDINAL,K - 1L - (1461L * LYear));



    Day := (Day + 4) DIV 4;
    Month := (5 * Day - 3) DIV 153;
    Day := 5 * Day - 3 - 153 * Month;
    Day := (Day + 5) DIV 5;
    IF Month < 10 THEN
        Month := Month + 2
    ELSE
        Month := Month - 10;
        Year := Year + 1
    END;
    Year := Year + 1968;

END KDate1968;




PROCEDURE KDate1970(K: LONGINT; VAR Year, Month, Day: CARDINAL);
CONST
    Jan11970 = 672L;   (* Days since the base of KDate1968 *)
BEGIN
    KDate1968(K+Jan11970, Year,Month,Day);
END KDate1970;




    (* ---------------------------------------------------------------

       TLW1HourToHour

       Convert an TLW1 hour and minute, representing a certain number of
       hours and minutes since the start of the TLW1 work day, to the hour
       and minute in TL that is the same distance from the start of the 
       TL work day.

       ---------------------------------------------------------------- *)



PROCEDURE TLW1HourToHour(     Day : CARDINAL;
                            TLW1Hour, TLW1Minute : CARDINAL;
                        VAR Hour, Minute     : CARDINAL   );
VAR
    QtrHour,
    QuartersInDay,
    QuartersRemaining : CARDINAL;
    ExtraMinutes      : CARDINAL;  (* Minutes that don't fit into quarters. *)

BEGIN
    QtrHour      := 0;
    Minute       := (TLW1Hour * 60) + TLW1Minute; (* Minutes into today *)


    WITH TimeTable.WeekTable[Day] DO

        QuartersRemaining := Minute DIV 15;  (* Truncate *)
        ExtraMinutes      := Minute MOD 15;

        LOOP
            IF (NOT (QtrHour IN WeekMap) ) THEN
                IF (QuartersRemaining = 0) THEN
                    EXIT;
                END;
                DEC(QuartersRemaining);  (* One less quarter hour *)
            END;

                (* In case we are off the end of the calendar,
                   stop now.
                *)
            IF (QtrHour = 95) THEN
                EXIT;
            END;

            INC(QtrHour);
        END;
    END;

    Hour   :=   QtrHour DIV 4;       (* Which hour of the day? *)
        (* minutes = fractional hour * 15 mins *)
    Minute := ((QtrHour MOD 4) * 15) + ExtraMinutes;
END TLW1HourToHour;




PROCEDURE ComplainAboutDate( TimeInfo : ATimeInfo; N : CARDINAL );
VAR
    S    : ARRAY [0..255] OF CHAR;
    S2   : ARRAY [0..25] OF CHAR;
BEGIN
    IF (NOT ComplainedAboutDate) THEN
        GetMessage(N,S);
        TimeToString(TimeInfo,DefaultDateFormat,S2);
        ConcatLS(S,S2);
        Error(S);
        ComplainedAboutDate := TRUE;
    END;
END ComplainAboutDate;




PROCEDURE TLWin1DateToDate( TLW1Date : LONGINT ) : ADate;
CONST
    MinimumTLDate = 4384L;   (* March 1, 1980 *)
VAR
    TimeInfo : ATimeInfo;
    ElapsedHours, ElapsedDays : LONGINT;
    LN : LONGINT;
    TLW1Hour, TLW1Minute : CARDINAL;
    Date : ADate;
BEGIN
    (*<TRACE
    SetString(TraceS,"TLW1DateToDate ");
    LongToString(TLW1Date,TraceS2);  ConcatLS(TraceS,TraceS2);
    PrintString(TraceS);
    TRACE>*)


        (* TLW1Date is 10ths of hours since January 1, 1970. *)
        (* Convert those 10ths into minutes. *)
    ElapsedHours := TLW1Date DIV 10L;
    LN := TLW1Date - (ElapsedHours * 10L);
    TLW1Minute := VAL(CARDINAL,LN) * 6;
    TimeInfo.tiSecond := 0;
        (* Now hours. *)
    LN := (ElapsedHours MOD 24L);
    TLW1Hour     := VAL(CARDINAL,LN);
        (* Now Year, Month, Day *)
    ElapsedDays := ElapsedHours DIV 24L;     (* 24 hours per day. *)

        (* Get the year, month and day. *)
    WITH TimeInfo DO
        KDate1970(ElapsedDays,tiYear,tiMonth,tiDay);
    END;

    IF (ElapsedDays < MinimumTLDate) THEN
        ComplainAboutDate(TimeInfo,ModuleNumber+13);
        Date := 0;
    ELSE
        WITH TimeInfo DO
                (* Locate the equivalent working hour in TL. *) 
            TLW1HourToHour( DayOfWeek(tiYear,tiMonth,tiDay ),
                          TLW1Hour, TLW1Minute, 
                          tiHour, tiMinute );
            (*<TRACE
            SetString(TraceS,"  Year   = "); CtoS(tiYear,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            SetString(TraceS,"  Month  = "); CtoS(tiMonth,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            SetString(TraceS,"  Day    = "); CtoS(tiDay,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            SetString(TraceS,"  Hour   = "); CtoS(tiHour,TraceS2);
              ConcatLS(TraceS,TraceS2);  
              ConcatS(TraceS,"  TLW1Hour   = "); CtoS(TLW1Hour,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            SetString(TraceS,"  Minute = "); CtoS(tiMinute,TraceS2);
              ConcatLS(TraceS,TraceS2);  
              ConcatS(TraceS,"  TLW1Minute   = "); CtoS(TLW1Minute,TraceS2);
              ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
            TRACE>*)

        END;
        IF NOT TtoAbsTimeU (TimeInfo,Date) THEN
            ComplainAboutDate(TimeInfo,ModuleNumber+14);
        ELSIF (Date <= 0) THEN
                (* If the converted date ends up at day zero, assume that
                   it was an earlier date that got rolled to the first day
                   of the calendar.  This is an accurate complaint for all
                   cased except the unlikely circumstance of a task in TLW1
                   starting exactly at the TL calendar day 0. *)
            ComplainAboutDate(TimeInfo,ModuleNumber+17);
        END;

    END;



      (*<TRACE
    SetString(TraceS,"  Date   = "); TimeUtoS(Date,TraceS2);
    ConcatLS(TraceS,TraceS2);  PrintString(TraceS);
      TRACE>*)

    RETURN Date;
END TLWin1DateToDate;


MODULE WordWrap;

IMPORT                      LengthOf, TrimRear, FatalError, ADDRESS,
                            AProcessLineProc, SubStr;

EXPORT                      ForEachLine;



PROCEDURE StartOfWord(VAR String        : ARRAY OF CHAR;
                          Position      : CARDINAL)
                                                   : BOOLEAN;

BEGIN                   (* StartOfWord *)

    RETURN (Position = 1) OR (Position > LengthOf(String))
           OR ((String[Position] <> " ") AND (String[Position - 1] = " "));

END StartOfWord;




PROCEDURE FindPriorWord(VAR String      : ARRAY OF CHAR;
                        VAR Position    : CARDINAL);

BEGIN                   (* FindPriorWord *)

    IF (Position > 1) THEN
        REPEAT
            DEC(Position);
        UNTIL (StartOfWord(String, Position));
    END;

END FindPriorWord;




PROCEDURE FindNextWord(VAR String       : ARRAY OF CHAR;
                       VAR Position     : CARDINAL);

BEGIN                   (* FindNextWord *)

    IF (Position <= LengthOf(String)) THEN
        REPEAT
            INC(Position);
        UNTIL (StartOfWord(String, Position));
    END;

END FindNextWord;


    (*  ForEachLine --

        Given an LString, call the ProcessLine procedure for each line which
        is not longer than Width.  Each line will be broken on a word
        boundary, if possible.
    *)

PROCEDURE ForEachLine( VAR String           : ARRAY OF CHAR;
                           Width            : CARDINAL;
                           ProcessLine      : AProcessLineProc;
                           Context          : ADDRESS           );

VAR
    Index                   : CARDINAL;
    Start                   : CARDINAL;
    Length                  : CARDINAL;
    i                       : CARDINAL;
    Line                    : ARRAY [0..255] OF CHAR;

BEGIN

    IF (Width > 255) THEN FatalError(); END;

    Index := 1;
    WHILE (Index <= LengthOf(String)) DO
        Start := Index;
        WHILE (((Index-Start) < Width) AND (Index <= LengthOf(String))) DO
            FindNextWord( String, Index );
        END;
        IF ((Index-Start) > Width) THEN
            FindPriorWord( String, Index);
            IF (Index <= Start) THEN
                Index := Start + Width - 1;
            END;
        END;
        Length := Index - Start;
        SubStr( String, Line, Start, Length );
        TrimRear( Line );
        ProcessLine( Line, Context );
    END;

END ForEachLine;

BEGIN                       (* WordWrap *)
END WordWrap;

BEGIN                       (* ImpTLWindows *)
END ImpTLWindows.




