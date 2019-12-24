IMPLEMENTATION MODULE AssListEdit;

(*  =========================================================================
    Last Edit : June 11, 1991 5:41PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        AssList - Provide a QuickPick list of Assignments for a task.

    MODIFICATION HISTORY:

    11-Jun-91 RSC First Version, from AssList.
    18-Jun-91 TGS Don't Glom OT amounts onto assigment list strings.
                  Get right phrase string for TrueString & FalseString.
    16-Jul-91 LAA In EditAssignmentList, the stuff that was being done
                  if NeedsRecalc was TRUE was causing extraneous display
                  work if the user pressed ESC from the assignment list.
                  I made this also conditional on the ok flag.  Bug #4727.
    01-Aug-91 LAA After changing DoGoToWithPrompts to take a parameter
                  defining the extra buttons to use when there's a mouse,
                  I've changed the call here to specify an Insert and
                  Delete key.
    29-Jan-92 TGS   Format NumberOf as a real now.
     6-Apr-92 TGS   Interface to LongDurationToString() changed.
     6-Apr-92 TGS   Use new proc, AssignmentDollars() instead of 
                    AssignmentCost().
    =========================================================================
*)




FROM Allocs         IMPORT
    (* TYPE *)          ATaskPtr, AnAssignmentSummary, AStartStatus,
                        ARollupStatus, ATaskStatus;

FROM AssgnCalc              IMPORT
    (* PROC *)                  AssignmentDollars;

FROM Assignments    IMPORT
    (* TYPES *)         AnAssignmentRecord,     AnAssignmentArray,
                        AnAssignmentAttribute,  AnAssignmentAttributeSet,
                        AnAssignmentPointer,
    (* PROCS *)         ForEachAssignment,     
                        InitAssignment,         
                        DisposeOneAssignmentRecordContents;

FROM AssList        IMPORT
    (* TYPE  *)         AnAssignmentTreeContext,
    (* PROCS *)         CheckResources,
                        DisposeOfAssignmentNodeAndData,
                        GetAssignmentPointerFromTree,
                        DisposeOfAssignmentNodes,
                        AddADefaultAssignmentToTree, PutAssignmentsInATree;

FROM Boxes          IMPORT
    (* TYPE *)          ABoxType, ABoxAttribute;

FROM ChartControl   IMPORT
    (* TYPE *)          AChartState,
    (* PROC *)          UnSetState;

FROM Codes          IMPORT
    (* TYPE *)          ACode;

FROM Dialog         IMPORT
    (* TYPE *)          ADialogOption,
    (* PROCS *)         ContinuationBox, WarningBox, Error, FatalError, Burp,
                        MultipleChoiceBox;

FROM FlexStor       IMPORT
    (* TYPE *)          AnExtHandle,             AnExtStoragePreference,
    (* PROC *)          NumberOfElements,        ArraySize,
                        LockObjectArray,         ReleaseObject,
                        ReleaseUnchangedObject,
                        SetExtSize,              GetExtSize,
                        CreateExtObject,         DiscardExtObject;

FROM GoTo           IMPORT
    (* TYPES *)         AGoToCheckProc, AGoToNameProc,
    (* PROCS *)         DoGoToWithPrompts;

FROM Keys           IMPORT
    (* CONST *)         InsertKey, DoIt, DeleteKey, EditKey, ExitKey;

FROM Layout         IMPORT
    (* CONST *)         GanttWStart, GanttWEnd;

FROM LongConvert    IMPORT
    (* PROC *)          LongToReal;

FROM LongDuration   IMPORT
    (* PROC *)          LongDurationToString;

FROM LStrings       IMPORT
    (* PROCS *)         SetString, ConcatS, ConcatLS, Copy, Compare, Upshift,
                        Procustes, SetLengthOf, LengthOf, StringsEqual,
                        Fill, CtoS, RJust, TrimRear, Insert;

FROM Menus          IMPORT
    (* PROC *)          WordNumber;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage, ConcatMessage;

FROM OutlineViews   IMPORT
    (* TYPE *)          AnOutlineView;

FROM RealFormat     IMPORT
    (* VAR  *)          DefaultCurrencyFormat, DefaultAmountFormat,
    (* PROC *)          FormatAsCurrency, FormatAsAmount;

FROM RsrcCalc       IMPORT
    (* TYPE *)          AnAssignmentCostType, AnAssignmentCostTypeSet,
    (* PROC *)          ComputeTaskNodeCosts, SummTaskNodeAmounts;

FROM RsrcEdit       IMPORT
    (* PROCS *)         SelectResource;

FROM RsrcMod        IMPORT
    (* CONST *)         ResourceNameLength,
    (* TYPE *)          AResourcePointer, AResourceType, ACostStyle,
    (* VAR *)           ResourceTree,
    (* PROC *)          FindResourceByName;

FROM Schedule       IMPORT
    (* VAR *)           ScheduleSaved;

FROM Space          IMPORT
    (* PROC *)          HeapAvailable;

FROM SYSTEM         IMPORT
    (* TYPE *)          TSIZE, ADR, ADDRESS;

FROM TaskAssForms   IMPORT
    (* PROC *)          DoAssignmentForm;

FROM Timei          IMPORT
    (* TYPE *)          ADurationUnit, ADate;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATree,      ATreeNode,      ATreeOrder,
    (* PROC *)          CreateTree, CreateTreeNode, ValidateTreeNode;






CONST
    ModuleNumber        = 4900;     (* For GetMessage *)



VAR
    GlobalContext           : AnAssignmentTreeContext;
    NeedsRecalc             : BOOLEAN;
    TrueString,
    FalseString,
    ResourceShortName,
    VarCostShortName,
    FixedCostShortName,
    UnitCostShortName       : ARRAY [0..19] OF CHAR;








(* Name The Assignment

    Given a node and some other info, build a string that the
    client can use to display info about the resource assignment.


    Preconditions

            The assignment record must be valid (eg, contain a valid
            resource pointer)

    Postconditions

            The data is unchanged, but a string is returned.

    Input:

            Assignment  is the assignment record to return a description of.
                           it is passed by VAL only for efficiency, it is
                           NOT altered.

            TaskStartDate,
            TaskEndDate are the dates of the task that contains this
                            assignment.
    Output:
            Name        is the returned text string.
*)
PROCEDURE NameTheAssignment( VAR Assignment     : AnAssignmentRecord;
                                 TaskStartDate,
                                 TaskEndDate    : ADate;
                             VAR Name           : ARRAY OF CHAR);
CONST
    NameWidth           = ResourceNameLength; (* Account for conflict char *)
    CurrencySize        = 16;  (* $234,678,012.45 *)
    UnitSize            = 10;
    PeopleSize          = 3;
    PercentSize         = 3;
    DurationSize        = 15;
    ConflictCharacter   = 20C;
VAR
    P, i            : CARDINAL;
    SpentCost,
    R               : REAL;
    LocalUnits      : ADurationUnit;
    s1              : ARRAY [0..69]  OF CHAR;
    Fragment        : ARRAY [0..79] OF CHAR;


    PROCEDURE Glom( VAR WhatToGlom : ARRAY OF CHAR );
    BEGIN
        IF ((LengthOf(Name) + LengthOf(WhatToGlom) + 1) <= HIGH(Name)) THEN
            ConcatS(  Name, " "         );
            ConcatLS( Name, WhatToGlom  );
        END;
    END Glom;


BEGIN

    WITH Assignment DO

        (* Name *)

        Copy( Resource^.Name, Name );
        Procustes( Name, NameWidth );


        (* Conflict char *)

        IF (Overloaded IN Attributes) THEN
            Fill( Fragment, ConflictCharacter, 1 );
        ELSE
            SetString( Fragment, " " );
        END;


        (* Type *)

        IF (Resource^.Type = Employable) THEN
            ConcatLS( Fragment, ResourceShortName );
        ELSIF (Resource^.CostStyle = CAmountRateTime) THEN
            ConcatLS( Fragment, VarCostShortName );
        ELSIF (Resource^.CostStyle = CAmountRate) THEN
            ConcatLS( Fragment, UnitCostShortName );
        ELSE
            ConcatLS( Fragment, FixedCostShortName );
        END;

        Glom( Fragment );


        (* $ value *)

        SpentCost := AssignmentDollars( Assignment,
                                     TaskStartDate, TaskEndDate,
                                     AnAssignmentCostTypeSet{
                                            IncludeSpent,
                                            IncludeExtras,
                                            IncludeOvertime} );

        R := AssignmentDollars( Assignment,
                             TaskStartDate, TaskEndDate,
                             AnAssignmentCostTypeSet{
                                    IncludeSpent,
                                    IncludeToGo,
                                    IncludeExtras,
                                    IncludeOvertime} );

        FormatAsCurrency(   R,
                            DefaultCurrencyFormat,
                            Fragment,
                            CurrencySize,
                            TRUE,                (* Right justify? *)
                            TRUE,                (* Show customary fraction? *)
                            TRUE );              (* Include the currency symbol? *)
        Glom( Fragment );

        (* Billable? *)

        IF (Billable IN Attributes) THEN
            Glom( TrueString );
        ELSE
            Glom( FalseString );
        END;


        (* Resource/VarCost specifics: *)

        IF (Resource^.CostStyle = CAmountRateTime) THEN

            P := ORD(PercentageEach);
            IF (P <> 0) THEN
                FormatAsAmount( FLOAT(MaxRatePercent)/FLOAT(P),
                                DefaultAmountFormat, Fragment,
                                HIGH(Fragment), 0, 4, FALSE);
                (* 29-Jan-92 TGS present this as a real now.
                CtoS( MaxRatePercent DIV P, Fragment );
                *)
            ELSE
                SetString( Fragment, "0" );
            END;
            Procustes( Fragment, PeopleSize );
            RJust(     Fragment );
            Glom(      Fragment );

            ConcatS( Name, " @" );

            CtoS( P,   Fragment );
            Procustes( Fragment, PercentSize );
            RJust(     Fragment );
            Glom(      Fragment );

            ConcatS(  Name, "%," );

            LocalUnits := ActualTimeUnits;
            LongDurationToString( (ActualQuantity + YetToGoQuantity),
                                  LocalUnits,
                                  0, 1,
                                  DurationSize,
                                  Fragment, i );
            TrimRear( Fragment );
            ConcatS(  Fragment, "," );
            Glom( Fragment );

            LocalUnits := ActualTimeUnits;
            LongDurationToString( ActualQuantity,
                                  LocalUnits,
                                  0, 1,
                                  DurationSize,
                                  Fragment, i );
            TrimRear( Fragment );
            Glom( Fragment );

            (* 18-Jun-91 TGS
            LocalUnits := Hours;
            LongDurationToString( LongToReal( OvertimeHours ),
                                  LocalUnits,
                                  0, 1,
                                  DurationSize,
                                  Fragment, i );
            TrimRear( Fragment );
            ConcatS(  Fragment, "," );
            Glom( Fragment );

            LocalUnits := Hours;
            LongDurationToString( LongToReal( OvertimeHours
                                            - YetToGoOvertimeHours),
                                  LocalUnits,
                                  0, 1,
                                  DurationSize,
                                  Fragment, i );
            TrimRear( Fragment );
            Glom( Fragment );
            *)

        (* Unit Cost specifics:  *)

        ELSIF (Resource^.CostStyle = CAmountRate) THEN

            R := (ActualQuantity + YetToGoQuantity);
            FormatAsAmount( R,
                            DefaultAmountFormat,
                            Fragment,
                            UnitSize,
                            0,          (* Min Decimals   *)
                            1,          (* Max Decimals   *)
                            FALSE );    (* Right Justify? *)
            TrimRear( Fragment );
            Glom( Fragment );
            Copy( Resource^.UnitOfMeasure, Fragment );
            TrimRear( Fragment );
            ConcatS( Fragment, "," );
            Glom( Fragment );

            FormatAsCurrency( SpentCost,
                              DefaultCurrencyFormat,
                              Fragment,
                              CurrencySize,
                              FALSE,               (* Right justify? *)
                              TRUE,                (* Show customary fraction? *)
                              TRUE );              (* Include the currency symbol? *)
            TrimRear( Fragment );
            Glom( Fragment );

            FormatAsAmount( ActualQuantity,
                            DefaultAmountFormat,
                            Fragment,
                            UnitSize,
                            0,          (* Min Decimals   *)
                            1,          (* Max Decimals   *)
                            FALSE );    (* Right Justify? *)
            TrimRear( Fragment );
            SetString( s1, "(" );
            Insert( Fragment, s1, 1 );
            Glom( Fragment );
            Copy( Resource^.UnitOfMeasure, Fragment );
            TrimRear( Fragment );
            ConcatS( Fragment, ")" );
            Glom( Fragment );


        (* Fixed Cost specifics:  *)

        ELSE
            FormatAsCurrency( SpentCost,
                              DefaultCurrencyFormat,
                              Fragment,
                              CurrencySize,
                              FALSE,               (* Right justify? *)
                              TRUE,                (* Show customary fraction? *)
                              TRUE );              (* Include the currency symbol? *)
            Glom( Fragment ); (* RSC 27-Jun-89 *)
        END;

    END;

END NameTheAssignment;








PROCEDURE CursorNodeToCursorPos(     Tree       : ATree;
                                     CursorNode : ATreeNode ) : CARDINAL;
VAR
    Position    : CARDINAL;
    ThisNode    : ATreeNode;
BEGIN
    (* Save the cursor's relative position.
    *)
    Position    := 0;
    ThisNode    := Tree^.Methods^.GetFirst( Tree );
    WHILE (ThisNode <> NIL) AND (ThisNode <> CursorNode) DO
        INC( Position );
        ThisNode := ThisNode^.Methods^.NextPreOrder( ThisNode );
    END;

    RETURN Position;

END CursorNodeToCursorPos;



PROCEDURE CursorPosToCursorNode(     Tree      : ATree;
                                     CursorPos : CARDINAL ) : ATreeNode;
VAR
    CursorNode : ATreeNode;
BEGIN
    CursorNode := Tree^.Methods^.GetFirst( Tree );
    WHILE (CursorNode <> NIL) AND (CursorPos > 0) DO
        DEC( CursorPos );
        CursorNode := CursorNode^.Methods^.NextPreOrder( CursorNode );
    END;

    RETURN CursorNode;

END CursorPosToCursorNode;








PROCEDURE GoToCheckProc(    Outline     : AnOutlineView;
                            Tree        : ATree;
                        VAR Code        : ACode         );
CONST
    ResynchCode     = 511;
VAR
    OldCursorPos        : CARDINAL;
    CursorNode          : ATreeNode;
    NextNode,
    RsrcNode            : ATreeNode;
    Assignment          : AnAssignmentPointer;



    (* Convince GoTo not to crash the machine.
    *)
    PROCEDURE Resynch(     CursorNode    : ATreeNode );
    VAR
        FirstNode   : ATreeNode;
    BEGIN
        FirstNode := Tree^.Methods^.GetFirst( Tree );
        IF (CursorNode = NIL) THEN
            CursorNode := FirstNode;
        END;
        Outline^.Methods^.SetFirst( Outline, FirstNode );
        Outline^.Methods^.SetCursorNode( Outline, CursorNode );

        Code := ResynchCode; (* RESYNCH ME, PLEASE, Mr. GoTo! *)

    END Resynch;




    PROCEDURE Recalc( VAR CursorNode    : ATreeNode );
    VAR
        ThisNode    : ATreeNode;
        Task        : ATaskPtr;
        ToGo        : AnAssignmentSummary;
        Completed   : AnAssignmentSummary;
        Position    : CARDINAL;
        ok          : BOOLEAN;
    BEGIN

        IF (CursorNode <> ATreeNode(NIL)) THEN

            (* Save the cursor's relative position.
            *)
            Position   := CursorNodeToCursorPos( Tree, CursorNode );

            (* Do the recalc.
            *)
            WITH GlobalContext DO
                ComputeTaskNodeCosts( TaskNode );
                SummTaskNodeAmounts(  TaskNode, FALSE, Completed, ToGo );
                Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
                Task^.ToGoSummary := ToGo;
                Task^.CompletedSummary := Completed;
                TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
            END;
            (* Restore the curosr.
            *)
            CursorNode := CursorPosToCursorNode( Tree, Position );
        END;

        (* Resynch GoTo.
        *)
        Resynch( CursorNode );

    END Recalc;




    (* Edit or Insert key has been hit. *)
    
    PROCEDURE EditAssignment( VAR Node : ATreeNode ) : BOOLEAN;
    VAR
        EditAssignment  : AnAssignmentPointer;
        ReleaseHandle   : AnExtHandle;
        Position        : CARDINAL;
        ok              : BOOLEAN;
    BEGIN

        ok := TRUE;

        IF (Node = NIL) THEN
            ok  := FALSE;  (* 25-Oct-89 RSC removed Burp for bug 1605. *)
        ELSE
            GetAssignmentPointerFromTree( Node, GlobalContext, EditAssignment, ReleaseHandle );
            Position       := CursorNodeToCursorPos(  Tree, Node );

            ok := DoAssignmentForm( GlobalContext.TaskNode, EditAssignment );

            ReleaseObject( ReleaseHandle );

            Node := CursorPosToCursorNode( Tree, Position );
        END;

        RETURN ok;

    END EditAssignment;



BEGIN
    IF (GlobalContext.TaskNode = ATreeNode(NIL)) THEN
        FatalError(); (* Not set up right! *)
    END;


    CursorNode := Outline^.Methods^.GetCursorNode( Outline );
    IF (CursorNode <> NIL) THEN
        Assignment := CursorNode^.Methods^.GetDataObject( CursorNode );
    END;


    (* Based on the key typed, do something.
    *)
    CASE Code OF
        DoIt,
        EditKey     :

            IF (EditAssignment( CursorNode )) THEN
                Recalc( CursorNode );
                NeedsRecalc := TRUE;
            ELSE
                Code := 0; (* Otherwise, we would exit back to the GoTo client. *)
            END;


      | InsertKey   :

        (* 23-Aug-90 RSC Removed initial positioning.
        *)
(*            IF (CursorNode <> NIL) THEN*)
(*                RsrcNode := FindResourceByName( Assignment^.Resource^.Name );*)
(*                IF (RsrcNode = NIL) THEN FatalError(); END; (* WHA? *)*)
(*            ELSE*)
                RsrcNode := NIL;
(*            END;*)

            IF (SelectResource(RsrcNode)) THEN
                OldCursorPos := CursorNodeToCursorPos( Tree, CursorNode );
                IF (AddADefaultAssignmentToTree( Tree, RsrcNode, GlobalContext, CursorNode )) THEN
                    Recalc( CursorNode );  (* The initial calc *)
                    IF (EditAssignment( CursorNode )) THEN
                        NeedsRecalc := TRUE;
                    ELSE
                        DisposeOfAssignmentNodeAndData( CursorNode, GlobalContext );
                        CursorNode := CursorPosToCursorNode( Tree, OldCursorPos );
                    END;
                    Recalc( CursorNode );  (* The final calc. *)
                END;
            END;


      | DeleteKey   :

            IF (CursorNode <> NIL) THEN
                DisposeOfAssignmentNodeAndData( CursorNode, GlobalContext );
                Recalc( CursorNode );
                NeedsRecalc := TRUE;
            ELSE
                Burp;
            END;

       | ExitKey    :

            IF (NOT CheckResources( GlobalContext.TaskNode, Tree, GlobalContext ))  THEN
                Code := 0; (* Don't let them leave. *)
            END;

    ELSE
    END;

END GoToCheckProc;












(* GoTo Name Proc

    This is a procedure that supplies "names" to GoTo, For the
    Edit Assignments proc

    Preconditions
                    AssNode     is the assignment tree node to
                                   return a name for.

    Postconditions
                    Name        is the returned text string.
*)
PROCEDURE GoToNameProc(     AssNode : ATreeNode;
                        VAR Name    : ARRAY OF CHAR);
VAR
    StartDate,
    EndDate         : ADate;
    ReleaseHandle   : AnExtHandle;
    Task            : ATaskPtr;
    Assignment      : AnAssignmentPointer;
BEGIN
    IF (AssNode = ATreeNode(NIL)) THEN
        SetLengthOf(Name,0);
        RETURN;
    END;

    WITH GlobalContext DO
        IF (TaskNode = ATreeNode(NIL)) THEN
            FatalError(); (* Not set up right! *)
        END;

        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        WITH Task^.Plan.Dates DO
            StartDate := EarlyStart;
            EndDate   := EarlyEnd;
        END;
        TaskNode^.Methods^.UnlockUnchangedDataObject(TaskNode);
    END;

    GetAssignmentPointerFromTree( AssNode, GlobalContext, Assignment, ReleaseHandle );

    NameTheAssignment( Assignment^, StartDate, EndDate, Name );

    ReleaseUnchangedObject( ReleaseHandle );

END GoToNameProc;








(* Edit Assignment List

        Edit the list of assignments for a task.  This does all the needed
        management of creating the assignment tree, calling GoTo, etc.

    Preconditions
                    TaskNode        Is the task the assignments belong to.

    Postconditions
                    The task's list of assignments has been edited,
                    TRUE  means that the changes were accepted,
                    FALSE means that they were not.
*)
PROCEDURE EditAssignmentList(     TaskNode      : ATreeNode
                            ) : BOOLEAN;
CONST
    FirstCol    = 1;
    LastCol     = 78;
VAR
    AssTree     : ATree;
    CursorNode  : ATreeNode;
    TaskPtr     : ATaskPtr;
    Title       : ARRAY [0..79] OF CHAR;
    ok          : BOOLEAN;
BEGIN
    NeedsRecalc    := FALSE;


    (* Create the assignment tree. *)

    IF (NOT HeapAvailable())       OR
       (NOT CreateTree( AssTree )) THEN
        RETURN FALSE;
    END;


    (* Fill it in. *)

    ok := (PutAssignmentsInATree( TaskNode, AssTree, GlobalContext ));

    IF (ok) THEN
        GetMessage( ModuleNumber + 5, Title ); (* "Assignments for " RSC 5-Jun-89 *)
        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        ConcatLS( Title, TaskPtr^.taskname );
        TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

        CursorNode := AssTree^.Methods^.GetFirst( AssTree );

        ok := (DoGoToWithPrompts(   (* 7-Aug-90 RSC Was DoGoTo *)
                       AssTree,
                       FirstCol, GanttWStart + 3, LastCol, GanttWEnd - 6, (* RSC 5-Jun-89 *)
                       Title,
                       TRUE,        (* OpenTree *)
                       GoToCheckProc,
                       GoToNameProc,
                       GoToNameProc,
                       ABoxType{HasInsert, HasDelete},         (* 01-Aug-91 *)
                       CursorNode ));
    END;

    DisposeOfAssignmentNodes(  AssTree, GlobalContext );
    AssTree^.Methods^.Discard( AssTree );

    IF (ok AND NeedsRecalc) THEN                               (* 16-Jul-91 *)
        UnSetState (Scheduled);
        UnSetState (Filtered);
        ScheduleSaved := FALSE;
        TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );
        INCL( TaskPtr^.TaskStatusSet, NeedsRecalculate );
        TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );
    END;

    RETURN ok;

END EditAssignmentList;







PROCEDURE Init();
VAR
    i,
    SizeOfLargestTF,
    SizeOfLargestResourceType   : CARDINAL;
    s                           : ARRAY [0..99] OF CHAR;
    s1                          : ARRAY [0..19] OF CHAR;
BEGIN

    SizeOfLargestResourceType := 0;
    GetMessage( ModuleNumber + 3, s );  (* "Res,Var,Fix,Unit" *)
    FOR i := 1 TO 4 DO
        WordNumber( s, i, s1 );
        IF (LengthOf( s1 ) > SizeOfLargestResourceType) THEN
            SizeOfLargestResourceType := LengthOf( s1 );
        END;
    END;
    WordNumber( s, 1, ResourceShortName );
    Procustes(        ResourceShortName,  SizeOfLargestResourceType );
    WordNumber( s, 2, VarCostShortName );
    Procustes(        VarCostShortName,   SizeOfLargestResourceType );
    WordNumber( s, 3, FixedCostShortName );
    Procustes(        FixedCostShortName, SizeOfLargestResourceType );
    WordNumber( s, 4, UnitCostShortName );
    Procustes(        UnitCostShortName,  SizeOfLargestResourceType );


    GetMessage( ModuleNumber + 4, s );  (* "Bill,Free" *) (* 18-Jun-91 TGS *)
    SizeOfLargestTF := 0;
    FOR i := 1 TO 2 DO
        WordNumber( s, i, s1 );
        IF (LengthOf( s1 ) > SizeOfLargestTF) THEN
            SizeOfLargestTF := LengthOf( s1 );
        END;
    END;
    WordNumber( s, 1, TrueString );
    Procustes(        TrueString,   SizeOfLargestTF );
    WordNumber( s, 2, FalseString );
    Procustes(        FalseString,  SizeOfLargestTF );

END Init;



BEGIN

    Init();

END AssListEdit.



