IMPLEMENTATION MODULE RsrcMod;

(*----------------------------------------------------------------------------
    MODIFICATION HISTORY

    11/28/86 LAA    Added support for a notes field in the resource, which is
                    a text.
    12/02/86 LAA    Whenever a resource is changed set ScheduleSaved to FALSE.
    05/21/87 EGK    This module has been rewritten to implement a tree of
                    resource nodes whose data objects are resource pointers.
    09/28/87 EGK    Wrote AddResource, RemoveResource, DeleteResource, and
                    CreateResource to more clearly define those routines which
                    manipulate resources without regard to the user interface.
    10/08/87 RSC    Initialized two new resource rec fields: Keyword  extra byte.
    19-Nov-87 LAA   Changed the ExtraByte in resource record to 
                    ExcludeFromLeveling.
    22-Feb-88 RSC   Removed some debugging code in prep for ship.
    10-Jan-89 RSC   Changed Storage to Space    .
     4-Jun-89 EGK   Changed NotifyUndo calls into SendNotice calls.
    16-Jun-89 RSC   Removed references to RsrcEdit, as part of putting
                    parts of rsrcedit into an overlay.
    28-Jul-89 KKC   Added 'Extras' to resource.
                    Set Extras to NIL in InitializeResource.
    RSC 21-Sep-89 - Added BaseLine param to the SetResourceRate proc.
    RSC 22-Sep-89 - Fixed problem in SetResourceRate proc where resource
                    was not getting the changes to the rate.
    AJL 29-May-90 - Changed to use the RateList module (but still only
                    looks at the first rate).
    RSC 20-Jun-90 - Changed TimeXLate procedure calls.
    RSC  2-Jul-90 - upgraded for additional baseline fields.  Added DateLists.
    EGK  6-Jul-90 - Check for Calendar = NIL before disposing it.
    AJL 10-Jul-90 - Dispose the ResidueAvailProfile.
                  - Copy the ResidueAvailProfile.
    RSC  7-Aug-90 - Added parameter to Copy?ateList.
    RSC 16-Aug-90 - Someone had added a cache of "LastRequestedNode".  It
                    seemed complete except for ever setting "LastRequestedNode"
                    to anything, so I did that.  I hope it works.
    RSC 21-Aug-90 - Average cost rate over time.
    RSC 25-Sep-90 - Handle case of 0 duration tasks in AverageResourceRate.
    RSC  2-Oct-90 - When there is no rate, use $1.00 rather than $0.00.
    9-Oct-90  AJL - Added SequenceNumber.
                  - Added LateResidueAvailableProfile.
    3-Nov-90  AJL - Disposing a resource disposes of the LateResidueAvailableProfile.
   26-Mar-91  AJL - Added QueryNumberOfResources.
   24-Apr-91  AJL - Changed QueryNumberOfResources to only report those in
                    the ResourceTree.
    5-Apr-91  AJL - AverageResourceRate was incorrectly scaling the final
                    result by FSMUPH, but this was unnecessary, and wrong,
                    because the average does not depend on the scale of the
                    time units.
                  - In AverageResourceRate, handle an instantaneous rate 
                    separately from a period rate.
   14-Sep-91 TGS    AverageResourceRate should always return One for Fixed
                    costs.
----------------------------------------------------------------------------*)

FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime;

FROM DateLists              IMPORT 
    (* TYPE *)                  ADateList,
    (* PROC *)                  CopyDateList, DisposeDateList;

FROM Dialog                 IMPORT
    (* PROC *)                  NotYetImplemented, FatalError;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
    (* PROC *)                  CreateExtObjectWithSize, DiscardExtObject,
                                CopyExtObject, LockObject,
                                ReleaseUnchangedObject, ReleaseObject;

FROM GaGa                   IMPORT
    (* PROCS *)                 GetGaGaMessage;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, Compare, Upshift, SubStr, Copy, 
                                LJust, TrimRear;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  SendNotices;


FROM RateLists              IMPORT 
    (* TYPE *)                  ARateList,
    (* PROC *)                  GetRateListEntry, LocateDateInRateList,
                                CopyRateList, CreateRateList, DisposeRateList;

FROM ResCal                 IMPORT
    (* TYPE *)                  AResAvailability,
    (* PROC *)                  CopyResAvailabilities, DisposeResAvailabilities;

FROM ResCalUI               IMPORT
    (* PROC *)                  CreateCalendar, DisposeCalendar, CopyCalendar;

FROM Schedule               IMPORT
    (* VAR  *)                  ScheduleSaved;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, TSIZE;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  CreateText, TextExists, DiscardText, 
                                AssignText;

FROM Timei                  IMPORT
    (* TYPE *)                  ADate, ADurationUnit, ADuration;

FROM TimeMath               IMPORT
    (* PROC *)                  DurationInBigPeriod;

FROM Timeu                  IMPORT
    (* VAR  *)                  FSMUPH;

FROM TimeXlate              IMPORT
    (* PROC *)                  TimesToBigTimes;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
    (* PROC *)                  CreateTree, CreateTreeNode;


CONST
    ModuleNumber  = 22100;

    ResourceTag   = 60954;    (* Linda's birthday. *)

    Zero          = 0.0;
    One           = 1.0;



VAR
    LastRequestedNode       : ATreeNode;
    NumberOfResources       : CARDINAL;


  (* Initialize Resource - Init one resource record.

      Preconditions  - an allocated resource pointer.
                       This procedure may be called during module init, and
                       IS by RsrcOutlines.
      Postconditions - resource record filled in with initial values.

   Note: When this procedure is first called, we are in MODULE INITIALIZATION
         (RsrcOutline calls us).  Don't assume that GetMessage works.
  *)

PROCEDURE InitializeResource( Resource : AResourcePointer );

CONST One         = 1.0;
      OneHundred  = 100.0;
      MAXCARDINAL = 65535;

BEGIN
    WITH Resource^ DO
        Tag                  := ResourceTag;
        ID                   := 0;
        Name[0]              := 0C;
        LongName[0]          := 0C;
        CostStyle            := CAmountRateTime;
        Type                 := Employable;
        Percent              := 100;
        Limit                := OneHundred;
        UpperPercent         := 100;
        UpperLimit           := OneHundred;
        GetGaGaMessage( ModuleNumber + 0, UnitOfMeasure ); (* "Units" *)
        Units                := Hours;
        Notes                := AText (NIL);
        FilteredIn           := FALSE;
        Filler               := 0C;
        WorkSpace            := NIL;
        OvertimeMultiplier   := One;
        ActualRates          := ARateList(NIL);
        BaseLineRates        := ARateList(NIL);
        Keyword[0]           := 0C;
        LevelThisResource    := TRUE;
        Extras               := AText (NIL);

        (* Added by RSC 12-Jun-90: *)

        Calendar             := NIL;
        BaselineCalendar     := NIL;
        Availability         := ADateList(NIL);
        BaselineAvailability := ADateList(NIL);
        ResidueAvailProfile  := AnExtHandle(NIL);
        LateResidueAvailProfile  := AnExtHandle(NIL);

        SequenceNumber       := 0;
    END;

END InitializeResource;




PROCEDURE CreateResource (VAR Node: ATreeNode): BOOLEAN;
VAR
    Resource: AResourcePointer;
BEGIN
    IF HeapAvailable() AND (CreateTreeNode (Node)) THEN
        NEW (Resource);
        InitializeResource( Resource );
        Node^.Methods^.SetDataObject (Node, Resource);
        LastRequestedNode := NIL;
        INC(NumberOfResources);
        RETURN TRUE;
    END;
    RETURN FALSE;
END CreateResource;



PROCEDURE AddResource ( NewNode         : ATreeNode;
                        Parent          : ATreeNode;
                        Prior           : ATreeNode     );
BEGIN
    IF (Prior <> NIL) THEN
        Prior^.Methods^.AddAfter (Prior, NewNode);
    ELSE
        ResourceTree^.Methods^.AddFirst (ResourceTree, NewNode);
    END;
    SendNotices (AddAResource, AfterActing, NewNode);        (* 6/4/89 EGK *)
END AddResource;





PROCEDURE DeleteResourcePointer( VAR Resource : AResourcePointer );
BEGIN
    CheckResourceValid (Resource);

    WITH Resource^ DO
        IF TextExists (Notes) THEN
            DiscardText (Notes);
        END;
        IF TextExists (Extras) THEN
            DiscardText (Extras);
        END;
        IF (ActualRates <> AnExtHandle(NIL)) THEN
            DiscardExtObject(ActualRates);
        END;
        IF (BaseLineRates <> AnExtHandle(NIL)) THEN
            DiscardExtObject(BaseLineRates);
        END;
        IF (Availability <> AnExtHandle(NIL)) THEN
            DiscardExtObject(Availability);
        END;
        IF (BaselineAvailability <> AnExtHandle(NIL)) THEN
            DiscardExtObject(BaselineAvailability);
        END;
        IF (BaselineCalendar <> NIL) THEN           (* 7/6/90 EGK *)
            DisposeCalendar(BaselineCalendar);
        END;
        IF (Calendar <> NIL) THEN                   (* 7/6/90 EGK *)
            DisposeCalendar(Calendar);
        END;
        DisposeResAvailabilities(ResidueAvailProfile);
        DisposeResAvailabilities(LateResidueAvailProfile);
    END;

    DISPOSE (Resource);

    DEC(NumberOfResources);

END DeleteResourcePointer;





PROCEDURE RemoveResource (VAR Node  : ATreeNode);
BEGIN
    SendNotices (DeleteAResource, BeforeActing, Node);   (* 6/4/89 EGK *)
    Node^.Methods^.DeList (Node);
    DeleteResource (Node);
END RemoveResource;





PROCEDURE DeleteResource (VAR Node: ATreeNode);
VAR
    Resource: AResourcePointer;
BEGIN
    Resource := Node^.Methods^.GetDataObject (Node);
    DeleteResourcePointer(Resource);
    Node^.Methods^.Discard (Node);
    LastRequestedNode := NIL;
END DeleteResource;




PROCEDURE ChangedResource (Node: ATreeNode);
VAR
    OtherNode               : ATreeNode;
    ResourcePtr, OtherResource : AResourcePointer;
    Name, OtherName         : ARRAY [0..ResourceNameLength] OF CHAR;
BEGIN
    ResourcePtr := Node^.Methods^.GetDataObject (Node);
    CheckResourceValid (ResourcePtr);
    Copy (ResourcePtr^.Name, Name);
    Upshift (Name);
    Node^.Methods^.DeList (Node);
    OtherNode := ResourceTree^.Methods^.GetFirst (ResourceTree);
    LOOP
        IF (OtherNode = NIL) THEN
            EXIT;
        END;
        OtherResource := OtherNode^.Methods^.GetDataObject (OtherNode);
        Copy (OtherResource^.Name, OtherName);
        Upshift (OtherName);
        IF (Compare (Name, OtherName) <= 0) THEN
            EXIT;
        END;
        OtherNode := OtherNode^.Methods^.GetNext (OtherNode);
    END;
    IF (OtherNode = NIL) THEN
        ResourceTree^.Methods^.AddLast (ResourceTree, Node);
    ELSE
        OtherNode^.Methods^.AddBefore (OtherNode, Node);
    END;
    ScheduleSaved := FALSE;
    LastRequestedNode := NIL;

END ChangedResource;




    (* Copy one resource pointer to another.  *)

PROCEDURE CopyResourcePointers( Source               : AResourcePointer;
                            VAR Dest                 : AResourcePointer;
                                SaveNotesAndBaseLine : BOOLEAN  );
BEGIN
        (* Copy the direct fields. *)

    Dest^ := Source^;

        (* Copy the structured fields. *)

    IF (Source^.ActualRates <> ARateList(NIL)) THEN
        CopyRateList(Dest^.ActualRates,Source^.ActualRates,ExtMedium);
    END;

    IF (Source^.Extras <> AText(NIL)) THEN
        IF (NOT AssignText(Source^.Extras,Dest^.Extras)) THEN
            Dest^.Extras := AText(NIL);
        END;
    END;

    CopyCalendar(Dest^.Calendar,Source^.Calendar);

    IF (Source^.Availability <> ADateList(NIL)) THEN
        CopyDateList(Dest^.Availability, Source^.Availability,ExtMedium);
    END;

    IF (CopyResAvailabilities(Dest^.ResidueAvailProfile, Source^.ResidueAvailProfile,
                              ExtSlow)) THEN
    END;

    IF (SaveNotesAndBaseLine)  THEN
        IF (Source^.BaseLineRates <> ARateList(NIL)) THEN
            CopyRateList(Dest^.BaseLineRates,Source^.BaseLineRates,ExtMedium);
        END;
        IF (Source^.BaselineCalendar <> NIL) THEN
            CopyCalendar(Dest^.BaselineCalendar,Source^.BaselineCalendar);
        END;
        IF (Source^.BaselineAvailability <> ADateList(NIL)) THEN
            CopyDateList(Dest^.BaselineAvailability, Source^.BaselineAvailability,ExtMedium);
        END;
        IF TextExists(Source^.Notes) THEN
            IF (NOT AssignText(Source^.Notes,Dest^.Notes)) THEN
                Dest^.Notes := AText(NIL);
            END;
        END;
    ELSE
        Dest^.BaseLineRates        := AnExtHandle(NIL);
        Dest^.BaselineCalendar     := NIL;
        Dest^.BaselineAvailability := ADateList(NIL);
        Dest^.Notes                := AText(NIL);
    END;

END CopyResourcePointers;




    (* Copy one resource node to another. *)

PROCEDURE CopyResourceNode( SourceNode, DestNode : ATreeNode;
                            SaveNotesAndBaseLine : BOOLEAN  );
VAR
    Source,
    Dest    : AResourcePointer;
BEGIN
    Source := SourceNode^.Methods^.GetDataObject( SourceNode );
    CheckResourceValid( Source );
    Dest   := DestNode^.Methods^.GetDataObject( DestNode );
    CheckResourceValid( Dest );
    
    CopyResourcePointers( Source, Dest, SaveNotesAndBaseLine );

END CopyResourceNode;





    (* FindResourceByName -- Ignores case. *)


PROCEDURE FindResourceByName (S: ARRAY OF CHAR): ATreeNode;
TYPE
    ADirection = (Forward, Reverse, Unknown);
VAR
    Node     : ATreeNode;
    Resource : AResourcePointer;
    S2       : ARRAY [0..ResourceNameLength] OF CHAR;
    i        : INTEGER;
    LastDirection : ADirection;
BEGIN
    LJust(S);
    TrimRear(S);
    Upshift(S);
    IF (S[0] = 0C) THEN RETURN NIL; END;

    IF (LastRequestedNode = NIL) THEN
        Node := ResourceTree^.Methods^.GetFirst (ResourceTree);
    ELSE
        Node := LastRequestedNode;
    END;
  
    LastDirection := Unknown;

    LOOP
        IF (Node = NIL) THEN
            EXIT;
        END;
        Resource := Node^.Methods^.GetDataObject (Node);
        SubStr(Resource^.Name,S2,1,HIGH(S2));
        Upshift(S2);
            (* Search, assuming that the resources are sorted in
               alphabetical order. *)
        i := Compare(S,S2);
        IF (i=0) THEN
            EXIT;
        ELSIF (i > 0) THEN
            IF (LastDirection = Reverse) THEN
                RETURN NIL; (* Catch a lookup on a non-existant name. *)
            END;
            Node := Node^.Methods^.GetNext (Node);
            LastDirection := Forward;
        ELSE
            IF (LastDirection = Forward) THEN
                RETURN NIL; (* Catch a lookup on a non-existant name. *)
            END;
            Node := Node^.Methods^.GetPrev (Node);
            LastDirection := Reverse;
        END;
    END;

    LastRequestedNode := Node;  (* 16-Aug-90 RSC  *)

    RETURN Node;

END FindResourceByName;




PROCEDURE FindResourceByNumber( MatchID  : INTEGER ) : ATreeNode;
VAR
    ResourcePtr  : AResourcePointer;
    ResourceNode : ATreeNode;
BEGIN
    ResourceNode := ResourceTree^.Methods^.GetFirst(ResourceTree);
    LOOP
        IF (ResourceNode = NIL) THEN
            EXIT;
        END;
        ResourcePtr := ResourceNode^.Methods^.GetDataObject(ResourceNode);
        IF (ResourcePtr^.ID = MatchID) THEN
            EXIT;
        END;
        ResourceNode := ResourceNode^.Methods^.NextPreOrder(ResourceNode);
    END;
    RETURN ResourceNode;
END FindResourceByNumber;






PROCEDURE CheckResourceValid(X:AResourcePointer);
BEGIN
    IF (X = NIL) OR
       (X^.Tag <> ResourceTag) THEN FatalError; END;
END CheckResourceValid;




  (* AverageResourceRate - Return the rate to be used over a time period.

        Preconditions  - Resource is the one you want the answer for.
                         Start and End Date is the range you want.
                         BaseLine is TRUE iff you want the baseline amount.

        Postconditions - RETURN is the averaged rate.
  *)
PROCEDURE AverageResourceRate( Resource         : AResourcePointer;
                               StartDate,
                               EndDate          : ADate;
                               BaseLine         : BOOLEAN
                             ) : REAL;
VAR
    Rate,
    Amount           : REAL;
    RateList         : ARateList;
    BStartDate,
    BEndDate,
    PeriodStartDate,
    PeriodThruDate   : ABigTime;
    TotalDuration,
    Duration         : ADuration;
    N                : CARDINAL;
BEGIN
    WITH Resource^ DO
        IF (CostStyle = CAmount) THEN (* 14-Sep-91 TGS *)
            RETURN One;
        END;
        IF (BaseLine) THEN
            RateList := BaseLineRates;
        ELSE
            RateList := ActualRates;
        END;

        IF (RateList <> ARateList(NIL)) THEN

            TimesToBigTimes( StartDate, EndDate, BStartDate, BEndDate );

            LocateDateInRateList( RateList, BStartDate, N );

                (* Rate for a moment, as opposed to rate for a period. *)

            IF (StartDate = EndDate) THEN
                IF (GetRateListEntry( RateList, N, PeriodStartDate, PeriodThruDate,
                                      Rate )) THEN
                ELSE
                    Rate := One;
                END;
                RETURN Rate;
            END;


                 (* Well . . . add up the rates and the period. *)

            Amount        := Zero;
            TotalDuration := 0;

            LOOP
                IF NOT (GetRateListEntry( RateList, N, PeriodStartDate, PeriodThruDate,
                       Rate )) THEN
            EXIT;
                END;

                Duration := DurationInBigPeriod( BStartDate,
                                                 BEndDate,
                                                 PeriodStartDate,
                                                 PeriodThruDate );

                IF (Duration = 0) THEN       (* PeriodStartDate >=  BEndDate *)
            EXIT;
                END;

                    (* 21-Aug-90 RSC Summ up Tics * DollarsPerHour
                    *)
                Amount        := Amount + (Rate * FLOAT(Duration));
                TotalDuration := TotalDuration + Duration;

                INC(N);
            END;

            IF (TotalDuration <> 0) THEN
                Amount := (Amount / FLOAT(TotalDuration));
            ELSE
                Amount := (Amount / FSMUPH);
            END;
        ELSE
            Amount := One;
        END;
    END;


    RETURN Amount;

END AverageResourceRate;



PROCEDURE AddOne  (VAR TaskTreeNode : ATreeNode;
                       Context      : ADDRESS);
VAR
    Count : POINTER TO CARDINAL;
BEGIN
    Count := Context;
    INC(Count^);
END AddOne;



    (* Returns the number of resources that exist in the ResourceTree.
       (There may also be resources in the Undo system.). *)

PROCEDURE QueryNumberOfResources(): CARDINAL;
VAR
    Count : CARDINAL;
BEGIN
    Count := 0;
    ResourceTree^.Methods^.TraverseTree(ResourceTree,ParentBeforeChild,
                                        MAX(CARDINAL),
                                        AddOne, ADR(Count));
    RETURN Count;
END QueryNumberOfResources;



BEGIN
    IF NOT (CreateTree (ResourceTree)) THEN
        FatalError ();
    END;
    LastRequestedNode := NIL;
    NumberOfResources := 0;
END RsrcMod.

