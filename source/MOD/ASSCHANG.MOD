IMPLEMENTATION MODULE AssChange;


    (*
        Ass Change - Edit an assignment record

            This module provides the ability to make changes to an assignment
            record by changing "columns" of data.  It deals with the same
            columns as are output by the "Captions" module.  For this reason,
            this module and its cousins are sometimes refered to as
            "AntiCaptions".


        Terminology:

            A Column HEADING is the formal name a column goes by.  This is the
            name found in a Lotus, DBase, or CSV file.  This heading is
            translated into a ColumnID, a "magic number" used to identify the
            column.  Note that some exporters, notably DBase, may translate
            the official formal name into a new name that is more compatible
            with the external program.  It is the importer's job to translate
            those names BACK into the "official" formal name.


        Procedure Overview:

            GetAssColumnID()    Given a column's formal name, return the
                                internal Column ID.

            BeginAssEdit()      Start the editing of an assignment.

            DigestAssString()   Change a text string into an internal format.

            ChangeAssColumn()   Change the value of a column.

            EndAssEdit()        End the editing of an assignment, and commit
                                the changes if there were no serious errors.


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

            AssAcquire   is used to find the assignment record to be edited.
            TaskEdit     edits task records.
            EdgeEdit     edits edge records.
            RsrcEdit     edits resource records.


        Modification History:


         21-Feb-89  RSC  First version.
         20-May-89  RSC  Accomidated new WorkHours module.
         13-Jul-89  MWP  Removed import of TaskID field.
         27-Jul-89  MWP  As most assignment data fields are calculated
                         using ActualQuantity and YetToGoQuantity, do not
                         overwrite these values if they have been imported
                         already in earlier fields.
         28-Jul-89  MWP  For fixed cost resources, do not average the resource
                         rate to calculate the final YetToGoCost and Completed
                         Cost.
          9-Aug-89  MWP  Allow changing of baseline assignment data.
         10-Sep-89  MWP  Check column data types to ensure they are
                         correct before using them.
         10-Sep-89  MWP  Change to using new percent format for percentage
                         fields.
         11-Sep-89  MWP  Changed method for editing baseline assignment data.
         12-Sep-89  MWP  Multiply percentage values by 100 before we truncate
                         the real!
         13-Sep-89  MWP  Re-worked acquiring and editing baseline records
                         to make it ( hopefully ) more clear.
          2-Oct-89  MWP  Change RelaeaseUnchangedObject to ReleaseChangedObject.
         26-Oct-89  MWP  If the Baseline time unit string is empty, don't check
                         it for validity.
         15-Nov-89  MWP  When importing assignment costs, we were multiplying
                         the cost by the Avg. resource rate, instead of dividing.
         30-Mar-90  RSC  Made Timeu to Timei/TimeForm conversions.
        17-Sep-91 TGS   We were referencing "UpperPercent". That was probably
                        wrong even before, but even more so now. Changed this
                        to allow any "reasonable" percentage (ó250), since we
                        can no longer tell what's bad and what's good until a
                        recalc. Gad I hope we don't have to tweak this more..
        30-Jan-92 TGS   NumberAt is now a RealValue. Changed that, and also a
                        couple of places where it looked like a range check 
                        was wrong.
    *)

FROM Allocs         IMPORT
    (* TYPE *)              ATaskPtr;

FROM AssFormat      IMPORT
    (* PROCS *)             GetAssInfo;

FROM Assignments    IMPORT
    (* TYPE *)              AnAssignmentArray,     AnAssignmentRecord,
                            AnAssignmentAttribute, AnAssignmentAttributeSet;

FROM Captions       IMPORT
    (* TYPE *)              AColumnDataRecord, AColumnInfoChoice,
                            AColumnDataField,  ASetOfColumnDataFields;

FROM Dialog         IMPORT
    (* PROC *)              FatalError;

FROM EditCommon     IMPORT
    (* TYPE *)              AGetInfoProc,
    (* PROC *)              GetAColumnID, DigestAString,
    (* PROC *)              DigestAIntString;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorHandlerProc, AnErrorSeverity, AKindOfError;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle, AnExtStoragePreference,
                            AnExtStatus,
    (* PROC *)              LockObjectArray, ReleaseUnchangedObject,
                            ReleaseObject,   CreateExtObjectWithSize,
                            SetExtSize,      GetExtStatus;

FROM ImPorTable     IMPORT
    (* TYPE *)              AImportTable, AnAskAlterBaselineProc, LogAnError;

FROM IntFileIO      IMPORT
                            AnIntDataRecord;

FROM LStrings       IMPORT
    (* PROCS *)             TrimFront, TrimRear, Copy, SetLengthOf, StringsEqual,
                            SetString, ConcatLS, CtoS, LengthOf;

FROM   MagicNum     IMPORT
    (* CONST *)             AssModuleNumber,   AssTaskName,
                            AssResourceName,   AssBillable,   AssNumberAt,
                            AssPercentEach,    AssTotalHours, AssCompletedHours,
                            AssYTGHours,       AssTotalTime,  AssCompletedTime,
                            AssYTGTime,        AssTimeUnits,  AssTotalUnits,
                            AssCompletedUnits, AssYTGUnits,   AssTotalCost,
                            AssCompletedCost,  AssYTGoCost,   AssTaskWBS,
                            BsLnBillable,
                            BsLnNumberAt,
                            BsLnPercentEach,
                            BsLnTotalHours,
                            BsLnCompletedHours,
                            BsLnYTGHours,
                            BsLnTotalTime,
                            BsLnCompletedTime,
                            BsLnYTGTime,
                            BsLnTimeUnits,
                            BsLnTotalUnits,
                            BsLnCompletedUnits,
                            BsLnYTGUnits,
                            BsLnTotalCost,
                            BsLnCompletedCost,
                            BsLnYTGoCost,

                            AssPlanLastColumn,
                            AssLastColumn;

FROM Matches        IMPORT
    (* PROC *)              MatchADurationUnit;

FROM RealFormat     IMPORT
    (* TYPE *)              AnAmountFormat;

FROM RsrcMod        IMPORT
    (* TYPE *)              ACostStyle,
    (* PROC *)              AverageResourceRate;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, TSIZE;

FROM Timei          IMPORT
    (* CONST*)              MinDate, MaxDate,
    (* TYPE *)              ADurationUnit;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode;

FROM WorkHours       IMPORT
    (* PROC *)              RealTimeToWorkHours;





CONST
    MAXCARDINAL             = 65535;
    FMAXCARDINAL            = 65535.0;
    Zero                    = 0.0;
    OneHundred              = 100.0;


TYPE
    AGlobalContext          = RECORD
                                 TaskNode          : ATreeNode;
                                 AssignmentEntry   : CARDINAL;
                                 BaseLineEntry     : CARDINAL;
                                 ContextReady      : BOOLEAN;
                                 EditError         : BOOLEAN;
                                 AlterBaseline     : AnAskAlterBaselineProc;
                                 PImportTable      : POINTER TO AImportTable;
                                 StateInfo         : AnAssEditContext;
                                 BsLnAltered       : BOOLEAN;
                              END;

VAR
    GlobalContext           : AGlobalContext;
    NilString               : ARRAY [0..1] OF CHAR;


(*
    Get Ass Column ID

        Preconditions
                        > "ColumnName" is an LString containing the FORMAL
                          NAME of the assignment column.
                          The caller must resolve any differences between
                          the name read in from a file and the "official"
                          formal name.  For example, DBase translates some
                          charactors.

        Postconditions
                        > Returns TRUE if the ColumnName is a known assignment
                          column name, or FALSE if it is unknown.

                        > ColumnID is the internal number to use for
                          changing the data, if TRUE is returned.
*)
PROCEDURE GetAssColumnID( VAR ColumnName       : ARRAY OF CHAR;
                          VAR ColumnID         : CARDINAL ) : BOOLEAN;
BEGIN
    RETURN GetAColumnID( AGetInfoProc(GetAssInfo), ColumnName, ColumnID );
END GetAssColumnID;







(*
    Begin Ass Edit

        Preconditions
                        > No assignment is currently being edited (close off
                          an edit with EndAssEdit)

                        > TaskNode is the TreeNode for the assignment's task.
                          AssignmentEntry identifies the (existing) record.

                        > ErrorHandler is the procedure to be called when an
                          edit error occurs.

        Postconditions
                        > Assignment is ready to be edited.
*)
PROCEDURE BeginAssEdit(     LTaskNode          : ATreeNode;
                            LAssignmentEntry   : CARDINAL;
                            LBaseLineEntry     : CARDINAL;
                            LAlterBaselineProc : AnAskAlterBaselineProc; (* 9-Aug-89 MWP *)
                            LImportTable       : ADDRESS;
                            LErrorHandler      : AnErrorHandlerProc;
                            LHandlersContext   : ADDRESS          );
VAR
    Task             : ATaskPtr;
    AssignmentHandle : AnExtHandle;
    BaseLineHandle   : AnExtHandle;                                (* 9-Aug-89 MWP *)
    AssignmentArray  : AnAssignmentArray;
    Count            : CARDINAL;
BEGIN
    WITH GlobalContext DO
        TaskNode          := LTaskNode;
        AssignmentEntry   := LAssignmentEntry;
        BaseLineEntry     := LBaseLineEntry;
        ContextReady      := (LTaskNode <> ATreeNode(NIL));

        AlterBaseline     := LAlterBaselineProc;
        PImportTable      := LImportTable;

        EditError         := FALSE;
        BsLnAltered       := FALSE;

        Task := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

        AssignmentHandle := Task^.Plan.Assignments;

        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

        (* First, the Plan assignment *)
        Count := LockObjectArray( AssignmentHandle,
                                  AssignmentArray,
                                  TSIZE(AnAssignmentRecord));

        IF (Count <= AssignmentEntry) THEN
            ReleaseUnchangedObject( AssignmentHandle ); (* Avoid harder crash in root. *)
            FatalError();  (* The assignment rec must exist now. *)
        END;

(*$O-*)  (* Sometimes a troublesome construct for the optimizer *)

        WITH StateInfo DO
            ErrorHandler          := LErrorHandler;
            HandlersContext       := LHandlersContext;

            WITH AssignmentArray^[ AssignmentEntry ] DO
                YTGValue          := YetToGoQuantity;
                ActualValue       := ActualQuantity;
                AssYTGTimeSeen    := FALSE;
                AssActualTimeSeen := FALSE;
                TimeUnits         := ActualTimeUnits;
                WhatsBeenSeen     := AWhatsBeenSeenSet{};          (* 27-Jul-89 MWP *)
            END;
        END;
(*$O=*)
        ReleaseUnchangedObject( AssignmentHandle );

        WITH StateInfo DO
            WITH DefaultBsLnAssignmentRecord DO
                BsLn_YTGValue          := YetToGoQuantity;
                BsLn_ActualValue       := ActualQuantity;
                BsLn_AssYTGTimeSeen    := FALSE;
                BsLn_AssActualTimeSeen := FALSE;
                BsLn_TimeUnits         := ActualTimeUnits;
                BsLn_WhatsBeenSeen     := AWhatsBeenSeenSet{};          (* 27-Jul-89 MWP *)
            END;
        END;
    END;

END BeginAssEdit;








(*
    Digest Ass String

        Convert a text string into the internal data record needed by
        "ChangeAssColumn".

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
                          assignment.

                        > The text is checked within the context of the
                          column in question, and the "ColumnData" record
                          is filled in appropriately.

                        > If any errors are encountered, the ErrorHandler is
                          called.  Any error that is fixable can be fixed,
                          at the descresion of the error handler.  A fix that
                          means "Ignore" will return ColumnData filled out as
                          if an empty string was passed.

                        > Returns TRUE if there were no formatting errors,
                          FALSE if there were, and were not fixed.
*)
PROCEDURE   DigestAssString(     ColumnID     : CARDINAL;
                            VAR TextString   : ARRAY OF CHAR;
                            VAR AmountFormat : AnAmountFormat;
                            VAR ColumnData   : AColumnDataRecord ;
                                LErrorHandler    : AnErrorHandlerProc;
                                LHandlersContext : ADDRESS          ) : BOOLEAN;
VAR
   EditError : BOOLEAN;
BEGIN

   EditError := DigestAString( AGetInfoProc(GetAssInfo),  ColumnID,
                               TextString,   AmountFormat,
                               ColumnData,
                               LErrorHandler,
                               LHandlersContext );

   IF ( NOT EditError ) THEN
       GlobalContext.EditError := TRUE;
   END;
   RETURN EditError;

END DigestAssString;

PROCEDURE   DigestIntAssString(     ColumnID         : CARDINAL;
                                    Type             : CARDINAL;
                                VAR Data             : AnIntDataRecord;
                                VAR AmountFormat     : AnAmountFormat;
                                VAR ColumnData       : AColumnDataRecord ;
                                    LErrorHandler    : AnErrorHandlerProc;
                                    LHandlersContext : ADDRESS  ) : BOOLEAN;
VAR
   EditError : BOOLEAN;
BEGIN

   EditError := DigestAIntString( AGetInfoProc(GetAssInfo),
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

END DigestIntAssString;





(*
    Change Ass Column

        Preconditions
                        > An assignment is being edited (BeginAssEdit has been
                          called).

                        > "ColumnID" is a valid column id.

                        > "ColumnData" is the data to be applied to the
                          assignment.

                        > Some columns may allow a "Null" value.  This is
                          handled here by an empty "DataFields" inside
                          "ColumnData".  This is not allowed for all columns.

        Postconditions
                        > The data is checked within the context of the
                          column in question, and the changes are applied,
                          except as noted below.

                        > If any errors are encountered, the ErrorHandler is
                          called.  Any error that is not fixable, or that the
                          error handler decides not to fix, will cause FALSE
                          to be returned.

                        > If TRUE is returned, it is implied that no errors
                          have yet been detected.  A call to EndAssEdit MIGHT
                          succeed, unless other errors are encountered.

                        > If FALSE is returned, no further edits will
                          be accepted (further calls to "ChangeAssColumn"
                          will return FALSE).  The changes should be ABORTED
                          by the caller.
*)
PROCEDURE ChangeAssColumn(     ColumnID    : CARDINAL;
                           VAR ColumnData  : AColumnDataRecord ) : BOOLEAN;
VAR
    Task             : ATaskPtr;
    AssignmentHandle : AnExtHandle;
    AssignmentArray  : AnAssignmentArray;
    BsLn_AssignmentHandle : AnExtHandle;                           (* 9-Aug-89 MWP *)
    BsLn_AssignmentArray  : AnAssignmentArray;
    Count            : CARDINAL;

BEGIN

    WITH GlobalContext DO
        IF (NOT ContextReady) THEN
            FatalError();  (* Code bug; no way to notify an error handler. *)
        END;

        IF (ColumnData.DataFields <> ASetOfColumnDataFields{}) AND  (* Ignore? *)
           (NOT EditError)                                     THEN

        (* Get the assignment handle.  Need to upgrade this to include baselines,
           when baseline columns are added.
        *)

            Task := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
            AssignmentHandle := Task^.Plan.Assignments;
            BsLn_AssignmentHandle := Task^.BaseLine.Assignments;          (* 9-Aug-89 MWP *)
            TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );



(*$O-*)  (* Pointers to arrays of records sometimes confuse the optimizer *)
         (* "The force has a strong influance on the weak minded" - ObeWan *)

            IF ( ColumnID <= AssPlanLastColumn ) THEN

                 Count := LockObjectArray( AssignmentHandle,
                                           AssignmentArray,
                                           TSIZE(AnAssignmentRecord));

                 EditError := ChangeAssRecord( ColumnID,
                                               AssignmentArray^[ AssignmentEntry ],
                                               ColumnData,
                                               StateInfo );
                 ReleaseObject( AssignmentHandle );               (* 2-Oct-89 MWP *)
            ELSE
                 EditError := ChangeBsLn_AssRecord( ColumnID,
                                                    DefaultBsLnAssignmentRecord,
                                                    ColumnData,
                                                    StateInfo );
            END;
(*$O=*)
        END;
    END;

    RETURN GlobalContext.EditError;

END ChangeAssColumn;












(*
    Change Ass Record

        This procedure is used internally, and is not meant for clients to use.
        Use "ChangeAssColumn" instead.

        Preconditions
                        > An assignment record is passed.

                        > "ColumnID" is a valid column id.

                        > "ColumnData" is the data to be applied to the
                          assignment.

                        > The rest of the parameters are from the GlobalContext
                          record, and are used to pass state information.
                          Here

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

                        > If TRUE is returned, no errors have yet been detected.

                        > If FALSE is returned, an error was detected and not
                          fixed by the error handler.
*)
PROCEDURE ChangeAssRecord(     ColumnID          : CARDINAL;
                           VAR Assignment        : AnAssignmentRecord;
                           VAR ColumnData        : AColumnDataRecord;
                           VAR Context           : AnAssEditContext
                          ) : BOOLEAN;
VAR
    i,
    Count,
    HighestValue, TempCard,
    TempNumberAt     : CARDINAL;
    TempReal,
    Fraction,
    WorkHours        : REAL;
    EditError        : BOOLEAN;
    Junk, ok         : BOOLEAN;

    PROCEDURE Assume( Field : AColumnDataField ) : BOOLEAN;       (* 10-Sep-89 MWP *)
    VAR
        LocalError : BOOLEAN;
    BEGIN
        IF (NOT (Field IN ColumnData.DataFields)) THEN
            Junk      := Context.ErrorHandler( SeriousError,
                                               DataFieldsWrong,
                                               ColumnID,
                                               NilString,
                                               Context.HandlersContext );
            RETURN FALSE;
        END;

        RETURN TRUE;

    END Assume;


    PROCEDURE Style( CostStyle : ACostStyle ) : BOOLEAN;
    BEGIN
        WITH GlobalContext DO
            IF (Assignment.Resource^.CostStyle <> CostStyle) THEN
               RETURN FALSE;
            ELSE
               RETURN TRUE;
            END;
        END;

    END Style;


    (* DoTime is working under the assumption that Context.TimeUnits has a
       valid value contained in it.
    *)
    PROCEDURE DoTime( VAR R : REAL ) : BOOLEAN;
    BEGIN
        IF (Style( CAmountRateTime )) THEN
            R         := ColumnData.RealValue;  (* For later fixup if needed *)
            WorkHours := RealTimeToWorkHours( R, Context.TimeUnits );
        END;

        RETURN (NOT EditError);

    END DoTime;


BEGIN  (* ChangeAssRecord *)                              (* 27-Jul-89 MWP *)
    WITH Context DO
        EditError := FALSE;

        IF (ColumnData.DataFields = ASetOfColumnDataFields{}) THEN
           RETURN EditError;
        END;

        WITH Assignment DO
            WITH ColumnData  DO
                CASE ColumnID OF

                    AssBillable         :

                        IF ( NOT Assume ( BooleanInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF (BooleanValue) THEN
                            INCL( Attributes, Billable );
                        ELSE
                            EXCL( Attributes, Billable );
                        END;

                  | AssNumberAt         :

                        IF ( NOT Assume(RealInUse) ) THEN
                           RETURN EditError;
                        END;

                        IF (PercentageEach > 0C) AND
                           (RealValue > (FMAXCARDINAL/FLOAT(ORD(PercentageEach)))) THEN

                            IF (ErrorHandler( FormatError,
                                              NumberOutOfRange,
                                              ColumnID,
                                              NilString,
                                              HandlersContext )) THEN
                                MaxRatePercent := (MAXCARDINAL DIV
                                                  ORD(PercentageEach) *
                                                  ORD(PercentageEach));
                            ELSE
                                EditError := TRUE;
                            END;

                        ELSE
                            MaxRatePercent := CARDINAL(TRUNC(RealValue *
                                              FLOAT(ORD(PercentageEach))));
                        END;

                  | AssPercentEach      :

                        IF ( NOT Assume(RealInUse) ) THEN
                           RETURN EditError;
                        END;

                        TempNumberAt := 0;
                        ok := (RealValue >= 0.0) AND
                            (RealValue <=  655.35 ); (* 30-Jan-92 TGS this was "65536.0", but that seemed wrong;
                                                                      we multiply it by 100.0 next *)

                        IF ( ok ) THEN
                            RealValue := RealValue * 100.0;
                            TempCard := CARDINAL(TRUNC(ABS(RealValue)));
                        ELSE
                            TempCard := MAXCARDINAL;
                        END;

                        IF (PercentageEach > 0C) THEN
                            TempNumberAt := MaxRatePercent DIV
                                            ORD(PercentageEach);
                        END;

                        HighestValue := 250;    (* 16-Sep-91 TGS UpperPercent is junk now *)
                     (*   HighestValue := Resource^.UpperPercent; *)
                        IF (HighestValue > 0) AND
                           (TempNumberAt > (MAXCARDINAL DIV HighestValue)) THEN
                            HighestValue := (MAXCARDINAL DIV TempNumberAt);
                        END;

                        IF (TempCard > HighestValue) THEN
                            IF (ErrorHandler( FormatError,
                                              NumberOutOfRange,
                                              ColumnID,
                                              NilString,
                                              HandlersContext )) THEN
                                PercentageEach := CHR(HighestValue);
                                MaxRatePercent := HighestValue *
                                                  TempNumberAt;
                            ELSE
                                EditError := TRUE;
                            END;
                        ELSE
                            PercentageEach := CHR( TempCard );
                            MaxRatePercent := TempCard * TempNumberAt;
                        END;

                  | AssTotalHours       :

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Style ( CAmountRateTime ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT ( YTG IN WhatsBeenSeen ) ) THEN
                            YetToGoQuantity := RealValue - ActualQuantity; (* COULD GO NEGATIVE *)
                        ELSE
                            IF ( NOT ( Actual IN WhatsBeenSeen ) ) THEN
                                 ActualQuantity := RealValue - YetToGoQuantity; (* COULD GO NEGATIVE *)
                            END;
                        END;

                  | AssCompletedHours   :

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( Style ( CAmountRateTime ) ) THEN
                            INCL( WhatsBeenSeen, Actual );
                            ActualQuantity := RealValue;
                        END;

                  | AssYTGHours         :

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( Style ( CAmountRateTime ) ) THEN
                            INCL( WhatsBeenSeen, YTG );
                            YetToGoQuantity := RealValue;
                        END;

                  | AssTotalTime        :

                        IF ( ( YTG IN WhatsBeenSeen ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;


                        IF ( DoTime ( TempReal )) THEN
                           YetToGoQuantity := WorkHours - ActualQuantity;
                        END;

                  | AssCompletedTime    :

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT DoTime( ActualValue ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( AssActualTimeSeen ) THEN
                           ActualQuantity    := WorkHours;
                        ELSE
                           AssActualTimeSeen := TRUE;
                        END;

                  | AssYTGTime          :

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT DoTime ( YTGValue ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( AssActualTimeSeen ) THEN
                           YetToGoQuantity := WorkHours;
                        ELSE
                           AssYTGTimeSeen  := TRUE;
                        END;

                  | AssTimeUnits        :

                        IF ( NOT Style ( CAmountRateTime ) ) THEN
                            RETURN EditError;
                        END;

                        IF ( NOT Assume ( StringInUse ) ) THEN
                           RETURN EditError;
                        END;

                        EditError := (NOT MatchADurationUnit( StringValue, 1,
                                                          ActualTimeUnits, i ));

                        IF ( EditError) THEN
                            Junk      := Context.ErrorHandler( SeriousError,
                                                               BadTimeUnit,
                                                               ColumnID,
                                                               NilString,
                                                               Context.HandlersContext );
                           RETURN EditError;
                        END;

                        TimeUnits := ActualTimeUnits;

                        IF (AssYTGTimeSeen) AND
                           ( NOT ( YTG IN WhatsBeenSeen ) ) THEN
                            RealValue := YTGValue;
                            INCL( ColumnData.DataFields, RealInUse );
                            EditError := ChangeAssRecord( AssYTGTime,
                                                          Assignment,
                                                          ColumnData,
                                                          Context );
                        END;

                        IF (AssActualTimeSeen) AND
                           ( NOT ( Actual IN WhatsBeenSeen ) ) THEN
                            RealValue := ActualValue;
                            INCL( ColumnData.DataFields, RealInUse );
                            EditError := EditError OR
                                         ChangeAssRecord( AssCompletedTime,
                                                          Assignment,
                                                          ColumnData,
                                                          Context );
                        END;

                  | AssTotalUnits       :

                        IF ( NOT Style( CAmountRate ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( ( YTG IN WhatsBeenSeen ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        YetToGoQuantity := RealValue - ActualQuantity;

                  | AssCompletedUnits   :

                        IF ( NOT Style( CAmountRate )) THEN
                           RETURN EditError;
                        END;

                        IF ( Assume(RealInUse) ) THEN
                           INCL( WhatsBeenSeen, Actual );
                           ActualQuantity := RealValue;
                        END;

                  | AssYTGUnits         :

                        IF ( NOT Style( CAmountRate )) THEN
                           RETURN EditError;
                        END;

                        IF ( Assume(RealInUse) ) THEN
                            INCL( WhatsBeenSeen, YTG );
                            YetToGoQuantity := RealValue;
                        END;

                  | AssTotalCost        :

                        IF ( NOT ( Actual IN WhatsBeenSeen ) ) OR
                           ( ( YTG IN WhatsBeenSeen ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse ) ) THEN
                            RETURN EditError;
                        END;

                        IF (Style( CAmount )) THEN             (* 28-Jul-89 MWP *)
                            TempReal := RealValue - ActualQuantity;
                        ELSE
                           TempReal := AverageResourceRate( Resource,      (* 15-Nov-89 MWP *)
                                                            MinDate, MaxDate,
                                                            FALSE );
                           IF ( TempReal <> 0.0 ) THEN
                              TempReal := (RealValue / TempReal) - ActualQuantity;
                           END;
(*
                            TempReal := (RealValue *
                                         AverageResourceRate( Resource,
                                                              MinDate, 
                                                              MaxDate,
                                                              FALSE ))
                                         - ActualQuantity;
*)
                        END;

                        YetToGoQuantity := TempReal;

                  | AssCompletedCost    :
                        IF ( ( Actual IN WhatsBeenSeen ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF (Style( CAmount )) THEN
                              ActualQuantity := RealValue;
                        ELSE
                           TempReal := AverageResourceRate( Resource,     (* 15-Nov-89 MWP *)
                                                            MinDate, MaxDate,
                                                            FALSE );
                           IF ( TempReal <> 0.0 ) THEN
                              ActualQuantity := RealValue / TempReal;
                           END;
(*
                              ActualQuantity := RealValue *
                                                AverageResourceRate( Resource,
                                                                     MinDate, 
                                                                     MaxDate,
                                                                     FALSE );
*)
                        END;

                  | AssYTGoCost         :
                       IF ( ( YTG IN WhatsBeenSeen ) ) THEN
                          RETURN EditError;
                       END;

                       IF ( NOT Assume ( RealInUse ) ) THEN
                          RETURN EditError;
                       END;

                       IF (Style( CAmount )) THEN             (* 28-Jul-89 MWP *)
                          YetToGoQuantity := RealValue;
                       ELSE
                          TempReal := AverageResourceRate( Resource,      (* 15-Nov-89 MWP *)
                                                           MinDate, MaxDate,
                                                           FALSE );
                          IF ( TempReal <> 0.0 ) THEN
                             YetToGoQuantity := RealValue / TempReal;
                          END;
(*
                          YetToGoQuantity := RealValue *
                                             AverageResourceRate( Resource,
                                                                  0, MAXCARDINAL,
                                                                  FALSE );
*)
                       END;
                ELSE
                END;
            END;
        END;
    END;

    RETURN EditError;

END ChangeAssRecord;


PROCEDURE ChangeBsLn_AssRecord(     ColumnID          : CARDINAL;         (* 9-Aug-89 MWP *)
                                VAR Assignment        : AnAssignmentRecord;
                                VAR ColumnData        : AColumnDataRecord;
                                VAR Context           : AnAssEditContext
                               ) : BOOLEAN;
VAR
    i,
    Count,
    HighestValue, TempCard, TempCard1,
    TempNumberAt     : CARDINAL;
    TempReal,
    WorkHours        : REAL;
    EditError        : BOOLEAN;
    Junk, ok         : BOOLEAN;
    TempChar         : CHAR;
    TempTime         : ADurationUnit;
    s                : ARRAY[0..19] OF CHAR;


    PROCEDURE Assume( Field : AColumnDataField ) : BOOLEAN;
    VAR
        LocalError : BOOLEAN;
    BEGIN
        IF (NOT (Field IN ColumnData.DataFields)) THEN
            Junk      := Context.ErrorHandler( SeriousError,
                                               DataFieldsWrong,
                                               ColumnID,
                                               NilString,
                                               Context.HandlersContext );
            RETURN FALSE;
        END;

        RETURN TRUE;

    END Assume;


    PROCEDURE Style( CostStyle : ACostStyle ) : BOOLEAN;
    BEGIN
        WITH GlobalContext DO
            IF (Assignment.Resource^.CostStyle <> CostStyle) THEN
               RETURN FALSE;
            ELSE
               RETURN TRUE;
            END;
        END;

    END Style;


    (* DoTime is working under the assumption that Context.TimeUnits has a
       valid value contained in it.
    *)
    PROCEDURE DoTime( VAR R : REAL ) : BOOLEAN;
    BEGIN

        IF (Style( CAmountRateTime )) THEN
            R         := ColumnData.RealValue;  (* For later fixup if needed *)
            WorkHours := RealTimeToWorkHours( R, Context.BsLn_TimeUnits );
        END;

        RETURN (NOT EditError);

    END DoTime;


    PROCEDURE AllowAlterBaseline () : BOOLEAN;
    BEGIN
        WITH GlobalContext DO
           IF ( NOT PImportTable^.BaseLineEncountered ) THEN
              PImportTable^.BaseLineEncountered := TRUE;
              PImportTable^.ImportBaseLineInfo  := AlterBaseline ();
              IF ( PImportTable^.ImportBaseLineInfo ) THEN
                 BsLnAltered := TRUE;
              END;
           ELSE
              IF ( PImportTable^.ImportBaseLineInfo ) THEN
                 BsLnAltered := TRUE;
              END;
           END;

           RETURN PImportTable^.ImportBaseLineInfo;
        END;
    END AllowAlterBaseline;


BEGIN

    WITH Context DO
        EditError := FALSE;

        WITH GlobalContext DO
           IF ( PImportTable^.BaseLineEncountered ) THEN
              IF ( NOT PImportTable^.ImportBaseLineInfo ) THEN
                 RETURN EditError;
              END;
           END;
        END;

        IF (ColumnData.DataFields = ASetOfColumnDataFields{} ) THEN
           RETURN EditError;
        END;

        WITH Assignment DO
            WITH ColumnData  DO
                CASE ColumnID OF
                    BsLnBillable         :
                        IF ( NOT Assume ( BooleanInUse ) ) THEN
                           RETURN EditError;
                        END;

                        ok := Billable IN Attributes;

                        IF ( BooleanValue = ok ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT AllowAlterBaseline () ) THEN
                           RETURN EditError;
                        END;

                        IF (BooleanValue) THEN
                           INCL( Attributes, Billable );
                        ELSE
                           EXCL( Attributes, Billable );
                        END;

                  | BsLnNumberAt         :

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF (PercentageEach > 0C) AND
                           (RealValue > (FMAXCARDINAL/FLOAT(ORD(PercentageEach)))) THEN

                            IF (ErrorHandler( FormatError,
                                              NumberOutOfRange,
                                              ColumnID,
                                              NilString,
                                              HandlersContext )) THEN

                                TempCard := (MAXCARDINAL DIV
                                             ORD(PercentageEach) *
                                             ORD(PercentageEach));
                            ELSE
                                EditError := TRUE;
                            END;

                        ELSE
                            TempCard := CARDINAL(TRUNC(RealValue *
                                        FLOAT(ORD(PercentageEach))));
                        END;

                        IF ( TempCard = 100 ) THEN
                            MaxRatePercent := TempCard;
                            GlobalContext.BsLnAltered := TRUE;
                        END;

                        IF ( NOT EditError ) AND
                           ( MaxRatePercent <> TempCard ) THEN
                             IF ( AllowAlterBaseline () ) THEN
                                 MaxRatePercent := TempCard;
                             END;
                        END;

                  | BsLnPercentEach      :

                        IF ( Assume(RealInUse) ) THEN
                            TempNumberAt := 0;
                             ok := (RealValue >= 0.0) AND
                                   (RealValue <=  655.36 ); (* 30-Jan-92 TGS *)

                             IF ( ok ) THEN
                                 RealValue := RealValue * 100.0;
                                 TempCard := CARDINAL(TRUNC(ABS(RealValue)));
                             ELSE
                                 TempCard := MAXCARDINAL;
                             END;

                            IF (PercentageEach > 0C) THEN
                                TempNumberAt := MaxRatePercent DIV
                                                ORD(PercentageEach);
                            END;

                            HighestValue := 250;    (* 17-Sep-91 TGS *)
                            IF (HighestValue > 0) AND
                               (TempNumberAt > (MAXCARDINAL DIV HighestValue)) THEN
                                HighestValue := (MAXCARDINAL DIV TempNumberAt);
                            END;

                            IF (TempCard > HighestValue) THEN
                                IF (ErrorHandler( FormatError,
                                                  NumberOutOfRange,
                                                  ColumnID,
                                                  NilString,
                                                  HandlersContext )) THEN
                                    TempChar := CHR(HighestValue);
                                    TempCard1 := HighestValue *
                                                 TempNumberAt;
                                ELSE
                                    EditError := TRUE;
                                END;
                            ELSE
                                TempChar := CHR( TempCard );
                                TempCard1 := TempCard * TempNumberAt;
                            END;

                            IF ( TempChar = CHR(100) ) THEN
                                MaxRatePercent := TempCard1;
                                PercentageEach := TempChar;
                                GlobalContext.BsLnAltered := TRUE;
                            ELSE
                                IF ( TempChar <> PercentageEach ) OR
                                   ( MaxRatePercent <> TempCard1 ) THEN
                                     IF ( AllowAlterBaseline () ) THEN
                                         MaxRatePercent := TempCard1;
                                         PercentageEach := TempChar;
                                     END;
                                END;
                            END;
                        END;

                  | BsLnTotalHours       :


                        IF ( NOT Style ( CAmountRateTime ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( ( YTG IN BsLn_WhatsBeenSeen ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( YetToGoQuantity = RealValue - ActualQuantity ) THEN
                           RETURN EditError;
                        END;

                        IF ( AllowAlterBaseline () ) THEN
                           YetToGoQuantity := RealValue - ActualQuantity;
                        END;

                  | BsLnCompletedHours   :

                        IF ( NOT Style( CAmountRateTime )) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        INCL( BsLn_WhatsBeenSeen, Actual );

                        IF ( ActualQuantity = RealValue ) THEN
                           RETURN EditError;
                        END;

                        IF ( AllowAlterBaseline () ) THEN
                             ActualQuantity := RealValue;
                        END;

                  | BsLnYTGHours         :

                        IF ( NOT Style ( CAmountRateTime ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse ) ) THEN
                            RETURN EditError;
                        END;

                        INCL( BsLn_WhatsBeenSeen, YTG );

                        IF ( YetToGoQuantity = RealValue ) THEN
                           RETURN EditError;
                        END;

                        IF ( AllowAlterBaseline () ) THEN
                            YetToGoQuantity := RealValue;
                        END;

                  | BsLnTotalTime        :

                        IF ( ( YTG IN BsLn_WhatsBeenSeen ) ) THEN
                            RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT DoTime ( TempReal ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( YetToGoQuantity = WorkHours - ActualQuantity ) THEN
                            RETURN EditError;
                        END;

                        IF ( AllowAlterBaseline () ) THEN
                           YetToGoQuantity := WorkHours - ActualQuantity; (* COULD GO NEGATIVE *)
                        END;

                  | BsLnCompletedTime    :

                        IF ( ( Actual IN BsLn_WhatsBeenSeen ) ) THEN
                            RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;


                        IF ( NOT BsLn_AssActualTimeSeen ) THEN
                            IF (DoTime( BsLn_ActualValue )) THEN
                                BsLn_AssActualTimeSeen := TRUE;
                            END;
                        ELSE
                            IF (DoTime( ActualValue )) THEN
                               IF ( ActualQuantity <> WorkHours ) THEN
                                  IF ( AllowAlterBaseline () ) THEN
                                      ActualQuantity    := WorkHours;
                                  END;
                               END;
                            END;
                        END;

                  | BsLnYTGTime          :

                        IF ( ( YTG IN BsLn_WhatsBeenSeen ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT BsLn_AssActualTimeSeen ) THEN
                            IF (DoTime( BsLn_YTGValue )) THEN
                                BsLn_AssYTGTimeSeen  := TRUE;
                            END;
                        ELSE
                            IF (DoTime( BsLn_YTGValue )) THEN
                               IF ( YetToGoQuantity <> WorkHours ) THEN
                                  IF ( AllowAlterBaseline () ) THEN
                                      YetToGoQuantity := WorkHours;
                                  END;
                               END;
                            END;
                        END;

                  | BsLnTimeUnits        :

                        IF ( NOT Style( CAmountRateTime )) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Assume(StringInUse) ) THEN
                           RETURN EditError;
                        END;

                        IF ( LengthOf ( StringValue ) = 0 ) THEN   (* 26-Oct-89 MWP *)
                           RETURN EditError;
                        END;

                        EditError := ( NOT MatchADurationUnit ( StringValue,
                                                            1,
                                                            TempTime,
                                                            i ) );
                        IF ( EditError) THEN
                           Junk      := Context.ErrorHandler( SeriousError,
                                                              BadTimeUnit,
                                                              ColumnID,
                                                              NilString,
                                                              Context.HandlersContext );
                           RETURN EditError;
                        END;

                        IF ( ActualTimeUnits = TempTime ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT AllowAlterBaseline () ) THEN
                           RETURN EditError;
                        END;

                        ActualTimeUnits := TempTime;
                        BsLn_TimeUnits := ActualTimeUnits;

                        IF (BsLn_AssYTGTimeSeen) AND
                           ( NOT ( YTG IN BsLn_WhatsBeenSeen ) ) THEN
                            RealValue := BsLn_YTGValue;
                            INCL( ColumnData.DataFields, RealInUse );
                            EditError := ChangeBsLn_AssRecord(  BsLnYTGTime,
                                                                Assignment,
                                                                ColumnData,
                                                                Context );
                        END;

                        IF (BsLn_AssActualTimeSeen) AND
                           ( NOT ( Actual IN BsLn_WhatsBeenSeen ) ) THEN
                            RealValue := BsLn_ActualValue;
                            INCL( ColumnData.DataFields, RealInUse );
                            EditError := EditError OR
                                         ChangeBsLn_AssRecord( BsLnCompletedTime,
                                                               Assignment,
                                                               ColumnData,
                                                               Context );
                        END;

                  | BsLnTotalUnits       :

                        IF ( NOT Style( CAmountRate ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( ( YTG IN BsLn_WhatsBeenSeen ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;


                        IF ( YetToGoQuantity = RealValue - ActualQuantity ) THEN
                           RETURN EditError;
                        END;

                        IF ( AllowAlterBaseline () ) THEN
                           YetToGoQuantity := RealValue - ActualQuantity; (* COULD GO NEGATIVE *)
                        END;

                  | BsLnCompletedUnits   :

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Style ( CAmountRate ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( ( Actual IN BsLn_WhatsBeenSeen ) ) THEN
                           RETURN EditError;
                        END;

                        INCL( BsLn_WhatsBeenSeen, Actual );

                        IF ( ActualQuantity = RealValue ) THEN
                           RETURN EditError;
                        END;

                        IF ( AllowAlterBaseline () ) THEN
                           ActualQuantity := RealValue;
                        END;

                  | BsLnYTGUnits         :

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Style( CAmountRate ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( ( YTG IN BsLn_WhatsBeenSeen ) ) THEN
                           RETURN EditError;
                        END;

                        INCL( BsLn_WhatsBeenSeen, YTG );

                        IF ( YetToGoQuantity = RealValue ) THEN
                           RETURN EditError;
                        END;

                        IF ( AllowAlterBaseline () ) THEN
                           YetToGoQuantity := RealValue;
                        END;

                  | BsLnTotalCost        :

                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT ( Actual IN BsLn_WhatsBeenSeen ) ) OR
                           ( YTG IN BsLn_WhatsBeenSeen ) THEN
                           RETURN EditError;
                        END;

                        IF (Style( CAmount )) THEN
                            TempReal := RealValue - ActualQuantity;
                        ELSE
                           TempReal := AverageResourceRate( Resource,     (* 15-Nov-89 MWP *)
                                                            MinDate, MaxDate,
                                                            TRUE );
                           IF ( TempReal <> 0.0 ) THEN
                              TempReal := (RealValue / TempReal) - ActualQuantity;
                           END;
(*
                            TempReal := (RealValue *
                                         AverageResourceRate( Resource,
                                                              0, MAXCARDINAL,
                                                              TRUE ))
                                          - ActualQuantity;
*)
                        END;

                        IF ( YetToGoQuantity = TempReal ) THEN
                           RETURN EditError;
                        END;

                        IF ( AllowAlterBaseline () ) THEN
                             YetToGoQuantity := TempReal;
                        END;

                  | BsLnCompletedCost    :

                        IF ( ( Actual IN BsLn_WhatsBeenSeen ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( NOT Assume ( RealInUse ) ) THEN
                            RETURN EditError;
                        END;

                        IF ( Style ( CAmount ) ) THEN
                           TempReal := RealValue;
                        ELSE
                           TempReal := AverageResourceRate( Resource,     (* 15-Nov-89 MWP *)
                                                            MinDate, MaxDate,
                                                            TRUE );
                           IF ( TempReal <> 0.0 ) THEN
                              TempReal := RealValue / TempReal;
                           END;
(*
                           TempReal := RealValue *
                                       AverageResourceRate( Resource,
                                                            0, MAXCARDINAL,
                                                            TRUE );
*)
                        END;

                        IF ( ActualQuantity = TempReal ) THEN
                           RETURN EditError;
                        END;

                        IF ( AllowAlterBaseline () ) THEN
                            ActualQuantity := TempReal;
                        END;

                  | BsLnYTGoCost         :
                        IF ( NOT Assume ( RealInUse ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( ( YTG IN BsLn_WhatsBeenSeen ) ) THEN
                           RETURN EditError;
                        END;

                        IF ( Style ( CAmount ) ) THEN             (* 28-Jul-89 MWP *)
                           TempReal := RealValue;
                        ELSE
                           TempReal := AverageResourceRate( Resource,     (* 15-Nov-89 MWP *)
                                                            MinDate, MaxDate,
                                                            TRUE );
                           IF ( TempReal <> 0.0 ) THEN
                              TempReal := RealValue / TempReal;
                           END;
(*
                           TempReal := RealValue *
                                       AverageResourceRate( Resource,
                                                            0, MAXCARDINAL,
                                                            TRUE );
*)
                        END;

                        IF ( YetToGoQuantity = TempReal ) THEN
                           RETURN EditError;
                        END;

                        IF ( AllowAlterBaseline () ) THEN
                            YetToGoQuantity := TempReal;
                        END;
                ELSE
                END;
            END;
        END;
    END;

    RETURN EditError;

END ChangeBsLn_AssRecord;







(*
    End Ass Edit

        Preconditions
                        > An assignment is being edited (BeginAssEdit has been
                          called).

        Postconditions
                        > Any changes made to the assignment after BeginAssEdit
                          have been applied to the assignment, or else the
                          ErrorHandler is called for each exception found.

                        > If any errors were found that were not fixable, or
                          where the error handler decided not to request
                          fixing, FALSE is returned.  Otherwise, TRUE is
                          returned.
*)
PROCEDURE EndAssEdit ( VAR TaskNode            : ATreeNode;
                           PImportContext      : ADDRESS
                     ) : BOOLEAN;
VAR
    PImport   : POINTER TO AImportTable;                            (* 9-Aug-89 MWP *)
    TaskPtr   : ATaskPtr;
    AssignmentHandle : AnExtHandle;
    AssignmentArray  : AnAssignmentArray;
    AssignmentEntry  : CARDINAL;
    NewSize,
    Count            : CARDINAL;
    ok               : BOOLEAN;
BEGIN

    PImport         := PImportContext;                              (* 9-Aug-89 MWP *)

    WITH GlobalContext DO
        IF (NOT ContextReady) THEN
            FatalError();  (* Code bug; no way to notify an error handler. *)
        END;

        ContextReady := FALSE;
    END;

    (* If we have edited the default baseline assignment record, we have to
       store it away in the task record assignments array. ( But only
       if edits are allowed, of course. )
    *)

    IF ( GlobalContext.BsLnAltered ) THEN
        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        AssignmentHandle := TaskPtr^.BaseLine.Assignments;
        IF ( AssignmentHandle = AnExtHandle(NIL) ) THEN
            ok := (GetExtStatus() = ExtGood) AND
                  (CreateExtObjectWithSize( AssignmentHandle,
                                            ExtMedium,
                                            TSIZE(AnAssignmentRecord)));

            IF (ok) THEN
               TaskPtr^.BaseLine.Assignments := AssignmentHandle;
            END;

            TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

            IF (ok) THEN
                Count := LockObjectArray( AssignmentHandle,
                                          AssignmentArray,
                                          TSIZE(AnAssignmentRecord));
(*$O-*)
                 AssignmentArray^[0] := DefaultBsLnAssignmentRecord;
(*$O=*)
                 INCL( AssignmentArray^[ 0 ].Attributes, RTempFlag1 );  (* 7-Sep-89 MWP *)

                 ReleaseObject( AssignmentHandle );
            END;
        ELSE
            TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );
            Count := LockObjectArray( AssignmentHandle,
                                      AssignmentArray,
                                      TSIZE(AnAssignmentRecord));

(*$O-*)     (* Pointers to arrays of records sometimes confuse the optimizer *)
            (* "The force has a strong influance on the weak minded" - ObeWan *)

            (* TempFlag1 is the bit we use to say "we edited this already". *)

            AssignmentEntry := 0;

            WHILE ( AssignmentEntry < Count ) AND
                 ((AssignmentArray^[ AssignmentEntry ].Resource <>
                   DefaultBsLnAssignmentRecord.Resource) OR
                  (RTempFlag1 IN AssignmentArray^[ AssignmentEntry ].Attributes)) DO
                INC( AssignmentEntry );
            END;
(*$O=*)

           IF (AssignmentEntry < Count) THEN   (* Found one! *)
(*$O-*)
                INCL( AssignmentArray^[ AssignmentEntry ].Attributes, RTempFlag1 );
                AssignmentArray^[AssignmentEntry] := DefaultBsLnAssignmentRecord;
(*$O=*)
                ReleaseObject( AssignmentHandle );
           ELSE
                ReleaseUnchangedObject( AssignmentHandle );

                NewSize := TSIZE(AnAssignmentRecord);
                IF (ODD(NewSize)) THEN
                    INC(NewSize);
                END;

                ok := SetExtSize( AssignmentHandle,
                                 (( AssignmentEntry + 1 )* NewSize));

                IF (ok) THEN
                   Count := LockObjectArray( AssignmentHandle,
                                             AssignmentArray,
                                             TSIZE(AnAssignmentRecord));
                   INCL( AssignmentArray^[ AssignmentEntry ].Attributes, RTempFlag1 );
(*$O-*)
                   AssignmentArray^[AssignmentEntry] := DefaultBsLnAssignmentRecord;
(*$O=*)
                   ReleaseObject( AssignmentHandle );

                   TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

                   TaskPtr^.BaseLine.Assignments := AssignmentHandle;

                   TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
                END;
           END;
        END;
    END;


    RETURN (NOT GlobalContext.EditError);

END EndAssEdit;





BEGIN
    GlobalContext.ContextReady := FALSE;
    SetLengthOf ( NilString, 0 );
END AssChange.


