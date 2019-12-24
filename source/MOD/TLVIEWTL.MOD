MODULE TLViewTL;

    (* TLViewTL

       Overlay called from TLLink; Displays the possible WBS number from
       a Time Line schedule file, allows the user to select one and
       returns it.

       The context passed is the FormValue array from the link form,
       containing the file directory, file name, link type, WBS field 
       and other optional fields.

       MODIFICATION HISTORY:

        4-Feb-91 AJL -Original version.
        6-Feb-91 AJL -Use a better ReadOnly mode when opening files.
       14-Apr-91 AJL -Position intial cursor on the WBS number entered.
       30-Apr-91 AJL -Include tasks in the list even if they do not have
                      a WBS number.
       30-Jul-91 AJL - Make list items longer, so GoTo doesn't write off
                      screen.

    *) 

FROM Allocs                 IMPORT
    (* CONST *)                 WBSLen, WBSLine,
    (* TYPE *)                  ATaskPtr, ATask;

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

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue;


FROM GoTo                   IMPORT
    (* PROC *)                  DoGoTo, NullGoToCheckProc;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWStart, GanttWEnd, MaxColumn;   

FROM LStrings               IMPORT LStringToTString, ConcatLS, SetString,
                                   Copy, SubStr, TrimRear, CtoS, ConcatS, StoC,
                                   StringsEqual, Insert, SetLengthOf, LengthOf,
                                   Procustes, LJust, TStringToLString, Fill;

FROM MsgFile                IMPORT  GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays       IMPORT
        (* TYPE *)      AnOverlayID,
        (* PROCS *)     OverlayContext, ImAnInstallableOverlay;

FROM OvTree         IMPORT
    (* TYPE *)          AnOverlayProc;

FROM RecordIO               IMPORT  ReadRecord, ReadString, ReadRecordPreface,
                                    ReadRecordBody, ReadStringBody;

FROM Rugs           IMPORT
    (* TYPE *)          ARug,
    (* PROC *)          GetRug, PutRug;

FROM Space          IMPORT
    (* PROC *)          Available, ALLOCATE, DEALLOCATE;

FROM Subfiles               IMPORT  StartFileInput, StartSubfileInput;

FROM SYSTEM         IMPORT
    (* Type *)          ADDRESS,
    (* PROC *)          ADR, SIZE, TSIZE;

FROM Text           IMPORT
        (* PROCS *)     DiscardText, AssignText, TextExists, SizeOfText, 
                        LineExists, CopyLine, AText, Compress, CreateText,
                        AssignLine, AppendLine;

FROM Transfer               IMPORT
    (* TYPE *)                  AHeaderRecord;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeNodeAttribute,
                        CreateTree, CreateTreeNode;

FROM V3Tasks                IMPORT
    (* TYPE *)                  ATaskV3, AV3BigDateBlock,
    (* PROC *)                  ConvertTaskFromV3;

FROM V4Tasks                IMPORT
    (* TYPE *)                  ATaskV4, AV4BigDateBlock,
    (* PROC *)                  ConvertTaskFromV4;


CONST
    ModuleNumber = 27900;   (* Share with TLLnkOT? *)


        (* Layout of the GoTo box. *)
    WBSWidth = 30;                   (* Maximum width *)
    NameWidth = 44;
    Spacer    = 5;

    LinesPerNode = 2;   (* Two text lines for each tree node. *)
    NameLine     = 1;

    PATH    = 0;    (* Drive and directory                      *)
    NAME    = 1;    (* File and extension                       *)
    LTYP    = 2;    (* Link type (0=schedule, 1=task)           *)
    LWBS    = 3;    (* Link WBS code                            *)
    LDAT    = 4;    (* Copy (Start date + duration, end date)   *)
    RCOP    = 5;    (* Copy resources? (No, Yes)                *)

    MinimumWBSNumberLength   = 6;  (* Minimum width on GoTo list. *)
    MinimumTaskNameLength    = 6;  


VAR
    OverlayID               : AnOverlayID;
        (* Text holds the WBS numbers. *)
    Text                    : AText;           (* Not reentrant. *)
        (* Width of Display *)
    DisplayWBSNumberLength,
    DisplayTaskNameLength   : CARDINAL;

        (* Used when reading tasks, but here so they aren't on the stack. *)
    newtask                 : ATask;
    newtaskV3               : ATaskV3;
    newtaskV4               : ATaskV4;




PROCEDURE Complain( N : CARDINAL );
VAR 
    S : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(N,S);
    Error(S);
END Complain;




PROCEDURE SkipRecordBody(VAR F      : File;
                             Length : CARDINAL );
VAR
    i : CARDINAL;
BEGIN
    ReadRecordBody(F,Length,ADR(i),0);
END SkipRecordBody;






PROCEDURE LoadWBSNumbers( VAR F : File;
                          VAR Text : AText;
                          VAR Count : CARDINAL );
CONST
    HeaderType            = 0;
    TaskType              = 6;
    OldCodingType         = 123;
    CodingType            = 124;
VAR
    Version                 : CARDINAL;
    Task                    : ATaskPtr;
    TaskVersion,
    i                       : CARDINAL;
    Duration                : REAL;
    Type                    : CARDINAL;
    Length                  : CARDINAL;
    Header                  : AHeaderRecord;
    CodingRecord            : RECORD 
                                  LineNumber : CARDINAL;
                                  S          : ARRAY [0..255] OF CHAR;
                              END;
    CodingLineNo            : CARDINAL;
    S                       : ARRAY [0..255] OF CHAR; 
    WBSNumber               : ARRAY [0..41] OF CHAR;
    TaskPending             : BOOLEAN;



        (* Store the WBS number and task name.
           Accumulate maximum lengths and task count. *)

    PROCEDURE ProcessWBSNumber( VAR WBS : ARRAY OF CHAR;
                                VAR Name : ARRAY OF CHAR;
                                    Level : CARDINAL);
    VAR 
        S : ARRAY [0..79] OF CHAR;
    BEGIN
            (* Indent the name. *)
        Fill(S," ",Level*2);
        ConcatLS(S,Name);
            (* Store WBS number and name *)
        IF NOT (AppendLine(WBS,Text) AND
                AppendLine(S,Text)) THEN
            RETURN;
        END;
            (* Save maximum size. *)
        IF (LengthOf(WBS) > DisplayWBSNumberLength) THEN
            DisplayWBSNumberLength := LengthOf(WBS);
        END;

        IF (LengthOf(S) > DisplayTaskNameLength) THEN
            DisplayTaskNameLength := LengthOf(S);
        END;

        INC(Count);

    END ProcessWBSNumber;



BEGIN
    DisplayWBSNumberLength := MinimumWBSNumberLength;
    DisplayTaskNameLength  := MinimumTaskNameLength;


    IF NOT (StartFileInput(F) AND 
            StartSubfileInput(F,TaskType,Version)) THEN
        RETURN;
    END;

    (* Reset to the beginning of the file and read records, looking
       for WBS numbers  When one is found, store it into the Text and
       store the line number of the text into the TaskIDTable[ID]. *)


    Count    := 0;
    TaskPending := FALSE;



    LOOP
        ReadRecordPreface (F,Type,Length);
        IF (CheckIO(F) <> done) THEN
            EXIT;
        END;
        CASE Type OF
            HeaderType :
                    (* Store the previous task. *)
                IF (TaskPending) THEN
                    ProcessWBSNumber(WBSNumber,newtask.taskname,
                                     Header.Level); 
                END;

                (* Read this task. *)
                ReadRecordBody (F,Length,ADR(Header),SIZE(Header));

                SetLengthOf(WBSNumber,0);
                TaskPending := TRUE;

          | TaskType :
                CodingLineNo := 0;

                IF (Length = SIZE(newtask)) THEN
                    ReadRecordBody (F,Length,ADR(newtask),SIZE(newtask));
                    TaskVersion := 50;

                ELSIF (Length = SIZE(newtaskV3)) THEN
                    ReadRecordBody (F,Length,ADR(newtaskV3),SIZE(newtaskV3));
                    ProcessWBSNumber(newtaskV3.WBS,newtaskV3.taskname,
                                     Header.Level);
                    TaskVersion := 30;
                    TaskPending := FALSE;

                ELSIF (Length = SIZE(newtaskV4)) THEN
                    ReadRecordBody (F,Length,ADR(newtaskV4),SIZE(newtaskV4));
                    ConvertTaskFromV4 (newtaskV4, newtask );
                    TaskVersion := 40;

                END;

        |   OldCodingType :     (* Text format for version 4.0 and earlier. *)

                ReadStringBody(F, Length, S);

                IF (CodingLineNo = WBSLine) AND (TaskVersion >= 40) THEN 
                    Copy(S,WBSNumber);
                END;
                INC (CodingLineNo);

        |   CodingType :       (* Text format for version 5.0 *)

                ReadRecordBody(F, Length, ADR(CodingRecord), SIZE(CodingRecord));

                IF (CodingRecord.LineNumber = WBSLine) THEN
                    IF (TaskVersion >= 40) THEN
                        Copy(CodingRecord.S,WBSNumber);
                    END;
                END;

        |   0FFH : EXIT;
        ELSE
            SkipRecordBody(F,Length);
        END;
    END;


        (* Store the previous task. *)
    IF (TaskPending) THEN
        ProcessWBSNumber(WBSNumber,newtask.taskname,
                         Header.Level); 
    END;

    IF (DisplayWBSNumberLength > WBSWidth) THEN
        DisplayWBSNumberLength := WBSWidth;
    END;
    IF (DisplayTaskNameLength > NameWidth) THEN
        DisplayTaskNameLength := NameWidth;
    END;

END LoadWBSNumbers;





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
            (* Add the node to the tree, at the end, since TL files
               are stored in display order. *)
        LinkTree^.Methods^.AddLast(LinkTree,TreeNode);
            (* Next line. *)
        INC(i,LinesPerNode);
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







PROCEDURE FileComplaint(VAR f:File);
VAR
   s  : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,s);    (* "Detail file " *)
    DisplayFileError( f, s );        (* RSC 2/19/88    *)
END FileComplaint;







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



BEGIN
    OverlayID := ImAnInstallableOverlay(SelectAWBS, AnOverlayProc(NIL));  (* 20-Jan-88 LAA *)
    SelectAWBS();
END TLViewTL.
