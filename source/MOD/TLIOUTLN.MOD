MODULE TliOutLn;

(*  =========================================================================
    Last Edit : July 22, 1991 1:52PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:
       June 8, 1986  AJL  - Modified the routine which reads .head
                            files to attempt to deal with lines
                            without a .head header.
       Jun 10, 1986  AJL  - Combined TLIREADY and TLITEXT into this
                            single program.

       Mar 22, 1988 RSC   - SPIKE upgrade.
       Apr 12, 1988 RSC   - Internationalization.
           2-Jan-89 RSC   - Added references to StringsEqual() rather than Compare().
           6-Jun-89 AJL   - Put filters into flexstor.
           2-Aug-89 WKH   - Use RenumberEverything from Renumber module.
       Aug 10, 1989 KKC   - Add copyright message.
          12-Aug-89 WKH   - Make notes text window larger for compressed mode.
          23-Oct-89 EGK   - Discard the GlobalNote when we're finished with
                            it.
           7-Nov-89 RSC   - Don't save memo into Journal except for keystroke
                            transfers.  Ed's change of 23-Oct caused the
                            Journal note to be discarded, but the memo thought
                            it was still there.  Did we loose a change here?
          21-Feb-90 KKC     Remove import of Timeu.
           2-Oct-90 DSL   - Changed $'s to %'s for Unix compatability
          23-Oct-90 RSC   - Changed %'s to TMP in filenames for Dos batch.
          11-Mar-91 RSC   - Open input file read-only.
          22-Jul-91 PFG     Added "DisplayErrors" parameter to ALoadingProc
                            so that importer can do the error reporting itself 
                            when needed.
    =========================================================================
*)



FROM ASCII          IMPORT EOL;

FROM AsOf           IMPORT AsOfDate;

FROM Allocs         IMPORT TaskTree, ATaskPtr, TskNmLen;

FROM Boxes          IMPORT ABoxType, ABoxAttribute;

FROM Chart          IMPORT
    (* VAR *)              CursorTask, GanttChart;

FROM ChartForms     IMPORT
    (* TYPE *)             AChartFormatPtr,
    (* VAR  *)             LayoutTree, CurrentChartFormat,
                           DefaultChartFormat;

FROM Codes          IMPORT ACode, SetCodeBits, ASetOfCodes;

FROM Dialog         IMPORT ADialogOption, Message, Error,
                           MultipleChoiceBox, FatalError;

FROM Directory      IMPORT ExpandPath;
                    
FROM Direct411      IMPORT AlwaysApprove, AQualificationProcedure;

FROM Edits          IMPORT EditText;

FROM FileAux        IMPORT DisplayFileError, FileResultMeans,
                           PrepareForIO, CheckIO;

FROM FileSystem     IMPORT File, Response, Reset, SetPos,
                           ReadChar, SetRead, Lookup, Close,
                           Delete, WriteChar, WriteByte,
                           OpenFile, ReadOnlyMode;

FROM FilterRc       IMPORT  FilterTree, AFilterRecordPointer;

FROM GoTo           IMPORT
    (* TYPE *)             AGoToNameProc,
    (* PROC *)             DoGoTo, NullGoToCheckProc;

FROM ImportSelect   IMPORT TryToEraseSchedule, LoadAFile;

FROM InText         IMPORT ErrorFlag, AReadATaskDataProc,
                           ReadTextFile;

FROM Keys           IMPORT DoIt, CancelKey;

FROM Kbio           IMPORT maxrow, maxcol, BreakRequested, GetAnyCode,
                           PutString, avidmode, Tone, soundon;

FROM LStrings       IMPORT SetString, Insert, ConcatS, ConcatLS, Remove,
                           SubStr, LStringToTString, TrimRear, Upshift,
                           TrimFront, StoC, StringsEqual, Procustes, Fill,
                           LJust, Copy, Overlay, Search;

FROM Matches        IMPORT EndOfWord;

FROM Memos          IMPORT
    (* TYPE *)             AMemoRecordPointer,
    (* VAR  *)             MemoTree,
    (* PROC *)             CreateMemo;

FROM Menus          IMPORT WordNumber, NoYes;

FROM MsgFile        IMPORT
    (* PROC *)             GetMessage;

FROM NetLayouts     IMPORT
    (* TYPE *)             ANetworkLayout,
    (* VAR  *)             NetLayoutTree, CurrentNetLayout,
                           EnlargedNetLayout;

FROM ObjectID       IMPORT NewID, InitializeIDs;

FROM RsrcMod        IMPORT ResourceTree, AResourcePointer;

FROM Schedule       IMPORT ProjectName, ProjectMedia,
                           Author, FullScheduleName, ProjectText;

FROM TextStack      IMPORT PopText, PushText, FlushTextStack;

FROM Text           IMPORT LineExists, AssignText, TextExists, SizeOfText, 
                           CopyLine, AText, Compress, CreateText, AssignLine,
                           AppendLine, DiscardText;

FROM Tran2          IMPORT EraseAll;

FROM TreeObjects    IMPORT
    (* TYPE *)             ATreeNode, ATreeOrder,
    (* PROC *)             CreateTreeNode, ValidateTreeNode;

FROM Renumber       IMPORT
    (* PROC *)          RenumberEverything;

FROM Rugs           IMPORT ARug, GetRug, PutRug;

FROM SYSTEM         IMPORT ADDRESS;




CONST
    ModuleNumber       = 23600;

    MaxCode            = 255;
    ConsoleName        = "CON:";
    EOF                = 32C;     (*  Ctrl-Z  *)
    CarriageReturn     = 15C;
    LineFeed           = 12C;
    ReadyHeadingIs     = ".HEAD";   (* Ready! headings start with this. *)
    MaxTextLineLength  = 113C;      (* 75 decimal *)



VAR
    GlobalNote     : AText;
    ReadATaskData  : AReadATaskDataProc;
    LastReadyLevel : CARDINAL;
    f              : File;
    GlobalNoteExists,
    IndentFlag     : BOOLEAN;
    ReadyHeading   : ARRAY [0..10] OF CHAR;
    Translator     : ARRAY CHAR OF CHAR;

    (* ---------------- MODULE InputReading ----------------- *)

MODULE InputReading;

    IMPORT File, ReadChar, Response, EOL, EOF, Remove, ConcatLS,
           BreakRequested, GetAnyCode,
           CancelKey, CarriageReturn, LineFeed;

    EXPORT ReadAChar, Again;


    VAR
        LastCharacterRead : CHAR;
        AgainFlag : BOOLEAN;

        (*  ReadAChar -- Read a character from the file.  Keep a record of
                     characters read. *)

    PROCEDURE ReadAChar(VAR f:File; VAR ch:CHAR);
    VAR
        s1 : ARRAY [0..1] OF CHAR;
    BEGIN
        IF (NOT AgainFlag) THEN
            IF (BreakRequested()) THEN
                f.eof := TRUE;
            ELSE
                ReadChar(f,LastCharacterRead);
            END;

            IF (f.eof) OR (f.res <> done) THEN RETURN; END;

            IF (LastCharacterRead = EOF) OR (LastCharacterRead = CHR(CancelKey)) THEN
                f.eof := TRUE;
                RETURN;
            END;

            IF (LastCharacterRead = LineFeed) OR (LastCharacterRead = CarriageReturn) THEN
                LastCharacterRead := EOL;
            END;
        END;

        ch := LastCharacterRead;
        AgainFlag := FALSE;
    END ReadAChar;

    PROCEDURE Again(VAR f:File);
    BEGIN
        IF (NOT f.eof) THEN
            AgainFlag := TRUE;
        END;
    END Again;

BEGIN
    AgainFlag := FALSE;
END InputReading;  (* ------------ Module ------------------- *)









PROCEDURE CheckFileStatus(VAR f: File):BOOLEAN;
VAR
    s : ARRAY [0..150] OF CHAR;
BEGIN
    IF (f.eof) THEN
        RETURN FALSE;
    ELSIF (CheckIO(f) = done) THEN
        RETURN TRUE;
    END;
    FileResultMeans(f,s);
    Error(s);
    Close(f);
    RETURN FALSE;
END CheckFileStatus;






PROCEDURE ReadLString(VAR f           : File;
                      VAR ls          : ARRAY OF CHAR);
VAR
    i               : CARDINAL;
    ch              : CHAR;
BEGIN
    ls[0] := 0C;
    i     := 0;

        (*  We are ready to read the first char of the string. *)

    LOOP
        ReadAChar(f, ch);
        IF NOT(CheckFileStatus(f)) THEN
            EXIT;
        ELSIF (ch = EOL) THEN
            EXIT;
        END;
        IF ( Translator[ch] <> 0C ) AND
           ( i < HIGH(ls)         ) THEN
            INC(i);
            ls[i] := ch;
        END;
    END;
    ls[0] := CHR(i);

END ReadLString;

        












PROCEDURE SkipBlanks (VAR S : ARRAY OF CHAR;
                      VAR i : CARDINAL );
BEGIN
    WHILE (i <= ORD(S[0])) AND (S[i] = " ") DO
        INC(i);
    END;
END SkipBlanks;




PROCEDURE MakeAMemo() : AText;        
VAR
    Note    : AText;
    Changed : BOOLEAN;
    s       : ARRAY [0..69] OF CHAR;
BEGIN
    Note := CreateText();
    GetMessage( ModuleNumber + 9, s );
    EditText(2,4,78,maxrow-2, ABoxType{ShadowBox, DoubleBox}, s, 0, Note, Changed);
    IF Changed THEN
        RETURN Note;
    END;
    RETURN AText(NIL);
END MakeAMemo;





PROCEDURE GetMemoName   (       Node    : ATreeNode;
                            VAR s       : ARRAY OF CHAR );
VAR
    Memo        : AMemoRecordPointer;
BEGIN
    Memo := Node^.Methods^.GetDataObject (Node);
    CopyLine (Memo^.text, 0, s);
    LJust(s);                                    (* 24-Dec-87 LAA *)
END GetMemoName;




PROCEDURE PickAMemo() : AText;
VAR
    Memo        : AMemoRecordPointer;
    CursorNode  : ATreeNode;
    Title       : ARRAY [0..31] OF CHAR;
BEGIN
    CursorNode := MemoTree^.Methods^.GetFirst( MemoTree );
    IF (CursorNode <> NIL) THEN
        GetMessage( ModuleNumber + 8, Title );  (* "Pick a Journal Note" *)
        IF DoGoTo (MemoTree, 40, 6, 75, maxrow-7, Title, TRUE,
                   NullGoToCheckProc, GetMemoName, CursorNode) THEN
            IF (CursorNode <> NIL) THEN
                Memo := CursorNode^.Methods^.GetDataObject( CursorNode );
                RETURN Memo^.text;
            END;
        END;
    END;
    RETURN AText(NIL);
END PickAMemo;




PROCEDURE ReadATaskDataReady( VAR f     : File;
                              VAR Name  : ARRAY OF CHAR;
                              VAR Level : CARDINAL;
                              VAR Eof   : BOOLEAN  );
VAR
    i,j         : CARDINAL;
    Heading     : ARRAY [0..30] OF CHAR;
    Type        : ARRAY [0..10] OF CHAR;
    S           : ARRAY [0..255] OF CHAR;
    ok          : BOOLEAN;
BEGIN
    IF (PopText(Name,Level)) THEN
        Eof := FALSE;
        RETURN;
    END;

    Eof := f.eof;
    LOOP
        IF (ErrorFlag) OR (f.eof) OR (BreakRequested()) THEN
            Eof := TRUE;
            EXIT;
        END;
        ReadLString(f,S);
        IF (ErrorFlag) THEN
            Eof := TRUE;
            EXIT;
        END;
        TrimRear(S);
        IF (S[0] > 0C) THEN
            IF (S[1] = ".") THEN
                i := 2;
                EndOfWord(S,i,j);
                SubStr(S,Heading,1,j-1);
                Upshift(Heading);
                IF (StringsEqual(Heading,ReadyHeading)) THEN    (* RSC 1/2/88 *)
                    i := j;
                    SkipBlanks(S,i);
                    Level := StoC(S,i);
                    LastReadyLevel := Level;
                    SkipBlanks(S,i);
                    EndOfWord(S,i,i);    (* Type *)
                    SkipBlanks(S,i);
                    SubStr(S,Name,i,HIGH(Name));
                    EXIT;
                ELSE
                    SubStr(S,Name,1,HIGH(Name)-2);
                    SetString(S,"--");
                    Insert(Name,S,1);
                    Level := LastReadyLevel + 1;
                END;
            ELSE
                    (*  Think Tank seems to generate text lines
                        without .head at the start.  These appear
                        to be detail lines. *)
                Level := LastReadyLevel + 1;
                SubStr(S,Name,1,HIGH(Name)-2);
                SetString(S,"--");
                Insert(Name,S,1);
                EXIT;
            END;
        END;
    END;

    Copy( Name, S );
    IF (S[0] >  MaxTextLineLength) THEN
        S[0] := MaxTextLineLength;
    END;
    Message( S );
    ok := AppendLine( S, GlobalNote );
    GlobalNoteExists := TRUE;
END ReadATaskDataReady;









PROCEDURE ReadATaskDataText ( VAR f     : File;
                              VAR Name  : ARRAY OF CHAR;
                              VAR Level : CARDINAL;
                              VAR Eof   : BOOLEAN  );
CONST
    Space = " ";
    Tab   = 11C;
VAR
    S,
    Phrase      : ARRAY [0..255] OF CHAR;
    ok          : BOOLEAN;
BEGIN
    IF (PopText(Name,Level)) THEN
        Eof := FALSE;
        RETURN;
    END;

    Eof := f.eof;
    LOOP
        IF (ErrorFlag) OR (f.eof) OR (BreakRequested()) THEN
            Eof := TRUE;
            EXIT;
        END;

        ReadLString(f,Phrase);

        IF (ErrorFlag) THEN
            Eof := TRUE;
            EXIT;
        END;

        TrimRear(Phrase);
        
        Copy( Phrase, S );
        IF (S[0] >  MaxTextLineLength) THEN
            S[0] := MaxTextLineLength;
        END;
        Message( S );
        ok := AppendLine( S, GlobalNote );
        GlobalNoteExists := TRUE;

        IF (Phrase[0] > 0C) THEN
                (* Count the number of blanks at the start of the
                   line.  *)
            Level := 0;
            WHILE   (Phrase[0] > 0C)
               AND ((Phrase[1] = Space) OR (Phrase[1] = Tab)) DO
                INC(Level);
                Remove(Phrase,1,1);
            END;
            SubStr(Phrase,Name,1,HIGH(Name));
            EXIT;
        END;
    END;
END ReadATaskDataText;










    (* DetermineFileType -- Adjust for different file structures. *)

PROCEDURE DetermineFileType(VAR f : File );
VAR
    Heading : ARRAY [0..255] OF CHAR;
BEGIN
    ReadLString(f,Heading);
    IF (ErrorFlag) THEN
        RETURN;
    END;
    Upshift(Heading);
    IF (Search(Heading,ReadyHeading,1) = 1) THEN
        ReadATaskData := ReadATaskDataReady;
    ELSE
        ReadATaskData := ReadATaskDataText;
    END;
    Reset(f);
    SetPos(f,0,0);
END DetermineFileType;






PROCEDURE LoadIt():BOOLEAN;
BEGIN
    IndentFlag := TRUE;
        (* Decide on internal format of the file. *)
    DetermineFileType(f);

        (* Read in the new file. *)
    ReadTextFile(f,ReadATaskData,IndentFlag);

    RETURN (NOT ErrorFlag);

END LoadIt;





PROCEDURE LoadingProcedure(VAR Dir, FileName, Ext   : ARRAY OF CHAR;
                           VAR DisplayErrors        : BOOLEAN       (* 22-Jul-91 PFG *)
                          ):BOOLEAN;
VAR
    S : ARRAY [0..100] OF CHAR;
BEGIN
    DisplayErrors := TRUE;
    Copy( Dir, ProjectMedia );
    Copy( FileName, ProjectName );
    Copy( ProjectMedia, S );
    ConcatLS( S, ProjectName );
    ConcatS(  S, "." );
    ConcatLS( S, Ext );
    LStringToTString( S, S );
    PrepareForIO( f );
    OpenFile( f, S, ReadOnlyMode ); (* 12-Mar-91 RSC  *)
(*    Lookup( f, S, FALSE );*)
    IF NOT(CheckFileStatus(f)) THEN RETURN FALSE; END;
    RETURN LoadIt();
END LoadingProcedure;






PROCEDURE OutputFileError( VAR f : File;
                           VAR s : ARRAY OF CHAR );
BEGIN
    ErrorFlag := TRUE;
    DisplayFileError( f, s );
END OutputFileError;







PROCEDURE ReadNote( Text : AText );
VAR
    j,
    i  : CARDINAL;
    ok : BOOLEAN;
    S  : ARRAY [0..255] OF CHAR;
    s  : ARRAY [0..79]  OF CHAR;
    Nil: ARRAY [0..1]   OF CHAR;
BEGIN
    IF (ADDRESS(Text) = NIL) THEN RETURN; END;  (* ESC from GoTo *)

    i := 1;
    SetString( S, "DK:" );
    Nil[0] := 0C;
    ExpandPath(S,Nil,s);
    ConcatS( s, "TLIOUTLN.TMP" );   (* 23-Oct-90 RSC *)
    LStringToTString(s,s);

    Lookup(f,s,TRUE);

    IF (f.res <> done) THEN
        OutputFileError(f,s);
        RETURN;
    END;

    i := 0;
    WHILE (LineExists( Text, i )) DO
        CopyLine( Text, i, S );
        FOR j := 1 TO ORD(S[0]) DO
            WriteChar(f,S[j]);
            IF (f.res <> done) THEN
                OutputFileError(f,s);
                RETURN;
            END;
        END;
        WriteChar(f, CarriageReturn );
        WriteChar(f, LineFeed );
        INC(i);
    END;
    WriteByte(f,EOF);

    Reset(f);
    SetPos(f,0,0);

    IF (f.res <> done) THEN
        OutputFileError(f,s);
        RETURN;
    END;

        (* Call the loading procedure to actually load the
           file. *)

    ok := (TryToEraseSchedule() AND LoadIt());

    ProjectName[0] := 0C;  (* erase the name if there was one. *)

    Close(f);  (* Get rid of the temp file. *)
    Delete(s,f);
END ReadNote;








PROCEDURE GetFile();
CONST
    DiskChoice               = 1;
    DefaultKeystrokeChoice   = 3;  (* When journal present. *)
    NoJournalKeystrokeChoice = 2;  (* When journal missing. *)
VAR
    KeystrokeChoice,
    Choice       : CARDINAL;
    Note         : AText;
    Memo         : ATreeNode;
    S0           : ARRAY [0..99] OF CHAR;
    S            : ARRAY [0..80] OF CHAR;
    BoxTitle     : ARRAY [0..20] OF CHAR;
    FileName     : ARRAY [0..99] OF CHAR;
    ok           : BOOLEAN;
BEGIN

    (* If there are no journal notes, then don't offer that choice. *)

    GetMessage( ModuleNumber + 3, S  );  (* "Disk,Journal Note,Keystroke transfer" *)

    KeystrokeChoice := DefaultKeystrokeChoice;
    IF (MemoTree^.Methods^.GetFirst( MemoTree ) = NIL) THEN
        Copy( S, S0 );                   (* Take first phrase. *)
        WordNumber( S0, 1, S );
        ConcatS( S, "," );              (* Add a comma. *)
        WordNumber( S0, 3, FileName );
        ConcatLS( S, FileName );        (* Add in third phrase. *)
        KeystrokeChoice := NoJournalKeystrokeChoice;
    END;
    GetMessage( ModuleNumber + 1, S0 );  (* "Where should the file data come from?" *)
    GetMessage( ModuleNumber + 2, BoxTitle );  (* "Read File From" *)

    Choice := 1;

    IF MultipleChoiceBox( S0, BoxTitle, NoHelp, BoxTitle, S, Choice ) THEN
        GlobalNote := CreateText();
        GlobalNoteExists := FALSE;
        IF (Choice = DiskChoice) THEN
            SubStr(ProjectMedia,FileName,1,HIGH(FileName));
            GetMessage( ModuleNumber + 4, S );  (* "Pick a Text file to import" *)
            GetMessage( ModuleNumber + 5, BoxTitle );  (* "Text Import" *)
            ConcatS(FileName,"*.TXT");
            ok := LoadAFile(S,BoxTitle,FileName,TRUE,AlwaysApprove,
                            LoadingProcedure);
            Close(f);
        ELSIF (Choice = KeystrokeChoice) THEN
            Note := MakeAMemo();
            ReadNote(    Note );

            (* DiscardText( Note ); REMOVED.  7-Nov-89 RSC *)

            (* 7-Nov-89 RSC Added: *)
            IF (Note <> AText(NIL)) THEN
                Memo := CreateMemo( Note );
                IF (Memo <> ATreeNode(NIL)) THEN
                    MemoTree^.Methods^.AddFirst( MemoTree, Memo );
                ELSE
                    DiscardText( Note );
                END;
            END;
            (* 7-Nov-89 RSC End of addition *)


        ELSE
            ReadNote( PickAMemo() );
        END;


(* 7-Nov-89 RSC Removed:
        Compress( GlobalNote );
        IF (GlobalNoteExists) THEN
            Memo := CreateMemo( GlobalNote );
            IF (ADDRESS(Memo) <> NIL) THEN
                MemoTree^.Methods^.AddFirst( MemoTree, Memo );
            END;
        END;
   7-Nov-89 RSC End of removal. *)


        DiscardText (GlobalNote);           (* 10/23/89 EGK *)
        S[0] := 0C;
        Message(S);
    END;
END GetFile;




(******************************************************  02-Aug-89 WKH

PROCEDURE NumberTheTask     ( VAR Node      : ATreeNode;
                                  Context   : ADDRESS   );
VAR
    TaskPtr             : ATaskPtr;
BEGIN
    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
    TaskPtr^.TaskID := NewID();
    Node^.Methods^.UnlockFlexStorDataObject (Node);
END NumberTheTask;




PROCEDURE NumberTheResource     ( VAR Node      : ATreeNode;
                                      Context   : ADDRESS   );
VAR
    ResourcePtr             : AResourcePointer;
BEGIN
    ResourcePtr := Node^.Methods^.GetDataObject (Node);
    ResourcePtr^.ID := NewID();
END NumberTheResource;




PROCEDURE NumberTheLayout     ( VAR Node      : ATreeNode;
                                    Context   : ADDRESS   );
VAR
    LayoutPtr             : AChartFormatPtr;
BEGIN
    LayoutPtr := Node^.Methods^.GetDataObject (Node);
    LayoutPtr^.ID := CARDINAL(NewID());
END NumberTheLayout;




PROCEDURE NumberTheNetLayout  ( VAR Node      : ATreeNode;
                                    Context   : ADDRESS   );
VAR
    LayoutPtr             : ANetworkLayout;
BEGIN
    LayoutPtr := Node^.Methods^.GetDataObject (Node);
    LayoutPtr^.ID := CARDINAL(NewID());
END NumberTheNetLayout;




PROCEDURE NumberTheFilter     ( VAR Node      : ATreeNode;
                                    Context   : ADDRESS   );
VAR
    FilterPtr             : AFilterRecordPointer;
BEGIN
    FilterPtr := Node^.Methods^.LockFlexStorDataObject (Node);
    FilterPtr^.ID := CARDINAL(NewID());
    Node^.Methods^.UnlockFlexStorDataObject (Node);
END NumberTheFilter;




PROCEDURE NumberTheMemo     ( VAR Node      : ATreeNode;
                                  Context   : ADDRESS   );
VAR
    MemoPtr             : AMemoRecordPointer;
BEGIN
    MemoPtr := Node^.Methods^.GetDataObject (Node);
    MemoPtr^.ID := CARDINAL(NewID());
END NumberTheMemo;




PROCEDURE RenumberEverything();

BEGIN
    InitializeIDs (0);

    (* You may be tempted to renumber only tasks and resources, as that is
       all we ever import.  However, if the customer decides NOT to proceed
       then the schedule is intact.  Also, if we partly proceed and bail out
       early due to error, it is hard to tell if we actually changed things
       or not.  To keep it simple, we renumber EVERYTHING.
    *)
    TaskTree^.Methods^.TraverseTree (TaskTree, ParentAfterChild, 9999,
        NumberTheTask, NIL);
    ResourceTree^.Methods^.TraverseTree (ResourceTree, ParentAfterChild, 9999,
        NumberTheResource, NIL);

    FilterTree^.Methods^.TraverseTree (FilterTree, ParentAfterChild, 9999,
        NumberTheFilter, NIL);
    LayoutTree^.Methods^.TraverseTree (LayoutTree, ParentAfterChild, 9999,
        NumberTheLayout, NIL);
    NetLayoutTree^.Methods^.TraverseTree(NetLayoutTree,ParentAfterChild,9999,  (* 17-Nov-87 LAA *)
        NumberTheNetLayout, NIL);
    MemoTree^.Methods^.TraverseTree (MemoTree, ParentAfterChild, 9999,
        NumberTheMemo, NIL);

END RenumberEverything;

01-Aug-89 WKH  *******************************************)




 (* Build a list of chars we do not like.  This helps us trap garbage, or
    rather, "unknown" chars.
 *)
PROCEDURE BuildTranslatorList();
VAR
    C           : CHAR;
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
  (* MAKE THESE CHARS HAVE SOME VALUE:
  *)
    FOR C := 0C TO 377C DO
        Translator[ C ] := C;    (* Most chars pass unfiltered. *)
    END;

  (* FILTER OUT THESE:
  *)
    FOR C := 0C TO 10C DO        (* Null to just before the TAB key. *)
        Translator[ C ] := 0C;   (* 0C means "don't use this" *)
    END;
    FOR C := 12C TO 37C DO       (* after TAB to before SPACE *)
        Translator[ C ] := 0C;
    END;
    Translator[ 277C ] := 0C;    (* Allow all graphics except 255 *)

END BuildTranslatorList;





BEGIN
    ErrorFlag      := FALSE;
    LastReadyLevel := 0;
    SetString(ReadyHeading,ReadyHeadingIs);
    BuildTranslatorList();
    GetFile();
    FlushTextStack();
    CursorTask := TaskTree^.Methods^.GetFirst(TaskTree);
    GanttChart^.Methods^.SetFirst(GanttChart, CursorTask);
    GanttChart^.Methods^.SetCursorNode(GanttChart, CursorTask);
    RenumberEverything();
    Author[0]           := 0C;
    FullScheduleName[0] := 0C;
END TliOutLn.
