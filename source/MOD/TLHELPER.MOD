    (*V1=DOS  stores file offsets directly in the tree node.    *)
    (*V2=OS2  creates data records to store file offsets.       *)
    (*V3=DEBUG Activates trace option on Alt-F9. *) 

MODULE TLHelper;

(*  =========================================================================
    Last Edit : October 9, 1991 8:32PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

       25 Jun 86   AJL - Add conditional Goto based on KeyPress.
                       - Add goto line command ("@").
                       - Add pause command, "#".
       14 Jul 86   AJL - Add indentation command, ")".
                       - Stack the indentations and y positions on
                         each subtext call.
                       - All @ positioning is relative to the starting
                         y as of the subtext call.
                       - Allow @-n to position relative to the end
                         of the window.
       24 Jul 86   AJL - Add "^" command to call a named overlay.
                         "^>" will call a named overlay file.
                         "^@" will execute the action given in plwhat.cfg.
                         "^=" will call the dispatcher with the following keycode.
                       - These commands can be also given in the menus,
                         that is, a menu choice (or alias) can begin with
                         a "^" character.
                       - Nested help does not overwrite the lights (last)
                         line on the screen.
                       - Modified the routines to allow reentrant calls
                         to GiveHelp.
       11/12/86 LAA    - In OpenHelpFiles, added a call to PrepareForIO.
       07/23/87 AJL    - Remove references to Dispatcher and RunMenu.
       08/24/87 EGK      Incorporated new object-oriented indexing scheme.
                         Moved expander into its own external module.
        9/29/87 AJL    - Changed the video control character to 375C
                         (Alt-253).
       10/14/87 EGK      Moved help index procedures outside of ManageHelp
                         and added TakeABranch procedure to allow
                         EscapeToOverlay (or any other routine) to directly
                         get a help item.
       2/3/87 EGK        Added interlocking to prevent recursive use of the
                         help index.
       2/15/88 EGK       TakeABranch checks for stack space before calling
                         ManageHelp recursively.  In version 2.0, checking
                         HeapAvailable accomplished the same thing; not so 
                         here.
       2/25/88 RSC       In my manic-compulsive style, I cleaned up odd-
                         aligned stack items.
       2/29/88 AJL      -Redid the indexing method to use new format (faster)
                         index file.
                        -?? Changed the default indentation to 1 from 2.
        3/3/88 EGK       Put up a "Please wait" box when loading index tree.
                         Disabled creation of HelpRecord objects; file
                         position is taken directly from the tree node's
                         DataObject and file variable from TextFile global.
        6-Mar-88 LAA     Inhibit the help key from the help index.
       14-Sep-88 AJL    -Allow help tracing.
                        -Allow change of the end-of-line character.  Whichever
                         character, RS (decimal 30) or Carriage Return (decimal
                         13), first appears in the helptext is used as the 
                         end of line character.   This requires a version of
                         Expander that uses ReadByte.  This makes this module
                         compatible with a proposed change to MakeHelp.
       13-Oct-88 EGK     Created OS/2 version by resurrecting code to attach
                         data records to each node in the help index tree.
       26-Oct-88 EGK     In TakeABranch, flipped the order in which stack and
                         heap are checked.  It was possible to run out of stack
                         while checking for heap.
        2-Jan-89 RSC     Added references to StringsEqual() rather than Compare().
       23-Jan-89 RSC     Changed Storage to Space    .
        2-Mar-89 AJL    -Use the Kbio.PourText procedure to write text to the 
                         screen.  This new version of PourText manages font changes.  
                        -Enable the trace mode toggle "DEBUG" which activates
                         the F9 key to provide a history of the help keys which
                         were accessed.  This is to help the tech writers
                         figure out what parts of the help text file need 
                         changing to affect the displayed help screen.
       15-Jun-89 AJL    -Changed OverlayPath to TextPath. 
       10-Aug-89 KKC    -Add copyright message.
        6-Sep-89 AJL    -Add conditional page break commands.  "/" will break
                         if there is less than half a screen left.
                         "//" will break unconditionally.   "/<anumber>"
                         will break if fewer than <anumber> lines remain.
                        -Support substitution for embedded keywords, similarly to
                         the reports headers.
                        -Embedded parameters, *1*, *2*, etc. can also be substituted.
                         Parameters are passed in to GiveHelp in parenthesis
                         after the subject, as in SUBJECT((P1)(P2)).
                        -Overlays are now called using the OverlayPackage
                         procedure which can supply parameters.
       12-Sep-89 WKH    -Make goto box bigger for compressed video mode.
       13-Sep-89 WKH    -Make Cursor go away in help, FOREVER!!!!
       20-Sep-89 AJL    -Expand the MaxInputLineLength from 80 to 255 (and
                         declare this as a constant, rather than embededded
                         numbers.) 
                        -Reduced the maximum menu prefix length from maxcol+1
                         to 31 (to save stack space).
       21-Sep-89 AJL    -Default menu prefix is now not blank, but phrase #7,
                         " Help:"
                        -Turned off F9 DEBUG trace.
                        - "+" in position 1 replaces menu choice,
                          "++" appends additional choices,
                          "=" sets goto equivalences for menus,
                          "=+" appends additional goto's.
       16-Nov-89 LAA    -Changed the stack check in TakeABranch to require
                         3500 bytes instead of 3000.  Turned out that 3000
                         wasn't enough, and Kris was able to produce a stack
                         overflow.
       11-Dec-89 RSC    -New menu parameter, fixed "no help" message.
       15-Dec-89 RSC    -Mouse support (changed GetAnyCode to GetNextEvent).
       4-Jan-90  AJL    -If the screen action is LeaveTheText, any mouse click
                         outside the menu will exit the help.  This is a bit of 
                         a kluge to make the help on forms easier to discard.
       1-Jan-90  AJL    -When a user presses Esc after taking a branch, we no
                         longer return to the screen before the branch.  Instead,
                         we do whatever we would have done had we not branched. 
      12-Mar-91  AJL    -Added documentation.
      29-Mar-91  AJL    -Corrected a problem with propagation of parameters.
                        -Reduced the stack consumption when branches are taken.
                        -Substitute parameters into all strings read from file.
                        -Added Backtrack capability.
                        -Better error checking, documentation, many small bug
                         fixes.
       3-Apr-91  AJL    -Don't try to backtrack past the initial page.
      12-May-91  AJL    -Add HelpExists.
      31-May-91  AJL    -Bug fix: cancel LineWaiting if user chooses to
                         backtrack.
                        -Correct order of some arithmetic to avoid overflow.
                        -Call InitPage early on, so that if we cannot find
                         the passed help key, we don't crash for writing off
                         screen.
       2-Jul-91  AJL    -Move several strings out of ManageHelp and to 
                         global allocation in order to save stack space. 
                        -If a help key is not found, we don't put up an
                         empty screen after the error message.
                        -Changed the TRACE key from F9 to ALT-F9.
      23-Jul-91  AJL    -Put imports into alphabetical order.
      17-Sep-91  AJL    -Correct printing to not drop last character of lines.
      22-Oct-91  AJL    -Allow the help index to nest, in order to find the
                         child topics of a main topic.
      22-Jan-92  AJL    -Put in phrases for the titles of the bookmarks boxes.
                        -Printing is forced out to hardcopy.
      25-Feb-92  AJL    -Add command "%" which sets an abstract (title) for
                         bookmarks, for topics in which the first line is
                         not a good summary.
    =========================================================================
*)

FROM ActiveViews            IMPORT
    (* TYPE *)                  AnActiveView;

FROM ASCII      IMPORT EOL;

FROM Boxes      IMPORT ABoxType, ABoxAttribute, DrawBox, GetInnerBoxSize;

FROM Clock      IMPORT Delay;

FROM Codes      IMPORT  SetCodeBits, ACode, ASetOfCodes, MaxCode;

FROM Dialog     IMPORT  Error, WarningBox, FatalError, Burp,
                        ADialogOption, NotYetImplemented, Message,
                        MultipleChoiceBox,
                        ABoxHandle, ProgressBox, ReleaseBox,
                        ErrorPhrase;

FROM Events     IMPORT
    (* TYPE *)          AnEvent, AnEventType,
    (* PROC *)          GetNextEvent;

FROM Expander               IMPORT
    (* PROC *)                  ReadUncompressedChar, InitExpansion;

FROM FileSystem IMPORT  File, Response, Close, ReadByte, ReadNBytes,
                        ReadWord, SetPos, GetPos, Reset;

FROM FileAux    IMPORT  FileResultMeans, PrepareForIO, CheckIO,
                        TextPath;

FROM FileOpen   IMPORT  RequestFileOpenReadOnly;

FROM FlexStor               IMPORT
    (* TYPE  *)                 AnExtHandle, AnExtStoragePreference,
    (* PROC *)                  GetExtData, SetExtData, LockObject,
                                ReleaseObject, CreateExtObjectWithSize;

FROM Foreign    IMPORT ConvertedCharacter, UpshiftTable;

FROM GoTo                   IMPORT
    (* PROC *)                  DoGoTo, NullGoToCheckProc;

FROM Helper                 IMPORT
    (* TYPE *)                  AScreenAction, AContextPointer;

FROM Holder                 IMPORT
    (* TYPE  *)                 AHoldType, AHoldTypeSet,
    (* PROC  *)                 LocateHeldItem, HoldThis, DeleteHeldItem;

FROM Kbio       IMPORT  ascreeny, maxrow, maxcol, ACursorType, GetCursorType,
                        GetCode, PutString, avidmode, SetCursorType,
                        ascreenx, KeyPress, PourText, PushCode;

FROM KeywdSub   IMPORT
    (* PROC *)      MakeSubstitutions;

FROM Keys       IMPORT  DoIt, CancelKey, HelpKey, ExitKey, ComputeKey,
                        PgUpKey, PgDnKey, HelpIndexKey, MouseDouble,
                        DsplyKey, GotoKey;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWStart, GanttWEnd, MaxRow, MaxColumn;   

FROM Lights     IMPORT EnableLights;

FROM LStrings   IMPORT  ConcatLS, ConcatS, SetString, Procustes, SetLengthOf,
                        SubStr, Remove, Upshift, StringsEqual, Fill, Insert,
                        Search, StoC, CtoS, LengthOf, LJust, TrimRear,
                        Copy, Overlay;   

FROM Menus      IMPORT Menu;

FROM MsgFile    IMPORT GetMessage, ConcatMessage, DisplayMessage;

FROM OutlineViews   IMPORT  AnOutlineView;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  OverlayContext, ImAnInstallableOverlay,
                                OverlayPackage;

FROM PrintStatic    IMPORT
    (* TYPE *)          APrinterStyle,
    (* VAR *)           PrintCB;

FROM PrintSupport   IMPORT
    (* PROC *)      StartReport, EndReport, PageTop, PrintLine,
                    PageWidth, PrintText;

FROM Rugs       IMPORT ARug, GetRug, PutRug;

FROM SegWords   IMPORT WordNumber;

FROM Space      IMPORT HeapAvailable, StackSpaceLeft, ALLOCATE, DEALLOCATE;

IMPORT SchedKey;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  ADR, SIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode, ATreeOrder,
    (* PROC *)                  CreateTree, CreateTreeNode,
                                ValidateTree, ValidateTreeNode;

FROM Words  IMPORT
    (* PROC *)                  FindNextWord, ParseBal;


CONST
    TextNameNumber = 12;
    IndexNameNumber = 13;
    TagLength  = 8;
    MaxChoicesLen = 250;
    MaxSaveChoicesLen = 79;
    ModuleNumber = 1900;    (* For GetMessage *)
    OurTag = 0B0B0H;
    CarriageReturn = 15C;   (* Our preferred end-of-line character. *)
    MaxInputLineLength = 255;  (* The longest line we can read from the text file. *)

       (* For book marks *)
    NumberOfMarks   = 9;
    MarkKey         = 354;        (* Ctrl-F5 *)
    JumpKey         = GotoKey;    (* F5 *)   


TYPE
    AFilePtr = POINTER TO File;

    AHelpRecordPointer = POINTER TO AHelpRecord;

    AHelpRecord = RECORD
                    FilePtr     : AFilePtr;
                    High,
                    Low         : CARDINAL;
                  END;

    AFilePosition = RECORD
                        CASE BOOLEAN OF
                            TRUE :
                                High, Low   : CARDINAL;
                        |   FALSE :
                                Addr        : ADDRESS;
                        END;
                    END;




VAR
    IndexTree               : ATree;
    LastHigh,
    LastLow                 : CARDINAL;
    LastNode                : ATreeNode;
    IndexFile, TextFile     : File;

    OverlayID               : AnOverlayID;

    IndexInited             : BOOLEAN;
    IndexInterlock          : BOOLEAN;
    IndexActive             : BOOLEAN;
    EOLChar                     : CHAR;
    FormerPrintStyle        : APrinterStyle;



    LineWaiting       : BOOLEAN;
        (* s is the waiting line. *)
    s                 : ARRAY [0..MaxInputLineLength]      OF CHAR;
    Choices           : ARRAY [0..MaxChoicesLen] OF CHAR;
    ChoiceEquivalents : ARRAY [0..MaxChoicesLen] OF CHAR;



    (* -------------------- Help Trace ----------------------------- *)

CONST
    TraceKey = 368;    (* Alt-F9 *)
    

MODULE Tracing;
    IMPORT Copy, SubStr, 
           SetString, DrawBox, GetInnerBoxSize, ABoxAttribute, ABoxType,
           ascreenx, ascreeny, avidmode, CtoS, Overlay, PutString, Fill,
           ARug, GetRug, PutRug, GetNextEvent, AnEvent, ACode;

    EXPORT TraceLS, ShowTrace, ClearTrace;

    CONST
        MaxTrace = 20;
    CONST
        ULX = 39;
        ULY = 3;
        LRX   = 79;
        LRY   = 23;

    TYPE
        ATraceRecord = RECORD
                           Seq  : CARDINAL;
                           What : ARRAY [0..11] OF CHAR;
                           Seen : BOOLEAN;
                       END;
    VAR
        In, N       : [0..MaxTrace-1];
        TraceQ      : ARRAY [0..MaxTrace-1] OF ATraceRecord;
        TraceCount  : CARDINAL;
        TraceSequence : CARDINAL;


PROCEDURE TraceLS( What : ARRAY OF CHAR );
BEGIN
    IF (TraceCount = 0) THEN
        INC(TraceCount);    (* Suppress internal usage. *)
        TraceSequence := (TraceSequence + 1) MOD 1000;
        TraceQ[In].Seq := TraceSequence;
        Copy(What,TraceQ[In].What);
        TraceQ[In].Seen := FALSE;
        In := (In+1) MOD MaxTrace;
        IF (N < MaxTrace-1) THEN
            INC(N);
        END;
        DEC(TraceCount);  (* End suppression of internal use. *)
    END;
END TraceLS;



PROCEDURE ShowTrace();
VAR
    Event   : AnEvent;
    Y       : ascreeny;
    i, Count : CARDINAL;
    S,S2    : ARRAY [0..61] OF CHAR;
    iULX, iLRX : ascreenx;
    iULY, iLRY : ascreeny;
    Rug : ARug;
BEGIN
    IF (NOT GetRug(ULX,ULY,LRX,LRY,Rug)) THEN RETURN; END;

    SetString(S,"Help Trace");
    DrawBox(ULX,ULY,LRX,LRY,ABoxType{SingleBox,ShadowBox},S,videonormal);
    iULX := ULX;
    iULY := ULY;
    iLRX := LRX;
    iLRY := LRY;
    GetInnerBoxSize(iULX,iULY,iLRX,iLRY,ABoxType{SingleBox,ShadowBox});

    Y := iULY;
    i := In;
    Count := 0;
    WHILE ( Y <= iLRY ) AND (Count < N) DO
        i := (i + MaxTrace - 1) MOD MaxTrace;
        Fill(S," ",iLRX-iULX+1);
        CtoS(TraceQ[i].Seq,S2);
        Overlay(S,S2,1,5);
        Overlay(S,TraceQ[i].What,5,ORD(TraceQ[i].What[0]));
        IF (TraceQ[i].Seen) THEN
            PutString(S,iULX,Y,videonormal);
        ELSE
            PutString(S,iULX,Y,videobright);
        END;
        TraceQ[i].Seen := TRUE;
        INC(Y);
        INC(Count);
    END;
    GetNextEvent(Event);
    PutRug(ULX,ULY,LRX,LRY,Rug);
END ShowTrace;


PROCEDURE ClearTrace();
BEGIN
    In := 0;
    N  := 0;
    TraceCount := 0;
    TraceSequence := 0;
END ClearTrace;



BEGIN
    ClearTrace();
END Tracing;
    (* ---------------- End Tracing Module -----------------------------*)




    (*--------------- BookMarks module ------------------------- *)

    (* Allows the user to mark various points in the help text and
       then return to those points by selecting them from a list.
    *)

MODULE BookMarks;
IMPORT
    TagLength, NumberOfMarks,
    Copy, SetLengthOf, LengthOf, CtoS, SetString,
    ConcatS, ConcatLS, SubStr, LJust, TrimRear, Remove,
    Fill, Search,
    GetMessage, MultipleChoiceBox, ADialogOption,  ErrorPhrase,
    CreateTree, CreateTreeNode, ATree, ATreeNode,
    ADDRESS, ADR, SIZE,
    DoGoTo, AnOutlineView, ACode, HelpKey, HelpIndexKey, Burp,
    GanttWStart, GanttWEnd, MaxColumn, MaxRow, 
    IndexInterlock,
    AHoldType, AHoldTypeSet,
    LocateHeldItem, HoldThis, DeleteHeldItem,
    AnExtHandle, AnExtStoragePreference,
    GetExtData, SetExtData,
    CreateExtObjectWithSize, ModuleNumber;

EXPORT QUALIFIED
    SetTopic, SetAbstract, SetBookMark, QueryBookMark, InitBookMarks,
    Terminate;
TYPE
    ATopic     = ARRAY [0..TagLength] OF CHAR;
    AnAbstract = ARRAY [0..43] OF CHAR;
    ABookMark  = RECORD 
                     Topic : ATopic;
                     Abstract : AnAbstract;
                 END;

VAR
    MostRecentTopic   : ATopic;
    MostRecentAbstract: AnAbstract;
    BookMark          : ARRAY [0..8] OF ABookMark;
    BookMarksHandle   :   AnExtHandle;             (* FlexStor copy of marks. *)
    i                 : CARDINAL;
    NeedAbstract      : BOOLEAN;



PROCEDURE SetTopic( VAR S : ARRAY OF CHAR );
BEGIN
    Copy(S,MostRecentTopic);
    NeedAbstract := TRUE;     (* Capture the next interesting line of text. *)
END SetTopic;


PROCEDURE SetAbstract( S : ARRAY OF CHAR );
CONST
    ChangeFont = 375C;              (* Alt-253 *)
VAR
    i : CARDINAL;
    S3 : ARRAY [0..3] OF CHAR;
BEGIN
    IF (NeedAbstract) THEN
            (* Clean the line of font changes and leading/trailing blanks. *)
        i := 1;
        WHILE (i <= LengthOf(S)) DO
            IF (S[i] = ChangeFont) THEN
                Remove(S,i,2);
            ELSE
                INC(i);
            END
        END;
            (* If there are 3 or more blanks in a row, end the phrase there. *)
        Fill(S3," ",3);
        i := Search(S,S3,1);
        IF (i > 0) THEN
            Remove(S,i,LengthOf(S)-i+1);
        END;
        LJust(S);  TrimRear(S);
        IF (LengthOf(S) > 0) THEN
            SubStr(S,MostRecentAbstract,1,HIGH(MostRecentAbstract));
            NeedAbstract := FALSE;
        END;
    END;
END SetAbstract;



PROCEDURE GoToCheckProc(    Outline     : AnOutlineView;
                            Tree        : ATree;
                        VAR Code        : ACode         );
BEGIN
        (* Prevent recursion. *)
    IF (Code = HelpKey) OR (Code = HelpIndexKey) THEN
        Code := 0;
        Burp;
    END;
END GoToCheckProc;


    (* SetBookMark -- Allow the user to select a book mark
                      number, and then set that book mark
                      value to reference the current text passage.
                      *)

PROCEDURE SetBookMark();
CONST
    TotalWidth          = 54;
    TotalHeight         = HIGH(BookMark);  (* Borders. *)
VAR
    Title : ARRAY [0..61] OF CHAR;
    Changed : BOOLEAN;
    BookMarkTree        : ATree;
    Node,FirstNode      : ATreeNode;
    i,N                 : CARDINAL;
    ULX,LRX             : CARDINAL;
    ULY,LRY             : CARDINAL;
BEGIN
    IndexInterlock := TRUE;

        (* Center the pick list. *)
    ULX := (MaxColumn - TotalWidth) DIV 2;
    LRX := ULX + TotalWidth;
    IF (LRX > MaxColumn) THEN
        LRX := MaxColumn;
    END;
    ULY := (GanttWEnd - TotalHeight) DIV 2;
    LRY := ULY + TotalHeight;
    IF (LRY > GanttWEnd) THEN
        LRY := GanttWEnd;
    END;

    GetMessage(ModuleNumber + 22,Title);   (* "Make Bookmark" *)

        (* Create the link tree. *)
    IF NOT CreateBookMarkTree( BookMarkTree ) THEN
        IndexInterlock := FALSE;
        RETURN;
    END;

        (* Try to find a blank space. *)

    FirstNode := BookMarkTree^.Methods^.GetFirst (BookMarkTree);
    Node := FirstNode;
    WHILE ( Node <> NIL ) AND
          ( LengthOf( BookMark[ IndexOf(Node) ].Topic ) > 0 ) DO
        Node := Node^.Methods^.GetNext(Node);
    END;

        (* Put up the list and select a bookmark node. *)
        
    Changed := DoGoTo ( BookMarkTree, ULX, GanttWStart, 
                                      LRX, LRY,
                        Title,
                        TRUE (*  OpenTree *),
                        GoToCheckProc,
                        NameProc,
                        Node );


    IF (Changed) AND (Node <> NIL) THEN
        N := IndexOf(Node);
        IF (N <= HIGH(BookMark)) THEN
            WITH BookMark[N] DO
                Copy(MostRecentTopic,Topic);
                Copy(MostRecentAbstract,Abstract);
            END;
        END;
        SaveChanges();     (* Put the changes back to Holder. *)
    END;

    BookMarkTree^.Methods^.Discard(BookMarkTree);

    IndexInterlock := FALSE;

END SetBookMark;



    (* CreateBookMarkTree -- Create a tree with a node for each
                             active book mark.  Returns FALSE if no
                             marks (or failure).  Each node contains
                             the index of the book mark.
                             
                             *)
    (* Not reentrant, because BookMark is global. *)

PROCEDURE CreateBookMarkTree( VAR BookMarkTree : ATree
                            ) : BOOLEAN;
VAR
    i : CARDINAL;
    ActiveMarks             : CARDINAL;
    A : ADDRESS;
    TreeNode : ATreeNode;
BEGIN
    IF NOT CreateTree(BookMarkTree) THEN
        RETURN FALSE;
    END;

    ActiveMarks := 0;
    FOR i := 0 TO HIGH(BookMark) DO
            (* Note its sequence in the list of marks. *)
        INC(ActiveMarks);
            (* Create a tree node. *)
        IF (NOT CreateTreeNode(TreeNode)) THEN
            BookMarkTree^.Methods^.Discard(BookMarkTree);
            RETURN FALSE;
        END;
            (* Store the book mark number into it. *)
        A.SEGMENT := 0;
        A.OFFSET  := i;
        TreeNode^.Methods^.SetDataObject(TreeNode,A);
            (* Add the node to the end of the tree. *)
        BookMarkTree^.Methods^.AddLast(BookMarkTree,TreeNode);
        
    END;

    RETURN (ActiveMarks > 0);

END CreateBookMarkTree;


PROCEDURE IndexOf( TreeNode : ATreeNode ) : CARDINAL;
VAR
    A : ADDRESS;
BEGIN
    A := TreeNode^.Methods^.GetDataObject(TreeNode);
    RETURN A.OFFSET;
END IndexOf;



    (* Not reentrant, because BookMark is global. *)

PROCEDURE NameProc(     TreeNode : ATreeNode;
                    VAR S        : ARRAY OF CHAR );
VAR
    i : CARDINAL;
BEGIN
    i := IndexOf(TreeNode);
    CtoS(i+1,S);
    ConcatS(S," : ");
    ConcatLS(S,BookMark[i].Abstract);
END NameProc;




PROCEDURE QueryBookMark( VAR Name : ARRAY OF CHAR ) : BOOLEAN;
CONST
    TotalWidth          = 54;
    TotalHeight         = HIGH(BookMark);  (* Borders. *)
VAR
    Title : ARRAY [0..21] OF CHAR;
    Changed : BOOLEAN;
    BookMarkTree            : ATree;
    Node                : ATreeNode;
    i                   : CARDINAL;
    ULX,LRX             : CARDINAL;
    ULY,LRY             : CARDINAL;
BEGIN
    IndexInterlock := TRUE;

        (* Center the pick list. *)
    ULX := (MaxColumn - TotalWidth) DIV 2;
    LRX := ULX + TotalWidth;
    IF (LRX > MaxColumn) THEN
        LRX := MaxColumn;
    END;
    ULY := (GanttWEnd - TotalHeight) DIV 2;
    LRY := ULY + TotalHeight;
    IF (LRY > GanttWEnd) THEN
        LRY := GanttWEnd;
    END;

    GetMessage(ModuleNumber + 21,Title);   (* "GOTO Bookmark" *)

        (* Create the link tree. *)
    IF NOT CreateBookMarkTree( BookMarkTree ) THEN
        IndexInterlock := FALSE;
        RETURN FALSE;
    END;

    Node := BookMarkTree^.Methods^.GetFirst (BookMarkTree);
        
    Changed := DoGoTo ( BookMarkTree, ULX, GanttWStart, 
                                      LRX, LRY,
                        Title,
                        TRUE (*  OpenTree *),
                        GoToCheckProc,
                        NameProc,
                        Node );

    IF (Changed) AND (Node <> NIL) THEN
        SubStr(BookMark[ IndexOf(Node) ].Topic, Name, 1, HIGH(Name) );
    END;

    BookMarkTree^.Methods^.Discard(BookMarkTree);

    IndexInterlock := FALSE;

    RETURN (Changed) AND (LengthOf(Name) > 0);


END QueryBookMark;


PROCEDURE InitBookMarks();
VAR
    A                       :   ADDRESS;
    i                       :   CARDINAL;
    ItemName                :   ARRAY [0..21] OF CHAR;
    Class                   :   CARDINAL;
    Size                    :   CARDINAL;
    Category                :   AHoldTypeSet;
BEGIN
        (* Note that we are not displaying any screens yet, and get
           ready to capture the title of the next one we see. *)
    SetLengthOf(MostRecentTopic, 0);
    SetLengthOf(MostRecentAbstract, 0);
    NeedAbstract := FALSE;

        (* If there are already bookmarks in holder, copy their contents
           to our array.  If not, initialize the bookmarks, and put them
           into holder. *)
            
    SetString(ItemName, "HELPBOOKMARKS");
    Class := 1;
    BookMarksHandle := AnExtHandle(NIL);
    IF ( LocateHeldItem(ItemName, Class, Category, A, Size) AND
       (Size = SIZE(BookMark))) AND
       (HoldInFlexStor IN Category) THEN    (* 23-Jan-91 RSC *)
        BookMarksHandle := AnExtHandle(A);
        Size   := GetExtData( BookMarksHandle, ADR(BookMark) );
    ELSE
            (* Create an array empty of bookmarks. *)
        FOR i := 0 TO HIGH(BookMark) DO
            WITH BookMark[i] DO
                SetLengthOf(Topic,0);
                SetLengthOf(Abstract,0);
            END;
        END;

            (* Remove any previous copy. *)
        DeleteHeldItem( ItemName, Class );
    
            (* Put into FlexStor. *)
        Size := SIZE(BookMark);
        IF (CreateExtObjectWithSize( BookMarksHandle, ExtSlow, Size )) THEN
            IF NOT SetExtData( BookMarksHandle, ADR(BookMark),
                               SIZE(BookMark) ) THEN
                ErrorPhrase(0);
            END;
            Category := AHoldTypeSet{HoldInConfig,     (* Save to cnfg file. *)
                                     HeapNoOwner,
                                     HoldInFlexStor};
            HoldThis(ItemName, Class, Category, ADDRESS(BookMarksHandle), Size);
        ELSE
            ErrorPhrase(0);
        END;
    END;

END InitBookMarks;


PROCEDURE SaveChanges();
BEGIN
    (*  Save changes to bookmarks.  *)
    IF NOT ((BookMarksHandle <> AnExtHandle(NIL)) AND
             SetExtData( BookMarksHandle, ADR(BookMark),
                         SIZE(BookMark) ) ) THEN
        ErrorPhrase(0);
    END;
END SaveChanges;



PROCEDURE Terminate();
BEGIN
    SaveChanges();
END Terminate;


BEGIN
END BookMarks;

    (*--------------- BookMarks module ------------------------- *)






(*-----------------------------------------------------------------------*)



   (* BackTrack -- Keeps a history of recent pages seen and their position. *)

MODULE BackTrack;

EXPORT QUALIFIED Init, Enqueue, UnStack, QueueSize;

    CONST
        MaxTrack = 32;
    TYPE
        ATrackRecord = RECORD
                           High, Low  : CARDINAL;
                       END;
    VAR
        In, n       : [0..MaxTrack-1];
        TrackQ      : ARRAY [0..MaxTrack-1] OF ATrackRecord;

PROCEDURE QueueSize():CARDINAL;
BEGIN
    RETURN n;
END QueueSize;


PROCEDURE Enqueue( H, L : CARDINAL );
BEGIN
        (* Avoid two items the same in a row.   This could happen,
           if the menu at the bottom of the page appears because the
           page filled up, and the user then presses BackTrack. *)
    WITH TrackQ[(In+MaxTrack-1) MOD MaxTrack] DO
        IF (High=H) AND (Low=L) THEN
            RETURN;
        END;
    END;

    WITH TrackQ[In] DO
        High := H;
        Low  := L;
    END;
    In := (In+1) MOD MaxTrack;
    IF (n < MaxTrack-1) THEN
        INC(n);
    END;
END Enqueue;



PROCEDURE UnStack( VAR H, L : CARDINAL):BOOLEAN;
BEGIN
    IF (n > 0) THEN
        DEC(n);
        In := (In+MaxTrack-1) MOD MaxTrack;
        WITH TrackQ[In] DO
            H := High;
            L := Low;
        END;
        RETURN TRUE;
    ELSE
       RETURN FALSE;
    END;
END UnStack;


PROCEDURE Init();
BEGIN
    In := 0;  n := 0;
END Init;

        
END BackTrack;   (* Module *)







MODULE KeyIndexing;

IMPORT  
    (* CONST*)  ModuleNumber, IndexNameNumber, 
    (* TYPE *)  Response,
    (* VAR *)   TextPath,
    (* PROC *)  IndexFile, PrepareForIO, GetMessage, RequestFileOpenReadOnly,
                CheckIO, FileComplaint, CloseHelpFiles, ReadNBytes, SetPos,
                ConcatMessage, Error, ADR, SIZE, Upshift, Close,
                StringsEqual, TrimRear;

EXPORT OpenIndexFile, CloseIndexFile, GetSubjectPosition;



TYPE

       AKey          = ARRAY [0..9] OF CHAR;
       AnIndex       = RECORD
                         Key   : AKey;
                         Low, High : CARDINAL;
                       END;  

           (* All the keys in the index are sorted into ascending order,
              and all are upshifted.  Within each index block the keys
              are in ascending order, and the smallest key in block n
              is larger than the largest key in block n-1.   There are
              no duplicates. *)

           (* The first block of the index file is a master index to
              the specific keys in the remaining blocks of the 
              file.  Indices [n] contains the highest key on page n.
           *)
       AMasterBlock  = RECORD     (* 512 bytes long *)
                         IndexVersion : CARDINAL;
                         TextVersion  : CARDINAL;
                         CompressionMethod : CARDINAL;
                         HighestBlock     : CARDINAL;
                         Filler       : ARRAY [1..4] OF CHAR;
                         Indices      : ARRAY [1..50] OF AKey;
                       END;
           (* Each subsequent index contains a sequence of help keys
              and the position in the text file of the data. *)
       AnIndexBlock  = RECORD     (* 512 bytes long *)
                         Count : CARDINAL; 
                         Index : ARRAY [1..36] OF AnIndex;
                         Filler : ARRAY [1..6] OF CHAR;
                       END;

VAR
    IsOpen : BOOLEAN;
    MasterIndex : AMasterBlock;
    IndexBlock  : AnIndexBlock; 



    (* We need a local copy of Compare that does not depend on the
       upshift values or the sort order in the phrases file. *)

PROCEDURE Compare (VAR First, Second: ARRAY OF CHAR) : INTEGER;
VAR
    L1, L2, i:  INTEGER;
BEGIN
    L1 := ORD(First[0]);
    L2 := ORD(Second[0]);

    i := 1;
    LOOP
        IF (i > L1) THEN
            IF (i > L2) THEN RETURN 0
            ELSE RETURN -i
            END
        ELSIF (i > L2) THEN
            RETURN i
        ELSIF (First[i] = Second[i]) THEN
        ELSIF (First[i] < Second[i]) THEN RETURN -i
        ELSE RETURN i
        END;
        INC(i);
    END;
END Compare;



PROCEDURE GetSubjectPosition(     Subject : ARRAY OF CHAR;
                              VAR high,low:CARDINAL):BOOLEAN;
CONST
    IndicesPerMaxCard = 128;   (* (MAXCARDINAL+1)  DIV SIZE(IndexBlock) *)
VAR
    i,Count,ILow,IHigh : CARDINAL;
    j : INTEGER;
BEGIN
        (* Convert (language independent) to a normal form. We do not
           use LStrings.Upshift because that would convert alpha characters
           (Alt-224) to capital A, etc., which would throw off the 
           sorting order, since Makehelp.exe doesn't know about our
           sophisticated upshift and comparison tables. *)
 
    TrimRear(Subject);
    FOR i := 1 TO ORD(Subject[0]) DO Subject[i] := CAP(Subject[i]); END;

        (* Search for the first block whose largest key is >= Subject. *)

    i := 1;
    WHILE (i <= MasterIndex.HighestBlock) AND 
          (Compare(MasterIndex.Indices[i],Subject) < 0) DO
        INC(i);            
    END; 

        (* If no such block, then the Subject is not in the file. *)

    IF (i > MasterIndex.HighestBlock) THEN RETURN FALSE; END;

        (* Read the index block *)
        (* This positioning calculation relies on the assumption that
           a master index is the same size as an index block, and that
           index blocks are 512 bytes long.   Note that the assumptions
           about the blocks being the same size remains even if the 
           particular size changes.   The skip over the master index
           is effected by having the index blocks numbered starting
           with 1.  *)


    ILow  := (i MOD IndicesPerMaxCard) * SIZE(IndexBlock);
    IHigh := i DIV IndicesPerMaxCard;

    PrepareForIO(IndexFile);
    SetPos(IndexFile,IHigh,ILow);
    ReadNBytes(IndexFile,ADR(IndexBlock),SIZE(IndexBlock),Count);
    IF (CheckIO(IndexFile) <> done) OR (Count <> SIZE(IndexBlock)) THEN
        FileComplaint(IndexFile,IndexNameNumber);
        CloseHelpFiles();
        RETURN FALSE;
    END;

        (* Search for the index whose key is = Subject. *)

    i := 1;
    WHILE (i <= IndexBlock.Count)
          AND
          (NOT StringsEqual(IndexBlock.Index[i].Key,Subject)) DO    (* RSC 1/2/88 *)
        INC(i);            
    END; 

    IF (i > IndexBlock.Count) THEN
        RETURN FALSE;
    END;

    WITH IndexBlock.Index[i] DO
        high := High;
        low  := Low;
    END;

    RETURN TRUE;
 
END GetSubjectPosition;







PROCEDURE OpenIndexFile():BOOLEAN;
VAR
    S,S2 : ARRAY [0..81] OF CHAR; 
    i    : CARDINAL;
BEGIN
    IF (IsOpen) THEN RETURN TRUE; END;

    GetMessage(ModuleNumber+IndexNameNumber,S);
    IF (NOT RequestFileOpenReadOnly(TextPath,S,S2,IndexFile)) THEN
        CloseHelpFiles();
        RETURN FALSE;
    END;

    PrepareForIO(IndexFile);                                       (* 11/12/86 LAA *)
    ReadNBytes(IndexFile,ADR(MasterIndex),SIZE(MasterIndex),i);
    IF (CheckIO(IndexFile) <> done) THEN
        FileComplaint(IndexFile,IndexNameNumber);
        CloseHelpFiles();
        RETURN FALSE;
    END;

    IF (MasterIndex.IndexVersion < 300) OR (MasterIndex.CompressionMethod <> 1) THEN
        ConcatMessage( S, ModuleNumber + 18 ); (* " is not a HELP index file." *)
        Error(S);
        CloseHelpFiles();
        RETURN FALSE;
    END;

    IsOpen := TRUE;

    RETURN TRUE;

END OpenIndexFile;


PROCEDURE CloseIndexFile;
BEGIN
    IF IsOpen THEN
        Close(IndexFile);
        IsOpen := FALSE;
    END;
END CloseIndexFile;






BEGIN
    IsOpen := FALSE;
END KeyIndexing;
(*----------------------------------------End Module----------------------*)



(*$S+*)

PROCEDURE OpenHelpFiles( VAR TextFile,
                             IndexFile : File ) : BOOLEAN;
VAR
    C   : CHAR;
    s   : ARRAY [0..80] OF CHAR;
    s2  : ARRAY [0..40] OF CHAR;
BEGIN

    GetMessage(ModuleNumber+1,s2);   (*  "Time Line SYSTEM START disk"  *)

    GetMessage(ModuleNumber+TextNameNumber,s);
    IF (NOT RequestFileOpenReadOnly(TextPath,s,s2,TextFile)) THEN
        RETURN FALSE;
    END;

         (* See which of the two possible EOL characters we encounter first. *)

    InitExpansion();
    REPEAT
        ReadUncompressedChar(TextFile,C);
    UNTIL (C = EOL) OR (C = CarriageReturn) OR (TextFile.res <> done);
    EOLChar := C;
    Reset(TextFile);
    InitExpansion();

    RETURN OpenIndexFile();

END OpenHelpFiles;





PROCEDURE CloseHelpFiles();
BEGIN

    CloseIndexFile();
    Close(TextFile);

END CloseHelpFiles;





PROCEDURE GetKeyWordValue( VAR Keyword : ARRAY OF CHAR;
                           VAR KeyValue : ARRAY OF CHAR;
                               Context  : ADDRESS );
VAR
    i, j : CARDINAL;
    Parameters : POINTER TO ARRAY [0..255] OF CHAR;
BEGIN
    j := 1;
    i := StoC(Keyword,j);
    IF (j = 1) THEN
        SchedKey.GetKeyWordValue(Keyword,KeyValue,NIL);  (* Not a number. *)
    ELSE
             (* i is a number.  Find the ith phrase in Parameters. *)
        j := 1;
        Parameters := Context;
        WHILE (i > 0) DO
            ParseBal(Parameters^,j,KeyValue);
            DEC(i);
        END; 
    END;
END GetKeyWordValue;



(*  Attempt to create the tree containing index entries by scanning
    the text following the "$INDEX" heading.  Returns TRUE if the
    tree was successfully created (even if there was not enough
    memory to include all the items).                               *)

PROCEDURE BuildIndexTree (VAR Tree      : ATree;
                          VAR F         : File  ) : BOOLEAN;
CONST
    SpacesPerLevel = 2;

VAR
    High, Low               : CARDINAL;
    IndexRecord             : AHelpRecordPointer;
    Node                    : ATreeNode;
    Level                   : CARDINAL;
    NumSpaces               : CARDINAL;
    s                       : ARRAY [0..100] OF CHAR;
    FirstChar               : CHAR;
    FilePosition            : AFilePosition;

BEGIN

    IF (IndexInited) THEN
        RETURN TRUE;        (* Never mind, it's already set up. *)
    END;

    GetMessage (ModuleNumber+14, s);        (* "INDEX" *)
    Procustes (s, TagLength);
    IF (NOT GetSubjectPosition (s, High, Low)) THEN
        RETURN FALSE;
    ELSIF (NOT CreateTree (Tree)) THEN
        RETURN FALSE;
    END;
    SetPos (F, High, Low);
    LOOP
        GetPos (F, High, Low);
        GetString (TextFile, s, FirstChar);
        IF (FirstChar = "$") THEN
            EXIT;
        END;

(*<DOS*)
        IF (CreateTreeNode (Node)) THEN
            FilePosition.High := High;
            FilePosition.Low := Low;
            Node^.Methods^.SetDataObject (Node, FilePosition.Addr);
(*DOS>*)


(*<OS2
        NEW (IndexRecord);
        IF (IndexRecord <> NIL) AND (CreateTreeNode (Node)) THEN
            IndexRecord^.FilePtr := ADR (F);
            IndexRecord^.High := High;
            IndexRecord^.Low := Low;
            Node^.Methods^.SetDataObject (Node, IndexRecord);
OS2>*)

            IF ((High = LastHigh) AND (Low = LastLow)) THEN
                LastNode := Node;
            END;

            (*  Count the number of leading spaces to find the level  *)

            NumSpaces := 0;
            WHILE (s[1] = " ") AND (s[0] <> 0C) DO
                Remove (s, 1, 1);
                INC (NumSpaces);
            END;
            Level := NumSpaces DIV SpacesPerLevel;

            AttachNodeOnTree (Tree, Node, Level);
        ELSE
            EXIT;
        END;
    END;
    IndexInited := TRUE;
    RETURN TRUE;
END BuildIndexTree;



PROCEDURE GetStringByPos (VAR F      : File;
                         High,
                         Low    : CARDINAL;
                     VAR s      : ARRAY OF CHAR);
VAR
    i : CARDINAL;
    C : CHAR;
BEGIN
    i := 0;
    SetPos (F, High, Low);
    InitExpansion;
    LOOP
        PrepareForIO(F);
        s[0] := CHR(i);
        ReadUncompressedChar(F,C);
        IF (F.eof) THEN
            EXIT;
        ELSIF (C = "$") THEN
            EXIT;
        ELSIF (C = EOLChar) THEN
            EXIT;
        ELSIF (i < HIGH(s)) THEN
            INC(i);
            s[i] := C;
        ELSE
            EXIT;           (* Line too long. *)
        END;
    END;
    LJust (s);
    TrimRear (s);
END GetStringByPos;





PROCEDURE GetItemName   (    Node       : ATreeNode;
                         VAR s          : ARRAY OF CHAR );
VAR
    HelpRecord      : AHelpRecordPointer;
    FilePosition    : AFilePosition;

BEGIN               (* HelpViewGetTitle *)

    IF (IndexActive) THEN

(*<OS2
        HelpRecord := Node^.Methods^.GetDataObject (Node);
        WITH HelpRecord^ DO
            GetStringByPos (FilePtr^, High, Low, s);
        END;
OS2>*)

(*<DOS*)
        FilePosition.Addr := Node^.Methods^.GetDataObject (Node);
        GetStringByPos (TextFile, FilePosition.High, FilePosition.Low, s);
(*DOS>*)

    ELSE
        SetLengthOf (s, 0);
    END;

END GetItemName;



(*  Put up the on-screen outline of help items (using go-to, so we
    get type-through for free) and handle event processing in the
    list.  Return TRUE iff the list is exited with a code of DoIt.
    If TRUE is returned, we change s to be the key to the selected
    item. *)

PROCEDURE HandleIndex     (VAR s        : ARRAY OF CHAR ): BOOLEAN;
VAR
    Node                : ATreeNode;
    SubTree             : ATree;
    PreviousTree,
    CopiedTree          : ATree;
    posn                : CARDINAL;
    HelpRecord          : AHelpRecordPointer;
    FilePosition        : AFilePosition;
    OldHigh, OldLow     : CARDINAL;
    Addr                : ADDRESS;
    Selected            : BOOLEAN;
    fc                  : CHAR;
    s2                  : ARRAY [0..100] OF CHAR;
    Title               : ARRAY [0..81] OF CHAR;
    pattern             : ARRAY [0..10] OF CHAR;
    BoxHandle           : ABoxHandle;
    OK                  : BOOLEAN;
    Cancelled           : BOOLEAN;
BEGIN

    IF (IndexInterlock) THEN
        RETURN FALSE;
    END;

    GetPos (TextFile, OldHigh, OldLow);       (* Save away our old position *)

        (* This view doesn't actually show up; we're just passing it
           to Go-to as a base    *)

    GetMessage (ModuleNumber+19, s2);       (* "Please wait" *)
    BoxHandle := ProgressBox (s2);

    IF (BuildIndexTree (IndexTree, TextFile)) THEN

        ReleaseBox (BoxHandle);

        SubTree    := IndexTree;   (* Start with whole tree. *)
        CopiedTree := ATree(NIL);  (* And no extra tree copy. *)

        IndexInterlock := TRUE;

        IF (LastNode = NIL) THEN
            Node := IndexTree^.Methods^.GetFirst (IndexTree);
        ELSE
            Node := LastNode;
        END;


        IndexActive := TRUE;

        GetMessage (ModuleNumber+16, Title);  (* The title *)

            (* Offer a quickpick list of index items.  If the user
               picks one with a reference to a help topic (line contains
               a "$") then exit indicating selected.  Esc cancels.
               Picking an item without a "$" topic brings up a new index 
               showing child choices of the one shown. *)


        REPEAT

            Cancelled := FALSE;
            Selected  := FALSE;


            IF DoGoTo ( SubTree, 10, 5, 70, maxrow-4, Title, TRUE,
                        GoToCheckProc, GetItemName, Node) THEN
    
(*<DOS*)
                FilePosition.Addr := Node^.Methods^.GetDataObject (Node);
                WITH FilePosition DO
(*DOS>*)

(*<OS2
                HelpRecord := Node^.Methods^.GetDataObject (Node);
                WITH HelpRecord^ DO
OS2>*)

                    SetPos (TextFile, High, Low);
                    LastHigh := High;
                    LastLow := Low;

                        (* We store the last node selected from the 
                           main index tree.  Subtrees are not kept, so
                           we cannot keep the node pointers to them. *)
                    IF (SubTree = IndexTree) THEN
                        LastNode := Node;
                    END;
    
                    GetString (TextFile, s2, fc);
                    SetString (pattern, "$");
                    posn := Search (s2, pattern, 1);
                    IF (posn > 0) THEN
                        SubStr (s2, s, posn+1, TagLength);
                        Selected := TRUE;
                    ELSE
                        GetItemName(Node,Title);  (* Title for next round. *)
                            (* Make a new tree for use in the next round
                               of selection.  Set SubTree to that, and,
                               if we are so nested that there was already
                               a copied tree, then discard the old copy.
                               We only keep the main tree and one subtree
                               copy.  And we do this, because unfortunately
                               the GoTo proc only works with whole trees. *)
                        PreviousTree := SubTree;
                        SubTree := Node^.Methods^.GetSubtree(Node);
                        IF (SubTree = NIL) THEN   (* Error failure check. *)
                            Cancelled := TRUE;    (* A line w/o a "$" but without *)
                            ErrorPhrase(0);       (* indented lines below it. *)
                        ELSE
                            IF (SubTree^.Methods^.Clone(SubTree,CopiedTree)) THEN
                                SubTree := CopiedTree;
                                IF (PreviousTree <> IndexTree) THEN
                                    PreviousTree^.Methods^.Discard(PreviousTree);
                                    PreviousTree := ATree(NIL);
                                END;
                                    (* Position cursor to first entry in tree. *)
                                Node := SubTree^.Methods^.GetFirst(SubTree);
                            ELSE   (* Out of memory? *)
                                Cancelled := TRUE;
                                ErrorPhrase(0);
                            END;
                        END;
                    END;
                END;
            ELSE
                Cancelled := TRUE;
            END;

        UNTIL Selected OR Cancelled;

        IndexActive := FALSE;

        IF (CopiedTree <> ATree(NIL)) THEN
            CopiedTree^.Methods^.Discard(CopiedTree);
        END;

    ELSE
       ReleaseBox (BoxHandle);
    END;

    IndexInterlock := FALSE;


    SetPos (TextFile, OldHigh, OldLow);
    RETURN Selected;
END HandleIndex;






PROCEDURE ChangePosition( High, Low : CARDINAL ):BOOLEAN;
BEGIN
    PrepareForIO(TextFile);
    Reset(TextFile);
    SetPos(TextFile,High,Low);
    IF (CheckIO(TextFile) <> done) THEN
        FileComplaint(TextFile,TextNameNumber);
        CloseHelpFiles();
        RETURN FALSE;
    END;
    InitExpansion;

    RETURN TRUE;
END ChangePosition;


PROCEDURE ChangeToNewSubject(VAR Subject:ARRAY OF CHAR):BOOLEAN;
VAR
    i           : CARDINAL;
    high, low   : CARDINAL;
    s           : ARRAY [0..maxcol+1] OF CHAR;
    s2          : ARRAY [0..40] OF CHAR;
    ok          : BOOLEAN;
BEGIN
    i := 1;
    SubStr(Subject,s,i,TagLength);
    Procustes(s,TagLength);
    IF (GetSubjectPosition(s,high,low)) THEN
        ok := ChangePosition(high,low);
    ELSE
        SubStr(s,s2,1,HIGH(s2));
        Message(s2);    (* 11-Dec-89 RSC  *)
        GetMessage(ModuleNumber+5,s);   (*  "Sorry--I can't give you any help with that.$$"  *)
        GetMessage(ModuleNumber+6,s2);  (*  "No Help" *)
        WarningBox(s,s2,NoHelp);
        SetLengthOf(s2,0);  (* 11-Dec-89 RSC  *)
        Message(s2);        (* 11-Dec-89 RSC  *)
        ok := FALSE;
    END;

    RETURN ok;
END ChangeToNewSubject;




    (* Store the current file position onto a queue. *)


PROCEDURE RecordPosition();
VAR
    High, Low : CARDINAL;
BEGIN
    GetPos (TextFile, High, Low);
    BackTrack.Enqueue(High,Low);
END RecordPosition;





(*<OS2
PROCEDURE DiscardIndexNode  (VAR Node       : ATreeNode;
                                 Context    : ADDRESS   );
VAR
    HelpRecord              : AHelpRecordPointer;
BEGIN
    HelpRecord := Node^.Methods^.GetDataObject (Node);
    DISPOSE (HelpRecord);
    Node^.Methods^.Discard (Node);
END DiscardIndexNode;
OS2>*)



PROCEDURE AttachNodeOnTree(     Tree     : ATree;
                                Node     : ATreeNode;
                                Level    : CARDINAL  );
VAR
   OtherNode : ATreeNode;
   ChildNode : ATreeNode;
BEGIN
   ValidateTree(Tree);
   ValidateTreeNode(Node);



   IF (Level = 0) THEN
       Tree^.Methods^.AddLast(Tree,Node);
   ELSE
       OtherNode := Tree^.Methods^.GetLast(Tree);
       LOOP
           IF (OtherNode^.Methods^.IndentationLevel (OtherNode) >= Level - 1) THEN
               OtherNode^.Methods^.AddAsLastChild (OtherNode, Node);
               EXIT;
           END;
           ChildNode := OtherNode^.Methods^.LastChild (OtherNode);
           IF (ChildNode = NIL) THEN
               OtherNode^.Methods^.AddAsLastChild (OtherNode, Node); 
               EXIT;
           ELSE
               OtherNode := ChildNode;
           END;
       END;
   END;

END AttachNodeOnTree;




PROCEDURE GetString ( VAR f     : File;
                      VAR s     : ARRAY OF CHAR;
                      VAR FC    : CHAR          );
VAR
    i : CARDINAL;
    C : CHAR;
BEGIN
    i := 0;
    LOOP
        PrepareForIO(f);
        s[0] := CHR(i);
        ReadUncompressedChar(f,C);
        IF (f.eof) THEN
            EXIT;
        ELSIF (CheckIO(f) <> done) THEN
            FileComplaint(TextFile,TextNameNumber);
            CloseHelpFiles();
            EXIT;
        ELSIF (C = EOLChar) THEN
            EXIT;
        ELSIF (i < HIGH(s)) THEN
            INC(i);
            s[i] := C;
        ELSE
            EXIT;           (* Line too long. *)
        END;
    END;
    FC := s[0];
    IF (FC <> 0C) THEN
        FC := s[1];
    END;
END GetString;



PROCEDURE GoToCheckProc    (    Outline     : AnOutlineView;
                                Tree        : ATree;
                            VAR Code        : ACode         );
VAR
    posn            : CARDINAL;
    Node            : ATreeNode;
    HelpRecord      : AHelpRecordPointer;
    FilePosition    : AFilePosition;
    pattern         : ARRAY [0..10] OF CHAR;
BEGIN

    IF (Code = CancelKey) THEN
        RETURN;
    END;

    IF (Code = HelpKey) OR                      (* 06-Mar-88 LAA *)
       (Code = HelpIndexKey) THEN
        Code := 0;
        Burp();
        RETURN;
    END;

END GoToCheckProc;
        



PROCEDURE MakePrinterCopy( VAR s : ARRAY OF CHAR );
CONST
    NEWLINE = 374C;
    NEWMODE = 375C;
VAR
    i,j : CARDINAL;
    S2 : ARRAY [0..255] OF CHAR;

BEGIN
        (* Remove video controls.   Wrap and print the lines. *)
    i := 1;
    j := 1;
    WHILE (j <= LengthOf(s)) DO

        IF (s[j] = NEWLINE) THEN
            SubStr(s,S2,i,j-i);
            PrintLine(S2,0);
            INC(j,2);
            i := j;
        ELSIF (s[j] = NEWMODE) THEN
            SubStr(s,S2,i,j-i);
            PrintText(S2,0);
            INC(j,2);
            i := j;
        ELSIF(j-i >= PageWidth()) THEN
            SubStr(s,S2,i,j-i);
            PrintLine(S2,0);
            INC(j);
            i := j;
        ELSE
            INC(j);
        END;
    END;

    SubStr(s,S2,i,j-i);
    PrintLine(S2,0);
END MakePrinterCopy;





    (*  ManageHelp -- Using screen area ULX,ULY..LRX,LRY, present
                    help about Subject.  Subject is a name of at
                    most 8 characters, please. *)


PROCEDURE ManageHelp (    Depth  : CARDINAL;
                          Subject:ARRAY OF CHAR;
                      VAR Parameters : ARRAY OF CHAR;
                          ULX    : ascreenx;
                          ULY    : ascreeny;
                          LRX    : ascreenx;
                          LRY    : ascreeny;
                          ScreenAction : AScreenAction;
                      VAR TextFile,
                          IndexFile : File );


(*<NORMAL*)

    CONST
        DefaultIndentation = 2;
        StackSize = 8;             (* Max subtext nesting allowed. *)
    TYPE
        ABranchType = (Jump,Goto,Call);
    VAR
        Rug             : ARug;
        CodeSet         : ASetOfCodes;
        Code            : ACode;
        y               : ascreeny;
        menutop,
        menuend         : CARDINAL;
        CopyToPrinter   : BOOLEAN;


            (* Store several items of information for each level of
               stacking (each "><" causes a subroutine call to
               occur, with a stack entry for it containing its
               context.

               High, Low   contain the return address in the text.
                           valid for the [n-1]th entries.

               Indentation :: the x indentation for the text.  Can
                              be increased through the ")" operator.

               StartingY   :: the y position for the start of the
                              subtext.  All "@" positioning will be
                              relative to this.
             *)
        StackCount        : CARDINAL;
        Stack             : ARRAY [0..StackSize-1] OF RECORD
                                              High, Low   : CARDINAL;
                                              Indentation : CARDINAL;
                                              StartingY   : CARDINAL;
                                          END;
        UserSuppliedMenu  : BOOLEAN;
        FirstTime         : BOOLEAN; 
        C,C2              : CHAR;
        Prefix            : ARRAY [0..31]      OF CHAR;


        PROCEDURE TakeABranch   (     Depth     : CARDINAL;
                                  VAR Name      : ARRAY OF CHAR;
                                  VAR Parameters : ARRAY OF CHAR ) : BOOLEAN;
        VAR
            Rug         : ARug;
            High, Low   : CARDINAL;
            s           : ARRAY [0..10] OF CHAR;
        BEGIN

                (* First, look for the special name that is the Index
                   entry.  Any entry beginning with this is an index, and
                   gets handled specially, by converting the name into
                   the one the user wants to search for. *)
        
            GetMessage (ModuleNumber+14, s);        (* "INDEX" *)
            IF (Search(Name,s,1) = 1) THEN
                IF (NOT HandleIndex(Name)) THEN
                    RETURN FALSE;
                END;
            END;
        
            BookMarks.SetTopic(Name);    (* Note that this is the current topic. *)

                (* For branches after we have taken over the full screen,
                   there is no need to do anything fancier than just
                   blanking the screen and carrying on from a new position. *)
        
            IF (Depth > 2) AND (ChangeToNewSubject(Name)) THEN
                RecordPosition();    (* Save file position for backtracking. *)
                StartPage(TRUE);
                RETURN TRUE;
            END;
        
            (* Recursive call to ManageHelp is used the first time the
               the user goes off on a detour.   We restore
               the screen when the detour is finished.  Since
               the detour can itself have detours, we only
               concern ourselves with restoring the screen
               when we come back to the top level. 

               The whole reason we do any of this is so that we can
               give detour-help at full screen size, even if the initial
               help was not full screen. 
            *)
        
            IF (NOT StackSpaceLeft(3500)) OR (NOT HeapAvailable()) THEN     (* 10/26/88 EGK *)  (* 16-Nov-89 LAA *)
                Burp();
                RETURN FALSE;
            END;

            IF (Depth <= 1) THEN
                IF (NOT GetRug(0,0,maxcol,maxrow-1,Rug)) THEN
                    RETURN FALSE;
                END;
                GetMessage (ModuleNumber+15, s);
                DrawBox(0,0,maxcol,maxrow-1,ABoxType{DoubleBox},s,videonormal);
            END;
                (* Save file position (file is not nested as a parm.) *)
            GetPos(TextFile,High,Low);
                (* Use "RestoreTheScreen" because this has the side-effect
                   of making mouse clicks off the menu ignored. Else,
                   they would cause exit of the help. *)
            ManageHelp (Depth+1,Name,Parameters,
                        1,1,maxcol-1,maxrow-2,RestoreTheScreen,
                        TextFile,IndexFile);  (* Nested call. *)
            IF (Depth <= 1) THEN
                PutRug(0,0,maxcol,maxrow-1,Rug);
            END;
                (* Do not stay at the lower depths.   Return to
                   higher ground. *)
            SetPos(TextFile,High,Low);
            IF (Depth > 0) THEN
                RETURN FALSE;
            END;
            
            
            RETURN TRUE;
        END TakeABranch;






        PROCEDURE GetNextString(VAR s:ARRAY OF CHAR;VAR C:CHAR):BOOLEAN;
        VAR
           ExcessiveLoopCount : CARDINAL;
        BEGIN
            ExcessiveLoopCount := 0;
            LOOP
                GetString(TextFile,s,C);
                WHILE (C=">") DO
                    IF (Branch(s)) THEN
                        GetString(TextFile,s,C);
                    ELSE
                       C := "$";
                    END;
                    INC(ExcessiveLoopCount);
                    IF (ExcessiveLoopCount > 30) THEN
                        Error(s);
                        s[0] := 0C;
                        C := 0C;
                        RETURN FALSE;
                    END;
                END;
                IF (C="$") THEN
                    IF (NOT MoreText()) THEN
                        RETURN FALSE;
                    END;
                ELSE
                        (* Substitute for any embedded keywords. *) 
                    MakeSubstitutions(s,HIGH(s),
                                      GetKeyWordValue,ADR(Parameters)); 
                    RETURN TRUE;
                END;
            END;
        END GetNextString;





        PROCEDURE Branch(Subject:ARRAY OF CHAR):BOOLEAN;
        VAR
            i           : CARDINAL;
            Event       : AnEvent;
            BType       : ABranchType;
            ok          : BOOLEAN;
        BEGIN
            (*
            IF (NOT FilesOpen) THEN
                DisplayMessage(ModuleNumber+2);   (*  "Help files not available."  *)
                RETURN FALSE;
            END;
            *)

            TraceLS(Subject);                

            IF (Subject[1]=">") THEN
                i := 2;
                BType := Goto;
                    (*  "><" means subtext call. *)
                IF (Subject[2]="<") THEN
                    BType := Call;
                    i := 3;
                END;
            ELSE
                BType := Jump;
                i := 1;
                GetMessage(ModuleNumber+7, Prefix); (* reset Prefix. *)
                UserSuppliedMenu := FALSE;       (* No user supplied menu. *)
                Fill(ChoiceEquivalents," ",0);   (* No alternate keywords *)
            END;

                (* Conditional Jumps and Calls *)

            IF (Subject[i] = "?") THEN
                IF (KeyPress()) THEN
                    GetNextEvent(Event);
                    RETURN FALSE;
                END;
                INC(i);
            END;


                (* Remove the characters at the start of Subject which
                   indicated what kind of a branch this is. *)

            Remove(Subject,1,i-1);

                    (*  Save return address on CALLS.
                        For calls, save current address.
                        *)

            IF (BType = Call) THEN
                IF (StackCount < StackSize-1) THEN
                    WITH Stack[StackCount] DO
                        GetPos(TextFile,High,Low);
                    END;
                    INC(StackCount);
                        (* Store all of the settings of the previous
                           subroutine. *)
                    Stack[StackCount] := Stack[StackCount-1];
                        (* What is our y offset position? *)
                    Stack[StackCount].StartingY := y;
                ELSE
                    GetMessage(ModuleNumber+4,s);   (*  "Help nested too deeply."  *)
                    Error(s);
                END;
            END;



            ok := ChangeToNewSubject(Subject);
            IF (NOT ok) AND (BType = Call) THEN
                 DEC(StackCount);
            END;

            RETURN ok;
        END Branch;


        PROCEDURE MoreText():BOOLEAN;
        BEGIN
            IF (MoreToGo()) THEN
                RETURN TRUE;
            ELSE
                RETURN (WaitAMinute(FALSE));
            END;
        END MoreText;


        PROCEDURE MoreToGo():BOOLEAN;
        BEGIN
            IF (StackCount > 0) THEN
                DEC(StackCount);
                WITH Stack[StackCount] DO
                    SetPos(TextFile,High,Low);
                END;
                RETURN TRUE;
            END;
            RETURN FALSE;
        END MoreToGo;



        PROCEDURE WaitAMinute(MoreFlag:BOOLEAN):BOOLEAN;
        VAR
            Code : ACode;
            Continue : BOOLEAN;
        BEGIN
            IF (ScreenAction = JustDisplayTheText) THEN
                RETURN FALSE;
            ELSE
                IF (NOT UserSuppliedMenu) THEN
                    GetMessage(ModuleNumber+9,Choices); (*  "Quit help,Index"  *)
                END;
                RETURN GetMenuChoice(Prefix,Choices,MoreFlag,(ScreenAction =LeaveTheText));
            END;
        END WaitAMinute;







 
        PROCEDURE GetMenuChoice(VAR Prefix,
                                    Choices     : ARRAY OF CHAR;
                                    MoreFlag    : BOOLEAN;
                                    ExitOnClick : BOOLEAN    )
                                                                 :BOOLEAN;
        VAR
            High, Low   : CARDINAL;
            Choice      : CARDINAL;
            ExtraChoices: CARDINAL;
            ExtraKeys   : ARRAY [0..3]  OF CARDINAL;
            OurChoices  : ARRAY [0..255] OF CHAR;
            s           : ARRAY [0..10] OF CHAR;
            Name        : ARRAY [0..90] OF CHAR;


                (* Backup -- Go back several pages. 
                             1 = Repeat current page.
                             2 = Previous page. *)

            PROCEDURE Backup( Pages : CARDINAL ) : BOOLEAN;
            BEGIN
                IF (BackTrack.QueueSize() >=  Pages) THEN
                    WHILE( Pages > 0) DO
                       IF NOT BackTrack.UnStack(High,Low) THEN   (* Current page. *)
                           RETURN FALSE;
                       END;
                       DEC(Pages);
                    END;
                    LineWaiting := FALSE;          (* Cancel any pending text. *)
                    IF ChangePosition(High,Low) THEN
                        RecordPosition();    (* Save file position for backtracking. *)
                        StartPage(TRUE);
                        RETURN TRUE;
                    END;
                END;
                RETURN FALSE;
            END Backup;


        BEGIN
                (* At the end of each page, see if we had been copying
                   the display text to the printer.  If so, switch it
                   off. *)

            IF (CopyToPrinter) THEN
                EndReport();
                PrintCB.Style := FormerPrintStyle;  (* Restore print device. *)
                CopyToPrinter := FALSE;    (* At the end of each page, turn
                                              printing off. *)
                IF (Backup(1)) THEN        (* Redisplay current screen. *)
                    RETURN TRUE;
                END;
            END;


            ExtraChoices := 0;
            SubStr(Choices,OurChoices,1,245);

            IF (BackTrack.QueueSize() > 1) THEN
                GetMessage(ModuleNumber+20,s);   (* "Backtrack," *)
                Insert(OurChoices,s,1);
                ExtraKeys[0] := PgUpKey;
                INC(ExtraChoices);
            END;

            IF (MoreFlag) THEN
                GetMessage(ModuleNumber+10,s);   (* "More," *)
                Insert(OurChoices,s,1);
                ExtraKeys[ExtraChoices] := PgDnKey;
                INC(ExtraChoices);
            ELSIF (LengthOf(Choices) = 0) THEN
                RETURN FALSE;
            END;


            Choice := 1;

            LOOP
                Code := Menu(Prefix,OurChoices,ULX,menutop,LRX,LRY,CodeSet,
                             (NOT ExitOnClick),Choice);    (* 11-Dec-89 RSC *)
                IF (ChoiceEquivalents[0] = 0C) THEN
                    WordNumber(OurChoices,Choice,Name);
                ELSIF (Choice > ExtraChoices) THEN
                       (* We inserted an extra word or two? *)
                       (* Get the alias of the menu item. *)
                    WordNumber(ChoiceEquivalents,Choice-ExtraChoices,Name);
                ELSE
                    Name[0] := 0C;
                END;

                    (* If they selected to jump to a previously recorded topic,
                       make that topic the choice. *)
                IF (Code = JumpKey) THEN
                    IF BookMarks.QueryBookMark( Name ) THEN
                        Code := DoIt;                (* Simulate picking a choice. *)
                        Choice := ExtraChoices + 1;  (* Avoid thinking it is an extra. *)
                    END;
                END;

                Upshift(Name);

                GetMessage(ModuleNumber+11,s);    (* "QUIT" *)

                IF (Code = TraceKey) THEN
                    ShowTrace();
                ELSIF (Code = PgDnKey) THEN
                    IF (MoreFlag) THEN
        (* EXIT *)      EXIT;
                    ELSE
                        Burp();
                    END;
                ELSIF (Code = PgUpKey) THEN
                    IF (Backup(2)) THEN       (* Current, previous *)
                        RETURN TRUE;
                    ELSE
                        Burp();
                    END;
                ELSIF (Code = HelpKey) OR (Code = HelpIndexKey) THEN
                        (* Go to the index. *)
                    GetMessage(ModuleNumber+14,Name);          (* INDEX *)
                    IF TakeABranch(Depth,Name,Parameters) THEN
                        RETURN TRUE;
                    END;
                ELSIF (Code = DsplyKey) THEN   (* Print the screen. *)
                        (* Back to top of page. *)
                    IF (Backup(1)) THEN       (* Current *)
                            (* Switch to printer output. *)
                        FormerPrintStyle := PrintCB.Style;
                        PrintCB.Style := OutToPrinter;
                            (* Set controls to initiate printing. *)
                        IF (StartReport()) THEN
                            CopyToPrinter := TRUE;     (* Turn printing on. *)
                            RETURN TRUE;
                        END;
                    ELSE
                        Burp();
                    END;
                ELSIF (Code=CancelKey) THEN
                    RETURN FALSE;
                ELSIF (Code = DoIt) THEN
                        (* Menu item selected. *)
                    IF (Choice <= ExtraChoices) THEN
                            (* Get the equivalent code. *)
                        Code := ExtraKeys[ ExtraChoices-Choice ];  (* Reverse order. *)
                        PushCode(Code);
                    ELSIF (Search(Name,s,1)=1) THEN
                        RETURN FALSE;
                    ELSIF (Name[1]="^") THEN
                            (* Special ability to call an escape from a menu. *)
                        IF (EscapeToOverlay(Name)) THEN
                            RETURN FALSE;
                        END;
                    ELSE
                            (* Branch to the named menu item. *)
                        RETURN TakeABranch(Depth,Name,Parameters);
                    END;
                ELSIF (Code = MarkKey) THEN
                    BookMarks.SetBookMark();
                ELSE
                    Burp();
                END;

            END;
            RETURN TRUE;
        END GetMenuChoice;

        PROCEDURE InitPage();
        BEGIN
            Choices[0] := 0C;
            GetMessage(ModuleNumber+7, Prefix); (* reset Prefix. *)
            UserSuppliedMenu := FALSE;
            menutop := LRY;
            menuend := LRY;
            IF (ULY >= menutop) THEN
                FatalError;
            END;
            StackCount := 0;
            WITH Stack[0] DO
                Indentation := DefaultIndentation;
                StartingY   := ULY;
            END;
        END InitPage;


        PROCEDURE StartPage(Fresh:BOOLEAN);
        VAR
            S : ARRAY [0..0] OF CHAR;
        BEGIN
            Fill(S," ",0);
            DrawBox(ULX,ULY,LRX,LRY,ABoxType{NoBox},S,videonormal);
            y := ULY;
            IF (Fresh) THEN
                InitPage();
            END;
        END StartPage;


        (*
            This procedure returns true for an overlay which is to take us out of
            help immediately after it finishes.
        *)
        PROCEDURE EscapeToOverlay( S : ARRAY OF CHAR ) : BOOLEAN;
        VAR
            i                   : CARDINAL;
            EarlyExitFlag       : BOOLEAN;
            C                   : CHAR;
            S0                  : ARRAY [0..0] OF CHAR;
        
        BEGIN
            C := S[2];
            Remove(S,1,2);
            EarlyExitFlag := FALSE;
        
            CASE (C) OF
                ">"   :  IF (OverlayPackage(S)) THEN; END;
        
              | "*"   :  EarlyExitFlag := TRUE;
                         S0[0] := 0C;
                         IF (TakeABranch (1,S,S0)) THEN END;
        
              (*
              | "="   :  i := 1;
                         Dispatch(ACode(StoC(S,i)));
              | "@"   :  ExecuteMenu(S,S);
              *)
                ELSE Error(S);
            END;
            RETURN (EarlyExitFlag);
        END EscapeToOverlay;



        PROCEDURE DoHelp;
        VAR
            i,j,k         : CARDINAL;
            MarginRelease : BOOLEAN;
            S2            : ARRAY [0..5] OF CHAR;
        BEGIN
                (*  Do one or several pages. *)


            LineWaiting := FALSE;
            FirstTime   := TRUE;

            LOOP
                RecordPosition();        (* Save file position for backtracking. *)

                    (* Do one page. *)
                StartPage(FirstTime);    (* But only erase user menus, etc.
                                            the first time called. *)
                FirstTime     := FALSE;
                MarginRelease := FALSE;


                    (*  When we enter this loop, s should be the next line to
                        display.  When we leave, it should be the line that forced
                        us to exit, either the line past the last one displayed or
                        the line whose initial character forced the exit. *)
                LOOP

                        (* Read in a new line to display, unless there is already one
                           in s. *)

                    IF (NOT LineWaiting) AND
                       (NOT GetNextString(s,C)) THEN
                        RETURN;
                    END;

                    LineWaiting := FALSE;

                        (* What is the second character of the string? *)
                    IF (s[0] >= 2C) THEN
                        C2 := s[2];
                    ELSE
                        C2 := 0C;
                    END;


                    CASE C OF 
                        "/" :   (* End of page 
                                   If there is anything following the 
                                   slash, it should be a number, or 
                                   another slash, meaning "unconditional break".  If there
                                   are fewer than that many lines left,
                                   end this page. *)
                            IF (LengthOf(s)=1) THEN
                                j := (LRY - ULY + 1) DIV 2;        (* Half page. *)
                            ELSIF (C2 = "/") THEN
                                EXIT;
                            ELSE
                                i := 2;                            (* Specific number of lines. *)
                                j := StoC(s,i);
                            END;
    
                            IF (j+y+1 >= menutop) THEN             (* Is requested space more than remaining? *)
                                EXIT;                              (* End the page. *)
                            ELSE
                                SetLengthOf(s,0);                  (* Insert a blank line in place of page break. *)
                                C := " "; 
                                LineWaiting := TRUE;
                            END;
                      | "+":    (* Add more menu choices. *)
                            IF (C2 = "+") THEN                (* ++ appends choices. *)
                                Remove(s,1,2);
                                ConcatLS(Choices,s);
                                DEC(menutop);
                            ELSE
                                SubStr(s,Choices,2,HIGH(Choices));   (* Replace the choices line. *)
                                UserSuppliedMenu := (Choices[0] > 0C);
                                menutop := menuend;
                            END;
                      | "=":    (* Menu choices, what they really mean. *)
                                (* Get the meanings of the choices. *)              
                            IF (C2 = "+") THEN                (* =+ appends equivalents. *)
                                Remove(s,1,1);
                                ConcatLS(ChoiceEquivalents,s);
                            ELSE
                                SubStr(s,ChoiceEquivalents,2,HIGH(ChoiceEquivalents));
                            END;
                      | "-":    (* Menu prefix *)
                            SubStr(s,Prefix,2,HIGH(Prefix));
                      | "^":  (* Overlay *)
                            IF (EscapeToOverlay(s)) THEN
                                RETURN;
                            END;

                      | "%":  (* A control command.  Control 
                                 commands don't print.
                                 Syntax = "%" Keyword "=" Argument *)          
                            C2 := s[2];   (* Take first letter, must be unique. *)
                            i := 2;
                            FindNextWord(s,i,"=");
                            Remove(s,1,i-1);
                            CASE C2 OF 
                                "T": 
                                      BookMarks.SetAbstract(s); (* Records first line of a topic. *)

                              | "D": (* Delay *)
                                       i := 1;
                                       Delay(StoC(s,i),KeyPress);

                              | "G":    (* Goto line *)
                                       IF (s[1] = "-") THEN
                                           i := 2;
                                           y := menutop - StoC(s,i);
                                           MarginRelease := TRUE;     (* Allow writing into menu area. *)
                                       ELSE
                                           i := 1;
                                           y := StoC(s,i) + Stack[StackCount].StartingY;
                                       END;

                              | "I":            (* Indent *)
                                       i := 1;
                                       k := StoC(s,i);
                                       IF (StackCount > 0) THEN
                                           j := Stack[StackCount-1].Indentation;
                                       ELSE
                                           j := DefaultIndentation;
                                       END;
                                       Stack[StackCount].Indentation := j+k;

                               ELSE;   (* Ignore unimplemented commands. *)
                           END;

                      ELSE
                              (* Not a special control character. *)
                            IF (y >= menutop) AND (NOT MarginRelease) THEN
                                LineWaiting := TRUE;
                                EXIT;
                            ELSE
                                PourText(s,videonormal, 
                                         ULX+Stack[StackCount].Indentation, 
                                         y,LRX,LRY,k);  
                                IF (CopyToPrinter) THEN
                                    MakePrinterCopy(s);
                                END;
                                BookMarks.SetAbstract(s); (* Records first line of a topic. *)
                                y := k+1;                 (* The next screen line. *)
                                MarginRelease := FALSE;
                            END;
                      END;  (* CASE C *)
                END;


                IF (NOT WaitAMinute(TRUE)) THEN
                    EXIT;
                END;
            END;
        END DoHelp;


(*NORMAL>*)

    BEGIN

        (*<NORMAL*)

        ClearTrace();

        SetCodeBits(CodeSet,0,MaxCode,FALSE);
        SetCodeBits(CodeSet,DoIt,DoIt,TRUE);
        SetCodeBits(CodeSet,CancelKey,CancelKey,TRUE);
        SetCodeBits(CodeSet,HelpKey,HelpKey,TRUE);
        SetCodeBits(CodeSet,HelpIndexKey,HelpIndexKey,TRUE);
        SetCodeBits(CodeSet,PgUpKey,PgUpKey,TRUE);
        SetCodeBits(CodeSet,PgDnKey,PgDnKey,TRUE);
        SetCodeBits(CodeSet,DsplyKey,DsplyKey,TRUE);
        SetCodeBits(CodeSet,MarkKey,MarkKey+NumberOfMarks-1,TRUE);
        SetCodeBits(CodeSet,JumpKey,JumpKey,TRUE);
        SetCodeBits(CodeSet,TraceKey,TraceKey,TRUE);


        Choices[0] := 0C;
        Prefix[0] := 0C;
        InitPage();

        CopyToPrinter := FALSE;         (* Printing is off. *)

            (*  Locate the text. *)

        IF (Branch(Subject)) THEN
            BookMarks.SetTopic(Subject);    (* Note that this is the current topic. *)
            DoHelp;
        END;

        (*NORMAL>*)

END ManageHelp;





PROCEDURE FileComplaint(f:File; N : CARDINAL);
VAR
    s, s2: ARRAY [0..80] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+N,s);
    ConcatS(s,", ");
    FileResultMeans(f,s2);
    ConcatLS(s,s2);
    Error(s);
END FileComplaint;






PROCEDURE DiscardIndexTree  (VAR Tree       : ATree);

BEGIN

(*<OS2
    Tree^.Methods^.TraverseTree (Tree, ParentAfterChild, 9999,
            DiscardIndexNode, NIL);
OS2>*)

    Tree^.Methods^.Discard (Tree);
    LastNode := NIL;
    IndexInited  := FALSE;
    Tree := ATree(NIL);
END DiscardIndexTree;




    (* ExtractParameters -- If the Subject is a word or phrase 
          followed by something in parenthesis, remove the stuff
          in parenthesis to Parameters. 
    *) 

PROCEDURE ExtractParameters( VAR Subject, Parameters : ARRAY OF CHAR );
VAR 
    i,j : CARDINAL;
    s1 : ARRAY [0..1] OF CHAR;
BEGIN
    SetLengthOf(Parameters,0);
    Fill(s1,"(",1);
    i := Search(Subject,s1,1);
    IF (i > 0) THEN
        j := i;  
        ParseBal(Subject,j,Parameters);
        SetLengthOf(Subject,i-1);
    END;    
END ExtractParameters;


PROCEDURE TLHelperBody();

VAR
    PrivateOverlayContext   : AContextPointer;
    High, Low               : CARDINAL;
    OldCursorState          : ACursorType;
    CallParameters          : ARRAY [0..255] OF CHAR;

BEGIN                       (* TLHelper *)
    BookMarks.InitBookMarks();

    PrivateOverlayContext := OverlayContext();
    WITH PrivateOverlayContext^ DO
            (* Extract any optional parameters. *)
        ExtractParameters(Subject,CallParameters);
            (* Normalize the subject. *)
        Procustes(Subject,TagLength);

        IF (Action = 0) THEN   (* Check subject exists. *)

            Reaction := ORD( GetSubjectPosition(Subject,High,Low) );


        ELSE (* Actually display help. *)
    
            BackTrack.Init();

            OldCursorState := GetCursorType();  (* 13-Sep-89 WKH *)
            SetCursorType(NoCursor);
    
    
            ManageHelp (Depth, Subject, CallParameters,
                        ULX, ULY, LRX, LRY,
                        ScreenAction, TextFile, IndexFile   );
    
            SetCursorType(OldCursorState);
        END;
    END;

END TLHelperBody;




PROCEDURE TLHelperExit();
VAR
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF (IndexInited) THEN
        DiscardIndexTree (IndexTree);
    END;
    CloseHelpFiles ();

    BookMarks.Terminate();

END TLHelperExit;

(*$S=*)




BEGIN
    LastHigh := 0;
    LastLow := 0;
    LastNode := NIL;
    IndexInited := FALSE;
    IndexInterlock := FALSE;

    IF (OpenHelpFiles (TextFile, IndexFile)) THEN

        OverlayID := ImAnInstallableOverlay(TLHelperBody, TLHelperExit);

        TLHelperBody();

    END;

END TLHelper.


---------------------------------------------------------------------

    To help you when writing help text, I want to list some of the current
capabilities:



          The helptext is stored on Nova3/MCAL1: (S:) in the \HELPTEXT
          directory.  The source is in a file called "helptext.txt"
          and is an ascii file that you can edit with a program
          editor such as Brief or Wordstar in non-document mode.

          After it is editted, it gets "compiled" by the MAKEHELP
          program, also in that directory.

          Each passage of the help text is identified by a line
          beginning with a dollar sign, and then an eight-character
          help key.  The compiler does two things to the help text: it
          compresses it into a file called TLHELP4.TXT and creates an
          index of all the passages into a file called TLHELP4.IDX.

          The text is so large that our file comparison programs
          cannot process it in one large chunk.  So, to check it for
          redline comparisons, you need to manually split it into
          several smaller files, and make splits in the previous
          versions, too, then run the BC program to compare them.

          I don't think it has ever been spell-checked.

          When someone is writing new help text, I recommend using two
          computers connected to the network, or else a task-switching
          program such as DeskView so that they can rapidly switch
          back and forth between editting the text, compileing it, and
          testing the results.

          To help the writer, there is a special key (Alt-F9) to press while in
          help text (debugging version only!) that will display the
          keys of the path of passages that led to the current screen.

WHAT GETS HELP

All menu items, form fields, and views.  Many dialog boxes and error
messages also have help text.

Help can be called from anywhere in Time Line.


INDEX

There is one index of help text, and QuickPick is supported.


HIGHLIGHTING

The text can contain various colors to highlight the contents.  These colors
are tied to the video configuration so they change appropriately.


NESTING

One passage of help text can call another as a "subroutine" or can branch 
to another passage.

When subroutine calls are made, text-substitution parameters can be passed.

Jumps can be made conditional on whether or not the user has pressed a
key.  (Necessary to end any animation, see below.)

PARAMETERS

Help text can expand any of the keywords which are available for report
headings, such as the current date.  In addition, parameters can be passed
to help text which can be included into the test at key points.  (See
the help for ".STATS" for an elaborate example of this.

When help is called for error messages, the text of the error message is
passed as parameter 1.

PAGE BREAKS

// breaks to a new screen panel
/  breaks if there is less than half a screen depth left (useful for 
   allowing the text to adapt to 25-line vs 50-line screens).
/<number> breaks if there is less than <number> lines left.

OVERLAYS

Help can call overlays with the "^" command.  For example, the help system
could exit to DOS or bring up the tutorial.

MENU AT BOTTOM OF PAGE

There is a menu at the bottom of each page of help text.  You can override
the menu, add items to it, or change the prefix.

Picking a menu item jumps to the selected item.  By default, the help 
system takes the text of the menu as the help key, but this is 
overridable with the "=" and "=+" commands.

OTHER CONTROLS

Lines beginning "%" are non-printing control commands.  Syntax is
"%" Keyword "=" Argument.

Controls implemented are:
    TOPIC       Sets the description that will appear if a bookmark
                is set to this help passage.
    DELAY       Waits <argument> seconds or until next keypress.
                This, plus the Goto screen line command can be used to
                do animation.
    GOTOLINE    Positions the cursor for writing to a specific line
                on the screen, relative to either the top or bottom of the
                screen.
    INDENT      Indents all following text.



