    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

(*<OS2
IMPLEMENTATION MODULE TLMain;
OS2>*)
(*<DOS*)
MODULE TLMain;
(*DOS>*)

    (*  MODIFICATION HISTORY                                       
                                                                   
         TimeLine's Main Menu                                      
                                                                   
        RSC Oct 15 87 - Added prompts for exiting program.         
        RSC Nov  6 87 - added PLOT EXIT with completion code 1.    
        RSC Nov 10 87 - added PLOT EXIT with completion code 0!    
        AJL Feb  9 88 - Used Error for version number.             
        LAA Feb 11 88 - Moved DisplayTheChart for codes which      
                        GanttOutlines can't handle.                
        AJL Feb 12 88 - Moved most of init and the former global   
                        variable S into a procedure Init.          
                      - If the InstalledFlag is FALSE, call help   
                        with key "FIRSTAID".                       
                      - Moved other variables local to MenuLoop.   
        AJL Feb 15 88 - Push codes even if NOT InstalledFlag.      
                      - FlushKeyboardBuffer first.                 
        RSC Feb 22 88 - Moved command params into GaGa.            
        EGK Feb 25 88 - Changed plotter code from 1 to PlotGantt.  
        AJL Feb 28 88 - Don't FlushKeys unless needed.             
        RSC Oct 28 88 - Save stack space in main loop.             
        RSC Jan  5 89 - Moved Actions to Keys.                     
        RSC Mar  2 89 - Changed "InstallNewKeys"                   
                                                                   
        7-Mar-89 LAA   Changed ADDRESS to ADR in calls to          
                       InstallNewProcedure.                        
        7-Apr-89 LAA   Added support for Spreadsheet View.         
        13-Apr-89 LAA  Changed the hotkey which brings up journal  
                       notes from Shift-F5 to Alt-F2, so that the  
                       previous key can be reused for GoTo based   
                       on WBS number (someday).  Sorry Roger, guess
                       this preempts your use of Alt-F2!           
        26-Apr-89 LAA  Modified the format of the modification history.
         4-Jun-89 EGK  Put in a call to SendNotices in MenuLoop, since
                       Permission no longer does it automatically.
        16-Jun-89 RSC  Try to get rid of silly "VERSION CONFLICT" messages.
        26-Jun-89 WKH  Show user name in Alt-N.  Also, TLReg will now, as
                       part of a successful exit, set ProgramState to
                       TLMainStarting.  TLMain is now resposible to see that
                       this is the case upon entry to it's init code.  If not,
                       then there was a problem or someone tried to bypass
                       TLReg by removing it from the TLWHAT4.CFG file.
        28-Jun-89 LAA  Added an import to resolve the old version conflict \
                       problem.
        01-Jul-89 WKH  Added more info to ShowVersionString key (Alt+N)
        02-Jul-89 WKH  Fixed formatting of Alt+N box.
        31-Jul-89 RSC  Removed flush of keyboard buffer, as TLREG has already
                       run, defeating the purpose of flushing typeahead.
                       Perhaps TLREG should flush the buffer, or TimeLine.Mod?
        06-Aug-89 WKH  Initial OS2 edits.
        09-Aug-89 KKC  Add copyright message.
        10-Aug-89 EGK  Moved WantToQuit procedure from here to GanttOutlines.
                       Now it's not necessary to exit an alternate view
                       before checking whether it's OK to quit.
        21-Aug-89 EGK  Removed some unused imports to "fix" the mysterious
                       linker bug.
         5-Sep-89 RSC  Moved the setting of "CursorTask" to GanttOutlines.
        21-Sep-89 AJL  Removed the Alt-N version number hot key.  Replaced by
                       the / Utilities Statistics screen.  
        13-Dec-89 LAA  The main loop was not useing GetNextEvent, so it would
                       not work for the new mouse events.  Fixed it.
        20-Aug-90 RSC  Removed spurious stack variable in GetAnyCode.
        21-Jan-91 RSC  Debugging code support.  THIS IS FOR TESTING ONLY.
    *)


FROM Allocs                 IMPORT ATask;

FROM BTStorage              IMPORT AStorageProc, ALLOCATE, DEALLOCATE;

FROM Chainer                IMPORT Chain;

FROM Chart                  IMPORT GanttChart;

FROM ChartControl           IMPORT DisplayTheChart, AChartState, ChartState,
                                   UnSetState;

FROM Dialog                 IMPORT Burp, Error, FatalError, Message;

FROM Dispatcher             IMPORT Dispatch;

FROM Endings                IMPORT CompletionCode, QuitDammitCode;

FROM ErrorHandler           IMPORT
    (* TYPE *)                  AnErrorMarker,
    (* PROC *)                  NewMarker, ErrorPosted, PopToMarker;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent, AnEventType,
    (* PROC *)                  GetNextEvent;

FROM FlexStor               IMPORT
    (* TYPE *)                  ALockObjectProc, AnExtHandle,
                                ACreateExtObjectProc, AnExtStoragePreference,
    (* PROC *)                  LockObject, CreateExtObjectWithSize;

FROM GaGa                   IMPORT
    (* PROC *)                  GetGaGaMessage;

FROM Helper                 IMPORT
    (* TYPE *)                  AScreenAction,
    (* PROC *)                  GiveHelp;

FROM Kbio                   IMPORT GetAnyCode,  PushCode, KeyPress,
                                   FlushKeyboardBuffer,
                                   ascreeny, avidmode, vidctrl,
                                   EraseScreen, ascreenx, EraseLn,
                                   VersionString;

FROM Keys                   IMPORT CancelKey, OnMenu, AlternateDisplayKey,
                                   ComputeKey, HelpIndexKey, ReInsertKey,

                                    (* From Actions before 1/5/89.  RSC. *)

                                   PlotGantt, QuitProgram, FileRetrieve;

FROM Layout                 IMPORT MenuStart, GanttWEnd, GanttWStart;

FROM Lights                 IMPORT EnableLights;

FROM LStrings               IMPORT Fill, SetString, CtoS, ConcatS, ConcatLS;

IMPORT Keyboard;

FROM Memos                  IMPORT PickAndEditMemo;

FROM MsgFile                IMPORT GetMessage, ConcatMessage, DisplayMessage;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  Permission, SendNotices;

FROM Overlays               IMPORT
    (* PROC *)                  InstallNewProcedure, CallOverlay;

FROM ParmLine               IMPORT   (* RSC 10/31/87 *)
        (* PROCS *)             GetOption;

FROM Paranoia               IMPORT
        (* TYPE *)              AProgramState,
        (* PROC *)              ProgramState, InitializationOK;

FROM RealFormat             IMPORT FormatAsAmount, DefaultAmountFormat;

FROM RunMenu                IMPORT
    (* PROC *)                     SelectAndRunMenu, ExecuteMenu;

FROM Schedule               IMPORT ScheduleSaved, ConfigSaved, InstalledFlag;

FROM SYSTEM                 IMPORT ADR, ADDRESS, TSIZE;

FROM Transfer               IMPORT RetrieveDammit;

FROM TreeObjects            IMPORT ATreeNode;


CONST
    ModuleNumber            = 4500; (* For GetMessage; SAME AS TIMELINE.MOD! *)






CONST
    ShowVersionNumberKey = 305;    (* ALT-N *)   (* LAA 8/7/86 *)
    EditHotKey           = ReInsertKey;                           (* 13-Apr-89 LAA *)

VAR
(*    StatsList               : ARRAY [1..40] OF RECORD*)
(*        TheHandle               : AnExtHandle;*)
(*        Count                   : CARDINAL;*)
(*    END;*)

    Categories              : ARRAY [0..4] OF CARDINAL;

    SizeAndCount            : ARRAY [1..30] OF RECORD
        TheSize,
        HowMany,
        TheCount            : CARDINAL;
        TheHandle           : ADDRESS;
    END;

    Interlock               : CARDINAL;

    OldLock                 : ALockObjectProc;
    OldCreate               : ACreateExtObjectProc;

    OldALLOCATE,
    OldDEALLOCATE           : AStorageProc;

    GSize                   : REAL;
    TotalLocks              : REAL;

    OldGetCode              : Keyboard.AGetCodeProcedure;

    InTLSpread              : BOOLEAN;
    Display                 : BOOLEAN;



    (* RSC 10/28/88 - Save stack space. *)

PROCEDURE MainHelp();
VAR
    S     : ARRAY [0..9] OF CHAR;
BEGIN
    SetString (S, "TM.INDEX");
    GiveHelp(S,0,GanttWEnd,RestoreTheScreen);
END MainHelp;



PROCEDURE XLock(       Handle      : AnExtHandle;
                   VAR Data        : ADDRESS  ) : CARDINAL;
VAR
    Size,
    i, j    : CARDINAL;
    s       : ARRAY [0..5] OF CHAR;
BEGIN
    INC(Interlock);

(* ********************************
    IF (Interlock = 1) THEN
        i := 1;
        WHILE (i <= HIGH(StatsList)) AND
              (StatsList[i].TheHandle <> Handle) DO
            INC(i);
        END;
    
        IF (i > HIGH(StatsList)) THEN
            FOR j := HIGH(StatsList) TO 2 BY -1 DO
                StatsList[j].TheHandle := StatsList[j-1].TheHandle;
            END;
            StatsList[1].TheHandle := Handle;
        ELSIF ( StatsList[i].Count < 65535) THEN
            INC(StatsList[i].Count);    (* FOUND IN THIS SLOT *)
        END;

        TotalLocks := TotalLocks + 1.0;
    END;
*************************************** *)

    Size := OldLock( Handle, Data );

    IF (Interlock = 1) THEN
        i    := 1;

        LOOP
            IF (i > HIGH(SizeAndCount)) OR
               (SizeAndCount[i].TheSize = 0) THEN
                EXIT;
            END;

            WITH SizeAndCount[i] DO
                IF (TheSize = Size) THEN
                    IF (TheCount < 65535) THEN
                        INC(TheCount);
                    END;
(*                    IF (TheHandle = ADDRESS(Handle)) AND*)
(*                       (Display)                     AND*)
(*                       (Size      = 29)    THEN*)
(*                        CtoS( Size, s );*)
(*                        Error(s);*)
(*                    END;*)
                    EXIT;
                END;
            END;

            INC(i);
        END;
    END;

    DEC(Interlock);

    RETURN Size;

END XLock;




PROCEDURE XCreate( VAR Handle : AnExtHandle;
                       Storage: AnExtStoragePreference;
                       Size   : CARDINAL
                 ):BOOLEAN;
VAR
    i   : CARDINAL;
    ok  : BOOLEAN;
BEGIN
    i    := 1;

    ok := OldCreate( Handle, Storage, Size );

    IF (Interlock = 0) AND (Size > 0) THEN
        INC(Interlock);
        LOOP
            IF (i > HIGH(SizeAndCount)) THEN
                EXIT;
            END;
            IF (SizeAndCount[i].TheSize = Size) THEN
                INC(SizeAndCount[i].HowMany);
                EXIT;
            END;
            WITH SizeAndCount[i] DO
                IF (TheSize = 0) THEN
                    TheSize  := Size;
                    TheCount := 0;
                    HowMany  := 1;
                    IF (TheHandle = NIL) THEN
                        TheHandle := ADDRESS(Handle);
                    END;
                    EXIT;
                END;
            END;
            INC(i);
        END;
        DEC(Interlock);
    END;

    RETURN ok;

END XCreate;





PROCEDURE PrintCategories();
VAR
    High,
    HighThisPass,
    IndexThisPass,
    i,j, k              : CARDINAL;
    s                   : ARRAY [0..255] OF CHAR;
    s1                  : ARRAY [0..9]   OF CHAR;
BEGIN
    INC(Interlock);

    s[0] := 0C;
    FOR i := 0 TO HIGH(Categories) DO
        CASE i OF
            0: SetString( s1, "Misc:" );
          | 1: SetString( s1, " TNodes:" );
          | 2: SetString( s1, " Edges:" );
          | 3: SetString( s1, " Trees:" );
          | 4: SetString( s1, " Cells:" );
        ELSE
            FatalError();
        END;
        ConcatLS( s, s1 );
        CtoS(Categories[i],s1);
        ConcatLS( s, s1 );
    END;
    ConcatS(s, " Total Bytes:" );
    FormatAsAmount( GSize, DefaultAmountFormat, s1, 9,0,0,FALSE );
    ConcatLS( s, s1 );
    Error(s);

(* *********************************************
    s[0] := 0C;

    FOR i := 1 TO HIGH(StatsList) DO
        IF (StatsList[i].Count > 0) THEN
            IF (s[0] <> 0C) THEN
                ConcatS(  s, ", " );
            END;
            CtoS( i, s1 );
            ConcatLS( s, s1 );
            ConcatS(  s, ":" );
            CtoS(StatsList[i].Count,s1);
            ConcatLS( s, s1 );
            IF (ORD(s[0]) > 200) THEN
                Error(s);
                s[0] := 0C;
            END;
        END;
    END;
    IF (s[0] <> 0C) THEN
        ConcatS(  s, ", " );
    END;
    ConcatS( s, "TOTAL:" );
    FormatAsAmount( TotalLocks, DefaultAmountFormat, s1, 9,0,0,FALSE );
    ConcatLS( s, s1 );

    Error(s);
*********************************************** *)

    s[0] := 0C;

    (* 1: Find the limit of the array
    *)
    j := 1;
    WHILE (j <= HIGH(SizeAndCount)) AND
          (SizeAndCount[j].TheSize > 0) DO
        INC(j);
    END;
    DEC(j);  (* We were one past the last one. *)

    (* SORT THE ARRAY BY DESCENDING SIZE *)

    FOR i := 1 TO j DO  (* There will be J entries to be searched *)

        HighThisPass  := 0;
        IndexThisPass := 0;

        FOR k := 1 TO j DO
            IF (SizeAndCount[k].TheCount < 65535) AND
               (SizeAndCount[k].TheCount > HighThisPass) THEN
                HighThisPass  := SizeAndCount[k].TheCount;
                IndexThisPass := k;
            END;
        END;

        (* Now IndexThisPass contains the highest entry remaining
        *)
        IF (IndexThisPass > 0) THEN
            IF (s[0] <> 0C) THEN
                ConcatS(  s, ", " );
            END;
            CtoS(SizeAndCount[IndexThisPass].TheCount,s1);
            ConcatLS( s, s1 );
            ConcatS( s, " locks of " );
            CtoS(SizeAndCount[IndexThisPass].TheSize,s1);
            ConcatLS( s, s1 );
            ConcatS(  s, " bytes in " );
            CtoS(SizeAndCount[IndexThisPass].HowMany,s1);
            ConcatLS( s, s1 );
            ConcatS(  s, "items" );
            IF (ORD(s[0]) > 200) THEN
                Error(s);
                s[0] := 0C;
            END;
            SizeAndCount[IndexThisPass].TheCount := 65535;
        END;
    END;

    IF (s[0] <> 0C) THEN
        Error(s);
    END;

    InitStats();

    DEC(Interlock);

END PrintCategories;





PROCEDURE OurGetCode():CARDINAL;

VAR
    Code  : CARDINAL;

BEGIN
    LOOP
        Code := OldGetCode();
        IF (Code = EditHotKey) THEN                      (* 01/06/87 LAA *)
            PickAndEditMemo();
        ELSIF (Code = HelpIndexKey) THEN
            Display := (NOT Display);
            MainHelp();     (* RSC 10/28/88 *)
        ELSIF (Code = ShowVersionNumberKey) THEN
            PrintCategories();
        ELSE
            RETURN Code;
        END;
    END;
END OurGetCode;







PROCEDURE CategorizeMemory( Size : CARDINAL; Increment : BOOLEAN );
VAR
    Category : CARDINAL;
BEGIN
    IF (Size = 24) THEN
        Category := 1;  (* TreeNode *)
    ELSIF (Size = 30) THEN
        Category := 2;  (* Edge *)
    ELSIF (Size = 12) THEN
        Category := 3;  (* Tree *)
    ELSIF (Size = 1024) THEN (* 256 * 4 *)
        Category := 4;  (* Cell table? *)
    ELSE
        Category := 0;
    END;

    IF (Increment) THEN
        INC(Categories[Category]);
    ELSE
        DEC(Categories[Category]);
    END;

END CategorizeMemory;







PROCEDURE MenuLoop;
VAR
    Event                   : AnEvent;
    ReturnEvent             : AnEvent;
    ErrorMarker             : AnErrorMarker;
    FirstTime               : BOOLEAN;


    PROCEDURE DoFirstTime( VAR FirstTime : BOOLEAN );
    VAR
        S                   : ARRAY [0..255] OF CHAR;
        WhatNext            : ARRAY [0..15]  OF CHAR;
        ok                  : BOOLEAN;
    BEGIN
        FirstTime := FALSE;
        GetGaGaMessage( ModuleNumber + 1, S ); (* "RECALC" *)
        GetOption(S,ok,WhatNext);
        IF (ok) THEN
            UnSetState(Showing);
            UnSetState(Scheduled);
            DisplayTheChart();
            Dispatch(ComputeKey);
            ExecuteMenu(WhatNext, WhatNext); (* Execute option *)
        END;
    END DoFirstTime;


BEGIN                       (* MenuLoop *)

    FirstTime := TRUE;
    DisplayTheChart();

    LOOP
        GetNextEvent( Event );                                 (* 13-Dec-89 *)

        ErrorMarker     := NewMarker();

        UnSetState(Showing);                                      (* 19-Aug-87 LAA *)
        GanttChart^.Methods^.ActOnEvent(GanttChart, Event, ReturnEvent);

        PopToMarker(ErrorMarker);

        IF (FirstTime) THEN
            DoFirstTime( FirstTime );
        END;

        IF (QuitDammitCode <> 0) THEN
            ReturnEvent.EventCode := QuitDammitCode;
        END;

        CASE (ReturnEvent.EventCode) OF
            0,
            CancelKey : ;

        |   QuitProgram   :
                    SendNotices (ProgramQuit, BeforeActing, NIL);   (* 6/4/89 EGK *)
                    EXIT;

        |   PlotGantt : (* QUIT TO PLOTTING PROGRAM *)

                    EXIT;
        ELSE
            Burp;
        END;
        DisplayTheChart();                                        (* 11-Feb-88 LAA *)
        QuitDammitCode := 0;
    END;

    SendNotices(ProgramQuit,AfterActing,NIL);

END MenuLoop;





PROCEDURE DoTLSpread( TaskNode : ATreeNode ) : BOOLEAN;
VAR
    s   : ARRAY [0..9] OF CHAR;
    ok  : BOOLEAN;
BEGIN

    IF (InTLSpread) THEN
        FatalError();  (* ReEntrant?  Me? *)
    END;

    InTLSpread := TRUE;

    SetString(s, "TLSPREAD" );
    ok := (CallOverlay( s )) AND
          (GanttChart^.Methods^.AlternateChangeTaskProc( TaskNode ));

    InTLSpread := FALSE;

    RETURN ok;

END DoTLSpread;





PROCEDURE XALLOCATE( VAR A : ADDRESS; size : CARDINAL );
BEGIN
   GSize := GSize + FLOAT( size );
   CategorizeMemory( size, TRUE );

   OldALLOCATE( A, size );  (* 02-Oct-89 WKH *)

END XALLOCATE;


PROCEDURE XDEALLOCATE( VAR A : ADDRESS; size : CARDINAL );
BEGIN
    GSize := GSize - FLOAT( size );
    CategorizeMemory( size, FALSE );
    OldDEALLOCATE( A, size );  (* 02-Oct-89 WKH *)
END XDEALLOCATE;



PROCEDURE InitStats();
VAR
    i                       : CARDINAL;
BEGIN
(*    FOR i := 1 TO HIGH(StatsList) DO*)
(*        StatsList[i].TheHandle := AnExtHandle(NIL);*)
(*        StatsList[i].Count     := 0*)
(*    END;*)
    TotalLocks := 0.0;

    FOR i := 1 TO HIGH(SizeAndCount) DO
        SizeAndCount[i].TheCount   := 0;
        SizeAndCount[i].TheHandle  := NIL;
    END;

END InitStats;




PROCEDURE Init();
VAR
    i                       : CARDINAL;
    S                       : ARRAY [0..99]  OF CHAR;
    Copyright               : ARRAY [0..50] OF CHAR;
BEGIN
    FOR i := 0 TO 4 DO
        Categories[i] := 0;
    END;
    FOR i := 1 TO HIGH(SizeAndCount) DO
        SizeAndCount[i].TheSize    := 0;
        SizeAndCount[i].HowMany    := 0;
    END;

    InitStats();

    GSize   := 0.0;

    InstallNewProcedure( ADR(CreateExtObjectWithSize), PROC(XCreate),  ADR(OldCreate));
    InstallNewProcedure( ADR(LockObject), PROC(XLock),  ADR(OldLock));
    InstallNewProcedure( ADR(ALLOCATE),   PROC(XALLOCATE),  ADR(OldALLOCATE));
    InstallNewProcedure( ADR(DEALLOCATE), PROC(XDEALLOCATE),ADR(OldDEALLOCATE));

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    IF (ProgramState = TLMainStarting) THEN  (* 26-Jun-89 WKH *)

        EnableLights(TRUE);

            (* Install our keystroke handler into the keystroke handling chain.

                2-Mar-89 RSC
            *)

        InstallNewProcedure(ADR(Keyboard.GetAnyCode),PROC(OurGetCode), ADR(OldGetCode));

        (* Install the spreadsheet view default proc. *)

        InTLSpread := FALSE;
        InstallNewProcedure( ADR(GanttChart^.Methods^.AlternateChangeTaskProc), PROC(DoTLSpread), NIL );


        EraseLn(GanttWStart-2);
        EraseLn(GanttWStart-1);
        Fill(S, " ", 0);
        Message(S);

        IF (InitializationOK) THEN
            ProgramState := TLMainRunning;
            IF (NOT InstalledFlag) THEN
                (* RSC 31-Jul-89 FlushKeyboardBuffer(); *)
                SetString(S,"FIRSTAID");
                GiveHelp (S, 0, GanttWEnd, RestoreTheScreen);
                GetMessage(ModuleNumber + 9, S); (* "SETUP" *)
                ExecuteMenu(S,S);
                InstalledFlag := TRUE;       (* Saved in config file. *)
            END;    
            IF (RetrieveDammit) THEN
                (* RSC 31-Jul-89 FlushKeyboardBuffer(); *)
                PushCode(FileRetrieve);
            ELSE
                PushCode(OnMenu);
            END;
        END;
    ELSE
        InitializationOK := FALSE;
    END;
END Init;

(*<OS2
PROCEDURE TLMainBind();
OS2>*)

BEGIN                       (* TLMain *)

    Interlock := 0;
    Display   := FALSE;

    Init();
   
    IF (InitializationOK) THEN
        MenuLoop();
        ProgramState := TLMainDone;
    END;
    
    Chain();                  (* Any clean up overlays. *)

(*<OS2
END TLMainBind;
OS2>*)

END TLMain.
