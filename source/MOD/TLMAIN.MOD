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
    *)


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
    (* PROC *)                  InstallNewProcedure, CallOverlayWithContext;

FROM ParmLine               IMPORT   (* RSC 10/31/87 *)
        (* PROCS *)             GetOption;

FROM Paranoia               IMPORT
        (* TYPE *)              AProgramState,
        (* PROC *)              ProgramState, InitializationOK;

FROM RunMenu                IMPORT
    (* PROC *)                     SelectAndRunMenu, ExecuteMenu;

FROM Schedule               IMPORT ScheduleSaved, ConfigSaved, InstalledFlag;

FROM SYSTEM                 IMPORT ADR, ADDRESS;

FROM Transfer               IMPORT RetrieveDammit;

FROM TreeObjects            IMPORT ATreeNode;


CONST
    ModuleNumber            = 4500; (* For GetMessage; SAME AS TIMELINE.MOD! *)






CONST
    (*ShowVersionNumberKey = 305;    (* ALT-N *)   (* LAA 8/7/86 *) *)
    EditHotKey           = ReInsertKey;                           (* 13-Apr-89 LAA *)

VAR
    OldGetCode              : Keyboard.AGetCodeProcedure;
    InTLSpread              : BOOLEAN;




    (* RSC 10/28/88 - Save stack space. *)

PROCEDURE MainHelp();
VAR
    S     : ARRAY [0..9] OF CHAR;
BEGIN
    SetString (S, "TM.INDEX");
    GiveHelp(S,0,GanttWEnd,RestoreTheScreen);
END MainHelp;



PROCEDURE OurGetCode():CARDINAL;

VAR
    Code  : CARDINAL;

BEGIN
    LOOP
        Code := OldGetCode();
        IF (Code = EditHotKey) THEN                      (* 01/06/87 LAA *)
            PickAndEditMemo();
        ELSIF (Code = HelpIndexKey) THEN
            MainHelp();     (* RSC 10/28/88 *)
        ELSE
            RETURN Code;
        END;
    END;
END OurGetCode;







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
    Context : RECORD
        TreeNode    : ATreeNode;
        ok          : BOOLEAN;
    END;

    s   : ARRAY [0..9] OF CHAR;
    ok2 : BOOLEAN;

BEGIN

    SetString(s, "TLSPBASE" );
    WITH Context DO
        ok       := FALSE;
        TreeNode := TaskNode;
    END;
    ok2 := CallOverlayWithContext( s, ADR(Context) );

    RETURN Context.ok AND ok2;

END DoTLSpread;





PROCEDURE Init();
VAR
    S                       : ARRAY [0..99]  OF CHAR;
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN

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