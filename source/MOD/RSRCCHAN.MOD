IMPLEMENTATION MODULE RsrcChange;


    (*
        Rsrc Change - Edit a resource record

            This module provides the ability to make changes to a resource
            record by changing "columns" of data.  It deals with the same
            columns as are output by the "Captions" module.  For this reason,
            this module and its cousins are sometimes refered to as
            "AntiCaptions".


        Terminology:

            For this module, we view the Rsrc Tree as if it were a giant TABLE
            of records, where each resource is a ROW in the table.  Each FIELD
            in a resource record is a COLUMN in the table.

            A Column HEADING is the formal name a column goes by.  This is the
            name found in a Lotus, DBase, or CSV file.  This heading is
            translated into a ColumnID, a "magic number" used to identify the
            column.  Note that some exporters, notably DBase, may translate
            the official formal name into a new name that is more compatible
            with the external program.  It is the importer's job to translate
            those names BACK into the "official" formal name.


        Procedure Overview:

            GetRsrcColumnID()   Given a column's formal name, return the
                                internal Column ID.

            BeginRsrcEdit()     Start the editing of a resource.

            DigestRsrcString()  Change a text string into an internal format.

            ChangeRsrcColumn()  Change the value of a column.

            EndRsrcEdit()       End the editing of a resource, and commit the
                                changes if there were no serious errors.


        Handling Errors:

            There is a client-supplied error handler, which is called whenever
            an error is detected.  Errors come in different severities and
            types, and the error handler is responsible for logging the errors
            and deciding the TRUE severity of the error (for example, you may
            want to ignore some warning errors).


        Undo:

            This module does not use Undo.  It is the job of clients to
            back out records deemed not valid.


        Related Modules:

            RsrcAcquire  is used to find the resource record to be edited.
            TaskEdit     edits task records.
            AssEdit      edits assignment records.
            EdgeEdit     edits edge records.


        Modification History:


         9-Feb-89  RSC  First version.
        27-Jul-89  MWP  Added parsing of unit amount for Unit Cost resources.
        31-Aug-89  LAA  Added a parameter to ParseAmountToReal.
        10-Sep-89  MWP  Changed reading of percent values to read true
                        percentage format.
        11-Sep-89  MWP  Added ability to import BaselineRates.
        12-Sep-89  MWP  Added better tracking of Limits and Percents for
                        resource records.
        26-Sep-89  MWP  Call SetResourceRate in Rsrcmod. Added better
                        reconciliation of resource limits and percents.
        27-Sep-89  MWP  If a resource type is not recognized, leave Resource
                        type set to Resource.
        27-Sep-89  MWP  If we truncate a string, warn the user.
         2-Oct-89  MWP  If the resource type is not recognized, set to Resource
                        and continue import of record.
         3-Oct-89  MWP  Fixed improper setting of resource rate values.
         3-Oct-89  MWP  For fixed resource types, we must still set the
                        resource rate, otherwise no costs will ever be
                        calculated for these resources.
        20-Oct-89  MWP  Allow for message support for changing baseline
                        data.
        30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.
        17-Oct-90 AJL   Added RsrcSeqNumColumn.
        20-Oct-90 RSC   Corrected syntax errors and removed
                        "NotYetImplemented" from AJL's changes of 17-Oct.
                        Also removed all other NotYetImplemented's for
                        setting rates.
         4-Feb-91 TGS   Read Pct/Amt columns into varying availability list, 
                        not the new defunct UpperLimit/UpperPercent fields.
        11-Jul-91 TGS   Use the Rate, Availability, and Calendar booleans for
                        import (if FALSE, get rid of the associated date/rate
                        list, if TRUE, leave 'em alone).
        16-Sep-91 TGS   Wow, when we were adjusting leveling limits/percents,
                        we were checking the ">" instead of "<". That'll
                        cause problems!
    *)

FROM BigTimeU       IMPORT
    (* TYPE *)              ABigTime,
    (* VAR  *)              MINBIGTIME;

FROM Captions       IMPORT
    (* TYPE *)              AColumnDataRecord, AColumnInfoChoice,
                            AColumnDataField,  ASetOfColumnDataFields,
    (* PROC *)              GetColumnInfo;

FROM DateLists  IMPORT
    (* TYPE *)      ADateList, ADateListIndex,
    (* PROC *)      GetDateListEntry, CreateDateListEntry,
                    DisposeDateListEntry, SetDateListEntryN,
                    CreateDateList, DisposeDateList;

FROM Dialog         IMPORT
    (* PROC *)              FatalError, Error, NotYetImplemented;

FROM EditCommon     IMPORT
    (* TYPE *)              AGetInfoProc,
    (* PROC *)              GetAColumnID, DigestAString, AjustName,
    (* PROC *)              DigestAIntString;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorHandlerProc, AnErrorSeverity, AKindOfError;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle,            AnExtStoragePreference,
    (* PROC *)              CreateExtObject,        SetExtData,
                            DiscardExtObject,       CopyExtObject,
                            LockObject,             ReleaseUnchangedObject,
                            ReleaseObject;

FROM ImPorTable     IMPORT
    (* TYPE *)              AImportTable, AnAskAlterBaselineProc;

FROM IntFileIO      IMPORT
                            AnIntDataRecord;

FROM LStrings       IMPORT
    (* PROCS *)             TrimFront,    TrimRear,  Copy,     SetLengthOf,
                            StringsEqual, LengthOf, Upshift,
                            SubStr,       Search;

FROM   MagicNum     IMPORT
    (* TYPES *)             RsrcModuleNumber,      RsrcName,
                            RsrcFullName,          RsrcKeyword,
                            RsrcNotes,             RsrcType,
                            RsrcDefaultPercent,    RsrcLevelingLimit,
                            RsrcLevelingPercent,   RsrcRate,
                            RsrcUnitCost,          RsrcDefaultLimit,
                            RsrcUnitOfMeasure,     RsrcBaselineRate,
                            RsrcLevelingPermitted, RsrcSeqNumColumn,

                            (* 7-May-91 TGS *)
                            RsrcVacationCalExists,  RsrcBslnVacationCalExists,
                            RsrcVaryingRatesExist,  RsrcBslnVaryingRatesExist,
                            RsrcVaryingAvailsExist, RsrcBslnVaryingAvailsExist,

                            RsrcLastColumn;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage;

FROM ParseReal      IMPORT
    (* PROC *)              ParseAmountToReal;

FROM RateLists      IMPORT
    (* TYPE *)              ARateList,
    (* PROC *)              CreateRateList, DisposeRateList,
                            GetRateListEntry, SetRateListEntryN,
                            DisposeRateListEntry;

FROM RealFormat     IMPORT
    (* TYPE *)              AnAmountFormat,
    (* VAR *)               DefaultAmountFormat;

FROM ResCalUI       IMPORT 
    (* PROC *)          DisposeCalendar,
    (* TYPE *)          AnAvailabilityRate;

FROM RptCommon      IMPORT
                            GetMessageWord;

FROM RsrcFormat     IMPORT
    (* PROCS *)             GetRsrcInfo;

FROM RsrcMod        IMPORT
    (* CONST *)         DefaultCostRate, DefaultAvailabilityAmount,
                        DefaultAvailabilityPercent,
    (* TYPES *)         ResourceNameLength, AResourcePointer,
                        ResourceTree,
                        AResourceType,      ACostStyle,
    (* PROCS *)         CreateResource,     ChangedResource,
                        FindResourceByName, AddResource,
                        AverageResourceRate,
                        FindResourceByNumber;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR, TSIZE;

FROM Text           IMPORT
    (* TYPE *)              AText,
    (* PROCS *)             TextExists, CreateText, AssignLine, Compress,
                            CopyLine,   DiscardText;

FROM Timei          IMPORT
                            ADurationUnit, MaxDate, MinDate;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode;

FROM Words          IMPORT
                            FindNextWord;
FROM   WorkHours     IMPORT
        (* PROCS *)     WorkHoursToRealTime;

CONST
    RsrcNameLen             = 10;
    LongNameLen             = 32;
    KeyNameLen              = 10;
    UnitOfMeasureLen        = 10;
    OneHundred              = 100.0;
    Zero                    = 0.0;
    One                     = 1.0;
    MAXCARDINAL             = 65535;

TYPE
    AGlobalContext          = RECORD
                                 RsrcNode          : ATreeNode;
                                 ContextReady      : BOOLEAN;
                                 EditError         : BOOLEAN;
                                 StateInfo         : ARsrcEditContext;
                                 AlterBaseline     : AnAskAlterBaselineProc;
                                 PImportTable      : POINTER TO AImportTable;
                              END;

VAR
    GlobalContext           : AGlobalContext;

    NilString               : ARRAY [0..1] OF CHAR;
    UnitsString             : ARRAY [0..99] OF CHAR;


(*
    Get Rsrc Column ID

        Preconditions
                        > "ColumnName" is an LString containing the FORMAL
                          NAME of the edge column.
                          The caller must resolve any differences between
                          the name read in from a file and the "official"
                          formal name.  For example, DBase translates some
                          charactors.

        Postconditions
                        > Returns TRUE if the ColumnName is a known resource
                          column name, or FALSE if it is unknown.

                        > ColumnID is the internal number to use for
                          changing the data, if TRUE is returned.
*)
PROCEDURE GetRsrcColumnID( VAR ColumnName       : ARRAY OF CHAR;
                           VAR ColumnID         : CARDINAL ) : BOOLEAN;
BEGIN
    RETURN GetAColumnID( AGetInfoProc(GetRsrcInfo), ColumnName, ColumnID );
END GetRsrcColumnID;


(*
    Begin Rsrc Edit

        Preconditions
                        > No resource is currently being edited (close off an edit
                          with EndRsrcEdit)

                        > RowNode is the TreeNode for the existing resource
                          to be edited.  It must not be NIL.

                        > ErrorHandler is the procedure to be called when an
                          edit error occurs.

        Postconditions
                        > Resource is ready to be edited.
*)
PROCEDURE BeginRsrcEdit(     RowNode         : ATreeNode;
                             LErrorHandler    : AnErrorHandlerProc;
                             LAlterBaselineProc : AnAskAlterBaselineProc;
                             LImportTable       : ADDRESS;
                             LHandlersContext : ADDRESS          );
BEGIN
    WITH GlobalContext DO
        RsrcNode          := RowNode;
        ContextReady      := (RsrcNode <> ATreeNode(NIL));
        EditError         := FALSE;
        AlterBaseline     := LAlterBaselineProc;
        PImportTable      := LImportTable;

        WITH StateInfo DO
            ErrorHandler          := LErrorHandler;
            HandlersContext       := LHandlersContext;
            WhatsBeenSeen         := AWhatsBeenSeenSet{};
            DefPercent            := Zero;
            LevPercent            := Zero;
            DefLimit              := 0;
            LevLimit              := 0;
        END;
    END;

END BeginRsrcEdit;





(*
    Digest Rsrc String

        Convert a text string into the internal data record needed by
        "ChangeRsrcColumn".

        Preconditions
                        > "ColumnID" is a valid column id.

                        > "TextString" is the string to be digested into
                          "ColumnData".  It is not modified (VAR only for
                          efficiency).

                        > "Amount Format" is the real number format to use
                          in analizing REAL numbers.  It is not altered.
                          VAR is just for efficiency.

                        > Some columns may allow a "Null" value.  This is
                          handled here by an empty text string.
                          This is not allowed for all columns.

        Postconditions
                        > "ColumnData" is the data to be applied to the
                          resource.

                        > The text is checked within the context of the
                          column in question, and the "ColumnData" record
                          is filled in appropriately.

                        > If any errors are encountered, the ErrorHandler is
                          called.  Any error above "NoError" will cause FALSE
                          to be returned.  Errors would all be simple formatting
                          errors.

                        > Returns TRUE if there were no formatting errors,
                          FALSE if there were.
*)
PROCEDURE DigestRsrcString(     ColumnID     : CARDINAL;
                            VAR TextString   : ARRAY OF CHAR;
                            VAR AmountFormat : AnAmountFormat;
                            VAR ColumnData   : AColumnDataRecord ;
                                LErrorHandler    : AnErrorHandlerProc;
                                LHandlersContext : ADDRESS          ) : BOOLEAN;
VAR
   EditError : BOOLEAN;
BEGIN

   EditError := DigestAString( AGetInfoProc(GetRsrcInfo),  ColumnID,
                               TextString,   AmountFormat,
                               ColumnData,
                               LErrorHandler,
                               LHandlersContext );

   IF ( NOT EditError ) THEN
       GlobalContext.EditError := TRUE;
   END;

   RETURN EditError;
END DigestRsrcString;

PROCEDURE DigestIntRsrcString(     ColumnID         : CARDINAL;
                                   Type             : CARDINAL;
                               VAR Data             : AnIntDataRecord;
                               VAR AmountFormat     : AnAmountFormat;
                               VAR ColumnData       : AColumnDataRecord ;
                                   LErrorHandler    : AnErrorHandlerProc;
                                   LHandlersContext : ADDRESS          ) : BOOLEAN;
VAR
   EditError : BOOLEAN;
BEGIN

   EditError := DigestAIntString( AGetInfoProc(GetRsrcInfo),
                                  ColumnID,
                                  Type,
                                  Data,
                                  AmountFormat,
                                  ColumnData,
                                  LErrorHandler,
                                  LHandlersContext );

   IF ( NOT EditError ) THEN
       GlobalContext.EditError := TRUE;
   END;

   RETURN EditError;
END DigestIntRsrcString;



(*
    Change Rsrc Column

        Preconditions
                        > A Rsrc is being edited (BeginRsrcEdit has been
                          called).

                        > "ColumnID" is a valid column id.

                        > "ColumnData" is the data to be applied to the resource.

                        > Some columns may allow a "Null" value.  This is
                          handled here by an empty "DataFields" inside
                          "ColumnData".  This is not allowed for all columns.

        Postconditions
                        > The data is checked within the context of the
                          column in question, and the changes are applied,
                          except as noted below.

                        > If any errors are encountered, the ErrorHandler is
                          called.  Any error above "NoError" will cause FALSE
                          to be returned.

                        > If TRUE is returned, it is implied that no errors
                          have yet been detected.  A call to EndRsrcEdit MIGHT
                          succeed, unless other errors are encountered.

                        > If FALSE is returned, no further edits will
                          be accepted (further calls to "ChangeRsrcColumn"
                          will return FALSE).  The changes should be ABORTED
                          by the caller.
*)
PROCEDURE ChangeRsrcColumn(     ColumnID    : CARDINAL;
                            VAR ColumnData  : AColumnDataRecord ) : BOOLEAN;
VAR
    ResourcePtr     : AResourcePointer;
BEGIN

    WITH GlobalContext DO
        IF (NOT ContextReady) THEN
            FatalError();  (* Code bug; no way to notify an error handler. *)
        END;

        IF (ColumnData.DataFields <> ASetOfColumnDataFields{}) AND  (* Ignore? *)
           (NOT EditError)                                     THEN

            ResourcePtr := RsrcNode^.Methods^.GetDataObject (RsrcNode);

            EditError := ChangeRsrcRecord( ColumnID,
                                           ResourcePtr,
                                           ColumnData,
                                           StateInfo );
        END;
    END;

    RETURN GlobalContext.EditError;

END ChangeRsrcColumn;


PROCEDURE ChangeRsrcRecord(     ColumnID    : CARDINAL;
                                RsrcPtr     : AResourcePointer;
                            VAR ColumnData  : AColumnDataRecord;
                            VAR Context     : ARsrcEditContext
                           ) : BOOLEAN;
VAR
    TempString  : ARRAY [0..9] OF CHAR;
    Junk        : BOOLEAN;
    EditError   : BOOLEAN;
    TempReal    : REAL;

    PROCEDURE Assume( Field : AColumnDataField ) : BOOLEAN;
    BEGIN
        IF (NOT (Field IN ColumnData.DataFields)) THEN
            Junk      := Context.ErrorHandler( SeriousError,
                                               DataFieldsWrong,
                                               ColumnID,
                                               NilString,
                                               Context.HandlersContext );
            EditError := TRUE;
        END;

        RETURN (NOT EditError);

    END Assume;

    PROCEDURE DoBoolean ( VAR Bool : BOOLEAN );
    BEGIN
        IF (Assume( BooleanInUse )) THEN
            WITH ColumnData DO
               IF (BooleanValue) THEN
                  Bool := TRUE;
               ELSE
                  Bool := FALSE;
               END;
            END;
        END;
    END DoBoolean;


    PROCEDURE DoString( VAR s : ARRAY OF CHAR ; MaxLen : CARDINAL );
    BEGIN
        IF (Assume( StringInUse )) THEN
            WITH ColumnData DO
                TrimFront( StringValue );
                TrimRear(  StringValue );

                IF ( LengthOf ( StringValue ) > MaxLen ) THEN
                    SetLengthOf ( StringValue, MaxLen );
                    Junk := Context.ErrorHandler( FormatError,     (* 27-Sep-89 MWP *)
                                                  TextTruncation,
                                                  ColumnID,
                                                  NilString,
                                                  Context.HandlersContext );
                END;

                Copy( StringValue, s );
            END;
        END;
    END DoString;

    PROCEDURE DoNotes( VAR Text : AText );
    BEGIN
        IF (Assume( StringInUse )) THEN
            IF (NOT TextExists( Text )) THEN
                Text := CreateText();
            END;
            IF (NOT TextExists( Text )) THEN
                EditError := TRUE;
            ELSE
                EditError := AssignLine( ColumnData.StringValue, 0, Text );
                Compress( Text );

                IF ( EditError ) THEN
                   EditError := FALSE;
                ELSE
                   EditError := TRUE;
                END;
            END;

            IF (EditError) THEN
                Junk := Context.ErrorHandler( SystemError,
                                              NoMemoryForEdit,
                                              ColumnID,
                                              NilString,
                                              Context.HandlersContext );
            END;
        END;
    END DoNotes;

    PROCEDURE  SetDefaultLimit ( VAR Limit : REAL );
    BEGIN
         IF (Assume( CardinalInUse )) THEN
             IF ( ColumnData.CardinalValue > 650 ) THEN
                Junk := Context.ErrorHandler( FormatError,
                                              NumberOutOfRange,
                                              ColumnID,
                                              NilString,
                                              Context.HandlersContext );
                Context.DefLimit := 650;
                INCL( Context.WhatsBeenSeen, DefaultLimitSeen );
             ELSE
                Context.DefLimit := ColumnData.CardinalValue;
                INCL( Context.WhatsBeenSeen, DefaultLimitSeen );
             END;
         END;
    END  SetDefaultLimit;


    PROCEDURE  SetDefaultPercent ( VAR Percent : CARDINAL );
    VAR
        ok : BOOLEAN;
    BEGIN
         IF (Assume( RealInUse )) THEN
                ok := (ColumnData.RealValue >= 0.0) AND
                      (ColumnData.RealValue <=  2.50 );

                IF ( ok ) THEN
                    Context.DefPercent := ColumnData.RealValue * 100.0;
                    INCL( Context.WhatsBeenSeen, DefaultPercentSeen );
                ELSE
                    Junk := Context.ErrorHandler( FormatError,
                                                  NumberOutOfRange,
                                                  ColumnID,
                                                  NilString,
                                                  Context.HandlersContext );
                    Context.DefPercent := 250.0;
                    INCL( Context.WhatsBeenSeen, DefaultPercentSeen );
                END;
         END;
    END  SetDefaultPercent;


    PROCEDURE  SetLevelingLimit ( VAR Limit : REAL );
    BEGIN
        IF (Assume( CardinalInUse )) THEN
            IF ( ColumnData.CardinalValue > 650 ) THEN
                Junk := Context.ErrorHandler( FormatError,
                                              NumberOutOfRange,
                                              ColumnID,
                                              NilString,
                                              Context.HandlersContext );
                Context.LevLimit := 650;
            ELSE
                Context.LevLimit := ColumnData.CardinalValue;
            END;
            INCL( Context.WhatsBeenSeen, LevelingLimitSeen );
        END;
    END  SetLevelingLimit;


    PROCEDURE  SetLevelingPercent ( VAR Percent : CARDINAL );
    VAR
        ok : BOOLEAN;
    BEGIN

        IF (Assume( RealInUse )) THEN
            ok := (ColumnData.RealValue >= 0.0) AND
                  (ColumnData.RealValue <=  2.50 );

            IF ( ok ) THEN
                Context.LevPercent := ColumnData.RealValue * 100.0;
            ELSE
                Junk := Context.ErrorHandler( FormatError,
                                              NumberOutOfRange,
                                              ColumnID,
                                              NilString,
                                              Context.HandlersContext );
                Context.LevPercent := 250.0;
            END;
            INCL( Context.WhatsBeenSeen, LevelingPercentSeen );
        END;
    END  SetLevelingPercent;

    PROCEDURE DoRsrcType( VAR CostStyle : ACostStyle; VAR Type : AResourceType );
    VAR
        i           : CARDINAL;
        s1, s2      : ARRAY [0..99] OF CHAR;
    BEGIN

        (* s1 contains the resource type *)
        DoString( s1, 99 );

        IF (NOT EditError) THEN
            (* Make sure it's uppercase *)
            Upshift(  s1 );

            (* Retrieve 'Resources' from phrases. *)
            GetMessageWord( 13801, 0, s2 );

            (* Make sure it's uppercase *)
            Upshift(  s2 );

            (* See if we have a Resource ( Employable ) *)
            IF (StringsEqual( s1, s2 )) THEN
                CostStyle := CAmountRateTime;
                Type := Employable;
                INCL( Context.WhatsBeenSeen, TypeSeen );
            ELSE
                FOR i := 1 TO 3 DO
                    GetMessageWord( 13801, i, s2 );
                    Upshift(  s2 );

                    IF (StringsEqual( s1, s2 )) THEN
                        CASE i OF
                             1      : (* Fixed *)
                                CostStyle := CAmount;
                                Type      := AccountingOnly;

                        |    2      : (* Unit *)
                                CostStyle := CAmountRate;
                                Type      := AccountingOnly;

                        |    3      : (* Variable *)
                                CostStyle := CAmountRateTime;
                                Type      := AccountingOnly;
                        END;
                        INCL( Context.WhatsBeenSeen, TypeSeen );

                        RETURN;
                    END;
                END;

                Junk := Context.ErrorHandler( FormatError,
                                              EnumerationWrong,
                                              ColumnID,
                                              NilString,
                                              Context.HandlersContext );
            END;
        END;

    END DoRsrcType;


    PROCEDURE DoRate ();
    VAR
        BStart, BThru   : ABigTime;
        Rate            : REAL;
    BEGIN
        IF (RateListFlagSeen IN Context.WhatsBeenSeen) AND
           (RsrcPtr^.ActualRates = ARateList(NIL))    THEN
            RETURN;
        ELSE
            IF (Assume( RealInUse )) THEN
                INCL( Context.WhatsBeenSeen, RateSeen );

                    (* 14-Sep-91 TGS reworked this *)
                WITH RsrcPtr^ DO
                    IF (ActualRates = ARateList(NIL)) AND
                       (ColumnData.RealValue <> One)  THEN
                        ActualRates := CreateRateList(  ColumnData.RealValue,
                                                        MINBIGTIME );
                    ELSIF SetRateListEntryN( RsrcPtr^.ActualRates,
                                             1, ColumnData.RealValue) AND
                          GetRateListEntry ( RsrcPtr^.ActualRates,
                                             2, BStart, BThru, Rate ) AND
                          (ColumnData.RealValue = Rate)               THEN
                        DisposeRateListEntry(RsrcPtr^.ActualRates, 2);
                    END;
                END;
            END;
        END;
    END DoRate;

    PROCEDURE DoBsLnRate ();
    BEGIN
        IF (Assume( RealInUse )) THEN

                (* 21-Oct-90 RSC Replaced "NotYetImplemented"
                *)
            WITH RsrcPtr^ DO
                IF (BaseLineRates <> ARateList(NIL)) THEN
                    DisposeRateList(BaseLineRates);
                END;
                IF (ColumnData.RealValue <> One) THEN
                    BaseLineRates := CreateRateList( ColumnData.RealValue, MINBIGTIME );
                END;
            END;
        END;
    END DoBsLnRate;




    PROCEDURE DoUnits();
    BEGIN
        IF (Assume( StringInUse )) THEN
           INCL( Context.WhatsBeenSeen, UnitsSeen );

           WITH ColumnData DO
                TrimFront( StringValue );
                TrimRear(  StringValue );
                Copy( StringValue, UnitsString );
            END;
        END;

    END DoUnits;

    PROCEDURE AllowAlterBaseline () : BOOLEAN;
    BEGIN
        WITH GlobalContext DO
           IF ( NOT PImportTable^.BaseLineEncountered ) THEN
              PImportTable^.BaseLineEncountered := TRUE;
              PImportTable^.ImportBaseLineInfo  := AlterBaseline ();
           END;

           RETURN PImportTable^.ImportBaseLineInfo;
        END;
    END AllowAlterBaseline;


BEGIN

    WITH Context DO
        EditError := FALSE;

        IF (ColumnData.DataFields <> ASetOfColumnDataFields{}) THEN
            WITH RsrcPtr^ DO
                WITH ColumnData  DO
                    CASE ColumnID OF
                        RsrcName               :
                            DoString( Name, RsrcNameLen );
                            AjustName( Name );

                      | RsrcFullName           :
                            DoString( LongName, LongNameLen );

                      | RsrcKeyword            :
                            DoString( Keyword, KeyNameLen );

                      | RsrcNotes              :
                            DoNotes( Notes );

                      | RsrcType               :
                            IF (Assume( StringInUse )) THEN       (* 10-Sep-89 MWP *)
                               DoRsrcType ( CostStyle, Type );
                            END;

                      | RsrcDefaultLimit       :
                            SetDefaultLimit ( Limit );

                      | RsrcDefaultPercent     :
                            SetDefaultPercent ( Percent );

                      | RsrcLevelingLimit      :
                            SetLevelingLimit ( UpperLimit );

                      | RsrcLevelingPercent    :
                            SetLevelingPercent ( UpperPercent );

                      | RsrcRate               :
                            DoRate ();

                      | RsrcUnitCost           :
                            DoUnits ();

                      | RsrcUnitOfMeasure      :
                           IF (Assume( StringInUse )) THEN        (* 10-Sep-89 MWP *)
                              DoString( UnitOfMeasure, UnitOfMeasureLen );
                              INCL( WhatsBeenSeen, UnitOfMeasureSeen );
                           END;

                      | RsrcLevelingPermitted  :
                           DoBoolean ( LevelThisResource );

                      | RsrcBaselineRate:
                           TempReal := AverageResourceRate( RsrcPtr,
                                                             MinDate,
                                                             MaxDate,
                                                             TRUE   );
                           IF ( TempReal <> RealValue ) THEN
                              IF ( AllowAlterBaseline () ) THEN
                                  DoBsLnRate ();
                              END;
                           END;

                     | RsrcSeqNumColumn:
                                (* 21-Oct-90 RSC Removed "NotYetImplemented" *)
                           IF (Assume( CardinalInUse )) THEN
                               SequenceNumber := CardinalValue;
                           END;

                        (* 11-Jul-91 TGS *)
                        (* With these, if they are FALSE then it means we
                           do NOT want a calendar, varying rate list, or
                           varying availability list, etc., and we want to
                           ignore the imports to RsrcRate, RsrcLevellingLimit,
                           etc., always ending up with a NIL list for the
                           associated data item. We set the WhatsBeenSeen flags
                           as appropriate so that routines that normally would
                           replace a NIL list with a non-NIL one (like DoRate)
                           will leave the NIL list NIL when it was made NIL here.
                        *)

                    | RsrcVacationCalExists     :
                        IF (BooleanValue = FALSE) AND
                           (Calendar <> NIL) THEN
                            DisposeCalendar(Calendar);
                        END;

                    | RsrcBslnVacationCalExists :
                        IF (BooleanValue = FALSE) AND
                           (BaselineCalendar <> NIL) THEN
                            DisposeCalendar(BaselineCalendar);
                        END;

                    | RsrcVaryingRatesExist     :
                        IF (BooleanValue = FALSE) AND
                           (ActualRates <> ARateList(NIL)) THEN
                            DisposeRateList(ActualRates);
                        END;
                        INCL(WhatsBeenSeen, RateListFlagSeen);

                    | RsrcBslnVaryingRatesExist :
                        IF (BooleanValue = FALSE) AND
                           (BaseLineRates <> ARateList(NIL)) THEN
                            DisposeRateList(BaseLineRates);
                        END;

                    | RsrcVaryingAvailsExist    :
                        IF (BooleanValue = FALSE) AND
                           (Availability <> ADateList(NIL)) THEN
                            DisposeDateList(Availability);
                        END;
                        INCL(WhatsBeenSeen, AvailListFlagSeen);

                    | RsrcBslnVaryingAvailsExist:
                        IF (BooleanValue = FALSE) AND
                           (BaselineAvailability <> ADateList(NIL)) THEN
                            DisposeDateList(BaselineAvailability);
                        END;

                    ELSE

                    END;
                END;
            END;
        END;
    END;

    RETURN EditError;

END ChangeRsrcRecord;



PROCEDURE Squeeze(  VAR TheString : ARRAY OF CHAR );
BEGIN
    TrimFront( TheString );
    TrimRear(  TheString );
    Upshift(   TheString );
END Squeeze;


PROCEDURE ParseSimpleUnits ( VAR UnitStr : ARRAY OF CHAR ;
                             VAR Units   : ADurationUnit ) : BOOLEAN;
CONST
    CaptionsModuleNumber = 19100;  (* FROM CAPTIONS *)
VAR
    TimeUnit    :  ADurationUnit;
    Regular,
    Plural      : ARRAY [0..99] OF CHAR;
    i           :  CARDINAL;
BEGIN
    Upshift ( UnitStr );

    FOR TimeUnit := Minutes TO Years DO

      GetMessage(CaptionsModuleNumber+1   +ORD(TimeUnit), Regular );
      GetMessage(CaptionsModuleNumber+11  +ORD(TimeUnit), Plural  );
      (* "Minutes,Hours,Days,Weeks,Months,Years" *)

      Squeeze( Regular );
      Squeeze( Plural  );

      IF (StringsEqual( UnitStr, Regular ))  THEN
          GetMessage(CaptionsModuleNumber+1   +ORD(TimeUnit), Regular );
          Copy ( Regular, UnitStr );
          Units := TimeUnit;
          RETURN TRUE;
      END;

      IF ( StringsEqual ( UnitStr, Plural  ) )  THEN
          GetMessage(CaptionsModuleNumber+11  +ORD(TimeUnit), Plural  );
          Copy ( Plural, UnitStr );
          Units := TimeUnit;
          RETURN TRUE;
      END;
    END;

    RETURN FALSE;

END ParseSimpleUnits;


(*
    Given a string like '$300 per day', parse it to get the resource rate
    and the resource unit. This amount overrides the rate field which
    may have been imported. This is the actual value entered by the
    user.
*)
PROCEDURE ParseResourceUnits ( VAR UnitOfMeasure : ARRAY OF CHAR ;
                               VAR RsrcPtr       : AResourcePointer );
CONST
    WordSeparator = " ";
VAR
    BStart, BThru   : ABigTime;
    TempReal,
    RealValue   : REAL;
    CurIndex    : CARDINAL;
    StoppedAt   : CARDINAL;
    TempUnits   : ADurationUnit;
    s1          : ARRAY [0..10] OF CHAR;
    s2          : ARRAY [0..50] OF CHAR;
    ok          : BOOLEAN;
BEGIN
    CurIndex := 1;

    TrimFront( UnitOfMeasure );                                   (* 27-Jul-89 MWP *)
    TrimRear ( UnitOfMeasure );

    Upshift(  UnitOfMeasure );

    FindNextWord( UnitOfMeasure, CurIndex, WordSeparator );

    IF ( UnitOfMeasure[1] = "$" ) THEN
       SubStr ( UnitOfMeasure, s2, 2, CurIndex - 3 );
    ELSE
       SubStr ( UnitOfMeasure, s2, 1, CurIndex - 2 );
    END;

    ParseAmountToReal( s2, DefaultAmountFormat, RealValue, ok, StoppedAt );  (* 31-Aug-89 LAA *)

    GetMessage( RsrcModuleNumber - 9, s1 );
    (* " per " *)
    Squeeze ( s1 );

    CurIndex := Search ( UnitOfMeasure, s1, 1 );

    (* What, no 'per' anything? *)
    IF ( CurIndex = 0 ) THEN
       ok := FALSE;
    ELSE
       FindNextWord( UnitOfMeasure, CurIndex, WordSeparator );
       SubStr ( UnitOfMeasure, s2, CurIndex, LengthOf ( UnitOfMeasure ) + 1 );
       TrimFront( s2 );
       TrimRear ( s2 );

       IF ( LengthOf ( s2 ) > UnitOfMeasureLen ) THEN
           SetLengthOf ( s2, UnitOfMeasureLen );
       END;

       (* Figure out what the time unit is *)
       ok := ParseSimpleUnits ( s2, TempUnits );

       IF ( ok ) THEN
         IF ( LengthOf ( s2 ) > 0 ) THEN
             Copy( s2, RsrcPtr^.UnitOfMeasure );
         END;
       END;
    END;

    IF ( ok ) THEN

        RsrcPtr^.Units := TempUnits;

        TempReal :=  WorkHoursToRealTime(RealValue,RsrcPtr^.Units);

            (* 14-Sep-91 TGS reworked this *)
        WITH RsrcPtr^ DO
            IF (ActualRates = ARateList(NIL)) AND
                (TempReal <> One)  THEN
                ActualRates := CreateRateList(  TempReal, MINBIGTIME );
            ELSIF SetRateListEntryN( RsrcPtr^.ActualRates, 1, TempReal) AND
                  GetRateListEntry ( RsrcPtr^.ActualRates, 2,
                                     BStart, BThru, RealValue )         AND
                  (TempReal = RealValue)                                THEN
                DisposeRateListEntry(RsrcPtr^.ActualRates, 2);
            END;
        END;
    END;

END ParseResourceUnits;


PROCEDURE ParseUnitAmt ( VAR UnitOfMeasure   : ARRAY OF CHAR ;
                         VAR RsrcPtr         : AResourcePointer;
                             RetrieveMeasure : BOOLEAN );
CONST
    WordSeparator = " ";
VAR
    RealValue   : REAL;
    StoppedAt   : CARDINAL;
    CurIndex    : CARDINAL;
    s1          : ARRAY [0..10] OF CHAR;
    s2          : ARRAY [0..50] OF CHAR;
    ok          : BOOLEAN;
BEGIN
    CurIndex := 1;

    TrimFront( UnitOfMeasure );
    TrimRear ( UnitOfMeasure );

    FindNextWord( UnitOfMeasure, CurIndex, WordSeparator );

    IF ( UnitOfMeasure[1] = "$" ) THEN
       SubStr ( UnitOfMeasure, s2, 2, CurIndex - 3 );
    ELSE
       SubStr ( UnitOfMeasure, s2, 1, CurIndex - 2 );
    END;

    ParseAmountToReal( s2, DefaultAmountFormat, RealValue, ok, StoppedAt );  (* 31-Aug-89 LAA *)

    IF ( ok ) THEN
            (* 21-Oct-90 RSC Replaced "NotYetImplemented"
            *)
        WITH RsrcPtr^ DO
            IF (ActualRates <> ARateList(NIL)) THEN
                DisposeRateList(ActualRates);
            END;
            IF (RealValue <> One) THEN
                ActualRates := CreateRateList( RealValue, MINBIGTIME );
            END;
        END;
    END;

    IF ( RetrieveMeasure ) THEN
        GetMessage( RsrcModuleNumber - 9, s1 );
        (* " per " *)
        Squeeze ( s1 );

        CurIndex := Search ( UnitOfMeasure, s1, 1 );

        IF ( CurIndex = 0 ) THEN
           RETURN;
        ELSE
           FindNextWord( UnitOfMeasure, CurIndex, WordSeparator );
           SubStr ( UnitOfMeasure, s2, CurIndex, LengthOf ( UnitOfMeasure ) + 1 );

           TrimFront( s2 );
           TrimRear ( s2 );

           IF ( LengthOf ( s2 ) > UnitOfMeasureLen ) THEN
               SetLengthOf ( s2, UnitOfMeasureLen );
           END;

           IF ( LengthOf ( s2 ) > 0 ) THEN
               Copy( s2, RsrcPtr^.UnitOfMeasure );
           END;
        END;
    END;

END ParseUnitAmt;



(*
    End Rsrc Edit

        Preconditions
                        > A Rsrc is being edited (BeginRsrcEdit has been
                          called).

        Postconditions
                        > Any changes made to the resource after BeginRsrcEdit
                          have been applied to the resource node, or else the
                          ErrorHandler is called for each exception found.

                        > If any errors were found that were not fixable, or
                          where the error handler decided not to request
                          fixing, FALSE is returned.  Otherwise, TRUE is
                          returned.
*)
PROCEDURE EndRsrcEdit() : BOOLEAN;
VAR
    RsrcPtr     : AResourcePointer;
    TempCard    : CARDINAL;
    TempReal    : REAL;
    BStartDate, BThruDate,
    ZeroBigTime : ABigTime;
    Avail, OldAvail : AnAvailabilityRate;
    ok          : BOOLEAN;

BEGIN

    WITH GlobalContext DO
        IF (NOT ContextReady) THEN
            FatalError();  (* Code bug; no way to notify an error handler. *)
        END;

        IF ( EditError) THEN
            RETURN FALSE;
        END;

        RsrcPtr := RsrcNode^.Methods^.GetDataObject (RsrcNode);
        WITH RsrcPtr^ DO
               (*
                  Resource or variable cost type. Have to fill in
                  RsrcPtr^.Units and RsrcPtr^.ActualRates.
                  ( Actually, ActualRates should have already been
                    filled in, if the field was in the import list. )

                  To fill in the units field which is an enumerated type
                  ADurationUnit, we need to glean the information from
                  one of two fields in the CSV file - UNITS, or,
                  UNITSOFMEASURE. UNITSOFMEASURE is the easiest to use
                  if we have received it. UNITS requires that we parse
                  the string for the actual timeunit.

                  The basic algorithm goes something like this:

                  If the CostStyle is equal to CAmountRateTime, then
                     (* Resource or Variable costs *)
                     If we have seen unitsofmeasure
                        Process UnitsString into Units.
                        return.
                     Else
                        If we have seen units, then
                           Parse out the Unit from the rest of the crap
                           Process UnitsString into Units.
                        Else
                           Units will be set to default, so leave.
                  Else
                     (* Unit costs *)
                     If the CostStyle is equal to CAmountRate, then
                        Parse out the ActualRate rest of the "UNITS" crap.
                     Else
                     (* Fixed costs *)

                        Everything is nulled out.
               *)

            IF ( CostStyle = CAmountRateTime ) THEN
                IF ( UnitsSeen IN StateInfo.WhatsBeenSeen) THEN
                     ParseResourceUnits ( UnitsString, RsrcPtr );
                END;
            ELSE
                IF ( CostStyle = CAmountRate ) THEN
                (*   Unit costs. If we have seen Units, then parse out rate
                     from "UnitString". This will be fed into ActualRates.
                     Then if we have seen UnitsOfMeasure, we can quit, else
                     we also need to retrieve the UnitsOfMeasure from "Unit-
                     String", and place into resource record field UnitOf-
                     Measure.
                *)
                   IF ( UnitsSeen IN StateInfo.WhatsBeenSeen) THEN
                      ParseUnitAmt ( UnitsString, RsrcPtr, TRUE );
                   END;
                ELSE
                   (* Fixed costs - Leave em alone. *)
                        (* 21-Oct-90 RSC Replaced "NotYetImplemented"
                        *)
                    WITH RsrcPtr^ DO
                        IF (ActualRates <> ARateList(NIL)) THEN
                            DisposeRateList(ActualRates);  (* Cost rate is 1.0 *)
                        END;
                    END;
                END;
            END
        END;

        (* Check the limits and percentages retrieved. *)

        WITH StateInfo DO                                          (* 12-Sep-89 MWP *)

            IF ( DefaultPercentSeen IN WhatsBeenSeen) THEN
                RsrcPtr^.Percent :=  CARDINAL(TRUNC(ABS(DefPercent)));
                IF ( DefaultLimitSeen IN WhatsBeenSeen) THEN
                    RsrcPtr^.Limit   :=  FLOAT(DefLimit) * FLOAT(RsrcPtr^.Percent);
                ELSE
                    RsrcPtr^.Limit   :=  RsrcPtr^.Limit * FLOAT(RsrcPtr^.Percent);
                END;
            ELSE
                IF ( DefaultLimitSeen IN StateInfo.WhatsBeenSeen) THEN
                    RsrcPtr^.Limit   :=  FLOAT(DefLimit) * FLOAT(RsrcPtr^.Percent);
                END;
            END;

            IF ( LevelingPercentSeen IN WhatsBeenSeen) OR
               ( LevelingLimitSeen   IN WhatsBeenSeen) THEN

                (* initialize an Availability list entry *)
                Avail.Amount  := DefaultAvailabilityAmount;
                Avail.Percent := DefaultAvailabilityPercent;
                IF ( LevelingPercentSeen IN WhatsBeenSeen) THEN
                    Avail.Percent := CARDINAL(TRUNC(ABS(LevPercent)));
                END;
                IF ( LevelingLimitSeen   IN WhatsBeenSeen) THEN
                    Avail.Amount  := CARDINAL(TRUNC(ABS(FLOAT(LevLimit))));
                END;

                IF (RsrcPtr^.Availability = ADateList(NIL)) AND
                   (AvailListFlagSeen IN WhatsBeenSeen)     THEN (* 11-Jul-91 TGS *)
                    IF ((Avail.Percent <> DefaultAvailabilityPercent) OR
                        (Avail.Amount  <> DefaultAvailabilityAmount)) THEN

                        (* Adjust percent if too big *)
                        IF (Avail.Amount <> 0) THEN
                            IF (MAXCARDINAL DIV Avail.Amount < Avail.Percent) THEN
                                Avail.Percent := MAXCARDINAL DIV Avail.Amount;
                            END;
                        END;

                        RsrcPtr^.Availability := CreateDateList(Avail, MINBIGTIME);
                    END;
                ELSE (* DateList not NIL, have to replace first one *)
                    ok := GetDateListEntry( RsrcPtr^.Availability, 1,
                                            BStartDate, BThruDate,
                                            OldAvail);
                    IF NOT (DefaultPercentSeen IN WhatsBeenSeen) THEN
                        Avail.Percent := OldAvail.Percent;
                    END;

                    IF NOT (DefaultLimitSeen   IN WhatsBeenSeen) THEN
                        Avail.Amount  := OldAvail.Percent;
                    END;

                    (* Adjust percent if too big *)
                    IF (Avail.Amount <> 0) THEN
                        IF (MAXCARDINAL DIV Avail.Amount < Avail.Percent) THEN
                            Avail.Percent := MAXCARDINAL DIV Avail.Amount;
                        END;
                    END;

                    ok := SetDateListEntryN( RsrcPtr^.Availability, 1, Avail);

                    IF GetDateListEntry(RsrcPtr^.Availability, 2, 
                                        BStartDate, BThruDate, OldAvail) THEN
                        IF (OldAvail.Percent = Avail.Percent) AND
                           (OldAvail.Amount  = Avail.Amount ) THEN
                            DisposeDateListEntry(RsrcPtr^.Availability, 
                                                 TSIZE(AnAvailabilityRate), 2);
                        END;
                    ELSE  (* dispose list if it has only one item and it is equal to default *)
                        IF ((Avail.Percent = DefaultAvailabilityPercent) AND
                            (Avail.Amount  = DefaultAvailabilityAmount)) THEN
                            DisposeDateList(RsrcPtr^.Availability);
                        END;
                    END;
                END;
            END;
        END;

        ChangedResource (RsrcNode);

        ContextReady := FALSE;
    END;


    SetLengthOf( UnitsString, 0 );

    RETURN (NOT GlobalContext.EditError);

END EndRsrcEdit;

BEGIN
    SetLengthOf( UnitsString, 0 );
    SetLengthOf( NilString, 0 );
    GlobalContext.ContextReady := FALSE;
END RsrcChange.



