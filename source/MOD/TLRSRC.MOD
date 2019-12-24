(*V9=TRACE*)


MODULE TLRsrc;

(*  =========================================================================
    Last Edit : July 10, 1991 6:27PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Do the Resource Form.        

    MODIFICATION HISTORY:

        1/18/87 - RSC - Split off from RsrcEdit.
        19-Jan-88 LAA   Made this an installable overlay.
         2-Feb-88 RSC   1) Don't protect num & % on var costs.
                        2) Dont allow default num * default % to exceed
                           MAXCARDINAL.
        18-Feb-88 LAA   Changed import from RsrcCalc to ManHours.
         3-Mar-88 RSC   For Var Costs, protect upper limit fields.
         6-Jan-89 RSC   Moved "AnOverlayProc" reference.
        20-May-89 RSC   Accomidated new WorkHours module.
        25-May-89 KKC   Check Maximum leveling vs default assignment when
                        exiting form.
                        Check valid Maximum leveling percent based on the
                        value of Maximum leveling.
        20-Jun-89 AJL   Return the passed-in code from the CheckProc unless
                        we explicitly override it.
        21-Jun-89 KKC   Check Maximum leveling vs default assignment only
                        for Resource.
        12-Jul-89 KKC   Change value to 250 percent when user enters a number 
                        that is greater than 250 percent for "default 
                        assignment" and "Maximum for leveling".
        09-Aug-89 KKC   Add copyright message.
        12-Sep-89 WKH   Make notes text window bigger for compressed video.
        20-Sep-89 RSC   Only set recalc when something significant has
                        changed.  Also, add new params to SetResourceRate.
         8-Nov-89 RSC   Tell the Gantt Chart to refresh its display of the
                        columns.  Bug # 1710.
        21-Feb-90 KKC   Remove all unreferenced id from Timeu.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
         1-Jun-90 TGS   Add field for access to resource calendars.
        29-Jun-90 TGS   Add fields for variable availability/cost & overtime
         5-Jul-90 TGS   There were too many fields for the BITSET scheme;
                        made an enumerated type and put in ORDs and VALs
         9-Jul-90 EGK   Put in support for varying assignment and varying
                        cost lists and their associated forms.
        10-Jul-90 RSC   Put in support for calendars.
        10-Jul-90 EGK   On F2 from the varying availability field, create
                        a new availability list if none existed previously,
                        containing a single entry matching the static
                        "number" and "percent" already on the form.
        11-Jul-90 EGK   Put in more safety checks to keep from disposing
                        a NIL calendar.  (This should really be fixed in
                        ResCalUI).
        13-Jul-90 AJL  -Compute the field location and pass it to the 
                        calendar editting proc when editting a resource
                        calendar.
                       -Use MaxRow and MaxColumn rather than maxrow and maxcol.
        19-Jul-90 AJL  -New parameters to ChangeResourceCalendar.
        30-Jul-90 RSC  - Cleanup the "*" fields and OvertimeMultiplyer
        31-Jul-90 RSC  - Cleanup the VarAvail list and VarCost list.
        16-Aug-90 RSC  - Raise up the cost and avail forms.
        20-Aug-90 RSC  - Don't create a rate list if there is only one
                         entry and that entry is ZERO.
         4-Sep-90 RSC  - Only use Dates (not DatesAndTimes) on the DateList
                         forms and lists.  Correct cursor positioning.
        26-Sep-90 DSL  - Changed DoResourceForm to do an UnSetState(Sort) and
                         UnSetState(Filtered) if Resource name or Keyword
                         are changed.
         2-Oct-90 RSC  - Bugs: Make default cost $1.00, not $0.00.
         6-Oct-90 AJL  -Allow the AlternateEraseKey (Ctrl-End) to erase to eol. 
         2-Nov-90 PFG   Changes to all three forms as per 4.5 prototype review.
         6-Nov-90 RSC   Added init of availability list.  Ajusted some stack
                        items to be in subprocedures to reduce the total
                        stack space used (in general, the taskform/rsrclist/
                        rsrcform/its subforms use a lot of space because they
                        are nested so deeply).
         7-Nov-90 RSC   Make strings longer
        13-Nov-90 RSC   Cost rate was not being saved for Unit Cost fields
                        on the Varying Cost form.  BigDates were susceptable
                        to having times attached when times are typed in
                        (like "TODAY", which implies an hour and minute).
         9-Jan-91 TGS   Allow Zero in AVNUM field.
        10-Jan-91 TGS   Burp when TL changes field values on Avails. form.
        18-Jan-91 TGS   Add resource name to avail/cost list titles.
        30-Jan-91 TGS   Import CONSTs for default cost rate and availability.
        31-Jan-91 TGS   Check AVNUM field to see if it is zero before DIVing
                        Make Resform fields consistent with VarAvail form's.
        16-May-91 TGS   Overtime Rate Multiplier field removed.
        24-May-91  PFG  Replaced DeleteOk proc with AvailDelete and CostDelete
                        and made them actually do the delete.  They used to
                        just verify that a delete was possible.  Also, took
                        the CollapseAdjacent... procs out one level so they
                        could be available to the Delete procs as well as the
                        Edit procs.  These things fix bug #4038, where
                        adjacent identical entries weren't getting deleted.
        21-Jun-91 PFG   Commented out code that kept the asterisk from 
                        displaying for cost rates if there was only one
                        cost rate, even if this cost rate had been edited.
                        Now the asterisk appears as long as there has been
                        any change to the cost rate, the same as it works
                        for availabilities.
        10-Jul-91 PFG   Added errors to catch the case where we run out of
                        memory adding availabilities or cost rates.
        14-Sep-91 TGS   On form exit, dispose of any resource vacation and
                        availability lists unless it is actually an 
                        Employable resource.
                        Also dispose of any varying rate lists for Fixed-type 
                        resources.
        15-Sep-91 TGS   Also dispose Baseline lists as appropriate.
        24-Sep-91 AJL   If the user changes the default availability,
                        and there is only a single entry on the 
                        availability list, warn about the distinction
                        between the two fields.
    =========================================================================
*)


FROM AsOf          IMPORT
        (* VAR *)       AsOfDate;

FROM BigTimeU   IMPORT
    (* TYPE *)      ABigTime,
    (* VAR *)       MINBIGTIME, MAXBIGTIME,
    (* PROC *)      TimeToBigTime, BigTimeToTime, TimeInfoToBigTime,
                    BigTimeToTimeInfo, CompareBigTimes;

FROM Boxes         IMPORT
        (* TYPE *)      ABoxType, ABoxAttribute;

FROM Chart          IMPORT
    (* VAR *)           GanttChart;     (* 8-Nov-89 RSC *)

FROM ChartControl   IMPORT
        (* TYPE *)      AChartState,
        (* PROCS *)     UnSetState, DisplayTheChart;

FROM Codes         IMPORT
        (* TYPE *)      ACode;

FROM DateGoto   IMPORT
    (* PROC *)      ManageDateList;

FROM DateLists  IMPORT
    (* TYPE *)      ADateList, ADateListIndex,
    (* PROC *)      GetDateListEntry, CreateDateListEntry,
                    DisposeDateListEntry, LocateDateInDateList,
                    NumberOfDatesInList, CreateDateList, DisposeDateList;

FROM   Dialog      IMPORT
        (* PROCS *)     Message, Burp, FatalError, Error, ErrorPhrase;

FROM   Edits       IMPORT
    (* PROC *)          EditText;

FROM   FormCon     IMPORT
        (* TYPE *)      AFieldNo;

FROM   Forms       IMPORT
        (* TYPE *)      AForm, AFieldValue, ACheckReason, ACursorAttribute,
                        AStringValue,
        (* PROCS *)     DoForm, ShowValue, SetFieldProtection, SetFieldHidden,
                        HighlightField, SetFormChange, FindFieldXY,
                        MinIndex, MaxIndex;

FROM GanttOutlines  IMPORT
    (* TYPE *)          AGanttOutlineSpecificChange;    (* 8-Nov-89 RSC *)

FROM   Keys        IMPORT
        (* CONST *)     ExitKey, UndoKey, ChngTskKey, DeleteKey,
                        BackSpace, CancelKey, DoIt,
                        EraseKey, EraseToEOLKey, InsertKey, EditKey,
                        AlternateEraseKey;

FROM   KeywdSub       IMPORT
        (* PROC *)          MakeSubstitutions;

FROM   Kbio        IMPORT
        (* TYPE *)      avidmode, ascreenx, ascreeny,
        (* PROCS *)     EraseLn;

FROM   Layout      IMPORT
        (* CONST *)     MaxColumn,
        (* VAR   *)     MaxRow, GanttWEnd;

FROM   LStrings    IMPORT
        (* PROCS *)     SetString, SubStr, ConcatLS, Fill,
                        LJust, TrimRear, StoC, CtoS, ConcatS,
                        TrimFront, Insert, Procustes, Upshift,
                        Remove, Search, Compare, Copy, RJust;

FROM Menus          IMPORT
    (* PROC *)          NoYes;

FROM MsgFile        IMPORT
        (* PROCS *)     GetMessage, DisplayMessage, ConcatMessage;

FROM   Overlays     IMPORT
        (* TYPE *)      AnOverlayID,
        (* PROC *)      OverlayContext, ImAnInstallableOverlay;

FROM   OvTree       IMPORT
    (* TYPE *)          AnOverlayProc;

FROM ParseTime      IMPORT
    (* PROC *)          StoD;

FROM RateLists      IMPORT
    (* TYPE *)          ARateList,
    (* PROC *)          CreateRateList, DisposeRateList, NumberOfRatesInList,
                        SetRateListEntryN, GetRateListEntry;

FROM RCalDays       IMPORT
    (* TYPE *)          ChangeResourceCalendar;

FROM   RealFormat   IMPORT
    (* TYPE *)          DefaultCurrencyFormat,
    (* PROC *)          FormatAsCurrency;

FROM ResCalUI       IMPORT
    (* TYPE *)          AResourceCalendarPointer, AnAvailabilityRate,
                        ACalendarEntry,
    (* PROC *)          CreateCalendar, DisposeCalendar, CopyCalendar;


FROM   RsrcEdit     IMPORT
        (* TYPE *)      AResourceFormLink;

FROM   RsrcMod      IMPORT
        (* CONST *)     ResourceNameLength, DefaultCostRate,
                        DefaultAvailabilityAmount, DefaultAvailabilityPercent,
        (* TYPES *)     ACostStyle, AResourceType, AResourcePointer,
        (* VARS  *)     ResourceTree,
        (* PROCS *)     CheckResourceValid,  
                        AverageResourceRate, FindResourceByName;

FROM   Rugs         IMPORT
        (* TYPE *)      ARug,
        (* PROCS *)     GetRug, PutRug;

FROM   Schedule     IMPORT
        (* VAR *)       ScheduleSaved;

FROM   SYSTEM       IMPORT
        (* THINGS *)    ADR, ADDRESS, TSIZE;

FROM   Text         IMPORT
        (* TYPE *)      AText,
        (* PROC *)      TextExists, CreateText, AssignLine, CopyLine,
                        DiscardText, Compress, AssignText;

FROM TimeFormat IMPORT
    (* VAR *)       DefaultDateFormat,
    (* PROC *)      TimeToString, TimeStringLength;

FROM Timei      IMPORT
    (* CONST *)     MinDate,
    (* TYPE *)      ADate, ATimeInfo, ADurationUnit,
    (* PROC *)      TimeUtoT, FindToday;

FROM TimeXlate  IMPORT
    (* PROC *)      BigTimeToCalendarTime;

FROM   TreeObjects  IMPORT
        (* TYPE *)      ATreeNode;

FROM   WorkHours     IMPORT
        (* PROCS *)     WorkHoursToRealTime, RealTimeToWorkHours;

(*<TRACE
FROM FlexDisp IMPORT HandleToString;
FROM LStrings   IMPORT  Fill, ConcatS, ConcatLS, SetString, CtoS;
FROM TimeFormat             IMPORT
    (* TYPE *)                  AnEndDateStyle,
    (* VAR   *)                 DefaultDateFormat, DefaultDateAndTimeFormat, EndDateStyle,
    (* PROC  *)                 TimeToString, TimeAsEndDateStyle, TimeUtoS;
FROM Tracer IMPORT PrintString, EndTrace;
FROM ResTrace IMPORT ConcatTaskID;
TRACE>*)



CONST
    ModuleNumber = 3000;   (* For GetMessage, SAME AS RsrcEdit!! *)

    Height      = 13;
    Width       = 49;
    ULX         = 13;

    MAXCARDINAL = 65535;

    Copyright   = "Program Copyright (c) 1990 Symantec Corporation.";


(*  At one time there were too many fields in this form to fit in a BITSET.
    Now they will fit, but we'll leave them as is for further expansion.

    NAM = 0;  (* Name *)
    FNM = 1;  (* Full Name *)
    KEY = 2;  (* Keyword *)
    NTS = 3;  (* Notes *)
    RCC = 4;  (* Resource or Cost Category *)
    CAL = 5;  (* Calendar *)
    VAV = 6;  (* Vary Availability *)
    VRA = 7;  (* Vary Cost Rate *)
    EXC = 8;  (* Exclude from leveling *)
    NAV = 9;  (* Normal Avail *)
    NAP = 10; (* Normal Avail Percent *)
    OVM = 11; (* Overtime multiplier *)
*)


TYPE
    AResourceField    = (NAM,FNM,KEY,NTS,RCC,CAL,VAV,VRA,EXC,NAV,NAP);
    AResourceFieldSet = SET OF AResourceField;
    AResourceCost     = REAL;

    AKeywordContext = RECORD
        Availability    : AnAvailabilityRate;
        StartDate       : ABigTime;
        Cost            : AResourceCost;
        ResourceName    : ARRAY [0..ResourceNameLength] OF CHAR;
        ResourceUnits   : ARRAY [0..10] OF CHAR;
    END;



CONST
    LastField       = NAP;
    StringFields    = AResourceFieldSet{NAM,FNM,NTS,KEY,CAL,VAV,VRA};
    MaxStringFields = 7; (* Number of the bits above *)

        (* These are the field IDs for the new variable assignment
           and cost forms *)

    AVDATE = 0;
    AVNUM  = 1;
    AVPCT  = 2;

    CSTDATE = 0;
    CSTRATE = 1;
    CSTUTIM = 2;
    CSTUMES = 3;


VAR
    ResourceBeingEdited   : AResourcePointer;
    NotesBeingEdited      : AText;
    OverlayID             : AnOverlayID;
    NeedsRecalc,
    NeedsSort,
    ResourceInUse,
    NeedToWarnAboutDefaultAvail : BOOLEAN;

    (* Get these off the overburdened stack. 1-Aug-90 RSC. *)

    ResourceFormValue     : ARRAY [0..ORD(LastField)]  OF AFieldValue;
    ResourceStringValues  : ARRAY [1..MaxStringFields] OF AStringValue;


    (*<TRACE
    TraceS : ARRAY [0..100] OF CHAR;
    TraceS2 : ARRAY [0..51] OF CHAR;
    TRACE>*)






PROCEDURE CopyNotesToText(VAR Notes         : ARRAY OF CHAR;
                          VAR Text          : AText);

VAR
    s                       : ARRAY [0..80] OF CHAR;

BEGIN                       (* CopyNotesToText *)

    TrimRear(Notes);
    IF NOT TextExists(Text) AND 
       (ORD(Notes[0]) > 0) THEN
        Text := CreateText();
    END;
    IF TextExists(Text) THEN
        IF NOT AssignLine(Notes, 0, Text) THEN
            GetMessage(ModuleNumber + 10, s);    (* Can't copy resource notes.  Are you out of memory? *)
            Error(s);
        END;
    END;
    Compress(Text);

END CopyNotesToText;



















(* Provide keywords for various strings.

    Preconditions:

        Context points to AKeywordContext, which has been filled in.

        This is being called from within the "MakeSubstitutions" proc,
        and obeys its conditions and rules.

    Keywords:

        D   Format the StartDate field.
        C   Format the Cost      field.
        N   Format the Amount    field.
        P   Format the Percent   field.
        R   Format the Name      field.
        U   Format the Units     field.
*)
PROCEDURE GetKeywords( VAR Keyword  : ARRAY OF CHAR;
                       VAR KeyValue : ARRAY OF CHAR;
                           Context  : ADDRESS );
VAR
    TimeInfo        : ATimeInfo;
    MyContext       : POINTER TO AKeywordContext;
BEGIN

    MyContext := Context;

    CASE CAP(Keyword[1]) OF
        "D" :

            BigTimeToTimeInfo (MyContext^.StartDate, TimeInfo);
            TimeToString (TimeInfo, DefaultDateFormat, KeyValue);


      | "P" :

            CtoS (MyContext^.Availability.Percent, KeyValue);
            Procustes( KeyValue, 3 );
            RJust( KeyValue );


      | "N" :

            CtoS (MyContext^.Availability.Amount, KeyValue);
            Procustes( KeyValue, 3 );
            RJust( KeyValue );

      | "C" :

            FormatAsCurrency(MyContext^.Cost, DefaultCurrencyFormat,
                             KeyValue, 15, TRUE, TRUE, TRUE );

      | "R" :

            Copy( MyContext^.ResourceName, KeyValue );

      | "U" :

            Copy( MyContext^.ResourceUnits, KeyValue );
    ELSE
    END;

END GetKeywords;










PROCEDURE CheckCostForm (     Form          : AForm;
                              FieldNo       : AFieldNo;
                          VAR FormValue     : ARRAY OF AFieldValue;
                              CheckReason   : ACheckReason;
                          VAR Code          : CARDINAL  ) : BOOLEAN;

VAR
    TimeInfo    : ATimeInfo;
    ok          : BOOLEAN;

BEGIN
    Code := 0;  (* For safety on return. *)
    ok   := TRUE;

    IF (CheckReason = CheckFormEntry)      AND
       (FieldNo     = 0)                   THEN

            (* If not the first entry, or not a resource/var cost,
               don't allow changes to the unit-of-time field.
            *)
        IF (FormValue[CSTDATE].CardValue   <> ORD(TRUE))       OR
           (ResourceBeingEdited^.CostStyle <> CAmountRateTime) THEN
            SetFieldProtection(Form, CSTUTIM, FormValue, TRUE);
            SetFieldHidden(    Form, CSTUTIM, FormValue, (ResourceBeingEdited^.CostStyle <> CAmountRateTime));
        END;

            (* If not the first entry, or not a unit cost,
               don't allow changes to the units string field.
            *)
        IF (FormValue[CSTDATE].CardValue   <> ORD(TRUE))   OR
           (ResourceBeingEdited^.CostStyle <> CAmountRate) THEN
            SetFieldProtection(Form, CSTUMES, FormValue, TRUE);
            SetFieldHidden(    Form, CSTUMES, FormValue, (ResourceBeingEdited^.CostStyle <> CAmountRate));
        END;

        IF (FormValue[CSTDATE].CardValue = ORD(TRUE)) THEN
            SetFieldProtection (Form,FieldNo,FormValue,TRUE);
        END;

    ELSIF (CheckReason = CheckFieldChange) AND
          (FieldNo     = CSTDATE)          THEN
        WITH FormValue[FieldNo] DO
            LJust(CharValue^);
            TrimRear(CharValue^);
            ok := StoD(CharValue^,TimeInfo);
            IF (ok) THEN
                TimeToString(TimeInfo, DefaultDateFormat, CharValue^);
            END;
            ShowValue(Form,FieldNo,FormValue);
        END;
    END;

    RETURN ok;

END CheckCostForm;






PROCEDURE CostToDisplay(     Cost : AResourceCost) : REAL;
BEGIN
    WITH ResourceBeingEdited^ DO
        IF (CostStyle = CAmountRateTime) THEN
            Cost := RealTimeToWorkHours( Cost, Units );
        END;
    END;

    RETURN Cost;

END CostToDisplay;







PROCEDURE EditCostData ( VAR StartDate      : ABigTime;
                         VAR Cost           : AResourceCost;
                             FirstElement   : BOOLEAN     )
                                                        : BOOLEAN;
VAR
    Code                    : ACode;
    TimeInfo                : ATimeInfo;
    Context                 : AKeywordContext;
    FormValue               : ARRAY [0..3] OF AFieldValue;
    CostUnits,
    DateString              : ARRAY [0..79] OF CHAR;
    ok                      : BOOLEAN;

BEGIN
    FormValue[CSTDATE].CharValue  := ADR(DateString);
    FormValue[CSTDATE].CardValue  := ORD(FirstElement);
    IF (FirstElement) THEN
        GetMessage( ModuleNumber + 25, DateString ); (* "<Start>" *)
    ELSE
        BigTimeToTimeInfo (StartDate, TimeInfo);
        TimeToString(TimeInfo, DefaultDateFormat, DateString);
    END;

    FormValue[CSTRATE].RealValue := CostToDisplay(Cost);

    WITH ResourceBeingEdited^ DO
        FormValue[ORD(CSTUTIM)].CardValue := ORD(Units);
        FormValue[CSTUMES].CharValue      := ADR(CostUnits);    (* 6-Nov-90 RSC *)
        Copy(UnitOfMeasure, FormValue[ORD(CSTUMES)].CharValue^);
    END;

    Code := DoForm(7,0,MaxColumn-10,GanttWEnd-7,36,TRUE,FormValue,CheckCostForm);

    IF (Code = ExitKey) THEN
        IF (FirstElement) THEN
            StartDate := MINBIGTIME;
        ELSE
            ok := StoD (FormValue[CSTDATE].CharValue^, TimeInfo);
            TimeInfo.tiHour   := 0; (* 13-Nov-90 RSC zero these out! *)
            TimeInfo.tiMinute := 0;
            TimeInfo.tiSecond := 0;
            TimeInfoToBigTime (TimeInfo, StartDate);
        END;


        WITH ResourceBeingEdited^ DO
            Units := VAL(ADurationUnit,FormValue[ORD(CSTUTIM)].CardValue);
            Copy (FormValue[ORD(CSTUMES)].CharValue^, UnitOfMeasure);
            Cost := FormValue[CSTRATE].RealValue;   (* 13-Nov-90 RSC *)
            IF (CostStyle = CAmountRateTime) THEN
                Cost := WorkHoursToRealTime( Cost, Units );
            END;              
        END;              

    END;

    RETURN (Code = ExitKey);

END EditCostData;






PROCEDURE CostDisplay(      DateList :  ADateList;
                            Element  :  ADateListIndex;
                        VAR Display  :  ARRAY OF CHAR );
VAR
    ThruDate        : ABigTime;
    Context         : AKeywordContext;
BEGIN
    WITH Context DO
        IF (NOT GetDateListEntry( DateList, Element,
                                  StartDate, ThruDate,
                                  Cost )) THEN
            FatalError();
        END;

        Cost := CostToDisplay(Cost);
    END;

    IF (Element = 1) THEN
        GetMessage( ModuleNumber + 32, Display ); (* "<Start>  : *C*" *)
    ELSE
        GetMessage( ModuleNumber + 33, Display ); (* "*D     * : *C*" *)
    END;

    MakeSubstitutions( Display, HIGH(Display),
                       GetKeywords, ADR(Context) );

END CostDisplay;






PROCEDURE SetDateListCursor(     DateList   : ADateList;
                                 StartDate  : ABigTime;
                                 DataSize   : CARDINAL  ) : ADateListIndex;
VAR
    N               : ADateListIndex;
BEGIN

    LocateDateInDateList (DateList, StartDate, DataSize, N);

    IF (N = 0) THEN
        N := 1;
    END;

    RETURN N;

END SetDateListCursor;






(* If adjacent nodes share the same cost, then collapse them
    into one node.
*)

PROCEDURE CollapseAdjacentCostNodes(VAR DateList    : ADateList; 
                                        N           : ADateListIndex;
                                        Cost        : AResourceCost );
VAR
    TempStart,
    TempThru    : ABigTime;
    TempCost    : AResourceCost;
BEGIN

        (* If the NEXT node is the same, delete it.
        *)
    IF (GetDateListEntry(DateList, N+1, TempStart, TempThru, TempCost)) AND
        (TempCost = Cost) THEN
        DisposeDateListEntry (DateList, TSIZE(AResourceCost), N+1);
    END;

        (* If the PRIOR node is the same, delete the Nth node, so the
            PRIOR will last longer ( PRIOR->N->NEXT ===> PRIOR--->NEXT )
        *)
    IF (N > 1) AND
        (GetDateListEntry(DateList, N-1, TempStart, TempThru, TempCost)) AND
        (TempCost = Cost) THEN
        DisposeDateListEntry (DateList, TSIZE(AResourceCost), N );
    END;

END CollapseAdjacentCostNodes;





PROCEDURE CostEdit( VAR DateList :    ADateList;
                    VAR Element  :    ADateListIndex;
                        Edit     :    BOOLEAN         ) : BOOLEAN;
VAR
    TempStart,
    TempThru,
    StartDate,
    ThruDate        : ABigTime;
    Date            : ADate;
    TimeInfo        : ATimeInfo;
    N               : ADateListIndex;
    TempCost,
    Cost            : AResourceCost;
    s               : ARRAY[0..255] OF CHAR;
    ok              : BOOLEAN;


BEGIN
    IF (NOT GetDateListEntry( DateList, Element, StartDate, ThruDate, Cost )) THEN
        FatalError();
    END;

    IF (Edit) THEN      (* edit an existing one *)

        ok := EditCostData(StartDate, Cost, (Element = 1));
        IF (ok) THEN
            DisposeDateListEntry (DateList, TSIZE(AResourceCost),
                                  Element);
            N := CreateDateListEntry (DateList, StartDate, Cost);
            CollapseAdjacentCostNodes(DateList, N, Cost);
        END;

    ELSE
        IF (Element = 1) THEN
            TimeUtoT(AsOfDate, TimeInfo);
            TimeInfo.tiHour   := 0; (* 13-Nov-90 RSC zero these out! *)
            TimeInfo.tiMinute := 0;
            TimeInfo.tiSecond := 0;
            TimeInfoToBigTime (TimeInfo, StartDate);
        END;

        ok := EditCostData (StartDate, Cost, FALSE);
        IF (ok) THEN
                (* Before we add this to the list, first make sure there
                   isn't an existing entry with this date.  If there is,
                   delete the existing one first. *)

            LocateDateInDateList (DateList, StartDate,
                                  TSIZE(AResourceCost), N);
            IF (N > 0) THEN
                IF (NOT GetDateListEntry (DateList, N, TempStart, TempThru,
                                          TempCost)) THEN
                    FatalError();
                END;
                IF (CompareBigTimes (StartDate, TempStart) = 0) THEN
                    DisposeDateListEntry (DateList,
                                          TSIZE(AResourceCost), N);
                END;
            END;
            N := CreateDateListEntry (DateList, StartDate, Cost);
            IF (N = 0) THEN             (* 10-Jul-91 PFG *)
                GetMessage(ModuleNumber + 37, s);
                Error(s);
                ok := FALSE;
            ELSE
                CollapseAdjacentCostNodes(DateList, N, Cost);
            END;
        END;
    END;

    Element := SetDateListCursor(DateList, StartDate, TSIZE(AResourceCost));   (* 4-Sep-90 RSC  *)

    RETURN ok;

END CostEdit;




PROCEDURE CostDelete(       DateList   : ADateList;
                        VAR Element    : ADateListIndex;
                        VAR WasDeleted : BOOLEAN ) : BOOLEAN;

VAR
    StartDate,
    ThruDate        : ABigTime;
    Cost            : AResourceCost;
    CanDelete       : BOOLEAN;

BEGIN

    CanDelete := (Element <> 1);      (*  Can't delete first entry.  *)

    IF (CanDelete) THEN

        IF (NOT GetDateListEntry( DateList, Element, StartDate, ThruDate, Cost )) THEN
            FatalError();
        END;

        DisposeDateListEntry (DateList,
                                TSIZE(AResourceCost), Element);

        (*  Back up to previous entry and see if it is identical to the entry 
            that now follows it.  If they are identical, collapse them into 
            one.  *)

        DEC(Element);

        IF (NOT GetDateListEntry( DateList, Element, StartDate, ThruDate, Cost )) THEN
            FatalError();
        END;

        CollapseAdjacentCostNodes(DateList, Element, Cost);

        WasDeleted := TRUE;     (*  Delete already taken care of  *)

    END;

    RETURN (CanDelete);

END CostDelete;





PROCEDURE CheckAvailForm (    Form          : AForm;
                              FieldNo       : AFieldNo;
                          VAR FormValue     : ARRAY OF AFieldValue;
                              CheckReason   : ACheckReason;
                          VAR Code          : CARDINAL  ) : BOOLEAN;
VAR
    TimeInfo    : ATimeInfo;
    ok          : BOOLEAN;

BEGIN
    Code := 0;  (* For safety on return. *)

    CASE FieldNo OF

    |   AVDATE :

            IF (CheckReason = CheckFormEntry) THEN
                IF (FormValue[AVDATE].CardValue = ORD(TRUE)) THEN
                    SetFieldProtection (Form,FieldNo,FormValue,TRUE);
                END;
            END;

            IF (CheckReason = CheckFieldChange) THEN
                WITH FormValue[FieldNo] DO
                    LJust(CharValue^);
                    TrimRear(CharValue^);
                    ok := StoD(CharValue^,TimeInfo);
                    IF (ok) THEN
                        TimeToString(TimeInfo, DefaultDateFormat, CharValue^);
                    END;
                    ShowValue(Form,FieldNo,FormValue);
                END;
                RETURN ok;
            END;

    |   AVNUM :

            IF (CheckReason = CheckFieldChange) THEN

                WITH FormValue[AVNUM] DO

                    IF (CardValue > 650) THEN
                        CardValue := 650;
                        ShowValue( Form, AVNUM, FormValue );
                        Burp();
                    END;

                    IF ((MAXCARDINAL DIV FormValue[AVPCT].CardValue) < CardValue) THEN
                        FormValue[AVPCT].CardValue := MAXCARDINAL DIV CardValue;
                        ShowValue( Form, AVPCT, FormValue );
                        Burp();
                    END;
                END;
            END;

    |   AVPCT :

            IF (CheckReason = CheckFieldChange) THEN
                WITH FormValue[AVPCT] DO
                    IF (CardValue = 0) THEN (* 9-Jan-91 *)
                        CardValue := 1;
                        ShowValue( Form, AVPCT, FormValue );
                        Burp();
                    END;

                    IF (CardValue > 250) THEN
                        CardValue := 250;
                        ShowValue( Form, AVPCT, FormValue );
                        Burp();
                    END;

                    IF (FormValue[AVNUM].CardValue <> 0) THEN (* 31-Jan-91 TGS *)
                        IF ((MAXCARDINAL DIV FormValue[AVNUM].CardValue) < CardValue) THEN
                            CardValue := MAXCARDINAL DIV FormValue[AVNUM].CardValue;
                            ShowValue( Form, AVPCT, FormValue );
                            Burp();
                        END;
                    END;
                END;
            END;

    ELSE
    END;

    RETURN TRUE;

END CheckAvailForm;




PROCEDURE EditAvailability ( VAR StartDate      : ABigTime;
                             VAR Availability   : AnAvailabilityRate;
                                 FirstItem      : BOOLEAN  )
                                                        : BOOLEAN;
VAR
    Code                    : ACode;
    FormValue               : ARRAY [0..3] OF AFieldValue;
    Strings                 : ARRAY [0..1] OF AStringValue;
    TimeInfo                : ATimeInfo;
    Context                 : AKeywordContext;
    ok                      : BOOLEAN;
BEGIN
    FormValue[AVDATE].CharValue := ADR(Strings[1]);
    FormValue[AVDATE].CardValue := ORD(FirstItem);
    IF (FirstItem) THEN
        GetMessage( ModuleNumber + 25, Strings[1] ); (* "<Start>" *)
    ELSE
        BigTimeToTimeInfo (StartDate, TimeInfo);
        TimeToString(TimeInfo, DefaultDateFormat, Strings[1]);
    END;

    FormValue[AVNUM].CardValue := Availability.Amount;
    FormValue[AVPCT].CardValue := Availability.Percent;

    Code := DoForm(7,0,MaxColumn-10,GanttWEnd-7,35,TRUE,FormValue,CheckAvailForm);

    IF (Code = ExitKey) THEN
        IF (FirstItem) THEN
            StartDate := MINBIGTIME;
        ELSE
            ok := StoD (FormValue[AVDATE].CharValue^, TimeInfo);
            TimeInfo.tiHour   := 0; (* 13-Nov-90 RSC zero these out! *)
            TimeInfo.tiMinute := 0;
            TimeInfo.tiSecond := 0;
            TimeInfoToBigTime (TimeInfo, StartDate);
        END;
        Availability.Amount  := FormValue[AVNUM].CardValue;
        Availability.Percent := FormValue[AVPCT].CardValue;
    END;

    RETURN (Code = ExitKey);

END EditAvailability;











PROCEDURE AvailDisplay(     DateList :  ADateList;
                            Element  :  ADateListIndex;
                        VAR Display  :  ARRAY OF CHAR );
VAR
    ThruDate        : ABigTime;
    Context         : AKeywordContext;
BEGIN
    IF (NOT GetDateListEntry( DateList, Element,
                              Context.StartDate, ThruDate,
                              Context.Availability )) THEN
        FatalError();
    END;

    IF (Element = 1) THEN
        GetMessage( ModuleNumber + 30, Display ); (* "<Start>  : *N* @ *P*%" *)
    ELSE
        GetMessage( ModuleNumber + 31, Display ); (* "*D     * : *N* @ *P*%" *)
    END;

    MakeSubstitutions( Display, HIGH(Display),
                       GetKeywords, ADR(Context) );

END AvailDisplay;






PROCEDURE AvailDelete(      DateList   : ADateList;
                        VAR Element    : ADateListIndex;
                        VAR WasDeleted : BOOLEAN ) : BOOLEAN;

VAR
    StartDate,
    ThruDate        : ABigTime;
    Availability    : AnAvailabilityRate;
    CanDelete       : BOOLEAN;

BEGIN

    CanDelete := (Element <> 1);      (*  Can't delete first entry.  *)

    IF (CanDelete) THEN

        IF (NOT GetDateListEntry( DateList, Element, StartDate, ThruDate, Availability )) THEN
            FatalError();
        END;

        DisposeDateListEntry (DateList,
                                TSIZE(AnAvailabilityRate), Element);

        (*  Back up to previous entry and see if it is identical to the entry 
            that now follows it.  If they are identical, collapse them into 
            one.  *)

        DEC(Element);

        IF (NOT GetDateListEntry( DateList, Element, StartDate, ThruDate, Availability )) THEN
            FatalError();
        END;

        CollapseAdjacentAvailNodes(DateList, Element, Availability);

        WasDeleted := TRUE;     (*  Delete already taken care of  *)

    END;

    RETURN (CanDelete);

END AvailDelete;




(*  If adjacent nodes share the same availability, then collapse them
    into one node.
*)

PROCEDURE CollapseAdjacentAvailNodes( VAR   DateList        : ADateList;
                                            N               : ADateListIndex;
                                            Availability    : AnAvailabilityRate );
VAR
    TempStart,
    TempThru    : ABigTime;
    TempAvail   : AnAvailabilityRate;

BEGIN

        (* If the NEXT node is the same, delete it.
        *)
    IF (GetDateListEntry(DateList, N+1, TempStart, TempThru, TempAvail)) AND
        (TempAvail.Amount  = Availability.Amount)  AND
        (TempAvail.Percent = Availability.Percent) THEN
        DisposeDateListEntry (DateList,
                                TSIZE(AnAvailabilityRate), N+1);
    END;

        (* If the PRIOR node is the same, delete the Nth node, so the
            PRIOR will last longer ( PRIOR->N->NEXT ===> PRIOR--->NEXT )
        *)
    IF (N > 1) AND
        (GetDateListEntry(DateList, N-1, TempStart, TempThru, TempAvail)) AND
        (TempAvail.Amount  = Availability.Amount)  AND
        (TempAvail.Percent = Availability.Percent) THEN
        DisposeDateListEntry (DateList,
                                TSIZE(AnAvailabilityRate), N);
    END;

END CollapseAdjacentAvailNodes;







PROCEDURE AvailEdit( VAR DateList :    ADateList;
                     VAR Element  :    ADateListIndex;
                         Edit     :    BOOLEAN     ) : BOOLEAN;
VAR
    StartDate,
    ThruDate        : ABigTime;
    TempStart,
    TempThru        : ABigTime;
    TimeInfo        : ATimeInfo;
    N               : ADateListIndex;
    Availability    : AnAvailabilityRate;
    TempAvail       : AnAvailabilityRate;
    s               : ARRAY[0..255] OF CHAR;
    ok              : BOOLEAN;


BEGIN
    IF (NOT GetDateListEntry( DateList, Element, StartDate, ThruDate, Availability )) THEN
        FatalError();
    END;

    IF (Edit) THEN      (* edit an existing one *)

        ok := EditAvailability (StartDate, Availability, (Element = 1));
        IF (ok) THEN
            DisposeDateListEntry (DateList, TSIZE(AnAvailabilityRate),
                                  Element);
            N := CreateDateListEntry (DateList, StartDate, Availability);
            CollapseAdjacentAvailNodes(DateList, N, Availability);
        END;

    ELSE
        IF (Element = 1) THEN
            TimeUtoT(AsOfDate, TimeInfo);
            TimeInfo.tiHour   := 0; (* 13-Nov-90 RSC zero these out! *)
            TimeInfo.tiMinute := 0;
            TimeInfo.tiSecond := 0;
            TimeInfoToBigTime (TimeInfo, StartDate);
        END;

        ok := EditAvailability (StartDate, Availability, FALSE);
        IF (ok) THEN

                (* Before we add this to the list, first make sure there
                   isn't an existing entry with this date.  If there is,
                   delete the existing one first. *)

            LocateDateInDateList (DateList, StartDate,
                                  TSIZE(AnAvailabilityRate), N);
            IF (N > 0) THEN
                IF (NOT GetDateListEntry (DateList, N, TempStart, TempThru,
                                          TempAvail)) THEN
                    FatalError();
                END;
                IF (CompareBigTimes (StartDate, TempStart) = 0) THEN
                    DisposeDateListEntry (DateList,
                                          TSIZE(AnAvailabilityRate), N);
                END;
            END;
            N := CreateDateListEntry (DateList, StartDate, Availability);
            IF (N = 0) THEN             (* 10-Jul-91 PFG *)
                GetMessage(ModuleNumber + 36, s);
                Error(s);
                ok := FALSE;
            ELSE
                CollapseAdjacentAvailNodes(DateList, N, Availability);
            END;
        END;
    END;

    Element := SetDateListCursor(DateList, StartDate, TSIZE(AnAvailabilityRate));   (* 4-Sep-90 RSC  *)

    RETURN ok;

END AvailEdit;



PROCEDURE CheckResourceForm(    Form        : AForm;
                                FieldNo     : AFieldNo;
                            VAR FormValue   : ARRAY OF AFieldValue;
                                CheckReason : ACheckReason;
                            VAR Code        : CARDINAL
                                                      ) : BOOLEAN;

CONST
    ResourceProtectedFields = AResourceFieldSet{};
    FixedProtectedFields    = AResourceFieldSet{CAL,NAV,NAP,EXC,VAV,VRA};
    UnitProtectedFields     = AResourceFieldSet{CAL,NAV,NAP,EXC,VAV};
    VarProtectedFields      = AResourceFieldSet{CAL,VAV,EXC};
    DeeperFields            = AResourceFieldSet{CAL,NTS,VAV,VRA}; (* Fields that allow CheckFieldKey. *)
    FirstProtectedField     = CAL;  (* First possible protected field *)
    LastProtectedField      = LastField; (* Last "        "       "   *)

VAR
    CodeIn    : CARDINAL;
    Node      : ATreeNode;
    Changed   : BOOLEAN;


    PROCEDURE SetProtection( TypeField : CARDINAL );
    VAR
        Loop      : AResourceField;
        Mask      : AResourceFieldSet;
        Protected : BOOLEAN;

    BEGIN
        CASE TypeField OF
           0: Mask := ResourceProtectedFields;
        |  1: Mask := FixedProtectedFields;
        |  2: Mask := UnitProtectedFields;
        |  3: Mask := VarProtectedFields;
        ELSE
            FatalError();
        END;
        FOR Loop := FirstProtectedField TO LastProtectedField DO
            Protected := (Loop IN Mask);
            SetFieldProtection(Form,ORD(Loop),FormValue,Protected);
            SetFieldHidden    (Form,ORD(Loop),FormValue,Protected);
        END;
    END SetProtection;



    PROCEDURE MessageNoYes( Offset : CARDINAL ) : BOOLEAN;
    VAR
        s   : ARRAY [0..255] OF CHAR;
    BEGIN

        GetMessage(ModuleNumber + Offset, s ); (* "Really delete the calendar?" *)
        RETURN NoYes(s);

    END MessageNoYes;



    PROCEDURE HandleCalendar() : BOOLEAN;
    VAR
        Calendar  : AResourceCalendarPointer;
        AULX      : ascreenx;
        AULY      : ascreeny;
        ALRX      : ascreenx;
        ALRY      : ascreeny;
        JunkX     : ascreenx;
        s         : ARRAY [0..40] OF CHAR;
    BEGIN
        IF (CheckReason = CheckFieldKey) THEN
            CASE CodeIn OF
              EditKey:

                MapFromResourceForm( ResourceBeingEdited, FormValue );

                HighlightField(Form,FormValue,FieldNo, CursorResting );
                IF (ResourceBeingEdited^.Calendar = NIL) THEN
                    Calendar := CreateCalendar();
                    IF (Calendar <> NIL) THEN
                        Copy( FormValue[ORD(NAM)].CharValue^,
                              Calendar^.Name );
                    END;
                ELSE
                    CopyCalendar( Calendar, ResourceBeingEdited^.Calendar );
                END;

                FindFieldXY(Form,FieldNo,MinIndex(Form,FieldNo),AULX,AULY,JunkX);
                FindFieldXY(Form,FieldNo,MaxIndex(Form,FieldNo),ALRX,ALRY,JunkX);

                GetMessage(ModuleNumber + 26, s); (* "Vacation Calendar for " *)
                ConcatLS(s, ResourceBeingEdited^.Name);

                IF (Calendar <> NIL) AND
                   (ChangeResourceCalendar( Calendar^,
                                            AsOfDate,
                                            AULX-1,AULY,ALRX+1,ALRY,s )) THEN
                    IF (ResourceBeingEdited^.Calendar <> NIL) THEN  (* 7/11/90 EGK *)
                        DisposeCalendar( ResourceBeingEdited^.Calendar );
                    END;

                        (* If they removed all exceptions,
                                remove the calendar.
                        *)
                    IF (NumberOfDatesInList(Calendar^.CalendarIntervals, TSIZE(ACalendarEntry)) < 2) THEN
                        DisposeCalendar( Calendar );
                    END;
                    CopyCalendar( ResourceBeingEdited^.Calendar, Calendar );
                    NeedsRecalc := TRUE;
                ELSIF (Calendar <> NIL) THEN        (* 7/11/90 EGK *)
                    DisposeCalendar( Calendar );
                END;

                HighlightField(Form,FormValue,FieldNo, CursorOff );

            |DeleteKey, 
             EraseKey,
             EraseToEOLKey,
             AlternateEraseKey:

                IF (ResourceBeingEdited^.Calendar <> NIL) THEN   (* 7/11/90 EGK *)
                    IF (MessageNoYes( 20 )) THEN     (* "Really delete the calendar?" *)
                        DisposeCalendar(ResourceBeingEdited^.Calendar);
                        NeedsRecalc := TRUE;
                    END;
                END;

            ELSE   (* Any other code goes back to be processed as-is. *)
                Code := CodeIn + CARDINAL({14}); 
                RETURN FALSE;
            END;

            SetStar( CAL, FormValue, (ResourceBeingEdited^.Calendar <> NIL));
            ShowValue(Form, FieldNo, FormValue);
        END;

        RETURN TRUE;

    END HandleCalendar;




    PROCEDURE HandleVaryAvailability() : BOOLEAN;
    VAR
        Avail     : AnAvailabilityRate;
        BS, BT    : ABigTime;
        s         : ARRAY [0..49] OF CHAR;
    BEGIN
        IF (CheckReason = CheckFieldKey) THEN

            IF (CodeIn = EditKey) THEN

                MapFromResourceForm( ResourceBeingEdited, FormValue );

                WITH ResourceBeingEdited^ DO
                    IF (Availability  =  ADateList(NIL)) THEN
                        
                        Avail.Amount  := DefaultAvailabilityAmount;    (* 6-Nov-90 RSC Init avail. *)
                        Avail.Percent := DefaultAvailabilityPercent;

                        Availability  := CreateDateList (Avail, MINBIGTIME);
                    END;
                END;

                HighlightField(Form,FormValue,FieldNo, CursorResting );
                GetMessage(ModuleNumber + 23, s ); (* "Availability of " *)
                ConcatLS(s, ResourceBeingEdited^.Name); (* 18-Jan-91 TGS *)

                Changed := ManageDateList (ResourceBeingEdited^.Availability,
                                           TSIZE(AnAvailabilityRate),
                                           AvailDisplay, AvailEdit,
                                           AvailDelete,  s );
                WITH ResourceBeingEdited^ DO
                    IF (NumberOfDatesInList(Availability,
                                    TSIZE(AnAvailabilityRate)) = 1) AND
                       (GetDateListEntry( Availability, 1,
                                                  BS, BT, Avail ))  AND
                       (Avail.Amount  = DefaultAvailabilityAmount)  AND
                       (Avail.Percent = DefaultAvailabilityPercent) THEN
                        DisposeDateList(Availability);
                    END;
                END;
                IF (Changed) THEN
                    SetFormChange (Form);
                    NeedsRecalc := TRUE;
                END;

                HighlightField(Form,FormValue,FieldNo, CursorOff );

                    (* If the user has looked at the varying availability list,
                       presumably they understand it well enough that we don't
                       need to warn them about the distinction between it and
                       the default availabilities. *)
                NeedToWarnAboutDefaultAvail := FALSE;

            ELSIF (CodeIn = DeleteKey)     OR
                  (CodeIn = EraseKey)   OR
                  (CodeIn = EraseToEOLKey) THEN
                IF (ResourceBeingEdited^.Availability <> ADateList(NIL)) AND
                   (MessageNoYes( 21 )) THEN     (* "Really delete the var avail list?" *)
                    DisposeDateList(ResourceBeingEdited^.Availability);
                    NeedsRecalc := TRUE;
                END;
            ELSE
                Code := CodeIn + CARDINAL({14}); 
                RETURN FALSE;
            END;

            SetStar( VAV, FormValue, (ResourceBeingEdited^.Availability <> ADateList(NIL)));
            ShowValue(Form, FieldNo, FormValue);
        END;

        RETURN TRUE;

    END HandleVaryAvailability;


        (* 6-Nov-90 RSC Moved to this sub proc.
        *)
    PROCEDURE HandleVaryRate() : BOOLEAN;
    VAR
        R         : REAL;
        BS, BT    : ABigTime;
        s         : ARRAY [0..49] OF CHAR;
    BEGIN
        IF (CheckReason = CheckFieldKey) THEN
            IF (CodeIn = EditKey) THEN
                HighlightField(Form,FormValue,FieldNo, CursorResting );

                MapFromResourceForm( ResourceBeingEdited, FormValue );

                WITH ResourceBeingEdited^ DO
                    IF (ActualRates = ARateList(NIL)) THEN
                        ActualRates := CreateRateList( DefaultCostRate, 
                                                       MINBIGTIME );
                    END;
                END;

                GetMessage(ModuleNumber + 24, s ); (* "Varying Costs for " *)
                ConcatLS(s, ResourceBeingEdited^.Name); (* 18-Jan-91 TGS *)

                Changed := ManageDateList (ResourceBeingEdited^.ActualRates,
                                           TSIZE(AResourceCost),
                                           CostDisplay, CostEdit,
                                           CostDelete,  s);

                WITH ResourceBeingEdited^ DO
                    IF (NumberOfRatesInList( ActualRates ) = 1)      AND
                       (GetRateListEntry(ActualRates, 1, BS, BT, R)) AND
                       (R = DefaultCostRate) THEN
                        DisposeRateList( ActualRates );
                    END;
                END;

                IF (Changed) THEN
                    NeedsRecalc := TRUE;
                    SetFormChange (Form);
                END;

                HighlightField(Form,FormValue,FieldNo, CursorOff );

            ELSIF (CodeIn = DeleteKey)     OR
                  (CodeIn = EraseKey)      OR
                  (CodeIn = EraseToEOLKey) THEN
                IF (ResourceBeingEdited^.ActualRates <> ARateList(NIL)) AND
                   (MessageNoYes( 22 )) THEN     (* "Really delete the var cost list?" *)
                    NeedsRecalc := TRUE;
                    DisposeRateList(ResourceBeingEdited^.ActualRates);
                END;
            ELSE
                Code := CodeIn + CARDINAL({14}); 
                RETURN FALSE;
            END;
            SetStar( VRA, FormValue,
                     ResourceBeingEdited^.ActualRates <> ARateList(NIL));
            ShowValue(Form, FieldNo, FormValue);

        END;

        RETURN TRUE;

    END HandleVaryRate;


    PROCEDURE WarnOfOtherNode( Node : ATreeNode ) : BOOLEAN;
    VAR
        Resource  : AResourcePointer;
        s         : ARRAY [0..255] OF CHAR;
        ok        : BOOLEAN;
    BEGIN
        Resource := Node^.Methods^.GetDataObject (Node);
        ok := (Resource = ResourceBeingEdited);

        IF (NOT ok) THEN
            GetMessage(ModuleNumber+3,s);   (* '"' *)
            ConcatLS(s,Resource^.Name);
            ConcatMessage(s,ModuleNumber+4);  (* '" already exists.' *)
            Message(s);
        END;

        RETURN ok;

    END WarnOfOtherNode;

        (* CheckDefaultChange -- If there is no varying availability
               list, and the user has changed the default assignment,
               warn them that the default is not the same as the 
               availability.  This is a common user error. *)

    PROCEDURE CheckDefaultChange();
    BEGIN
        IF (ResourceBeingEdited^.Availability = ADateList(NIL)) AND 
           (NeedToWarnAboutDefaultAvail) THEN
            ErrorPhrase( ModuleNumber + 50 );
            NeedToWarnAboutDefaultAvail := FALSE;
        END;
    END CheckDefaultChange;


BEGIN (* CheckResourceForm *)
    CodeIn := Code;
    Code   := 0;  (* For safety on return. *)

    IF (CheckReason = CheckFormEntry) THEN 
        NeedToWarnAboutDefaultAvail := TRUE;
        IF (FieldNo = ORD(NAM))          THEN
            SetFieldProtection(Form,ORD(RCC),FormValue,ResourceInUse);
            SetProtection(      FormValue[ORD(RCC)].CardValue);
        END;
    END;

    IF (CheckReason = CheckFieldEntry) OR 
      ((CheckReason = CheckFieldExit)  AND (FieldNo <> ORD(NAM))) OR
       (CheckReason = CheckFormEntry)  OR
      ((CheckReason = CheckFormExit)   AND (FieldNo <> ORD(NAM))) THEN
        RETURN TRUE;
    END;

    IF (CheckReason = CheckFieldKey) AND 
       (NOT (VAL(AResourceField, FieldNo) IN DeeperFields)) THEN
        Code := CodeIn + CARDINAL({14}); 
        RETURN FALSE;
    END;


    CASE VAL(AResourceField, FieldNo) OF
        (* NAME FIELD *)
    | NAM: 
        WITH FormValue[ORD(NAM)] DO   
            LJust(    CharValue^);
            TrimRear( CharValue^);
            IF (CharValue^[0] = 0C) THEN
                DisplayMessage(ModuleNumber+2); (* "Please enter a name." *)
                RETURN FALSE;
            ELSE
                (* Don't allow a name change to match another resource's name. *)
                Node := FindResourceByName (CharValue^);
                IF (Node <> NIL) THEN
                    RETURN WarnOfOtherNode( Node );
                END;
            END;
        END;
        NeedsSort := TRUE;

        (* Calendar field *)
    | CAL:
        RETURN HandleCalendar();

        (* Notes field *)
    | NTS: 
        IF (CheckReason = CheckFieldKey) THEN
            IF (CodeIn = EditKey) THEN
                HighlightField(Form,FormValue,FieldNo, CursorResting );
                WITH FormValue[ORD(NTS)] DO
                    CopyNotesToText(CharValue^, NotesBeingEdited);
                    EditText(13, 3, 78, MaxRow-10,
                             ABoxType{ShadowBox, DoubleBox},
                             FormValue[0].CharValue^, ModuleNumber, 
                             NotesBeingEdited, Changed);
                    IF (Changed) THEN
                        SetFormChange( Form );
                    END;
                    IF TextExists(NotesBeingEdited) THEN
                        CopyLine(NotesBeingEdited, 0, CharValue^);
                    END;
                END;
                ShowValue(Form, ORD(NTS), FormValue);
                HighlightField(Form,FormValue,FieldNo, CursorOff );
            ELSE
                Code := CodeIn + CARDINAL({14}); 
                RETURN FALSE;
            END;
        END;

    | RCC:
        IF (CheckReason = CheckFieldChange) THEN
            SetProtection( FormValue[ORD(RCC)].CardValue );
            NeedsRecalc := TRUE;
        END;

    | NAV:
        WITH FormValue[ORD(NAV)] DO
            IF (CardValue > 650) THEN
                CardValue := 650;
                ShowValue( Form, ORD(NAV), FormValue );
            END;

            (* If total would be too big, adjust the NAP CardValue *)
            IF ((MAXCARDINAL DIV FormValue[ORD(NAP)].CardValue) < CardValue) THEN
                FormValue[ORD(NAP)].CardValue := MAXCARDINAL DIV CardValue;
                ShowValue( Form, ORD(NAP), FormValue );
            END;
        END;
        NeedsRecalc := NeedsRecalc OR (CheckReason = CheckFieldChange);
        CheckDefaultChange();

    | NAP: (* Percentage fields.  Never let the max go less than norm. *) 
        WITH FormValue[ORD(NAP)] DO
            IF (CardValue > 250) THEN
                CardValue := 250;
                ShowValue( Form, ORD(NAP), FormValue );
            END;

            IF (CardValue = 0) THEN
                CardValue := 1;
                ShowValue( Form, ORD(NAP), FormValue );
            END;

            (* If total would be too big, adjust the NAP CardValue *)
            IF (FormValue[ORD(NAV)].CardValue <> 0) THEN
                IF ((MAXCARDINAL DIV FormValue[ORD(NAV)].CardValue) < CardValue) THEN
                    CardValue := MAXCARDINAL DIV FormValue[ORD(NAV)].CardValue;
                    ShowValue( Form, ORD(NAP), FormValue );
                END;
            END;
        END;
            
        NeedsRecalc := NeedsRecalc OR (CheckReason = CheckFieldChange);
        CheckDefaultChange();

        (* Vary Availability *)
    | VAV:
        RETURN HandleVaryAvailability();


        (*  Vary Rate *)
    | VRA:
        RETURN HandleVaryRate(); (* 6-Nov-90 RSC *)

    | KEY: 
        LJust( FormValue[ ORD(KEY) ].CharValue^ );
        ShowValue( Form,  ORD(KEY), FormValue );
        NeedsSort := TRUE;

    | EXC: 
        NeedsRecalc := NeedsRecalc OR (CheckReason = CheckFieldChange);

    ELSE
    END;

    RETURN TRUE;

END CheckResourceForm;






PROCEDURE SetStar(     ResourceField  : AResourceField;
                   VAR FormValue      : ARRAY OF AFieldValue;
                       DataExists     : BOOLEAN );
BEGIN

    IF (DataExists) THEN
        SetString(FormValue[ORD(ResourceField)].CharValue^,"*");
    ELSE
        SetString(FormValue[ORD(ResourceField)].CharValue^," ");
    END;

END SetStar;






PROCEDURE MapToResourceForm( Resource : AResourcePointer;
                         VAR FormValue: ARRAY OF AFieldValue );

BEGIN
    WITH Resource^ DO
        SubStr(Name,FormValue[ORD(NAM)].CharValue^,1,HIGH(Name));
        SubStr(LongName,FormValue[ORD(FNM)].CharValue^,1,HIGH(LongName));
        Copy( Keyword, FormValue[ORD(KEY)].CharValue^ );

        IF TextExists(Resource^.Notes) THEN
            CopyLine(Resource^.Notes, 0, FormValue[ORD(NTS)].CharValue^);
        ELSE
            FormValue[ORD(NTS)].CharValue^[0] := 0C;
        END;

        SetStar( CAL, FormValue, (Calendar     <> NIL));
        SetStar( VAV, FormValue, (Availability <> ADateList(NIL)));
        SetStar( VRA, FormValue, (ActualRates  <> ARateList(NIL)));
                                (* 21-Jun-91 PFG removed this:
                                        AND
                                 (NumberOfRatesInList(ActualRates) > 1));
                                *)

        WITH FormValue[ORD(RCC)] DO

            CASE CostStyle OF
                CAmount         : CardValue := 1;     (* Fixed Cost *)
              | CAmountRate     : CardValue := 2;     (* Unit Cost *)
              | CAmountRateTime : IF (Type = Employable) THEN
                                      CardValue := 0; (* Resource *)
                                  ELSE
                                      CardValue := 3; (* Var cost *)
                                  END;
            ELSE
                FatalError();
            END;
        END;

        FormValue[ORD(EXC)].CardValue := ORD(LevelThisResource);     (* 20-Nov-87 LAA *)
        FormValue[ORD(NAV)].CardValue := TRUNC((Limit / FLOAT(Percent)) + 0.1);
        FormValue[ORD(NAP)].CardValue := Percent;
       
     END;

END MapToResourceForm;





PROCEDURE MapFromResourceForm( Resource  : AResourcePointer;
                           VAR FormValue : ARRAY OF AFieldValue );
VAR StartDate : ABigTime;
    s         : AStringValue;

BEGIN
    WITH Resource^ DO

        LJust(FormValue[ORD(NAM)].CharValue^);
        Copy( FormValue[ORD(NAM)].CharValue^, Name );
        TrimRear(Name);

        LJust(FormValue[ORD(FNM)].CharValue^);
        Copy( FormValue[ORD(FNM)].CharValue^, LongName );
        TrimRear(LongName);

        LJust(FormValue[ORD(KEY)].CharValue^);
        Copy( FormValue[ORD(KEY)].CharValue^, Keyword );
        TrimRear(Keyword);

        Copy(FormValue[ORD(NTS)].CharValue^,s);
        TrimFront(s);
        TrimRear(s);
        IF (s[0] = 0C) THEN
            DiscardText( NotesBeingEdited ); (* Get rid of dem dere notes. *)
            NotesBeingEdited := AText(NIL);
        ELSE
            CopyNotesToText(FormValue[ORD(NTS)].CharValue^, NotesBeingEdited);
        END;
        
        Type  := AccountingOnly; (* Default *)

        CASE FormValue[ORD(RCC)].CardValue OF
           0 : CostStyle := CAmountRateTime;        (* Resource *)
               Type      := Employable;
               GetMessage(ModuleNumber + 12 + ORD(Units), UnitOfMeasure); (* "Hours" *)

         | 1 : CostStyle := CAmount;                (* Fixed Cost *)
               GetMessage(ModuleNumber + 11, UnitOfMeasure); (* "Bucks" *)

         | 2 : CostStyle := CAmountRate;            (* Unit Cost *)

         | 3 : CostStyle := CAmountRateTime;        (* Variable Cost *)
               GetMessage(ModuleNumber + 12 + ORD(Units), UnitOfMeasure); (* "Hours" *)

        ELSE
            FatalError();
        END;

        Percent      := FormValue[ORD(NAP)].CardValue;
        Limit        := FLOAT(FormValue[ORD(NAV)].CardValue) * FLOAT(Percent);
        LevelThisResource := (FormValue[ORD(EXC)].CardValue <> 0);   (* 20-Nov-87 LAA *)
        IF (Type <> Employable) THEN
            LevelThisResource := FALSE;
        END;

        OvertimeMultiplier := 0.0; (* 16-May-91 TGS *)

    END;
END MapFromResourceForm;







PROCEDURE DoResourceForm();


VAR
    Resource                : AResourcePointer;
    Loop, i                 : CARDINAL;
    Code                    : ACode;
    ResourceFormLink        : POINTER TO AResourceFormLink;

BEGIN
    ResourceFormLink := OverlayContext();
    Resource         := ResourceFormLink^.Resource;
    NeedsRecalc      := FALSE;
    NeedsSort        := FALSE; (* DSL 9/26/90 *)

        (* Reference copyright so the optimizer doesn't remove it *)

    SetString(ResourceStringValues[1], Copyright);

    i := 0;
    FOR Loop := 0 TO ORD(LastField) DO                          (* 20-Nov-87 LAA *)
        IF (VAL(AResourceField,Loop) IN StringFields) THEN
            INC(i);
            ResourceFormValue[ Loop ].CharValue := ADR(ResourceStringValues[ i ]);
        ELSE
            ResourceFormValue[ Loop ].CharValue := NIL;
        END;
    END;
    (* DEBUG: *) IF (i > HIGH(ResourceStringValues)) THEN FatalError(); END;

    IF (NOT AssignText (Resource^.Notes, NotesBeingEdited)) THEN END;
    MapToResourceForm( Resource, ResourceFormValue );

    ResourceBeingEdited := Resource;
    ResourceInUse       := (Resource^.WorkSpace <> NIL); (* set by caller *)

    Code := DoForm(0,0,MaxColumn,GanttWEnd,15,TRUE,ResourceFormValue,CheckResourceForm);

    IF (Code = ExitKey) THEN
        MapFromResourceForm( Resource, ResourceFormValue );
        
            (* 14-Sep-91/15-Sep-91 TGS garbage disposal.. *)
        WITH Resource^ DO
            IF (Type <> Employable) THEN
                    (* dispose of vacation and availability lists *)
                IF (Calendar <> NIL) THEN
                    DisposeCalendar( Calendar );
                END;
                IF (BaselineCalendar <> NIL) THEN
                    DisposeCalendar( BaselineCalendar );
                END;
                IF (Availability <> ADateList(NIL)) THEN
                    DisposeDateList( Availability );
                END;
                IF (BaselineAvailability <> ADateList(NIL)) THEN
                    DisposeDateList( BaselineAvailability );
                END;

                IF (CostStyle = CAmount) THEN
                        (* also dispose of varying rate list *)
                    IF (ActualRates <> ARateList(NIL)) THEN
                        DisposeRateList( ActualRates );
                    END;
                    IF (BaseLineRates <> ARateList(NIL)) THEN
                        DisposeRateList( BaseLineRates );
                    END;
                END;
            END;
        END;

        IF (ADDRESS(Resource^.Notes) <> NIL) THEN
            DiscardText( Resource^.Notes ); (* Get rid of old notes. *)
        END;
        IF (ADDRESS(NotesBeingEdited) <> NIL) AND
           (AssignText (NotesBeingEdited, Resource^.Notes)) THEN
        END;
        IF (NeedsRecalc) THEN   (* 21-Sep-89 RSC *)
            UnSetState(Scheduled);                     (* LAA 11/04/86 *)
        END;
        IF (NeedsSort) THEN            (* DSL 9/26/90 *)
            (*<TRACE
            SetString(TraceS,"If needs sort");  
            PrintString(TraceS);
            TRACE>*)

            UnSetState (Sorted);
            UnSetState (Filtered);
            ScheduleSaved := FALSE;
        END;

        (* 8-Nov-89 RSC added this to refresh the columns: *)
        GanttChart^.Methods^.NoteSpecificChange(GanttChart, SubviewsChange);
    END;
    IF (ADDRESS(NotesBeingEdited) <> NIL)  THEN
        DiscardText( NotesBeingEdited ); (* Get rid of dem dere notes. *)
    END;

    ResourceFormLink^.Code := Code;

END DoResourceForm;






BEGIN

    OverlayID := ImAnInstallableOverlay(DoResourceForm, AnOverlayProc(NIL));     (* 19-Jan-88 LAA *)
    DoResourceForm();

END TLRsrc.


