MODULE TLVuTW1;

(*V1=DEBUG*)

    (* TLViewTLW

       Overlay called from TLLink; Displays the possible WBS numbers from
       a Time Line Windows schedule file, allows the user to select one and
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
       13-Jan-92 AJL - Created from TLViewOT.
       23-Mar-92 TGS - Do ANSIToOEM conversion.

    *) 

(*<DEBUG
FROM Boxes                  IMPORT
                                ABoxType, ABoxAttribute;
DEBUG>*)


FROM Dialog                 IMPORT
    (* PROC *)                  Error, Burp, ErrorPhrase;

FROM Directory              IMPORT
    (* TYPE *)                  AFileNamePart, ASetOfFileNameParts,
    (* PROC *)                  NormalizeFileName, RemovableMedia;


(*<DEBUG
FROM Edits                  IMPORT
                                EditText;
DEBUG>*)

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

FROM LStrings               IMPORT LStringToTString, ConcatLS, SetString, Fill,
                                   Copy, SubStr, TrimRear, CtoS, ConcatS, StoC,
                                   StringsEqual, Insert, SetLengthOf, LengthOf,
                                   Procustes, LJust, TStringToLString, Compare;

FROM MsgFile                IMPORT  GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays       IMPORT
        (* TYPE *)      AnOverlayID,
        (* PROCS *)     OverlayContext, ImAnInstallableOverlay;

FROM OvTree         IMPORT
    (* TYPE *)          AnOverlayProc;

FROM Rugs           IMPORT
    (* TYPE *)          ARug,
    (* PROC *)          GetRug, PutRug;

FROM Space          IMPORT
    (* PROC *)          Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM         IMPORT
    (* Type *)          ADDRESS,
    (* PROC *)          SIZE, TSIZE;

FROM Text           IMPORT
        (* PROCS *)     DiscardText, AssignText, TextExists, SizeOfText, 
                        LineExists, CopyLine, AText, Compress, CreateText,
                        AssignLine, AppendLine;

FROM TLW1File                IMPORT
    (* TYPE *)                  ATLWinTask, AFileHeaderRecord,
    (* PROC *)                  ReadRecordPreface, ReadRecordBody,
                                SkipRecordBody, StartFileInput; 

FROM TreeObjects    IMPORT
    (* TYPE *)          ATree, ATreeNode, ATreeNodeAttribute,
                        CreateTree, CreateTreeNode;


CONST
    ModuleNumber = 30600;   (* Share with TLLnkTW1 *)


        (* Layout of the GoTo box. *)
    WBSWidth = 30;                   (* Maximum width *)
    NameWidth = 30;
    Spacer    = 5;

    LinesPerNode = 2;   (* Two text lines for each tree node. *)
    WBSLine      = 0;
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

    CharacterTable          : ACharacterConversionTable;


PROCEDURE FileComplaint(VAR F:File);
VAR
   s  : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,s);    (* "Time Line Windows file " *)
    DisplayFileError( F, s );
END FileComplaint;


PROCEDURE Complain( N : CARDINAL );
VAR 
    S : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(N,S);
    Error(S);
END Complain;






PROCEDURE LoadWBSNumbers( VAR F : File;
                          VAR Text : AText;
                          VAR Count : CARDINAL );
VAR
    Length                  : LONGINT;
    Type                    : CARDINAL;
    ID                      : CARDINAL;
    MaxTaskNumber           : CARDINAL;
    LineUsed                : CARDINAL;
    NextLineUsed            : CARDINAL;
    S                       : ARRAY [0..255] OF CHAR;
    S2                      : ARRAY [0..61] OF CHAR;
    TLWinTask               : ATLWinTask;
    i                       : CARDINAL;
    Changed                 : BOOLEAN;  (* DEBUGGING *)
    FileHeaderRecord        : AFileHeaderRecord;
BEGIN
    DisplayWBSNumberLength := MinimumWBSNumberLength;
    DisplayTaskNameLength  := MinimumTaskNameLength;


    IF NOT StartFileInput(F,FileHeaderRecord) THEN
        Count := 0;
        RETURN;
    END;

    MaxTaskNumber := FileHeaderRecord.MaximumTaskID;

    (* Reset to the beginning of the file and read records, looking
       for task records, WBS numbers and Task Names.  The task record
       must precede the task name and wbs records, and there must not
       be any intervening records from other tasks.

       This fills in the text array containing WBS, Task Name and sort
       sequence.
    *)

    NextLineUsed := 0;   (* Counts text lines used. *)
    Count        := 0;

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
                    IF (Length <> VAL(LONGINT,SIZE(TLWinTask))) THEN
                        Complain(ModuleNumber+12);
                        EXIT;
                    END;
                    ReadRecordBody (F,Length,TLWinTask);
                        (* Unless this is the record summarizing the entire
                           project, store the task information.  In the case
                           of task records, they don't contain the fields we
                           need, so we just set aside space for the WBS and
                           task name. *)
                    IF (ID <> 0) THEN
                            (* Record the line number used. *)
                        LineUsed := NextLineUsed;
                        INC(NextLineUsed, LinesPerNode );
                        INC(Count);
                            (* Add blank lines that will later hold
                               the task name and wbs number. *)
                        SetLengthOf(S,0);
                        FOR i := 1 TO LinesPerNode DO
                            IF NOT (AppendLine(S,Text)) THEN
                                ErrorPhrase(ModuleNumber+19);
                                EXIT;
                            END;
                        END;
                    END;

              | 35 : (* A WBS Number *)
                    ReadRecordBody (F,Length,S);
                    IF (ID <> 0) THEN
                        TStringToLString(S,S);
                        ConvertString(S, CharacterTable);   (* 23-Mar-92 TGS *)
                        IF (NOT AssignLine(S,LineUsed+WBSLine,Text)) THEN
                            EXIT;
                        END;
                            (* Save maximum size. *)
                        IF (LengthOf(S) > DisplayWBSNumberLength) THEN
                            DisplayWBSNumberLength := LengthOf(S);
                        END;
                    END;
                        

              | 36 : (* A Task Name *)
                    ReadRecordBody (F,Length,S);
                    IF (ID <> 0) THEN
                        TStringToLString(S,S);
                        ConvertString(S, CharacterTable);   (* 23-Mar-92 TGS *)
                            (* Indent the task name. *)
                        IF (TLWinTask.Level > 1) THEN
                            Fill(S2," ",(TLWinTask.Level-1) * 2);
                            Insert(S,S2,1);
                        END;
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


    IF (DisplayWBSNumberLength > WBSWidth) THEN
        DisplayWBSNumberLength := WBSWidth;
    END;
    IF (DisplayTaskNameLength > NameWidth) THEN
        DisplayTaskNameLength := NameWidth;
    END;


    (*<DEBUG
    Fill(S," ",0);
    EditText(0,2,79,23,ABoxType{DoubleBox},S,0,Text,Changed);
    DEBUG>*)

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
            (* Add the node to the tree.   TL Windows tasks are stored
               in outline display (Parent before Child) order.  *)
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
END TLVuTW1.

