IMPLEMENTATION MODULE IV4Resources;

(*  =========================================================================
    Last Edit : September 13, 1990 11:22AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Import Version 3 and 4 resources into version 4.5

    MODIFICATION HISTORY:

        12-Sep-90 RSC   First version, taken from TLITL3 and TLITL4.
        30-Jan-91 TGS   Create a DateList if Avail <> 1 @100%
                        Create a RateList if Rate <> 1.0, not 0.0
                        Import default cost rate and availability CONSTs
        30-Apr-91 AJL   Transfer the default Limit and Percent from the 
                        V4 record to the V3 one.
         4-Oct-91 TGS   Hmm, we were always using 100% as the default
                        levelling percentage, instead of what V4 had.
    =========================================================================
*)


FROM BigTimeU               IMPORT
    (* TYPE *)                      ABigTime,
    (* VAR  *)                      MINBIGTIME;

FROM DateLists              IMPORT
    (* PROC *)                  CreateDateList;

FROM Dialog                 IMPORT Message;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle;

FROM FileAux                IMPORT FileResultMeans,
                                   PrepareForIO, CheckIO;

FROM FileSystem             IMPORT  File, Response;

FROM Kbio                   IMPORT
    (* PROC *)                  BreakRequested;

FROM LoadCommon             IMPORT  ErrorFlag, SkipRecordBody,
                                ReadOldFormatTextLine;

FROM LStrings               IMPORT
    (* PROC *)                  Copy;

FROM RateLists              IMPORT
    (* TYPE *)                  ARateList,
    (* PROC *)                  CreateRateList, DisposeRateList;

FROM RecordIO               IMPORT  ReadRecord, ReadString, ReadRecordPreface,
                                    ReadRecordBody, ReadStringBody;

FROM ResCalUI               IMPORT
    (* TYPE *)                  AnAvailabilityRate;

FROM RsrcMod                IMPORT
    (* TYPE *)                  AResourceType, AResourcePointer, ACostStyle,
    (* CONST *)                 DefaultCostRate, DefaultAvailabilityPercent,
                                DefaultAvailabilityAmount,
    (* VAR  *)                  ResourceNameLength, ResourceTree,
    (* PROC *)                  CreateResource, ChangedResource,
                                FindResourceByName, AddResource,
                                FindResourceByNumber;

FROM Space                  IMPORT  HeapAvailable;

FROM Subfiles               IMPORT  StartFileInput, StartSubfileInput,
                                    TraverseSubfiles;

FROM SYSTEM                 IMPORT ADDRESS, TSIZE, SIZE, ADR, BYTE;

FROM Text                   IMPORT
    (* PROC *)                  CreateText, TextExists, DiscardText, AppendLine,
                                Compress, AText;

FROM Timei                  IMPORT
    (* TYPE *)                  ADurationUnit;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode, ATreeOrder;



CONST
    ResourceType    = 5;








PROCEDURE RenumberTheResource  (VAR Node    : ATreeNode;
                                    Context : ADDRESS   );
VAR
    Resource        : AResourcePointer;
BEGIN
    Resource                   := Node^.Methods^.GetDataObject (Node);
    Resource^.WorkSpace.OFFSET := Resource^.ID;
    Resource^.ID               := -Resource^.ID;

END RenumberTheResource;




PROCEDURE GetResources(VAR f:File) : BOOLEAN;

TYPE

    ARateCalendarEntry = 
        RECORD
            StartDate : ABigTime;
            RateThen  : REAL;
        END;
    ARateCalendar = AnExtHandle;  (* --> ARateCalendarArray *)

    AV4Resource = RECORD
                        Tag                : CARDINAL; (* Rsrc tag *)
                        ID                 : INTEGER;  (* Internal use *)
                        Name               : ARRAY [0..ResourceNameLength] OF CHAR;
                        LongName           : ARRAY [0..32] OF CHAR;
                        CostStyle          : ACostStyle;
                        Type               : AResourceType;
                        Percent            : CARDINAL;   (* % avail for each resource. *)
                        Limit              : REAL;       (* How many FTE's are there?  *)
                        UpperPercent       : CARDINAL;   (* overtime % avail for each resource. *)
                        UpperLimit         : REAL;       (* Limit + Overtime available *)
                        UnitOfMeasure      : ARRAY [0..10] OF CHAR;
                        Units              : ADurationUnit;
                        Notes              : AText;
                        FilteredIn         : BOOLEAN;
                        CostPlace          : CHAR;  (* 26-Jul-90 RSC *)
                        WorkSpace          : ADDRESS;
                        OvertimeMultiplier : REAL;
                        ActualRates        : ARateCalendar;
                        BaseLineRates      : ARateCalendar;
                        Keyword            : ARRAY [0..10] OF CHAR;
                        LevelThisResource  : BOOLEAN;
                        Extras             : AText;
                    END;

VAR
    Resource      : AResourcePointer;
    LocalResource : AV4Resource;
    Node          : ATreeNode;
    Version       : CARDINAL;
    Length        : CARDINAL;
    Type          : CARDINAL;
    s             : ARRAY [0..81] OF CHAR;



    PROCEDURE CopyResource( VAR V4R  : AV4Resource;
                                V45R : AResourcePointer );

    VAR
        Avail : AnAvailabilityRate;

    BEGIN

        V45R^.ID           := V4R.ID;  (* 16-Aug-90 RSC  *)

        Copy( V4R.Name,     V45R^.Name );
        Copy( V4R.LongName, V45R^.LongName );
        V45R^.CostStyle    := V4R.CostStyle;
        V45R^.Type         := V4R.Type;
        V45R^.Percent      := V4R.Percent;
        V45R^.Limit        := V4R.Limit;
        V45R^.UpperPercent := DefaultAvailabilityPercent;
        V45R^.UpperLimit   := FLOAT(DefaultAvailabilityAmount);

        (* 30-Jan-91 TGS, 30-Apr-91 AJL *)
        Avail.Amount       := TRUNC(V4R.UpperLimit/FLOAT(V4R.UpperPercent));
        Avail.Percent      := V4R.UpperPercent; (* 4-Oct-91 TGS *)
        IF  (Avail.Percent <> DefaultAvailabilityPercent       ) OR
            (Avail.Amount  <> DefaultAvailabilityAmount ) THEN
            V45R^.Availability := CreateDateList (Avail, MINBIGTIME);
        END;

        Copy( V4R.UnitOfMeasure, V45R^.UnitOfMeasure );
        V45R^.Units        := V4R.Units;
        V45R^.FilteredIn   := V4R.FilteredIn;
        Copy( V4R.Keyword, V45R^.Keyword );
        V45R^.LevelThisResource := V4R.LevelThisResource;

    END CopyResource;




    PROCEDURE AddRates( VAR Handle : ARateList ) : BOOLEAN;
    VAR
        Entry : ARateCalendarEntry; (* 26-Jul-90 RSC SPIKE: 1 entry only. *)
        i     : CARDINAL;
    BEGIN
        i := TSIZE(ARateCalendarEntry); (* 16-Aug-90 RSC  *)
        ReadRecordBody(f,Length,ADR(Entry),i);

        IF (Entry.RateThen <> DefaultCostRate) THEN
            Handle := CreateRateList( Entry.RateThen, MINBIGTIME );
        ELSE
            Handle := ARateList(NIL);
        END;

        RETURN (Entry.RateThen = DefaultCostRate) OR (Handle <> ARateList(NIL));

    END AddRates;


BEGIN
    IF (NOT StartSubfileInput(f,ResourceType,Version)) OR
       (NOT HeapAvailable()) THEN                                 (* 02-Feb-88 LAA *)
        RETURN FALSE;
    END;

    Resource := NIL;

    (* If we are doing a file combine, we need to clear out the IDs of any
       existing resources before loading in the new ones.  *)

    ResourceTree^.Methods^.TraverseTree (ResourceTree, ParentBeforeChild,
                9999, RenumberTheResource, NIL);

    LOOP
        IF (BreakRequested() OR ErrorFlag) THEN                   (* 12-Feb-88 LAA *)
            EXIT;
        END;
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN
            EXIT;
        END;
        CASE Type OF
            ResourceType:
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
                       Notes            := AText(NIL); (* 12/02/86 LAA *)
                       ActualRates      := AnExtHandle(NIL);
                       BaseLineRates    := AnExtHandle(NIL);
                       Extras           := AText(NIL); (* 26-Jul-89 KKC *)
                       WorkSpace        := NIL;
                       WorkSpace.OFFSET := 0; (* No ID. *)
                   END;

                   Copy (LocalResource.Name, s);
                   Message(s);

                   Node     := FindResourceByName(s);
                   Resource := NIL;
                   IF (Node <> NIL) THEN
                       Resource := Node^.Methods^.GetDataObject (Node);
                       Resource^.ID := LocalResource.ID;
                       Resource := NIL;  (* Don't save the new info. *)

                   ELSE

                       IF (CreateResource (Node)) THEN
                           Resource := Node^.Methods^.GetDataObject (Node);
                           CopyResource( LocalResource, Resource );
                           AddResource (Node, NIL, NIL);
                           ChangedResource (Node);
                           Message(s);
                       ELSE (* Probably out of heap space. *)
                           EXIT;
                       END;
                   END;

          | ResourceType + 1 :

                   IF (Resource <> NIL) THEN
                       IF (NOT AddRates( Resource^.ActualRates )) THEN
                           EXIT;
                       END;
                   ELSE
                       SkipRecordBody(f, Length);
                   END;

          | ResourceType + 2 :

                   IF (Resource <> NIL) THEN
                       IF (NOT AddRates( Resource^.BaseLineRates )) THEN
                           EXIT;
                       END;
                   ELSE
                       SkipRecordBody(f, Length);
                   END;

          | 100 :  IF (Resource <> NIL) THEN
                       ReadOldFormatTextLine(f, Length, Resource^.Notes);
                   ELSE
                       SkipRecordBody(f, Length);
                   END;

          | 101 :  IF (Resource <> NIL) THEN
                       ReadOldFormatTextLine(f, Length, Resource^.Extras);
                   ELSE
                       SkipRecordBody(f, Length);
                   END;

          | 0FFH : EXIT;
        ELSE
            SkipRecordBody(f,Length);
        END;
    END;

    IF (Resource <> NIL) THEN
        Compress(Resource^.Notes);
        Compress(Resource^.Extras);
    END;

    RETURN (CheckIO(f) = done);

END GetResources;






END IV4Resources.



