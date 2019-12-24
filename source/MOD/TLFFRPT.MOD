MODULE TLFFRpt;


(*  =========================================================================

    Free-Form report

    Reads a report specification from a text file and uses it to prepare a
    report.

    The basic operation of the report is to print a section of text for each 
    task or resource, replacing keywords in the text with the values of the
    columns that they identify.  
    
    When printing tasks, any column available on the tasks spreadsheet is 
    permitted, as well as any keyword available for report headers.

    A new page may be started by a line beginning "NEWPAGE".

    Optionally, notes text and assignments to the task can also be reported
    by the inclusion of lines reading "LIST NOTES" and "LIST ASSIGNMENTS"
    among the task lines.  

    Any keywords found in the notes to a task are similarly expanded.  Notes
    are printed up to their end or a line beginning ".ENDPRINT".

    To print assignments, a section of the file must be identified beginning
    with a line starting "SECTION=ASSIGNMENTS".

    When assignments are printed, keywords that identify assignment, resource
    and task columns can be used.

    The special character (default ".") that begins each output line is
    changeable by the command ".CONTROL=<New Character>".

    Lines beginning "--" are comments.

    Each script file consists of several sections:
        MAIN         Contains commands (such as .LIST TASKS) that control
                       the main looping of the program.
        TASKS        Format and commands for each task that is printed.
        RESOURCES    Format and commands for each resource that is printed.
        ASSIGNMENTS  Format and commands for each assignment printed.
        PREDECESSORS Format and commands for predecessors of the task.
        SUCCESSORS   Format and commands for successors of the task.

    See a sample template at the end of this source file.

    Future enhancements:

    LIST x ORDER BY expression
    LIST x WHERE condition
    LIST x USING section
    INDENT
    TOTAL field
    KEEP (prints the entire section on a page, rather than splitting
          over boundaries)
    LIST {DAYS,WEEKS,MONTHS,YEARS}



    Modification History:

    23-Dec-91  AJL  -Initial version.

*)

FROM Allocs                 IMPORT
    (* TYPE  *)                 ATaskFilter, ATaskFilterSet, ATaskPtr,
    (* VAR   *)                 TaskTree;

FROM ASCII                  IMPORT EOL;

FROM AssColumns             IMPORT
    (* PROCS *)                 CreateAssColumnsTree, DisposeAssColumnsTree,
                                PickAssColumn, SearchForAssColumn,
                                GetAssgColumnName;

FROM AssFormat              IMPORT
    (* VAR   *) (* PROC *)      GetAssString, GetAssInfo;

FROM Assignments            IMPORT
    (* TYPE *)                  AnAssignmentRecord, AnAssignmentArray;
    
FROM Boxes                  IMPORT
                                ABoxAttribute, ABoxType;


FROM Captions               IMPORT
    (* TYPE  *)                 AColumnInfoChoice, AColumnDataRecord,
                                AColumnDataField, ASetOfColumnDataFields,
    (* VAR   *) (* PROC *)      GetColumnString, GetColumnInfo;

FROM Dialog                 IMPORT
    (* PROC  *)                 FatalError, Error, Burp, NotYetImplemented,
                                ADialogOption, MultipleChoiceBox;

FROM Direct411              IMPORT
    (* PROC *)                  GiveDirectoryAssistance, AlwaysApprove,
                                DontAllowZero;

FROM Directory              IMPORT
        (* CONST *)             MaximumFileNameLength, MaximumExtensionLength,
                                MaximumDeviceNameLength, MaximumPathNameLength,
        (* TYPES *)             AFileNameRecord,
                                AFileNamePart, ASetOfFileNameParts,
        (* PROC *)              NormalizeFileName;

FROM Edges                   IMPORT
    (* TYPE  *)                 AnEdgePtr,
    (* PROC *)                  CheckEdgeValid;

FROM EdgeColumns            IMPORT
    (* PROCS *)                 CreateEdgeColumnsTree,
                                DisposeEdgeColumnsTree, SearchForEdgeColumn;

FROM EdgeFormat             IMPORT
    (* PROC *)                  GetEdgeString, GetEdgeInfo;

FROM Edits                  IMPORT
    (* PROC *)                  EditText;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
                                LockObjectArray, ReleaseUnchangedObject;
    
FROM FileSystem IMPORT  File, Response, OpenFile, Close, ReadChar,
                        FullAccessMode, ReadOnlyMode, 
                        Reset;

FROM FileAux    IMPORT  FileResultMeans, PrepareForIO, CheckIO,
                        TextPath, DisplayFileError;

FROM Filter1                IMPORT
    (* PROC  *)                 TaskFiltersPassed, AssignmentFiltersPassed,
                                ResourceFiltersPassed;

FROM Gantt                  IMPORT
    (* TYPE *)                  AGanttLineType;

FROM Kbio                   IMPORT
        (* TYPE *)              ascreeny;

FROM KeywdSub               IMPORT
     (* PROC *)                 MakeSubstitutions;

FROM Layout                 IMPORT
    (* VAR   *)                 GanttWStart, GanttWEnd, MaxColumn;

FROM LStrings               IMPORT
    (* PROC  *)                 ConcatLS, Copy, CtoS, Fill, LengthOf,
                                Search, SetLengthOf, SubStr, TrimFront,
                                ConcatS, Insert, LJust, StoC, Upshift,
                                Procustes, TrimRear, RJust, SetString,
                                LStringToTString, Remove, StringsEqual;

FROM MsgFile                IMPORT
    (* PROC  *)                 GetMessage, ConcatMessage;

FROM PrintCaptions          IMPORT
    (* PROC  *)                 FilterNotes, PageHead;

FROM PrintSupport           IMPORT
    (* VAR   *)                 Stopped,
    (* PROC  *)                 PageWidth, PrintLine,  PrintText,
                                EndReport, StartReport, RowsLeft,
                                AllowUnlimitedPageLength, PageTop,
                                StartPage, SetPageCaptionProcedures;

FROM RsrcColumns            IMPORT
    (* PROCS *)                 CreateRsrcColumnsTree, PickRsrcColumn,
                                DisposeRsrcColumnsTree, SearchForRsrcColumn,
                                GetRsrcColumnName;

FROM RsrcFormat             IMPORT
    (* PROC *)                  GetRsrcString, GetRsrcInfo;

FROM RsrcMod                IMPORT
    (* TYPE  *)                 AResourcePointer, 
    (* VAR   *)                 ResourceTree;

IMPORT SchedKey;

FROM Schedule               IMPORT
    (* VAR *)                   ProjectText;

FROM Searcher               IMPORT
    (* PROC *)                  PatternSearch;

FROM SegWords               IMPORT
    (* PROC *)                  WordNumber;

FROM Space                  IMPORT
    (* PROC  *)                 ALLOCATE,DEALLOCATE;

FROM SYSTEM                 IMPORT
                                ADDRESS, ADR, TSIZE;

FROM TaskColumns            IMPORT
    (* PROCS *)                 CreateTaskColumnsTree, PickTaskColumn,
                                DisposeTaskColumnsTree, SearchForTaskColumn,
                                GetTaskColumnName;

FROM Text                   IMPORT
    (* PROC  *)                 LineExists, CopyLine, CreateText, DiscardText,
                                AText, AppendLine;

FROM TreeObjects            IMPORT
    (* TYPE  *)                 ATreeNode, ATreeOrder,
    (* PROC *)                  ValidateTreeNode;





CONST
    ModuleNumber        =   30900;
    MaxWidth            =   255;
    Normal              =   0;
    Bold                =   1;
    MaxNumberLength     =   15;
    WarningLimit        =   5;    (* Stop printing warnings after this many. *)

TYPE
    ASourceTypeRecord       = RECORD
                                  ExtTemplate   : ARRAY [0..MaximumExtensionLength] OF CHAR;
                              END;

    ALineType               = ( Comment, Control, Display );    
                                  (* List control sections. *)
    ASection                = ( PageHeaderSection,       (* Top of each page *)
                                PageFooterSection,       (* End of each page *)
                                MainSection,             (* Main loop. *)
                                TasksSection,            (* For each task *)
                                ResourcesSection,        (* For each resource *)
                                AssignmentsSection,      (* For each assignment *)
                                PredecessorsSection,     (* For each precedessor *)
                                SuccessorsSection );     (* For each successor *)

    ATemplateTextArray      = ARRAY ASection OF AText;
    AnAssignmentContext     = RECORD
                                  TaskNode   : ATreeNode;
                                  Task       : ATaskPtr;
                                  Assignment : POINTER TO AnAssignmentRecord;
                              END;
    AnAssignmentContextPtr  = POINTER TO AnAssignmentContext;

VAR
        (* These records are used to avoid displaying files that we
           know are data files. *)
    SourceTypes             : ARRAY [1..21] OF ASourceTypeRecord;
    MaxSources              : CARDINAL;
        (* Keywords that control the organization of the report. *)
    DisplayIndicator        : ARRAY [0..31] OF CHAR;    (* Start of each command line or comment. *)
    CommentIndicator        : ARRAY [0..31] OF CHAR;    (* Comment command *)
    ControlKeywords         : ARRAY [0..255] OF CHAR;   (* List of control words. *)
        (* Each section of the report has a text template. *)
    TemplateText            : ATemplateTextArray;
        (* *)
    PageNumber              : CARDINAL;   (* Current page number. *)
    WarningsPrinted         : CARDINAL;   (* Number displayed so far. *)



(**Begin**** Get a node from node pointer, this may be deleted later  *****)

MODULE RsrcNode;

    IMPORT  AResourcePointer, ResourceTree, ADDRESS, ADR, TSIZE,
            ATreeNode, ATreeOrder, FatalError;

    EXPORT  GetResourceNodeFromPointer;




(****************************************************************************
    GetResourceNodeFromPointer  -
        Given a resource pointer, returns a resource node.
****************************************************************************)
PROCEDURE GetResourceNodeFromPointer(Resource : AResourcePointer) : ATreeNode;
VAR
    RsrcNode                :   ATreeNode;
BEGIN
    RsrcNode := ResourceTree^.Methods^.GetFirst(ResourceTree);
    WHILE ( RsrcNode <> NIL ) DO
        IF ( RsrcNode^.Methods^.GetDataObject( RsrcNode ) = Resource ) THEN
            RETURN RsrcNode;
        END;
        RsrcNode := RsrcNode^.Methods^.GetNext(RsrcNode);
    END;
    FatalError();
END GetResourceNodeFromPointer;
END RsrcNode;

(** End **** Get a node from node pointer, this may be deleted later  *****)








PROCEDURE GetDataFileExtensions();
VAR
    S : ARRAY [0..255] OF CHAR;
    TempS             : ARRAY [0..25] OF CHAR;
    ExtensionIndex, i, j : CARDINAL;
BEGIN
        (* Blacklisted file extensions. *)
    GetMessage(ModuleNumber+1,S);  (* e.g. "5T?,T$?,T#?,T@?,5?V,TG1,TW1,M$0,5M0,BAT,EXE,DAT,OVL,ZIP,ARC" *)

    MaxSources := 0;
    LOOP
        WordNumber(S,MaxSources+1,TempS);
        IF (LengthOf(TempS)=0) THEN
            EXIT;
        END;
        INC(MaxSources);
        i := 1;
        Copy(TempS, SourceTypes[MaxSources].ExtTemplate );
    END;
END GetDataFileExtensions;
 


  (* Analyze Extension -

        Given an extension, find out if it is in our list of special
        (blacklisted) extensions.
  *)
PROCEDURE AnalyzeExtension( VAR Extension  : ARRAY OF CHAR;
                            VAR Index      : CARDINAL
                          ) : BOOLEAN;
BEGIN
    Upshift(   Extension );
    Procustes( Extension, 3 );

        (* Get a list of extension templates and the overlay to read them. *)
        (* Compare each template against the actual extension.  If they match, *)
        (* use that linker. *)

    Index := 1;
    WHILE (Index <= MaxSources) DO
        WITH SourceTypes[Index] DO
            IF (PatternSearch(Extension,ExtTemplate)=1) THEN
                RETURN TRUE;
            END;
        END;
        INC(Index);
    END;

    RETURN FALSE;
END AnalyzeExtension;







PROCEDURE FilterValidFiles( FileNameRecord : AFileNameRecord ) : BOOLEAN;
VAR
    Index           : CARDINAL; 
BEGIN
    IF (FileNameRecord.Size =  0) THEN
        RETURN FALSE;
    ELSE
        RETURN NOT AnalyzeExtension( FileNameRecord.Extension,
                                     Index );
    END;
END FilterValidFiles;


    (* SelectAFile -- Pick a file to use for a report template.
                      Avoid certain file extensions that reflect 
                      data or executable files. 
                      *)




PROCEDURE SelectAFile( VAR FileName : ARRAY OF CHAR ): BOOLEAN;
VAR
    TopY, BottomY : ascreeny;
    s : ARRAY [0..81] OF CHAR;
    Title : ARRAY [0..0] OF CHAR;
BEGIN
    TopY    := GanttWStart+2;
    BottomY := GanttWEnd-2;
    SetLengthOf(Title,0);
    SetString(s,"*.*");
    IF (NOT GiveDirectoryAssistance( TopY, BottomY, Title,
                                     s,
                                     FileName, (* CURSOR NAME *)
                                     FilterValidFiles)) THEN
        RETURN FALSE;
    END;
    Copy(s,FileName);
    RETURN TRUE;
END SelectAFile;



PROCEDURE FileComplaint( VAR F : File );
VAR
    S : CHAR;
BEGIN
    S := 0C;
    DisplayFileError(F,S);
END FileComplaint;




PROCEDURE LookupTemplateFile  ( VAR FNam : ARRAY OF CHAR;
                                VAR F    : File          ) : BOOLEAN;

VAR
    Res         : Response;
    FileName    : ARRAY [0..99] OF CHAR;

BEGIN
    Copy(FNam,FileName);
    NormalizeFileName(FileName, ASetOfFileNameParts{DevicePart..ExtensionPart});
    LStringToTString( FileName, FileName );
    PrepareForIO(F);
    OpenFile(F, FileName, FullAccessMode + ReadOnlyMode); 
    Res := CheckIO(F);

    IF (Res <> done) THEN
        FileComplaint(F);
        RETURN FALSE;
    END;

    RETURN TRUE;
END LookupTemplateFile;









PROCEDURE GetString ( VAR f     : File;
                      VAR s     : ARRAY OF CHAR );
VAR
    i : CARDINAL;
    C : CHAR;
BEGIN
    i := 0;
    LOOP
        PrepareForIO(f);
        s[0] := CHR(i);
        ReadChar(f,C);
        IF (f.eof) THEN
            EXIT;
        ELSIF (CheckIO(f) <> done) THEN
            FileComplaint(f);
            EXIT;
        ELSIF (C = EOL) THEN
            EXIT;
        ELSIF (i < HIGH(s)) THEN
            INC(i);
            s[i] := C;
        ELSE
            EXIT;           (* Line too long. *)
        END;
    END;
END GetString;




PROCEDURE ReadFileIntoText( VAR FileName : ARRAY OF CHAR;
                                Text     : AText ): BOOLEAN;
VAR
    F : File;
    S : ARRAY [0..255] OF CHAR;
BEGIN
    IF NOT LookupTemplateFile( FileName, F ) THEN
        RETURN FALSE;
    END;

        (* Read lines of text from the source and put them into the
           internal text. *)

    LOOP
        GetString(F,S);
        IF (F.eof) OR (CheckIO(F) <> done) THEN
            EXIT;
        END;
        IF (NOT AppendLine(S,Text)) THEN
            Close(F);
            RETURN FALSE;
        END;
    END;

    Close (F);
    RETURN TRUE;
END ReadFileIntoText;




PROCEDURE SelectAReport( VAR Text : AText ) : BOOLEAN;
VAR
    FileName : ARRAY [0..79] OF CHAR;
BEGIN
        (* Select a file. *)

    SetLengthOf(FileName,0);
    IF (NOT SelectAFile(FileName)) THEN
        RETURN FALSE;
    END;

        (* Read the file into the text. *)

    RETURN ReadFileIntoText(FileName,Text);

END SelectAReport;






PROCEDURE DetermineLineType( VAR S : ARRAY OF CHAR ) : ALineType;
VAR
    i : CARDINAL;
BEGIN
    IF (LengthOf(S)=0) THEN
        RETURN Comment;
    ELSIF (S[1]=CommentIndicator[1]) AND (Search(S,CommentIndicator,1)=1) THEN
        RETURN Comment;
    ELSIF (S[1]=DisplayIndicator[1]) AND (Search(S,DisplayIndicator,1)=1) THEN
        RETURN Display;
    ELSE
        RETURN Control;
    END;
END DetermineLineType;









    (* GetAssgnKeyWordValue --
       
       Given an assignment of a resource to a task, and a keyword
       identifying a column, return a printable keyvalue which is the
       value of that column of the assignment table, resource table
       or task table, in that search order. 

       *)


PROCEDURE GetAssgnKeyWordValue( VAR Keyword : ARRAY OF CHAR;
                                VAR KeyValue : ARRAY OF CHAR;
                                    Context  : ADDRESS );
VAR
    ColumnId : CARDINAL;
    i, j : CARDINAL;
    AssignmentContext : AnAssignmentContextPtr;
BEGIN
    AssignmentContext := AnAssignmentContextPtr(Context);

    SetLengthOf(KeyValue,0);

        (* Lookup the Keyword to find what column it refers to.  Lookup
           that column value for the current assignment.  Failing to find
           one of those, look up a value for the assigned resource, or
           the current task. *)
    IF SearchForAssColumn(Keyword,ColumnId) THEN
        IF (GetAssString(AssignmentContext^.Assignment^,
                         AssignmentContext^.Task,
                         ColumnId, HIGH(KeyValue), KeyValue)) THEN
            LJust(KeyValue);
            TrimRear(KeyValue);
        ELSE
            SetLengthOf(KeyValue,0);
        END;
    ELSIF SearchForRsrcColumn(Keyword,ColumnId) THEN
        IF (GetRsrcString(
            GetResourceNodeFromPointer(AssignmentContext^.Assignment^.Resource),
                          ColumnId, HIGH(KeyValue), KeyValue )) THEN
            LJust(KeyValue);
            TrimRear(KeyValue);
        ELSE
            SetLengthOf(KeyValue,0);
        END;
    ELSE   (* Not an assignment keyword.  Try a task keyword. *)
        GetTaskKeyWordValue(Keyword,KeyValue,AssignmentContext^.TaskNode);
    END;
END GetAssgnKeyWordValue;





    (* MailMerge -- Modify the text line S so that keywords are
                    substituted into it, referring to the column
                    values of the current assignment. *)

PROCEDURE MailMergeAssignment(     TaskNode   : ATreeNode;
                                   TaskPtr    : ATaskPtr;
                               VAR Assignment : AnAssignmentRecord;
                               VAR S    : ARRAY OF CHAR );
VAR
    AssignmentContext : AnAssignmentContext;
BEGIN
    AssignmentContext.TaskNode   := TaskNode;
    AssignmentContext.Task       := TaskPtr;
    AssignmentContext.Assignment := ADR(Assignment);
        (* Substitute for any embedded keywords. *) 
    MakeSubstitutions(S,HIGH(S),
                      GetAssgnKeyWordValue,ADR(AssignmentContext)); 
END MailMergeAssignment;


PROCEDURE UnknownCommand(VAR S : ARRAY OF CHAR);
VAR
    S2 : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+2,S2);    (* "Unknown command: " *)
    ConcatLS(S2,S);
    IF (WarningsPrinted >= WarningLimit) THEN
        Error(S2);
        INC(WarningsPrinted); 
    END;
END UnknownCommand;




PROCEDURE GetTaskKeyWordValue( VAR Keyword : ARRAY OF CHAR;
                               VAR KeyValue : ARRAY OF CHAR;
                                   Context  : ADDRESS );
VAR
    ColumnId : CARDINAL;
    i, j : CARDINAL;
    TaskNode : ATreeNode;
    Task : ATaskPtr;
BEGIN
    TaskNode := ATreeNode(Context);
    ValidateTreeNode(TaskNode);

    SetLengthOf(KeyValue,0);

        (* Lookup the Keyword to find what column it refers to.  Lookup
           that column value for the current task. *)
    IF SearchForTaskColumn(Keyword,ColumnId) THEN
        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        IF (GetColumnString(TaskNode, Task, ColumnId, Plan, HIGH(KeyValue), KeyValue)) THEN
            LJust(KeyValue);
            TrimRear(KeyValue);
        ELSE
            SetLengthOf(KeyValue,0);      (* No value on this this field/this task. *)
        END;
        TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);
    ELSE
            (* Try to look up the keyword as a schedule-level item.  This
               uses the same keywords as the report form header. *)
        SetLengthOf(KeyValue,0);
        SchedKey.GetKeyWordValue(Keyword,KeyValue,NIL);
            (* Prepare an error message. *)
        IF (LengthOf(KeyValue)=0) THEN
            UnknownCommand(Keyword);
            GetMessage(ModuleNumber+3,KeyValue);    (* "??? " *)
            ConcatLS(KeyValue,Keyword);
        END;
    END;
END GetTaskKeyWordValue;








    (* MailMerge -- Modify the text line S so that keywords are
                    substituted into it, referring to the column
                    values of the current task. *)

PROCEDURE MailMergeTask( VAR TaskNode : ATreeNode;
                         VAR S    : ARRAY OF CHAR );
BEGIN
        (* Substitute for any embedded keywords. *) 
    MakeSubstitutions(S,HIGH(S),
                      GetTaskKeyWordValue,TaskNode); 
END MailMergeTask;








PROCEDURE QueryCommandNumber( VAR Command : ARRAY OF CHAR;
                              VAR ListOfCommands : ARRAY OF CHAR ) : CARDINAL;
VAR
    CommandNumber : CARDINAL;
    S3            : ARRAY [0..31] OF CHAR;
BEGIN
        (* Convert the command string to a number. *)
    CommandNumber := 1;
    LOOP
        WordNumber(ListOfCommands,CommandNumber,S3);
        IF (LengthOf(S3)=0) THEN
            CommandNumber := 0;  (* Not found. *)
            EXIT;
        ELSIF (StringsEqual(Command,S3)) THEN
            EXIT;
        END;
        INC(CommandNumber);
    END;

    RETURN CommandNumber;
END QueryCommandNumber;



PROCEDURE ExtractArgument( VAR S : ARRAY OF CHAR;
                               i : CARDINAL;
                           VAR Argument : ARRAY OF CHAR ) : BOOLEAN;
VAR
    Len : CARDINAL;
BEGIN
    Len := LengthOf(S);
    WHILE (i <= Len) AND ((S[i]=" ") OR (S[i]="=")) DO
        INC(i);
    END;

    IF (Len >= i) THEN
        SubStr(S,Argument,i,Len-i+1);
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;

END ExtractArgument;







PROCEDURE ListProjectNotes( VAR EndAt : ARRAY OF CHAR);
VAR
    S : ARRAY [0..MaxWidth] OF CHAR;
    N : CARDINAL;
    Done : BOOLEAN;
BEGIN
    N := 0;
    Done := FALSE;
    WHILE (LineExists(ProjectText,N)) AND (NOT (Stopped OR Done)) DO
        CopyLine(ProjectText,N,S);
        IF (Search(S,EndAt,1)=1) THEN
            Done := TRUE;
        ELSE
            MailMergeSchedule(S);
            PrintText(S,Normal);
            SetLengthOf(S,0);   PrintLine(S,Normal);
        END;
        INC(N);
    END;
END ListProjectNotes;










    (* List the notes of the task, expanding any embedded keywords.
       Stop, however, if we hit any line beginning with EndAt. *)

PROCEDURE ListTaskNotes(     TaskNode : ATreeNode;
                          VAR EndAt : ARRAY OF CHAR);
VAR
    Task : ATaskPtr;
    Text : AText;
    S : ARRAY [0..MaxWidth] OF CHAR;
    N : CARDINAL;
    Done : BOOLEAN;
BEGIN
    IF (TaskNode = ATreeNode(NIL)) THEN
        RETURN;
    END;

    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    Text := Task^.notes;
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);

    N := 0;
    Done := FALSE;
    WHILE (LineExists(Text,N)) AND (NOT (Stopped OR Done)) DO
        CopyLine(Text,N,S);
        IF (Search(S,EndAt,1)=1) THEN
            Done := TRUE;
        ELSE
            MailMergeTask(TaskNode,S);
            PrintText(S,Normal);
            SetLengthOf(S,0);   PrintLine(S,Normal);
        END;
        INC(N);
    END;

END ListTaskNotes;




    (* Make Template -- Transform the string into a template for
                        output. *)


PROCEDURE MakeTemplate( VAR S : ARRAY OF CHAR );
BEGIN
    Remove(S,1,LengthOf(DisplayIndicator));
END MakeTemplate;





PROCEDURE ReportOneAssignment(     TaskNode : ATreeNode;
                                   Task     : ATaskPtr;
                               VAR Assignment : AnAssignmentRecord;
                                   AssignmentsText : AText );
VAR
    S : ARRAY [0..MaxWidth] OF CHAR;
    N : CARDINAL;
BEGIN
    N := 0;
    WHILE (LineExists(AssignmentsText,N)) AND (NOT Stopped) DO
        CopyLine(AssignmentsText,N,S);
            (* Analyze the type of line. *)
        CASE DetermineLineType( S ) OF 
            Comment :
          | Control :
                        (* Controls are not allowed in assignments section
                           because they might lead to infinite recursion. *)
                        (* DoControl(S,TaskNode); *)
          | Display :
                        IF (Selected IN AssignmentFiltersPassed(TaskNode,
                                                                Assignment)) THEN
                            MakeTemplate(S);
                            MailMergeAssignment(TaskNode,Task,Assignment,S);
                            PrintText(S,Normal);
                            SetLengthOf(S,0);   PrintLine(S,Normal);
                        END;
        END;
        INC(N);
    END;
END ReportOneAssignment;






PROCEDURE ReportEachAssignmentToTask( TaskNode : ATreeNode;
                                AssignmentsText : AText );
VAR
    AssignmentsHandle : AnExtHandle;
    Assignments : AnAssignmentArray;
    Task        : ATaskPtr;
    Count       : CARDINAL;
    i           : CARDINAL;
BEGIN
    IF (TaskNode = ATreeNode(NIL)) THEN
        RETURN;
    END;

    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    AssignmentsHandle := Task^.Plan.Assignments; 

    Count := LockObjectArray( AssignmentsHandle,
                              Assignments, TSIZE( AnAssignmentRecord ) );

    IF (Count > 0) THEN
        FOR i := 0 TO Count-1 DO
            ReportOneAssignment( TaskNode, Task, Assignments^[i], AssignmentsText );
        END;
    END;

    ReleaseUnchangedObject(AssignmentsHandle);
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);

END ReportEachAssignmentToTask;




TYPE
    AnEdgeContext = RECORD
                        Edge          : AnEdgePtr;
                        OtherTaskNode : ATreeNode;
                    END;


PROCEDURE GetEdgeKeyWordValue( VAR Keyword : ARRAY OF CHAR;
                               VAR KeyValue : ARRAY OF CHAR;
                                   Context  : ADDRESS );
TYPE
    AnEdgeContextPointer = POINTER TO AnEdgeContext;
VAR
    ColumnId : CARDINAL;
    i, j : CARDINAL;
    EdgeContext : AnEdgeContextPointer;
    Edge : AnEdgePtr;
    Task, PredecessorTask, SuccessorTask : ATaskPtr;
    OtherTaskNode : ATreeNode;

BEGIN
    EdgeContext := AnEdgeContextPointer( Context );
    Edge := EdgeContext^.Edge;
    CheckEdgeValid(Edge);
    OtherTaskNode := EdgeContext^.OtherTaskNode;
    ValidateTreeNode(OtherTaskNode);


    SetLengthOf(KeyValue,0);

        (* Lookup the Keyword to find what column it refers to.  Lookup
           that column value for the current task. *)
    IF SearchForEdgeColumn(Keyword,ColumnId) THEN
        PredecessorTask := Edge^.headtask^.Methods^.LockFlexStorDataObject(Edge^.headtask);
        SuccessorTask := Edge^.tailtask^.Methods^.LockFlexStorDataObject(Edge^.tailtask);
        IF GetEdgeString( Edge, PredecessorTask, SuccessorTask,
                          ColumnId, HIGH(KeyValue), 
                          KeyValue ) THEN
        ELSE
            SetLengthOf(KeyValue,0);      (* No value on this this field/this task. *)
        END;
        Edge^.tailtask^.Methods^.UnlockFlexStorDataObject(Edge^.tailtask);
        Edge^.headtask^.Methods^.UnlockFlexStorDataObject(Edge^.headtask);
    ELSIF SearchForTaskColumn(Keyword,ColumnId) THEN
        Task := OtherTaskNode^.Methods^.LockFlexStorDataObject(OtherTaskNode);
        IF (GetColumnString(OtherTaskNode, Task, ColumnId, Plan, HIGH(KeyValue), KeyValue)) THEN
        ELSE
            SetLengthOf(KeyValue,0);      (* No value on this this field/this task. *)
        END;
        OtherTaskNode^.Methods^.UnlockFlexStorDataObject(OtherTaskNode);
    ELSE
            (* Try to look up the keyword as a schedule-level item.  This
               uses the same keywords as the report form header. *)
        SetLengthOf(KeyValue,0);
        SchedKey.GetKeyWordValue(Keyword,KeyValue,NIL);
            (* Prepare an error message. *)
        IF (LengthOf(KeyValue)=0) THEN
            UnknownCommand(Keyword);
            GetMessage(ModuleNumber+3,KeyValue);
            ConcatLS(KeyValue,Keyword);
        END;
    END;
    LJust(KeyValue);
    TrimRear(KeyValue);
END GetEdgeKeyWordValue;





PROCEDURE MailMergeEdge( VAR Edge : AnEdgePtr;
                             OtherTaskNode : ATreeNode;
                         VAR S    : ARRAY OF CHAR );
VAR
    EdgeContext : AnEdgeContext;
BEGIN
    EdgeContext.Edge := Edge;
    EdgeContext.OtherTaskNode := OtherTaskNode;
        (* Substitute for any embedded keywords. *) 
    MakeSubstitutions(S,HIGH(S),
                      GetEdgeKeyWordValue,ADR(EdgeContext)); 
END MailMergeEdge;





PROCEDURE ReportThisEdge( Edge : AnEdgePtr;
                          OtherTaskNode : ATreeNode;
                          EdgeText : AText );
VAR
    S : ARRAY [0..MaxWidth] OF CHAR;
    N : CARDINAL;
BEGIN
    N := 0;
    WHILE (LineExists(EdgeText,N)) AND (NOT Stopped) DO
        CopyLine(EdgeText,N,S);
            (* Analyze the type of line. *)
        CASE DetermineLineType( S ) OF 
            Comment :
          | Control :
                        DoControl(S,ATreeNode(NIL),ATreeNode(NIL));
          | Display :
                        MakeTemplate(S);
                        MailMergeEdge(Edge,OtherTaskNode,S);
                        PrintText(S,Normal);
                        SetLengthOf(S,0);   PrintLine(S,Normal);
        END;
        INC(N);
    END;

END ReportThisEdge;






PROCEDURE ReportEachPredecessor( TaskNode : ATreeNode );
VAR
    Task        : ATaskPtr;
    Predecessor : AnEdgePtr;
    PTaskNode   : ATreeNode;
BEGIN
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    Predecessor := Task^.antetasks;
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);

    WHILE (Predecessor <> NIL) DO
        PTaskNode := Predecessor^.headtask;
        ReportThisEdge( Predecessor, PTaskNode, TemplateText[ PredecessorsSection ] );
        Predecessor := Predecessor^.taillink;
    END;

END ReportEachPredecessor;




PROCEDURE ReportEachSuccessor( TaskNode : ATreeNode );
VAR
    Task      : ATaskPtr;
    Successor : AnEdgePtr;
    STaskNode : ATreeNode;
BEGIN
    Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
    Successor := Task^.antetasks;
    TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);

    WHILE (Successor <> NIL) DO
        STaskNode := Successor^.tailtask;
        ReportThisEdge( Successor, STaskNode, TemplateText[ SuccessorsSection ] );
        Successor := Successor^.headlink;
    END;

END ReportEachSuccessor;






PROCEDURE DoListInTasksCommand( VAR Command      : ARRAY OF CHAR;
                                     TaskNode     : ATreeNode );
CONST
    Tasks       = 1;
    Notes       = 2;
    Assignments = 3;
    Predecessors= 4;
    Successors  = 5;
VAR
    CommandKeywords : ARRAY [0..81] OF CHAR;
    S2              : ARRAY [0..81] OF CHAR;
    AssignmentsText : AText;
BEGIN
    GetMessage(ModuleNumber+4,CommandKeywords);    (* "TASKS,NOTES,ASSIGNMENTS,PREDECESSORS,SUCCESSORS" *)


    CASE QueryCommandNumber(Command,CommandKeywords) OF
        Tasks   :  
                    ListTasks();

      | Notes   :
                    
                    GetMessage(ModuleNumber+5,S2);    (* ".ENDPRINT" *)
                    ListTaskNotes( TaskNode, S2 );

      | Assignments :
                    AssignmentsText := TemplateText[ AssignmentsSection ];
                    IF (AssignmentsText <> AText(NIL)) THEN
                        ReportEachAssignmentToTask( TaskNode, AssignmentsText );
                    END;

      | Predecessors :
                    ReportEachPredecessor( TaskNode );

      | Successors :
                    ReportEachSuccessor  ( TaskNode );


      ELSE
                    UnknownCommand(Command);
                    GetMessage(ModuleNumber+3,S2);   (* "??? " *)
                    PrintText(S2,Normal); PrintText(Command,Normal);
                    SetLengthOf(S2,0);   PrintLine(S2,Normal);

    END;
END DoListInTasksCommand;








PROCEDURE DoControlInTasks(VAR S : ARRAY OF CHAR;
                               TaskNode : ATreeNode );
CONST
    Unknown       = 0;
    ControlChange = 2;
    Organization  = 1;
    NewPage       = 4;
    List          = 5;
VAR
    i, CommandNumber : CARDINAL;
    S2 : ARRAY [0..31] OF CHAR;
BEGIN
        (* Figure out which control command this is.  The control command
           is terminated by "=" or EOL, and will be placed into S2. *)
    i := 1;
    WHILE (i <= LengthOf(S)) AND (S[i] <> "=") AND (S[i] <> " ") DO
        INC(i);
    END;
    SubStr(S,S2,1,i-1);   Upshift(S2);

        
        (* Execute the command. *)

    CASE QueryCommandNumber(S2,ControlKeywords) OF
        ControlChange    :
                    IF (ExtractArgument(S,i,S2)) THEN
                        Copy(S2,DisplayIndicator);
                    END;
      | NewPage :
                        (* Finish printing on this page. *)
                    SetLengthOf(S2,0);
                    i := RowsLeft();
                    WHILE (i > 0) DO
                        PrintLine(S2,Normal);
                        DEC(i);
                    END;

      | List    :
                    IF (ExtractArgument(S,i,S2)) THEN
                        DoListInTasksCommand(S2,TaskNode);
                    END;

      ELSE
                    UnknownCommand(S);
                    GetMessage(ModuleNumber+3,S2);   (* "??? " *)
                    PrintText(S2,Normal); PrintText(S,Normal);
                    SetLengthOf(S2,0);   PrintLine(S2,Normal);

    END;

END DoControlInTasks;



PROCEDURE ReportThisTask( TaskNode : ATreeNode;
                          TasksText : AText );
VAR
    S : ARRAY [0..MaxWidth] OF CHAR;
    N : CARDINAL;
BEGIN
    N := 0;
    WHILE (LineExists(TasksText,N)) AND (NOT Stopped) DO
        CopyLine(TasksText,N,S);
            (* Analyze the type of line. *)
        CASE DetermineLineType( S ) OF 
            Comment :
          | Control :
                        DoControlInTasks(S,TaskNode);
          | Display :
                        MakeTemplate(S);
                        MailMergeTask(TaskNode,S);
                        PrintText(S,Normal);
                        SetLengthOf(S,0);   PrintLine(S,Normal);
        END;
        INC(N);
    END;


END ReportThisTask;












    (* List the notes of the task, expanding any embedded keywords.
       Stop, however, if we hit any line beginning with EndAt. *)

PROCEDURE ListResourceNotes(     ResourceNode : ATreeNode;
                              VAR EndAt : ARRAY OF CHAR);
VAR
    Resource : AResourcePointer;
    Text : AText;
    S : ARRAY [0..MaxWidth] OF CHAR;
    N : CARDINAL;
    Done : BOOLEAN;
BEGIN
    IF (ResourceNode = ATreeNode(NIL)) THEN
        RETURN;
    END;

    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );
    Text := Resource^.Notes;

    N := 0;
    Done := FALSE;
    WHILE (LineExists(Text,N)) AND (NOT (Stopped OR Done)) DO
        CopyLine(Text,N,S);
        IF (Search(S,EndAt,1)=1) THEN
            Done := TRUE;
        ELSE
            MailMergeResource(ResourceNode,S);
            PrintText(S,Normal);
            SetLengthOf(S,0);   PrintLine(S,Normal);
        END;
        INC(N);
    END;

END ListResourceNotes;








PROCEDURE ReportEachAssignmentToResource( ResourceNode : ATreeNode;
                                          AssignmentsText : AText );
VAR
    TaskNode    : ATreeNode;
    Resource    : AResourcePointer;
    AssignmentsHandle : AnExtHandle;
    Assignments : AnAssignmentArray;
    Task        : ATaskPtr;
    Count       : CARDINAL;
    i           : CARDINAL;
    S : ARRAY [0..MaxWidth] OF CHAR;
    N : CARDINAL;
BEGIN
    IF (ResourceNode = ATreeNode(NIL)) THEN
        RETURN;
    END;
    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );

        (* Loop over all tasks, searching for assignments to this 
           resource. *)

    TaskNode := TaskTree^.Methods^.GetFirstVisible(TaskTree);
    WHILE ( TaskNode <> NIL ) AND (NOT Stopped) DO

        Task := TaskNode^.Methods^.LockFlexStorDataObject(TaskNode);
        AssignmentsHandle := Task^.Plan.Assignments; 

            (* Loop over the assignments to this task. *)
    
        Count := LockObjectArray( AssignmentsHandle,
                                  Assignments, TSIZE( AnAssignmentRecord ) );
    
        IF (Count > 0) THEN
            FOR i := 0 TO Count-1 DO
                IF (Assignments^[i].Resource = Resource) THEN
                    ReportOneAssignment( TaskNode, Task,
                                         Assignments^[i], AssignmentsText );
                END;
            END;
        END;
    
        ReleaseUnchangedObject(AssignmentsHandle);
        TaskNode^.Methods^.UnlockFlexStorDataObject(TaskNode);

        TaskNode := TaskNode^.Methods^.NextForDisplay(TaskNode);
    END;

    
END ReportEachAssignmentToResource;






PROCEDURE DoListCommand( VAR Command      : ARRAY OF CHAR;
                              TaskNode     : ATreeNode;
                              ResourceNode : ATreeNode );
CONST
    Tasks       = 1;
    Resources   = 2;
    Notes       = 3;
    Assignments = 4;
    Filters     = 5;
VAR
    CommandKeywords : ARRAY [0..81] OF CHAR;
    S2              : ARRAY [0..81] OF CHAR;
    AssignmentsText : AText;

    PROCEDURE ShowWrongCommand();
    BEGIN
        SetString(S2,"??? "); 
        PrintText(S2,Normal); PrintText(Command,Normal);
        SetLengthOf(S2,0);   PrintLine(S2,Normal);
    END ShowWrongCommand;

BEGIN
    GetMessage(ModuleNumber+6,CommandKeywords);    (* "TASKS,RESOURCES,NOTES,ASSIGNMENTS,FILTERS" *)


    CASE QueryCommandNumber(Command,CommandKeywords) OF
        Tasks   :   IF (TaskNode = ATreeNode(NIL)) THEN  (* Not nested within a task. *)
                        ListTasks();
                    ELSE
                        ShowWrongCommand();
                        GetMessage(ModuleNumber+7,S2);  (* "To print assignments, use .LIST ASSIGNMENTS." *)
                        PrintLine(S2,Normal);
                    END;

      | Resources : IF (ResourceNode = ATreeNode(NIL)) THEN  (* Not nested within a resource. *)
                        ListResources();
                    ELSE
                        ShowWrongCommand();
                        GetMessage(ModuleNumber+7,S2);  (* "To print assignments, use .LIST ASSIGNMENTS." *)
                        PrintLine(S2,Normal);
                    END;

      | Notes   :
                    
                    GetMessage(ModuleNumber+5,S2);    (* ".ENDPRINT" *)
                    IF (TaskNode <> ATreeNode(NIL)) THEN
                        ListTaskNotes( TaskNode, S2 );
                    ELSIF (ResourceNode <> ATreeNode(NIL)) THEN
                        ListResourceNotes( ResourceNode, S2 );
                    ELSE
                        ListProjectNotes( S2 );
                    END;

      | Assignments :
                    AssignmentsText := TemplateText[ AssignmentsSection ];
                    IF (AssignmentsText <> AText(NIL)) THEN
                        IF (TaskNode <> ATreeNode(NIL)) THEN
                            ReportEachAssignmentToTask( TaskNode, AssignmentsText );
                        ELSIF (ResourceNode <> ATreeNode(NIL)) THEN
                            (* Iterate over all tasks assigned to this resource. *)
                            ReportEachAssignmentToResource( ResourceNode, AssignmentsText );
                        END;
                    END;

      | Filters :
                    FilterNotes( TRUE (*ShowSelect*), FALSE (*ShowHighlights*) );


      ELSE
                    UnknownCommand(Command);
                    ShowWrongCommand();

    END;
END DoListCommand;








PROCEDURE DoControl(VAR S : ARRAY OF CHAR;
                        TaskNode : ATreeNode;
                        ResourceNode : ATreeNode );
CONST
    Unknown       = 0;
    ControlChange = 2;
    Organization  = 1;
    NewPage       = 4;
    List          = 5;
VAR
    i, CommandNumber : CARDINAL;
    S2 : ARRAY [0..31] OF CHAR;
BEGIN
        (* Figure out which control command this is.  The control command
           is terminated by "=" or EOL, and will be placed into S2. *)
    i := 1;
    WHILE (i <= LengthOf(S)) AND (S[i] <> "=") AND (S[i] <> " ") DO
        INC(i);
    END;
    SubStr(S,S2,1,i-1);   Upshift(S2);

        
        (* Execute the command. *)

    CASE QueryCommandNumber(S2,ControlKeywords) OF
        ControlChange    :
                    IF (ExtractArgument(S,i,S2)) THEN
                        Copy(S2,DisplayIndicator);
                    END;
      | NewPage :
                        (* Finish printing on this page. *)
                    SetLengthOf(S2,0);
                    i := RowsLeft();
                    WHILE (i > 0) DO
                        PrintLine(S2,Normal);
                        DEC(i);
                    END;

      | List    :
                    IF (ExtractArgument(S,i,S2)) THEN
                        DoListCommand(S2,TaskNode,ResourceNode);
                    END;

      ELSE
                    UnknownCommand(S);
                    GetMessage(ModuleNumber+3,S2);
                    PrintText(S2,Normal); PrintText(S,Normal);
                    SetLengthOf(S2,0);   PrintLine(S2,Normal);

    END;

END DoControl;












PROCEDURE GetScheduleKeyWordValue( VAR Keyword : ARRAY OF CHAR;
                                   VAR KeyValue : ARRAY OF CHAR;
                                       Context  : ADDRESS );
VAR
    ColumnId : CARDINAL;
    S        : ARRAY [0..31] OF CHAR;
    i, j : CARDINAL;
BEGIN
    SetLengthOf(KeyValue,0);

        (* Lookup the Keyword to find what column it refers to.  Lookup
           that column value for the whole schedule, or the report. *)

    GetMessage(ModuleNumber+8,S);    (* "PAGENUMBER" *)
    IF StringsEqual(S,Keyword) THEN
        CtoS(PageNumber,KeyValue);
    ELSE
            (* Try to look up the keyword as a schedule-level item.  This
               uses the same keywords as the report form header. *)
        SetLengthOf(KeyValue,0);
        SchedKey.GetKeyWordValue(Keyword,KeyValue,NIL);
            (* Prepare an error message. *)
        IF (LengthOf(KeyValue)=0) THEN
            GetMessage(ModuleNumber+3,KeyValue);
            ConcatLS(KeyValue,Keyword);
        END;
    END;
END GetScheduleKeyWordValue;



    (* MailMerge -- Modify the text line S so that keywords are
                    substituted into it, referring to the global
                    keywords of the schedule. *)

PROCEDURE MailMergeSchedule( VAR S    : ARRAY OF CHAR );
BEGIN
        (* Substitute for any embedded keywords. *) 
    MakeSubstitutions(S,HIGH(S),
                      GetScheduleKeyWordValue,NIL); 
END MailMergeSchedule;




    (* ListASection -- Copy lines from the text to the printer,
                        expanding any keywords and honoring controls,
                        optionally. *)


PROCEDURE ListASection( Text : AText; 
                         HonorControls : BOOLEAN );
VAR
    S : ARRAY [0..MaxWidth] OF CHAR;
    N : CARDINAL;
BEGIN
    N := 0;
    WHILE (LineExists(Text,N)) AND (NOT Stopped) DO
        CopyLine(Text,N,S);
            (* Analyze the type of line. *)
        CASE DetermineLineType( S ) OF 
            Comment :
          | Control :
                        IF (HonorControls) THEN
                            DoControl(S,ATreeNode(NIL),NIL);
                        END;
          | Display :
                        MakeTemplate(S);
                        MailMergeSchedule(S);
                        PrintText(S,Normal);
                        SetLengthOf(S,0);   PrintLine(S,Normal);
        END;
        INC(N);
    END;
END ListASection;





    (* Execute this at the start of every printed page. *)



PROCEDURE TopOfPageProc ();
BEGIN
    INC(PageNumber);

    ListASection( TemplateText[PageHeaderSection],
                   FALSE (* Controls not allowed. *)  );
END TopOfPageProc;



    (* Execute this at the end of every printed page. *)

PROCEDURE EndOfPageProc ();
BEGIN
    ListASection( TemplateText[PageFooterSection],
                   FALSE (* Controls not allowed. *)  );
END EndOfPageProc;








PROCEDURE SplitSections(     Text : AText;
                         VAR TemplateText : ATemplateTextArray );
CONST
    SectionCommand = 1;
VAR
    Section : ASection;
    N,i,j   : CARDINAL;
    FooterLines : CARDINAL;
    S       : ARRAY [0..255] OF CHAR;
    S2      : ARRAY [0..31] OF CHAR;
    SectionName : ARRAY [0..31] OF CHAR;
    SectionNames : ARRAY [0..255] OF CHAR;
    
    PROCEDURE StoreIt();
    BEGIN
        IF (TemplateText[Section] = AText(NIL)) THEN
            TemplateText[Section] := CreateText();
        END;
        IF (NOT AppendLine(S,TemplateText[Section])) THEN
        END;
    END StoreIt;

BEGIN

        (* Split the report text into sections. *)
    FOR Section := MIN(ASection) TO MAX(ASection) DO
        TemplateText[ Section ] := AText(NIL);
    END;
    GetMessage(ModuleNumber+9,SectionNames);    (* "HEADER,FOOTER,MAIN,TASKS,RESOURCES,ASSIGNMENTS,PREDECESSORS,SUCCESSORS" *)

        (* Sections of the report are separated by control lines of the
           form 
           SECTION = <Section Name>
        *)

    Section := MainSection;
    N := 0;
    WHILE (LineExists(Text,N)) DO
        CopyLine(Text,N,S);

        IF (Search(S,DisplayIndicator,1) <> 1) THEN
                (* Figure out which control command this is.  The control command
                   is terminated by "=" or EOL, and will be placed into S2. *)
            i := 1;
            j := i;
            WHILE (i <= LengthOf(S)) AND (S[i] <> "=") AND (i-j < HIGH(S2)) DO
                INC(i);
            END;
            SubStr(S,S2,j,i-j);   TrimFront(S2); Upshift(S2);
            j := QueryCommandNumber(S2,ControlKeywords);
            IF (j = SectionCommand) THEN
                IF (ExtractArgument(S,i,SectionName)) AND (i > 0) THEN
                    Upshift(SectionName);
                    i := QueryCommandNumber(SectionName,SectionNames);
                    IF (i > 0) THEN
                        Section := VAL(ASection,i-1);      (* Change sections. *)
                            (* Erase any previous contents. *)
                        IF (TemplateText[ Section ] <> AText(NIL)) THEN
                            DiscardText(TemplateText[ Section ]);
                            TemplateText[ Section ] := AText(NIL);
                        END;
                    ELSE
                        UnknownCommand(S);
                    END;
                ELSE
                    UnknownCommand(S);
                END;
            ELSE
                StoreIt();   (* Not a section command. *)
            END;
        ELSE
            StoreIt();       (* Not a command. *)
        END;
        INC(N);
    END;


        (* Set the call-back procedures for top and end of pages. *)

    FooterLines := 0;
    IF (TemplateText[PageFooterSection] <> AText(NIL)) THEN
        WHILE (LineExists(TemplateText[PageFooterSection],FooterLines)) DO
            INC(FooterLines);
        END;
    END;
    
    SetPageCaptionProcedures( TopOfPageProc, EndOfPageProc, FooterLines );



END SplitSections;






PROCEDURE ListTasks();
VAR
    Node : ATreeNode;
BEGIN
        (* List tasks data. *)

    Node := TaskTree^.Methods^.GetFirstVisible(TaskTree);
    WHILE ( Node <> NIL ) AND (NOT Stopped) DO
        ReportThisTask( Node, TemplateText[ TasksSection] );
        Node := Node^.Methods^.NextForDisplay(Node);
    END;
END ListTasks;







    (* GetResourceKeyWordValue --
       
       Given a resource and a keyword
       identifying a column, return a printable keyvalue which is the
       value of that column of the resource table.

       *)


PROCEDURE GetResourceKeyWordValue( VAR Keyword : ARRAY OF CHAR;
                                   VAR KeyValue : ARRAY OF CHAR;
                                       Context  : ADDRESS );
VAR
    ColumnId : CARDINAL;
    i, j : CARDINAL;
    ResourceNode : ATreeNode;
BEGIN
    ResourceNode := ATreeNode(Context);
    ValidateTreeNode(ResourceNode);

    SetLengthOf(KeyValue,0);

        (* Lookup the Keyword to find what column it refers to.  Lookup
           that column value for the current resource. 
           *)
    IF SearchForRsrcColumn(Keyword,ColumnId) THEN
        IF (GetRsrcString( ResourceNode,
                           ColumnId, HIGH(KeyValue), KeyValue )) THEN
            LJust(KeyValue);
            TrimRear(KeyValue);
        ELSE
            SetLengthOf(KeyValue,0);
        END;
    ELSE
            (* Try to look up the keyword as a schedule-level item.  This
               uses the same keywords as the report form header. *)
        SetLengthOf(KeyValue,0);
        SchedKey.GetKeyWordValue(Keyword,KeyValue,NIL);
            (* Prepare an error message. *)
        IF (LengthOf(KeyValue)=0) THEN
            UnknownCommand(Keyword);
            GetMessage(ModuleNumber+3,KeyValue);
            ConcatLS(KeyValue,Keyword);
        END;
    END;
END GetResourceKeyWordValue;







    (* MailMerge -- Modify the text line S so that keywords are
                    substituted into it, referring to the column
                    values of the current Resource. *)

PROCEDURE MailMergeResource(   ResourceNode : ATreeNode;
                               VAR S    : ARRAY OF CHAR );
BEGIN
        (* Substitute for any embedded keywords. *) 
    MakeSubstitutions(S,HIGH(S),
                      GetResourceKeyWordValue,ResourceNode); 
END MailMergeResource;







PROCEDURE ReportThisResource( ResourceNode : ATreeNode;
                              ResourcesText : AText );
VAR
    Resource : AResourcePointer;
    S : ARRAY [0..MaxWidth] OF CHAR;
    N : CARDINAL;
BEGIN
    N := 0;
    WHILE (LineExists(ResourcesText,N)) AND (NOT Stopped) DO
        CopyLine(ResourcesText,N,S);
            (* Analyze the type of line. *)
        CASE DetermineLineType( S ) OF 
            Comment :
          | Control :
                        DoControl(S,ATreeNode(NIL),ResourceNode);
          | Display :
                        MakeTemplate(S);
                        MailMergeResource(ResourceNode,S);
                        PrintText(S,Normal);
                        SetLengthOf(S,0);   PrintLine(S,Normal);
        END;
        INC(N);
    END;

END ReportThisResource;






PROCEDURE ListResources();
VAR
    Node : ATreeNode;
    FilterSet         : ATaskFilterSet;
BEGIN
        (* List resources data. *)

    Node := ResourceTree^.Methods^.GetFirst(ResourceTree);
    WHILE ( Node <> NIL ) AND (NOT Stopped) DO
        FilterSet := ResourceFiltersPassed(Node);
        IF (Selected IN FilterSet ) THEN
           ReportThisResource( Node, TemplateText[ ResourcesSection] );
        END;
        Node := Node^.Methods^.GetNext(Node);
    END;
END ListResources;







PROCEDURE MakeReport( Text : AText );
CONST
    SectionCommand = 1;
VAR
    Section : ASection;
BEGIN
        (* Divide the report spec into various sections. *)
    SplitSections( Text, TemplateText );

        (* Open the report printer, skip top margin, print header. *)

    PageNumber := 0;                             (* A global to this report. *)

    IF (NOT StartReport()) THEN RETURN; END;

        (* Run the main printing loop. *)

    ListASection(  TemplateText[MainSection], TRUE );

    EndReport();

        (* Get rid of the texts containing the various sections. *)

    FOR Section := MIN(ASection) TO MAX(ASection) DO
        IF TemplateText[ Section ] <> AText(NIL) THEN
            DiscardText( TemplateText[ Section ] );
        END;
    END;

END MakeReport;








PROCEDURE DoFreeFormTaskReport();
VAR
    Line                    :   ARRAY [0..MaxWidth] OF CHAR;
    Copyright               :   ARRAY[0..50] OF CHAR;
    Text                    :   AText;
    Choice                  :   CARDINAL;
    ok,Changed              :   BOOLEAN;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF (TaskTree^.Methods^.GetFirstVisible(TaskTree) = NIL) THEN
        GetMessage(11750, Line);          (* "There are not tasks on which to report." *)
        Error(Line);
        RETURN;
    END;

    WarningsPrinted := 0;

    IF ( NOT CreateTaskColumnsTree() ) THEN RETURN; END;  (* Task column names. *)
        (* Resource Column names. *)
    IF ( NOT CreateRsrcColumnsTree() ) THEN
        DisposeTaskColumnsTree();
        RETURN;
    END;  (* Assignment column names. *)
    IF ( NOT CreateAssColumnsTree() )  THEN
        DisposeRsrcColumnsTree();
        DisposeTaskColumnsTree();
        RETURN;
    END;  (* Assignment column names. *)
    IF ( NOT CreateEdgeColumnsTree() ) THEN
        DisposeAssColumnsTree();
        DisposeRsrcColumnsTree();
        DisposeTaskColumnsTree();
        RETURN;
    END;  (* Edge column names. *)

    GetDataFileExtensions();                    (* Blacklist of file extensions. *)
    GetMessage(ModuleNumber+10,DisplayIndicator);    (* "." *)
    GetMessage(ModuleNumber+11,ControlKeywords);    (* "SECTION,CONTROL,ORGANIZATION,NEWPAGE,LIST,PRINT" *)
    GetMessage(ModuleNumber+12,CommentIndicator);    (* "--" *)



        (* Create a text. *)
    Text := CreateText();


    Choice := 1;
    LOOP
        GetMessage(ModuleNumber+13,Line);    (* "Select A Report File,Edit,Go,Quit" *)
        SetLengthOf(Copyright,0);
        IF (NOT MultipleChoiceBox(Copyright,Copyright,NoHelp,Copyright,
                                  Line,Choice)) THEN
                                      EXIT;
        END;
        CASE Choice OF
            1: 
                IF NOT SelectAReport( Text ) THEN
                    EXIT;
                END;
          | 2: 
                SetLengthOf(Line,0);
                EditText(0,GanttWStart,MaxColumn,GanttWEnd,ABoxType{DoubleBox},
                         Line, 0, Text, Changed );
          | 3:  
                MakeReport( Text );
                EXIT;
          ELSE 
                EXIT;
        END;
        Choice := 3;     (* "Go" *)
    END;

    DiscardText( Text );
    DisposeEdgeColumnsTree();
    DisposeAssColumnsTree();
    DisposeRsrcColumnsTree();
    DisposeTaskColumnsTree();

END DoFreeFormTaskReport;




BEGIN
    DoFreeFormTaskReport();
END TLFFRpt.




-- A test of the free form report generator.
--
-- 
SECTION=MAIN
.                  
.                  Free-form task report
.
.                  *SCHEDULENAME* as of *ASOF*
.
.                  *USER*
.
LIST NOTES
LIST FILTERS
NEWPAGE
LIST TASKS
.                  
.                  End of Free-form task report
.                      *SCHEDULENAME*
--
-- For each task, print the following:
--
SECTION=TASKS
.
.   ######################################################################
.   #                                                                    #
.   #                  *TASK NAME(L)                 *                   #
.   #                                                                    #
.   ######################################################################
.
.Brief Summary:       *DURATION*, due to end by *END DATE*
.
.Task notes:
.
LIST NOTES
.
.Resource                             Spent Hours
----------------------------------   -----------
LIST ASSIGNMENTS
.
.Predecessors
.WBS                     Task Name                          From Dur
LIST PREDECESSORS
NEWPAGE
--
-- -----------------------------------------------------------------------
--
-- For each assignment to a task, print the following:
--
-- -----------------------------------------------------------------------
--
SECTION=ASSIGNMENTS
.*Resource Full Name(L)           *   *Spent Hours(R3W11)*   
--
-- -----------------------------------------------------------------------
--
-- For each predecessor to a task, print the following:
--
-- -----------------------------------------------------------------------
--
SECTION=PREDECESSORS
.*WBS(L)             *   *Task Name(L)                  *   *(From Duration (Hrs))*
--
-- -----------------------------------------------------------------------
--       Print this at the top of every page.
-- -----------------------------------------------------------------------
--
SECTION=HEADER
--
-- -----------------------------------------------------------------------
--       Print this at the end of every page.
-- -----------------------------------------------------------------------
--
SECTION=FOOTER
.
._______________________________________________________________________
.Free-Form task report     *DATEANDTIME(L)    *                 page *PAGENUMBER(RW3)*



