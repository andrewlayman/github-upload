MODULE TLViewOT;

    (* TLViewOT

       Overlay called from TLLink; Displays the possible WBS number from
       an On Target schedule file, allows the user to select one and
       returns it.

       The context passed is the FormValue array from the link form,
       containing the file directory, file name, link type, WBS field 
       and other optional fields.

       MODIFICATION HISTORY:

        2-Feb-91 AJL -Original version.
        6-Feb-91 AJL -Use ReadOnlyAccessMode in place of ReadOnlyMode 
                      when opening files.  This works with file sharing
                      on networks.
       12-Feb-91 AJL -Sort tasks by WBS number.
       14-Apr-91 AJL -Position intial cursor on the WBS number entered.
       30-Jul-91 AJL - Make list items longer, so GoTo doesn't write off
                      screen.
       23-Mar-92 TGS - Do ANSIToOEM conversion on incoming strings.

    *) 

FROM Dialog                 IMPORT
    (* PROC *)                  Error, Burp;

FROM Directory              IMPORT
    (* TYPE *)                  AFileNamePart, ASetOfFileNameParts,
    (* PROC *)                  NormalizeFileName, RemovableMedia;

FROM FileAux                IMPORT 
    (* PROC *)                  PrepareForIO, CheckIO, FileResultMeans,
                                DisplayFileError;

FROM FileSystem             IMPORT
                                File, Response, Close,
                                OpenFile, ReadNBytes, 
                                FullAccessMode, ReadOnlyMode, 
                                ReadByte, ReadWord, SetRead, SetPos,
                                Reset;

FROM Foreign        IMPORT
    (* TYPE *)          ACharacterConversionTable,
    (* PROC *)          DecodeString, DoDash, ConvertString;

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue;


FROM GoTo                   IMPORT
    (* PROC *)                  DoGoTo, NullGoToCheckProc;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWStart, GanttWEnd, MaxColumn;   

FROM LStrings               IMPORT LStringToTString, ConcatLS, SetString,
                                   Copy, SubStr, TrimRear, CtoS, ConcatS, StoC,
                                   StringsEqual, Insert, SetLengthOf, LengthOf,
                                   Procustes, LJust, TStringToLString, Compare;

FROM MsgFile                IMPORT  GetMessage, ConcatMessage, DisplayMessage;

FROM OTFiles                IMPORT
    (* TYPE *)                  AnOnTargetTask,
    (* PROC *)                  ReadRecordPreface, ReadRecordBody,
                                SkipRecordBody, StartFileInput; 

FROM Overlays       IMPORT
        (* TYPE *)      AnOverlayID,
        (* PROCS *)     OverlayContext, ImAnInstallableOverlay;

FROM OvTree         IMPORT
    (* TYPE *)          AnOverlayProc;

FROM Rugs           IMPORT
    (* TYPE *)          ARug,
    (* PROC *)          GetRug, PutRug;

FROM Sorter         IMPORT
    (* TYPE *)          AnObjectCompareProc,
    (* PROC *)          SortTree;

FROM Space          IMPORT
    (* PROC *)          Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM         IMPORT
    (* Type *)          ADDRESS,
    (* PROC *)          SIZE, TSIZE;

FROM Text           IMPORT
        (* PROCS *)     DiscardText, AssignText, TextExists, SizeOfText, 
                        LineExists, CopyLine, AText, Compress, CreateText,
                        AssignLine, AppendLine;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeNodeAttribute,
                        CreateTree, CreateTreeNode;


CONST
    ModuleNumber = 16600;   (* Share with TLLnkOT? *)


        (* Layout of the GoTo box. *)
    WBSWidth = 30;                   (* Maximum width *)
    NameWidth = 30;
    Spacer    = 5;

    LinesPerNode = 3;   (* Three text lines for each tree node. *)
    NameLine     = 1;
    ListOrderLine= 2;

    PATH    = 0;    (* Drive and directory                      *)
    NAME    = 1;    (* File and extension                       *)
    LTYP    = 2;    (* Link type (0=schedule, 1=task)           *)
    LWBS    = 3;    (* Link WBS code                            *)
    LDAT    = 4;    (* Copy (Start date + duration, end date)   *)
    RCOP    = 5;    (* Copy resources? (No, Yes)                *)

    EmptyTaskID = 0FFFFH;  (* In the TaskIDTable, means empty slot. *)

    MinimumWBSNumberLength   = 6;  (* Minimum width on GoTo list. *)
    MinimumTaskNameLength    = 6;  



TYPE
    ATaskIDTable = ARRAY [0..2000] OF CARDINAL;
    ATaskIDTablePointer = POINTER TO ATaskIDTable;



VAR
    OverlayID               : AnOverlayID;
        (* Text holds the WBS numbers. *)
    Text                    : AText;           (* Not reentrant. *)
        (* Width of Display *)
    DisplayWBSNumberLength,
    DisplayTaskNameLength   : CARDINAL;

    CharacterTable          : ACharacterConversionTable;


PROCEDURE FileComplaint(VAR F:File);
VAR
   s  : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,s);    (* "Detail file " *)
    DisplayFileError( F, s );        (* RSC 2/19/88    *)
END FileComplaint;


PROCEDURE Complain( N : CARDINAL );
VAR 
    S : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(N,S);
    Error(S);
END Complain;






PROCEDURE CreateTaskIDTable(     MaxTaskNumber : CARDINAL;
                             VAR TaskIDTable : ATaskIDTablePointer
                           ) : BOOLEAN;
VAR
    i : CARDINAL;
    TableSize : CARDINAL;
BEGIN
    TableSize := (MaxTaskNumber+1) * TSIZE(CARDINAL);
    IF NOT Available(TableSize) THEN
        RETURN FALSE;
    END;
    ALLOCATE(TaskIDTable,TableSize);
    FOR i := 0 TO MaxTaskNumber DO
        TaskIDTable^[i] := EmptyTaskID;
    END;
    RETURN TRUE;
END CreateTaskIDTable;




PROCEDURE DiscardTaskIDTable(     MaxTaskNumber : CARDINAL;
                             VAR TaskIDTable : ATaskIDTablePointer );
VAR
    TableSize : CARDINAL;
BEGIN
    TableSize := (MaxTaskNumber+1) * TSIZE(CARDINAL);
    DEALLOCATE(TaskIDTable,TableSize);
END DiscardTaskIDTable;





PROCEDURE LoadWBSNumbers( VAR F : File;
                          VAR Text : AText;
                          VAR Count : CARDINAL );
VAR
    Type                    : CARDINAL;
    ID                      : CARDINAL;
    Length                  : CARDINAL;
    MaxTaskNumber           : CARDINAL;
    LineUsed                : CARDINAL;
    TaskIDTable             : ATaskIDTablePointer;
    S                       : ARRAY [0..255] OF CHAR; 
    OnTargetTask            : AnOnTargetTask;
BEGIN
    DisplayWBSNumberLength := MinimumWBSNumberLength;
    DisplayTaskNameLength  := MinimumTaskNameLength;


    IF NOT StartFileInput(F,MaxTaskNumber) THEN
        Count := 0;
        RETURN;
    END;

    (* Create a table that lists the text line for each found WBS. *)

    IF NOT (CreateTaskIDTable(MaxTaskNumber, TaskIDTable )) THEN
        RETURN;
    END;


    (* Reset to the beginning of the file and read records, looking
       for WBS numbers  When one is found, store it into the Text and
       store the line number of the text into the TaskIDTable[ID]. *)

    PrepareForIO(F);
    Reset(F);
    SetRead(F);

    LineUsed := 0;   (* Counts text lines used. *)
    Count    := 0;

    IF (CheckIO(F) = done) THEN
        LOOP
            ReadRecordPreface (F,Type,ID,Length);
            IF (CheckIO(F) <> done) THEN
                EXIT;
            END;
            CASE Type OF
                0 : (* File Ender *)
                    EXIT;

              | 35 : (* A WBS Number *)
                    ReadRecordBody (F,Length,S);
                    TStringToLString(S,S);
                    ConvertString(S, CharacterTable);   (* 23-Mar-92 TGS *)
                    IF NOT AppendLine(S,Text) THEN
                        EXIT;
                    END;
                        (* Save maximum size. *)
                    IF (LengthOf(S) > DisplayWBSNumberLength) THEN
                        DisplayWBSNumberLength := LengthOf(S);
                    END;
                        (* Add blank lines that will later hold
                           the task name and sort sequence. *)
                    SetLengthOf(S,0);
                    IF NOT (AppendLine(S,Text) AND
                            AppendLine(S,Text)) THEN
                        EXIT;
                    END;

                        (* Record the line number used into the task
                           id table. *)

                    TaskIDTable^[ID] := LineUsed;
                    INC(LineUsed, LinesPerNode );
                    INC(Count);

            ELSE
                SkipRecordBody(F,Length);
            END;
        END;
    END;

    (* Reset to the beginning of the file and read records, looking
       for task names that go with tasks that have WBS numbers.
       When found, fill in the Text line following the WBS number.
    *)

    PrepareForIO(F);
    Reset(F);
    SetRead(F);

    IF (CheckIO(F) = done) THEN
        LOOP
            ReadRecordPreface (F,Type,ID,Length);
            IF (CheckIO(F) <> done) THEN
                EXIT;
            END;
            CASE Type OF
                0 : (* File Ender *)
                    EXIT;

              | 36 : (* A Task Name *)
                    ReadRecordBody (F,Length,S);
                    TStringToLString(S,S);
                    ConvertString(S, CharacterTable);   (* 23-Mar-92 TGS *)
                    LineUsed := TaskIDTable^[ID];
                    IF (LineUsed <> EmptyTaskID) THEN
                        IF (NOT AssignLine(S,LineUsed+NameLine,Text)) THEN
                            EXIT;
                        END;
                            (* Save maximum size. *)
                        IF (LengthOf(S) > DisplayTaskNameLength) THEN
                            DisplayTaskNameLength := LengthOf(S);
                        END;
                    END;
            ELSE
                SkipRecordBody(F,Length);
            END;
        END;
    END;

    (* Reset to the beginning of the file and read records, looking
       for task records that go with tasks that have WBS numbers.
       When found, fill in the Text line two past the WBS number
       to contain the sort sequence.
    *)

    PrepareForIO(F);
    Reset(F);
    SetRead(F);

    IF (CheckIO(F) = done) THEN
        LOOP
            ReadRecordPreface (F,Type,ID,Length);
            IF (CheckIO(F) <> done) THEN
                EXIT;
            END;
            CASE Type OF
                0 : (* File Ender *)
                    EXIT;

              | 1 : (* ATask *)
                    IF (Length <> SIZE(OnTargetTask)) THEN
                        Complain(ModuleNumber+12);
                    END;
                    ReadRecordBody (F,Length,OnTargetTask);
                    LineUsed := TaskIDTable^[ID];
                    IF (LineUsed <> EmptyTaskID) THEN
                        CtoS(OnTargetTask.ListLocation,S);
                        IF (NOT AssignLine(S,LineUsed+ListOrderLine,Text)) THEN
                            EXIT;
                        END;
                    END;
            ELSE
                SkipRecordBody(F,Length);
            END;
        END;
    END;

    DiscardTaskIDTable(MaxTaskNumber, TaskIDTable );

    IF (DisplayWBSNumberLength > WBSWidth) THEN
        DisplayWBSNumberLength := WBSWidth;
    END;
    IF (DisplayTaskNameLength > NameWidth) THEN
        DisplayTaskNameLength := NameWidth;
    END;

END LoadWBSNumbers;



  (* CompareDisplaySequence was intended to sort OT tasks into the
     original display order of the OT file.  However, unfortunately,
     the ListOrder field in the OT file is relative only to the 
     task's position within its parent.  So, being to hard to use,
     we aren't using it.
  *)

  (*
  IFF the first node is > the second node, TRUE is returned.
  *)
(*-----------------------------
PROCEDURE CompareDisplaySequence( A, B : ATreeNode ) : BOOLEAN;
VAR
    I1, I2 : CARDINAL;
    S1, S2 : CARDINAL;
    i      : CARDINAL;
    S : ARRAY [0..5] OF CHAR;
BEGIN
    (* Our mechanism here is not very efficient, converting strings
       to sequence numbers each time, but it is simple. *)

    I1 := IndexOf(A);
    CopyLine(Text,I1+ListOrderLine,S);
    i := 0;
    S1 := StoC(S,i);

    I2 := IndexOf(B);
    CopyLine(Text,I2+ListOrderLine,S);
    i := 0;
    S2 := StoC(S,i);

    RETURN (S1 > S2);
END CompareDisplaySequence;
---------------------------------*)



PROCEDURE CompareWBSSequence( A, B : ATreeNode ) : BOOLEAN;
VAR
    S1, S2 : ARRAY [0..WBSWidth] OF CHAR;
BEGIN
    CopyLine(Text,IndexOf(A),S1);
    CopyLine(Text,IndexOf(B),S2);
    RETURN (Compare(S1,S2) > 0);
END CompareWBSSequence;


    (* Create a tree with one node in it for every WBS number in the 
       text.  Store the line number of the WBS number into the tree
       data object.
    *)


PROCEDURE CreateLinkTree(     Text : AText;
                          VAR LinkTree : ATree ) : BOOLEAN;
VAR
    i : CARDINAL;
    A : ADDRESS;
    TreeNode : ATreeNode;
BEGIN
    IF NOT CreateTree(LinkTree) THEN
        RETURN FALSE;
    END;

    i := 0;
    WHILE (LineExists(Text,i)) DO
            (* Create a tree node. *)
        IF (NOT CreateTreeNode(TreeNode)) THEN
            LinkTree^.Methods^.Discard(LinkTree);
            RETURN FALSE;
        END;
            (* Store the line number into it. *)
        A.SEGMENT := 0;
        A.OFFSET  := i;
        TreeNode^.Methods^.SetDataObject(TreeNode,A);
            (* Add the node to the tree. *)
            (* Add it at the top, since experience with On Target
               files suggests that the tasks are stored in reverse order. *)
        LinkTree^.Methods^.AddFirst(LinkTree,TreeNode);
            (* Next line. *)
        INC(i,LinesPerNode);
    END;

        (* Sort the tree into the display order. *)

    IF SortTree( LinkTree, AnObjectCompareProc(CompareWBSSequence) ) THEN
    END;

    RETURN TRUE;

END CreateLinkTree;



PROCEDURE IndexOf( TreeNode : ATreeNode ) : CARDINAL;
VAR
    A : ADDRESS;
BEGIN
    A := TreeNode^.Methods^.GetDataObject(TreeNode);
    RETURN A.OFFSET;
END IndexOf;



    (* Not reentrant, because Text is global. *)

PROCEDURE NameProc(     TreeNode : ATreeNode;
                    VAR S        : ARRAY OF CHAR );
VAR
    i : CARDINAL;
    S2 : ARRAY [0..51] OF CHAR;
BEGIN
    i := IndexOf(TreeNode);
    CopyLine(Text,i,S);
    Procustes(S,DisplayWBSNumberLength);
    ConcatS(S,"  :  ");
    CopyLine(Text,i+NameLine,S2);
    Procustes(S2,DisplayTaskNameLength);
    ConcatLS(S,S2);
    ConcatS(S,"  ");
END NameProc;







PROCEDURE LocateNodeByWBS(     LinkTree : ATree;
                           VAR WBS : ARRAY OF CHAR;
                           VAR Node : ATreeNode
                         ) : BOOLEAN;
VAR
    Found : BOOLEAN;
    S     : ARRAY [0..81] OF CHAR;
BEGIN
    Node := LinkTree^.Methods^.GetFirst (LinkTree);
    Found := FALSE;
    WHILE (NOT Found) AND ( Node <> NIL ) DO
        CopyLine(Text,IndexOf(Node),S);
        IF (StringsEqual(S,WBS)) THEN
            Found := TRUE;
        ELSE
            Node := Node^.Methods^.GetNext(Node);
        END;
    END;
    RETURN Found;
END LocateNodeByWBS; 






PROCEDURE PickANumber(     Text : AText;
                           Count : CARDINAL;
                       VAR WBS : ARRAY OF CHAR ) : BOOLEAN;
CONST
    ULX = 3;
VAR
    Title : ARRAY [0..0] OF CHAR;
    Changed : BOOLEAN;
    LinkTree            : ATree;
    Node                : ATreeNode;
    i                   : CARDINAL;
    TotalWidth          : CARDINAL;
    LRX                 : CARDINAL;
    LRY                 : CARDINAL;
BEGIN
    TotalWidth := DisplayWBSNumberLength + Spacer + DisplayTaskNameLength
                  + 4 (* At right of names + borders. *)
                  + 2 (* At left of names. *);
    LRX := ULX + TotalWidth;
    IF (LRX > MaxColumn) THEN
        LRX := MaxColumn;
    END;
    LRY := GanttWStart + Count + 2;   (* 2 for the borders. *)
    IF (LRY > GanttWEnd) THEN
        LRY := GanttWEnd;
    END;

    Title[0] := 0C;

        (* Create the link tree. *)
    IF NOT CreateLinkTree( Text, LinkTree ) THEN
        RETURN FALSE;
    END;

    IF (LengthOf(WBS) = 0) OR NOT (LocateNodeByWBS(LinkTree,WBS,Node)) THEN
        Node := LinkTree^.Methods^.GetFirst (LinkTree);
    END;
        
    Changed := DoGoTo ( LinkTree, ULX, GanttWStart, 
                                  LRX, LRY,
                        Title,
                        TRUE (*  OpenTree *),
                        NullGoToCheckProc,
                        NameProc,
                        Node );

    IF (Changed) AND (Node <> NIL) THEN
        CopyLine(Text,IndexOf(Node),WBS);
    END;

    LinkTree^.Methods^.Discard(LinkTree);

    RETURN (Changed);


END PickANumber;




    (* SelectWBS  -- From the open file, display a list of WBS numbers.
                     If one is picked, return it in WBS, and return TRUE.
                     Initial value of WBS can be passed in.
    *)

PROCEDURE SelectWBS( VAR F : File;
                     VAR WBS : ARRAY OF CHAR 
                   ) : BOOLEAN;
VAR
    Changed : BOOLEAN;
    Count   : CARDINAL;
BEGIN
        (* Load the WBS numbers from the file. *)
    Text := CreateText();
    IF (Text = AText(NIL)) THEN
        RETURN FALSE;
    END;
    LoadWBSNumbers(F,Text,Count);

    IF (Count = 0) THEN
        Complain(ModuleNumber+50);
        RETURN FALSE;
    END;

        (* Select one. *)

    Changed := PickANumber( Text, Count, WBS );

        (* Get rid of our storage used. *)

    DiscardText(Text);


    RETURN Changed;
END SelectWBS;





PROCEDURE LookupRollupFile  ( VAR Dir : ARRAY OF CHAR;
                              VAR FNam : ARRAY OF CHAR;
                              VAR F    : File          ) : BOOLEAN;

VAR
    Res         : Response;
    FileName    : ARRAY [0..99] OF CHAR;

BEGIN
    Copy( Dir, FileName );
    ConcatLS(FileName,FNam);
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
END LookupRollupFile;



PROCEDURE SelectAWBS();
VAR
    FormValue : POINTER TO ARRAY [PATH..RCOP] OF AFieldValue;
    F         : File;
    S         : ARRAY [0..31] OF CHAR;
BEGIN
    FormValue := OverlayContext();
        (* Open the file. *)
    IF (FormValue <> NIL) AND 
       (LookupRollupFile(FormValue^[PATH].CharValue^,
                         FormValue^[NAME].CharValue^,
                         F))
        THEN

        Copy(FormValue^[LWBS].CharValue^, S);
            (* From the open file, pick a particular WBS number. *)
        IF (SelectWBS(F,S)) THEN
            LJust(S);
            Copy(S,FormValue^[LWBS].CharValue^);
        END;
            (* Close the file. *)
        Close (F);
    END;
END SelectAWBS;


    (* Build the character translation table used to do ANSIToOEM
        conversion. *)

PROCEDURE BuildCharacterTable ();
VAR 
    i               : CARDINAL; 
    From            : ARRAY [0..199] OF CHAR; 
    To              : ARRAY [0..127] OF CHAR; 
    Pos             : CARDINAL; 

BEGIN 
    i := 0;
    Pos := 0; 

    LOOP
        IF (Pos > 255) THEN 
            EXIT; 
        END;

        GetMessage (6020+i, From);  

        IF (LengthOf(From) = 0) THEN
            EXIT; 
        END;
        DecodeString (From, To);
        DoDash (To, CharacterTable, Pos); 
        INC (i);
    END;
END BuildCharacterTable;



BEGIN
    BuildCharacterTable();
    OverlayID := ImAnInstallableOverlay(SelectAWBS, AnOverlayProc(NIL));  (* 20-Jan-88 LAA *)
    SelectAWBS();
END TLViewOT.

