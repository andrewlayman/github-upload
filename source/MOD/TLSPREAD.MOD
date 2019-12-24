MODULE TLSpread;

(*V7=TRACE*)

(*  =========================================================================
    Last Edit : February 20, 1991 10:34AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        
        Time Line's Spread Sheet View.

    MODIFICATION HISTORY:

        RSC  7-Apr-89  First Version.
        RSC 14-Apr-89  Added support for the NotePad (for the NOTES
                       field) and for TASK LINK (for "Linked File" field).
                       Generally made improvements in field protection.
        RSC 19-Apr-89  Moved task protections to a seperate module.
                       Removed the "@" in formulas.
                       F2 on non-editable columns absorb all cars up to
                       F10, ESC, etc.
        RSC  4-May-89  1) If a field does not change, do not edit it; this
                          prevents the importer code from setting the RECALC
                          flag.
                       2) When changing the start status of a task to Done or
                          Future, make appropriate changes/run appropriate
                          warning boxes if assignments have/don't have work
                          to go.
        RSC 12-May-89  Made the edit string ony char wider, to fill the entire
                       top line.
                       Allow enumerated types to get numeric editing rules,
                       but allow alpha chars.
        RSC 18-May-89  Added the new error checking at the end when you change
                       the start status fields.
        RSC 24-May-89  1) Set the maximum length for fields that care.
                          (Bug # 252)
                       2) Linked file column wasn't setting the task flags
                          correctly.  (Bug # 329).
        RSC 30-May-89  1) Better reporting of the reason a column is not
                          editable.
        RSC  1-Jun-89  Added use of AssUtilities.
        EGK  4-Jun-89  Changed NotifyUndo call into SendNotices call.
        RSC  5-Jun-89  Removed reference to AdvancedTaskForm.
        RSC  3-Aug-89  Extended the allowed codes for string fields.
        KKC 10-Aug-89  Add copyright message.
        RSC 10-Aug-89  For protected fields, make sure that Copy/Paste work.
        RSC 13-Dec-89  Mouse support and use Events rather than codes.
        RSC 15-Dec-89  Remove references to GetAnyCode.
        AJL  8-Oct-90  Removed unused import of Menus.NoYes
        AJL 29-Oct-90  Allow editting of enumerated types when the F2 key
                       is pressed.
                       Give column-specific help when available.
        PFG  9-Nov-90  Added 4.0.3 changes:
                       LAA  13-Jul-90  
                         Incorporate a special check for the task name column,
                         in case it comes in all blanks.  This is consequence 
                         of spreadsheet insert.  In DoOneInstanceOfTLSpread.
                       RSC 23-Sep-90  
                         If we edit the Summarizes field, make sure we do the 
                         same fixups as the task form (related to BUG 3115).
                       End of 4.0.3 changes.
        PFG 20-Feb-91  Removed unused imports to remove "Too Many Symbols"
                       compile error.
         5-Apr-91 TGS   Moved Task Column numbers to TaskColN from MagicNum.
         8-Apr-91 TGS   Dreaded "Too many identifiers". Hard-code the one we
                        still get from MagicNum until I figure out a better
                        solution.
        30-Apr-91 TGS   Call SanitizeTask after successful AssList edit.
                        This is primarily to check effort-driven tasks to 
                        ensure that spent effort does not exceed estimated
                        effort, so recalc doesn't have to try to schedule
                        negative ToGo efforts.
        22-Jul-91 AJL  -After edit of a multiple choice column with a
                        dialog box, push a DoIt code so that we will return
                        to the spreadsheet.  
                       -When editting a multiple choice value, position to
                        the choice text in the dialog box matching the field
                        value.
        28-Aug-91 TGS   Don't call CheckStatusChange and therefore
                        SanitizeTask unless we're changing something that
                        could force a recalc. Bug 4878.
         3-Apr-92 TGS   Extended allowable codes for StringCode. We cut off
                        at ASCII 250, that causes problems with languages
                        that use, for example, ASCII 252 in the normal 
                        alphabet (Czech code page 852).
        16-Apr-92 TGS   If we do something that changes the Spent/Togo effort
                        of the assignments, blast the VaryingAssignments so
                        that $ amounts will be estimated without reference to
                        them. Bug 5547.
    =========================================================================
*)



FROM Allocs     IMPORT
    (* CONST *)     AUXLen,   WBSLen,       OBSLen,
    (* TYPE *)      ATaskPtr, AStartStatus, ATaskStatus, ATask, ARollupStatus,
                    AFixType, ADurationMethod;

FROM Assignments    IMPORT
    (* TYPE *)              AnAssignmentRecord, AnAssignmentArray;

FROM Boxes      IMPORT
    (* TYPE *)      ABoxType, ABoxAttribute;

FROM Captions   IMPORT
    (* TYPE *)      AColumnDataRecord, AColumnInfoChoice,
    (* PROC *)      GetColumnInfo, GetColumnString;

FROM Changer    IMPORT
    (* TYPE *)      ATaskFormContext;

FROM Chart      IMPORT
    (* VAR  *)      GanttChart,
    (* PROC *)      DisplayTaskStats;

FROM ChartControl   IMPORT
    (* TYPE *)          AChartState,
    (* PROC *)          UnSetState;

FROM Codes      IMPORT
    (* TYPE *)      ACode, ASetOfCodes,
    (* VAR  *)      EmptyCodeSet,
    (* PROC *)      SetCodeBits;

FROM Dialog     IMPORT
    (* TYPE *)      ADialogOption,
    (* PROC *)      Message, Burp, FatalError, MultipleChoiceBox;

FROM Dispatcher IMPORT
    (* PROC *)      Dispatch;

FROM Edits      IMPORT
    (* PROC *)      EditText;

FROM EditError  IMPORT
    (* TYPE *)      AnErrorSeverity, AKindOfError;

FROM Events     IMPORT
    (* TYPE *)      AnEvent, AnEventType,
    (* PROC *)      GetNextEvent, PushEvent;

FROM FieldView  IMPORT
    (* PROC *)      DoFieldView, DefaultFieldViewCheckProc;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle,
    (* PROC *)              LockObjectArray, ReleaseObject;

FROM Gantt      IMPORT
    (* TYPE *)      AGanttLineType;

FROM Helper     IMPORT
    (* TYPE *)      AScreenAction,
    (* PROC *)      GiveHelp;

FROM ImPorTable IMPORT
    (* TYPE *)      AImportTable,
    (* PROC *)      AskAlterBaseline;

FROM Kbio       IMPORT
    (* TYPE  *)     avidmode, ascreenx, ascreeny,
    (* CONST *)     maxcol,
    (* PROC  *)     PushCode, PutString;

FROM Keys       IMPORT
    (* CONST *)     CancelKey, EditKey, DoIt, ExitKey, DependViewKey, HelpKey;

FROM Layout     IMPORT
    (* CONST *)     GanttWStart, GanttWEnd;

FROM Links      IMPORT
    (* CONST *)     LinkActionForm,
    (* TYPES *)     ALinkInterface,
    (* PROCS *)     InvokeTLLink;

FROM LStrings   IMPORT
    (* PROC *)      SetString, ConcatLS, ConcatS, LengthOf, SetLengthOf,
                    TrimFront, TrimRear, Search, Remove, Insert, Copy,
                    StringsEqual, CtoS, RJust, Procustes, Upshift, LJust;

(* 8-Apr-91 TGS
FROM MagicNum   IMPORT
    (* CONST *)     IsEnumValue;
*)

FROM Menus      IMPORT
    (* PROC *)      WordNumber;

FROM MsgFile    IMPORT
    (* PROC *)      GetMessage;

FROM Notices    IMPORT
    (* TYPE *)      AnOccasion, AStep,
    (* PROC *)      SendNotices;

FROM Overlays   IMPORT
    (* TYPE *)      AnOverlayID,
    (* PROC *)      ImAnInstallableOverlay, CallOverlayWithContext,
                    OverlayContext;

FROM OvTree     IMPORT
    (* TYPE *)      AnOverlayProc;

FROM RealFormat IMPORT
    (* VAR  *)      DefaultAmountFormat;

FROM Schedule   IMPORT
    (* VAR *)       ScheduleSaved;

FROM StatusChange IMPORT
    (* PROC *)      CheckStatusChange, DefaultStatusDialogProc;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS, ADR, TSIZE;

FROM TaskChange IMPORT
    (* PROC *)      BeginTaskEdit, DigestTaskString, ChangeTaskColumn,
                    EndTaskEdit, SanitizeTask;
                    
FROM TaskColNumbers IMPORT 
    (* CONST *)     NotesColumn,    Summarizes, TaskNameColumn,
                    ResourceColumn, CostColumn, CostAmount, ResourceAmount,
                    StartStatusColumn, PredecessorWBS, SuccessorWBS,
                    AUXColumn, WBSColumn, OBSColumn;

FROM TaskProtection IMPORT
    (* CONST *)     EditableColumns, NumericFields,
    (* VAR   *)     RecalcColumns,
    (* TYPE  *)     AColumnSet,      AFieldKindSet,     AReasonWhyProtected,
    (* PROC  *)     ColumnIsProtected;

FROM Text       IMPORT
    (* TYPE *)      AText,
    (* PROC *)      CreateText, DiscardText, TextExists, LineExists;

FROM TreeObjects IMPORT
    (* TYPE *)      ATreeNode;

FROM VaryAssgnment      IMPORT
    (* TYPE *)              AVaryingAssgnList,
    (* PROC *)              DisposeVaryingAssgnList;




CONST
    ModuleNumber            = 29500;
    (* 8-Apr-91 TGS KLUDGE!! we ran out of identifiers...       *)
    (*              This guy should be imported from MagicNum:  *)
    IsEnumValue             = 6;



VAR
    OverlayID                   : AnOverlayID;

    NullCodeSet                 : ASetOfCodes;
    StringCodes                 : ASetOfCodes;
    NumericCodes                : ASetOfCodes;

    Initialized                 : BOOLEAN;














PROCEDURE Editable(     TaskNode    : ATreeNode;
                        ColumnID    : CARDINAL ) : BOOLEAN;
VAR
    Event,
    LastEvent       : AnEvent;
    DebugMe         : AColumnSet;
    CursorPos       : INTEGER;
    WhyProtected    : AReasonWhyProtected;
    InsertMode      : BOOLEAN;
    s               : ARRAY [0..255] OF CHAR;
    ok              : BOOLEAN;

BEGIN
    WhyProtected := ColumnIsProtected( TaskNode, ColumnID );

    CASE WhyProtected OF

        RNotProtected   :   (* This is ok, it is not protected. *)

    |   RNotPossible    :

            GetMessage(ModuleNumber + 2, s ); (* "Sorry, but this column is not editable.  Press [ESC]." *)

    |   RSummaryTask    :

            GetMessage( ModuleNumber + 1, s ); (* "Sorry, but you can not edit this column on a summary task.  Press [ESC]." *)

    |   RLinkedTask     :

            GetMessage( ModuleNumber + 3, s ); (* "Sorry, but you can not edit this column on a Linked task.  Press [ESC]." *)

    |   RNoAssignments  :

            GetMessage( ModuleNumber + 4, s ); (* "Sorry, but you can not edit this column on a task with no assignments.  Press [ESC]." *)

    |   RNoFSD          :

            GetMessage( ModuleNumber + 5, s ); (* "Sorry, but you can not edit this column on this task.  Press [ESC]." *)
    ELSE
        FatalError();
    END;

    ok := (WhyProtected = RNotProtected);  (* Is it protected? *)

    IF (NOT ok) THEN
        Burp;
        PutString( s, 0, 1, cvideoformdata );

        (* Pretend that a form is up.  This is for MACROS. *)

        InsertMode := FALSE;
        GetNextEvent( Event );
        CursorPos  := 1;
        GetTheColumnString( ColumnID, TaskNode, s );
        WHILE (DefaultFieldViewCheckProc( Event,         LastEvent,
                                          s,             InsertMode,
                                          1,             CursorPos,
                                          EmptyCodeSet,  FALSE,
                                          NIL )) DO
            IF (Event.EventCode > 255) THEN
                Burp;        (* Because the check proc assumes these are ok *)
            END;
            GetNextEvent( Event );
        END;
        (* Save the code for our caller? *)

        ManageLastCode( Event );
    END;

    RETURN ok;

END Editable;







PROCEDURE EditTaskNotes( TaskNode : ATreeNode ) : BOOLEAN;
VAR
    NotesText       : AText;
    TaskPtr         : ATaskPtr;
    Changed         : BOOLEAN;
    Title           : ARRAY [0..39] OF CHAR;
BEGIN

    (* Get the task's notes. *)

    TaskPtr   := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
    NotesText := TaskPtr^.notes;
    Copy( TaskPtr^.taskname, Title );
    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );


    (* No notes?  Create some. *)

    IF (NOT TextExists(NotesText)) THEN
        NotesText := CreateText();
        IF (NOT TextExists(NotesText)) THEN
            RETURN FALSE;
        END;
    END;


    (* Edit the notes. *)

    EditText(   9, GanttWStart + 4, 74, GanttWEnd,
                ABoxType{ShadowBox, DoubleBox},
                Title,
                0,
                NotesText,
                Changed );


    (* No text?  blast it! *)

    IF (NOT LineExists( NotesText, 0 )) THEN
        DiscardText(    NotesText );
        Changed := TRUE;
    END;


    (* If it changed, we must put the notes back. *)

    IF (Changed) THEN
        TaskPtr   := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        TaskPtr^.notes := NotesText;
        TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
    END;


    RETURN TRUE;

END EditTaskNotes;





(* Do the task link feature.
*)
PROCEDURE DoTaskLinkForm( TheTaskNode : ATreeNode ) : BOOLEAN;
VAR
    LinkInterface  : ALinkInterface;
    SummarizeText  : AText;
    TaskPtr        : ATaskPtr;

BEGIN
    WITH LinkInterface DO
        TaskNode      := TheTaskNode;
        TaskPtr       := TheTaskNode^.Methods^.LockFlexStorDataObject( TheTaskNode );
        LinkText      := TaskPtr^.summarizes;
        TheTaskNode^.Methods^.UnlockUnchangedDataObject( TheTaskNode );
        DesiredAction := LinkActionForm;   (* Do the Link Form *)
    END;

    InvokeTLLink( LinkInterface );

    WITH LinkInterface DO
        IF (CompletedOK) AND (ChangesMade) THEN
            TaskPtr   := TheTaskNode^.Methods^.LockFlexStorDataObject( TheTaskNode );
            WITH TaskPtr^ DO
                summarizes := LinkText;
                IF (LinkText <> AText(NIL)) THEN  (* RSC 24-May-89 *)
                    rollupstatus := RollupNotLoaded;

                        (* 23-Sep-90 RSC When changing to linked task,
                                         do the same edits as the task form.
                        *)
                    fixation       := FixedDate;
                    DurationMethod := DurationDriven; 

                ELSE
                    rollupstatus := NotRollup;
                END;
            END;
            TheTaskNode^.Methods^.UnlockFlexStorDataObject( TheTaskNode );
        END;
    END;

    RETURN LinkInterface.CompletedOK;

END DoTaskLinkForm;






(* RSC 24-May-89
*)
PROCEDURE ColumnLength(     ColumnID : CARDINAL ) : CARDINAL;
VAR
    Size    : CARDINAL;
    Task    : ATask;
BEGIN

    CASE ColumnID OF
        TaskNameColumn  :

            Size := HIGH( Task.taskname );

      | AUXColumn       :

            Size := AUXLen;

      | WBSColumn       :

            Size := WBSLen;

      | OBSColumn       :

            Size := OBSLen;

    ELSE
        Size := maxcol + 1;
    END;

    RETURN Size;

END ColumnLength;







PROCEDURE ManageLastCode( VAR LastEventSeen : AnEvent );
VAR
    LastCodeSeen    : ACode;
BEGIN
    (* Save the code for our caller? *)

    LastCodeSeen := LastEventSeen.EventCode;

    IF (LastCodeSeen <> CancelKey)  AND
       (LastCodeSeen <> DoIt)       AND
       (LastCodeSeen <> ExitKey)    THEN
        PushEvent( LastEventSeen );
    END;

END ManageLastCode;







PROCEDURE GetTheColumnString(     ColumnID      : CARDINAL;
                                  TaskNode      : ATreeNode;
                              VAR StringToEdit  : ARRAY OF CHAR );
VAR
    TaskPtr         : ATaskPtr;
    ok              : BOOLEAN;
BEGIN

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
    IF (ColumnID = TaskNameColumn) THEN
        Copy( TaskPtr^.taskname, StringToEdit );
        Procustes( StringToEdit, maxcol+1 );
    ELSE
        ok := GetColumnString( TaskNode, TaskPtr,
                               ColumnID,
                               Plan,
                               maxcol+1,
                               StringToEdit );
    END;
    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

END GetTheColumnString;





PROCEDURE ErrorHandler( Severity        : AnErrorSeverity;
                        ErrorKind       : AKindOfError;
                        ColumnID        : CARDINAL;
                    VAR ErrorText       : ARRAY OF CHAR;
                        MyContext       : ADDRESS
                       ) : BOOLEAN;         (* Continue?         *)
VAR
    s   : ARRAY [0..255] OF CHAR;
    ok  : BOOLEAN;
BEGIN

    GetMessage( ModuleNumber + 30 + ORD(ErrorKind), s );

    Burp;
    IF (LengthOf(s) > 0) THEN
        Message(s);
    END;

    RETURN FALSE;

END ErrorHandler;



TYPE
    AFieldViewContext = RECORD
                            ColumnID      : CARDINAL;
                        END;



PROCEDURE FieldViewCheckProc( VAR Event            : AnEvent;
                                  LastEventSeen    : AnEvent;
                              VAR StringToEdit     : ARRAY OF CHAR;
                              VAR InsertMode       : BOOLEAN;
                                  FieldLength      : CARDINAL;
                              VAR CursorPosition   : INTEGER;
                                  ValidCodes       : ASetOfCodes;
                                  TreatAsNumerics  : BOOLEAN;
                                  FieldViewContext : ADDRESS
                             ) : BOOLEAN;

VAR
    Context : POINTER TO AFieldViewContext;

    PROCEDURE GiveColumnHelp( ColumnID : CARDINAL );
    VAR
        ColumnData      : AColumnDataRecord;
        TaskPtr         : ATaskPtr;
        HelpMessageKey  : ARRAY [0..8] OF CHAR;
    BEGIN
        TaskPtr := ATaskPtr(NIL);
        GetColumnInfo( ATreeNode(NIL), TaskPtr, ColumnID,
                       ColumnHelpKey, HIGH(HelpMessageKey),
                       ColumnData );
        IF (LengthOf(ColumnData.StringValue) > 0) THEN
            Copy(ColumnData.StringValue,HelpMessageKey);
        ELSE
            SetString( HelpMessageKey, "SPRDVIEW" );
        END;

        GiveHelp(  HelpMessageKey, GanttWStart+1, GanttWEnd, RestoreTheScreen );
    END GiveColumnHelp;



    PROCEDURE GiveEnumerationChoices(     ColumnID : CARDINAL;
                                      VAR StringToEdit : ARRAY OF CHAR;
                                      VAR CursorPosition : INTEGER
                                    ) : BOOLEAN;
    VAR
        ColumnData      : AColumnDataRecord;
        TaskPtr         : ATaskPtr;
        Selection       : CARDINAL;
        S               : ARRAY [0..255] OF CHAR;
        Description     : ARRAY [0..61] OF CHAR;           
        Prefix          : ARRAY [0..0] OF CHAR;           
        Title           : ARRAY [0..0] OF CHAR;           
    BEGIN
            (* Put up a menu of possible choices for the column.  There is 
               a phrase in the phrases file for each enumerated column, and 
               will will ask for that phrase number, get the phrase, and 
               use it to display the menu. *)

        TaskPtr := ATaskPtr(NIL);
        GetColumnInfo( ATreeNode(NIL), TaskPtr, ColumnID, ColumnEnumerations, 0, ColumnData );
        IF (ColumnData.CardinalValue > 0) THEN
            GetMessage(ColumnData.CardinalValue,S);   (* Read the list of possible choices. *)

                (* Locate the choice matching the current string value. *)

            Upshift(StringToEdit); LJust(StringToEdit); TrimRear(StringToEdit);
            Selection := 1;
            LOOP
                WordNumber(S,Selection,Description);
                IF (LengthOf(Description)=0) THEN
                    Selection := 1;   (* Offer something. *)
                    EXIT;
                END;
                Upshift(Description);
                IF (StringsEqual(StringToEdit,Description)) THEN
                    EXIT;
                END;
                INC(Selection);
            END;

                (* Get the box contents, including the description of the field. *)

            SetLengthOf(Title,0);
            SetLengthOf(Prefix,0);
            GetColumnInfo( ATreeNode(NIL), TaskPtr, ColumnID, ColumnName, HIGH(Description), ColumnData );
            Copy(ColumnData.StringValue,Description);

                (* User chooses new enumerated value.  We return the text string. *)

            IF MultipleChoiceBox(Description,Title,NoHelp,Prefix,S,Selection) THEN
                WordNumber(S,Selection,StringToEdit);    (* Return chosen text. *)
                CursorPosition := 1;
                PushCode(DoIt);          (* Accept the value and exit edit. *)
                RETURN TRUE;
            ELSE
                RETURN FALSE;
            END;
        ELSE
            Burp();
            RETURN FALSE;
        END;
    END GiveEnumerationChoices;

BEGIN
    Context := FieldViewContext;

        (* Pressing the EditKey (F2) on a column that is an enumerated
           type can bring up a list of legal values. *)
    IF (Event.EventCode = EditKey) THEN
        RETURN GiveEnumerationChoices( Context^.ColumnID,
                                       StringToEdit, CursorPosition );
    ELSIF (Event.EventCode = HelpKey) THEN
        GiveColumnHelp(Context^.ColumnID);
        RETURN TRUE;
    ELSE
        RETURN DefaultFieldViewCheckProc( Event, LastEventSeen,
                                          StringToEdit, InsertMode, FieldLength,
                                          CursorPosition, ValidCodes,
                                          TreatAsNumerics, FieldViewContext );
    END;

END FieldViewCheckProc;





PROCEDURE DoOneInstanceOfTLSpread( TaskNode : ATreeNode ) : BOOLEAN;
VAR
    AssignmentArray : AnAssignmentArray;
    LastEventSeen   : AnEvent;
    ValidCodes      : ASetOfCodes;
    TaskPtr         : ATaskPtr;
    ColumnID        : CARDINAL;
    ColumnData      : AColumnDataRecord;
    ImportTable     : AImportTable;
    TaskFormContext : ATaskFormContext;
    FieldViewContext: AFieldViewContext; 
    OriginalValue,
    StringToEdit    : ARRAY [0..maxcol+1] OF CHAR;
    NumericEdits,
    FirstTimeAndNoChanges,
    ok,
    InsertMode      : BOOLEAN;
    Loop, i         : CARDINAL;


    PROCEDURE InitView();
    VAR
        s           : ARRAY [0..19] OF CHAR;
        Copyright   : ARRAY[0..50] OF CHAR;
    
    
        PROCEDURE SetChar( VAR Set : ASetOfCodes;
                               C   : CHAR );
        VAR
            Code    : ACode;
        BEGIN
            Code := ORD(C);
            SetCodeBits( Set, Code, Code, TRUE );
        END SetChar;
    
    
        PROCEDURE SetStringOfChars( VAR Set : ASetOfCodes;
                                    VAR s   : ARRAY OF CHAR );
        VAR
            Loop    : CARDINAL;
        BEGIN
            FOR Loop := 1 TO LengthOf(s) DO
                SetChar( Set, s[Loop] );
            END;
        END SetStringOfChars;
    
    
    BEGIN
        Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    
        NumericCodes := EmptyCodeSet;
    
        WITH DefaultAmountFormat DO
            SetCodeBits( NumericCodes, ORD("0"), ORD("9"), TRUE );
    
            SetChar( NumericCodes, RadixSymbol           );
            SetChar( NumericCodes, SymbolForSignificance );
    
            SetString( s, " +-*/()" );
            SetStringOfChars( NumericCodes, s );
    
            WITH Decorations DO
    
                SetStringOfChars( NumericCodes, LeadingNegativeSymbol );
                SetStringOfChars( NumericCodes, TrailingNegativeSymbol );
                SetStringOfChars( NumericCodes, LeadingPositiveSymbol );
                SetStringOfChars( NumericCodes, TrailingPositiveSymbol );
    
            END;
        END;
    
        StringCodes  := EmptyCodeSet;
        SetCodeBits( StringCodes,ORD(" "),255,TRUE); (* 3-Apr-92 TGS *)
    
    END InitView;


BEGIN
    IF (NOT Initialized) THEN
        InitView();
        Initialized := TRUE;
    END;

    LastEventSeen.EventCode := ACode(0);
    LastEventSeen.EventType := KeyboardEvent;
    InsertMode              := FALSE;
    FirstTimeAndNoChanges   := TRUE;


    (* Check the cursor task, if there is one.   This should have been done in
       GanttOutlines, but lets just be absolutely sure.
    *)

    IF (TaskNode = NIL) THEN
        RETURN FALSE;
    END;


    (* Get the current column ID and see if that is one we can edit. *)

    ColumnID := GanttChart^.Methods^.GetColumnId( GanttChart );


    (* If it is not editable, leave now. *)

    IF (NOT (Editable( TaskNode, ColumnID ))) THEN
        RETURN FALSE;
    END;


    (* Erase any prior error messages. *)

    SetLengthOf( StringToEdit, 0 );
    Message(     StringToEdit );


    (* Tell UNDO we are about to DO something. *)

    SendNotices (ChangeATask, BeforeActing, TaskNode);   (* 6/4/89 EGK *)


    (* Process some exception columns. *)

    CASE ColumnID OF


        (* If the notes column, go right to the edit box. *)

        NotesColumn     :

            ok := (EditTaskNotes( TaskNode ));
            IF (ok) THEN
                UnSetState (Sorted);
                UnSetState (Filtered);
                ScheduleSaved := FALSE;
            END;
            RETURN ok;


        (* For Pred/Succ, bring up the dependency view. *)

      | PredecessorWBS,
        SuccessorWBS    :

            Dispatch( DependViewKey );
            RETURN FALSE; (* Cancel this transaction. *)


        (* If the summarizes column, go right to the edit box. *)

      | Summarizes      :

            ok := (DoTaskLinkForm( TaskNode ));
            IF (ok) THEN
                UnSetState (Sorted);
                UnSetState (Filtered);
                UnSetState (Scheduled);
                ScheduleSaved := FALSE;
                TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
                INCL( TaskPtr^.TaskStatusSet, NeedsRecalculate );
                TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
            END;
            RETURN ok;


        (* Handle the resource columns. *)

      | ResourceColumn,
        CostColumn,
        CostAmount,
        ResourceAmount  :
       
            SetString( StringToEdit, "TLFBASE(TLASLIST)" );
            TaskFormContext.TaskNode := TaskNode;
            TaskFormContext.Code     := CancelKey;
            (* 30-Apr-91 TGS check for unsavory conditions *)
            IF (CallOverlayWithContext( StringToEdit,
                                        ADR(TaskFormContext) )) AND
               (TaskFormContext.Code <> CancelKey) THEN
                SanitizeTask(TaskNode, ErrorHandler, NIL,
                             AskAlterBaseline,
                             ADR(ImportTable)     );
                RETURN TRUE;
            ELSE
                RETURN FALSE;
            END;
            (*
            RETURN (CallOverlayWithContext( StringToEdit,
                                            ADR(TaskFormContext) )) AND
                   (TaskFormContext.Code <> CancelKey);
            *)
    ELSE
    END;




    (* See which set of keycodes we should use, numeric or string. *)

    TaskPtr := ATaskPtr(NIL);
    GetColumnInfo( TaskNode, TaskPtr, ColumnID, ColumnDataType, 0, ColumnData );
    IF (ColumnData.CardinalValue IN NumericFields) THEN
        IF (ColumnData.CardinalValue = IsEnumValue) THEN
            ValidCodes   := StringCodes;    (* RSC 12-May-89. *)
        ELSE
            ValidCodes   := NumericCodes;
        END;
        NumericEdits := TRUE;
    ELSE
        ValidCodes   := StringCodes;
        NumericEdits := FALSE;
    END;
    SetCodeBits( ValidCodes, EditKey, EditKey, TRUE );

       (* Store information into the context area that will be used
          by the check proc. *)

    FieldViewContext.ColumnID      := ColumnID;

    (* Get the string. *)

    GetTheColumnString( ColumnID, TaskNode, StringToEdit );


    (* Save the original value to later determine if the string was edited.
    *)
    Copy( StringToEdit, OriginalValue );
    TrimRear(  OriginalValue );             (* for later comparison *)
    TrimFront( OriginalValue ); 

    (* Force an edit check if the StringToEdit is a null LString, and the 
       column is the task name column.  This can occur because of the new 
       spreadsheet insert feature.  *)

    IF ((ColumnID = TaskNameColumn) AND (LengthOf( OriginalValue ) = 0)) THEN  (* 13-Jul-90 *)
        FirstTimeAndNoChanges := FALSE; 
    END;


    (* Display the current value, edit it, and check it. *)

    LOOP
        DoFieldView( StringToEdit,
                     LastEventSeen,
                     0, 
                     GanttWStart - 2,
                     ColumnLength( ColumnID ),  (* RSC 24-May-89 *)
                     InsertMode,
                     TRUE,
                     FieldViewCheckProc,
                     ValidCodes,
                     NumericEdits,
                     ADR(FieldViewContext) );

        IF (LastEventSeen.EventCode = CancelKey) THEN
            EXIT;
        END;


        (* No changes and this is the first time through?  Skip the
           editing, so we don't set the RECALC flag.  RSC 5-May-89
           Trim the strings, because the DoFieldView may do so.
        *)
        IF (FirstTimeAndNoChanges) THEN
            TrimRear(  StringToEdit );
            TrimFront( StringToEdit );
            IF (StringsEqual( StringToEdit, OriginalValue )) THEN
                EXIT;
            END;
            FirstTimeAndNoChanges := FALSE;
        END;

        (* Edit the task record with the entered data. *)

        BeginTaskEdit( TaskNode,
                       ErrorHandler, NIL,
                       AskAlterBaseline,
                       ADR(ImportTable) );
        IF (DigestTaskString( ColumnID,
                              StringToEdit,
                              DefaultAmountFormat,
                              ColumnData,
                              ErrorHandler, NIL ))     AND
            (ChangeTaskColumn( ColumnID, ColumnData )) AND
            (EndTaskEdit())                            THEN
            EXIT;
        END;
    END;


    IF (NOT FirstTimeAndNoChanges) AND
       (ColumnID IN RecalcColumns) THEN (* 28-Aug-91 TGS *)
        IF (CheckStatusChange( TaskNode,
                               DefaultStatusDialogProc )) THEN

            (* 16-Apr-92 TGS 
                We changed something. Can't trust any Varying
                Assignment records any more (to compute $), so blast 'em. 
            *)          
            TaskPtr  := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
            WITH TaskPtr^ DO
                Loop := LockObjectArray( Plan.Assignments,
                                         AssignmentArray, 
                                         TSIZE( AnAssignmentRecord ) );
            END;
            TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);

            i := 0;
(*$O-*)
            WHILE (i < Loop) DO
                WITH AssignmentArray^[i] DO
                    IF ( VaryingAssignment <> AVaryingAssgnList(NIL) ) THEN (* 6-Apr-92 TGS *)
                        DisposeVaryingAssgnList(VaryingAssignment);
                        VaryingAssignment := AVaryingAssgnList(NIL);
                    END;
                END;
                INC(i);
            END;
(*$O=*)
            ReleaseObject( TaskPtr^.Plan.Assignments );

            SanitizeTask( TaskNode, ErrorHandler, NIL,
                          AskAlterBaseline,
                          ADR(ImportTable)     );
        ELSE
            LastEventSeen.EventCode := CancelKey;  (* Abort transaction. *)
        END;
    END;


    (* Save the code for our caller? *)

    ManageLastCode( LastEventSeen );


    (* Get rid of any of our error messages.  They have been fixed. *)

    SetLengthOf( StringToEdit, 0 );
    Message( StringToEdit );

    DisplayTaskStats( TaskNode );

    RETURN (LastEventSeen.EventCode <> CancelKey);

END DoOneInstanceOfTLSpread;













(* Do the spreadsheet editing.
*)
PROCEDURE DoTLSpread();
VAR
    Context : POINTER TO RECORD
        TaskNode    : ATreeNode;
        ok          : BOOLEAN;
    END;

BEGIN
    Context     := OverlayContext();
    Context^.ok := DoOneInstanceOfTLSpread( Context^.TaskNode );
END DoTLSpread;






BEGIN
    Initialized := FALSE;
    OverlayID   := ImAnInstallableOverlay( DoTLSpread, AnOverlayProc(NIL) );
    DoTLSpread();
END TLSpread.



