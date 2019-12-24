MODULE TLDOS;

  (*
     RSC  2/13/88 -Took Andrew's original and got it to work by futzying
                   around with the low memory notice.  Added dialogs.
     AJL  2/23/88 -Add a message at the top of the dos screen.
     AJL  6/30/88 -Add ability to run arbitrary dos programs.
                   If the context parameter string (from Overlays) has
                   a program name in it, that program will be run.  If
                   the name begins with a drive or directory, we will look
                   for the program there; otherwise the overlays search path
                   is used.  The file name must contain the proper extension.
                   If followed by further text in parenthesis, the enclosed
                   text is passed to the executed program as parameters.
                  -Interlock with Ctrl-C.
     LAA  7/20/88 -Expanded S2 to 255 characters, and used it instead of
                   Params to hold the error message.  Message was longer than
                   the array (resulted in Too Long error).  Bug #8381.
     AJL  8/25/88 -Disallow exit to dos for DOS < 3.0.
     RSC 2-Jan-89  Changed references to Compare() to StringsEqual().
     RSC 2-Mar-89  Changed "InstallNewProcedure" for Overlays.Mod.
     KKC 12-May-89 Call KKCDosShell and KKCExecute instead of DosShell and
                   Execute.
                   Remove all trailing blanks from Parms and append a CR
                   instead a NULL to the end of it.
                   I have discussed this with Andrew.  Even thought he
                   strongly believes we need a NULL at the end of the command
                   line, I've checked it out and DOS doesn't put a null at the
                   end of command line.
     KKC 22-May-89 Search environment path for executable file.
     KKC 26-May-89 Return full path of executable file in
                   SearchForExecutableFile even for the files that are found
                   in current directory.
     WKH 05/29/89  Reset the video settings on return from DOS
     KKC 31-May-89 Create swap file at the current directory.
                   Insert "command.com /c " in front of a batch file.
                   Reject all unexecutable files.
     AJL 5 -Jun-89 Send out a (new) ExitToDOS notice.
                   Move the form up above the end of the screen.
     KKC 12-Jun-89 Rename swapmem.ovl to tlswpmem.ovl
     WKH 13-Jun-89 Added calls to PrepareForVideoExit and PrepareForVideoReturn
     WKH 15-Jun-89 Switch sequence that we call PrepareForVideoReturn and ResetVideo
     KKC 30-Jun-89 Move cursor one row below the warning message when exiting to Dos
     KKC 10-Jul-89 Call InitSwapFileDelete in RunDosProgram.
     AJL 12-Jul-89 Send notices after return from DOS.
     AJL 26-Jul-89 Add a Quick Exit option.
                   Added a "One moment . . ." message when running a program.
     KKC 02-Aug-89 Import getoption and expandpath,
                   Pass SwapVol to InitSwapFileDelete.
     KKC 08-Aug-89 Use SwapVol for memory image file.
                   Include Overlaypath in our search path.
     KKC 10-Aug-89 Add copyright message.
     KKC 11-Aug-89 Check Length of directory before passing it
                   to DirectoryIsReachable
     EGK/RSC 28-Aug-89   Moved calls to OverlayContext and
                         InstallNewProcedure to the very beginning of this
                         module's initialization section.
     KKC 30-Aug-89 Put a semicolon before the dos path and the overlay path.
     WKH 11-Sep-89 Get PSP address from OurPSP instead of RTSMain.
     KKC 14-Sep-89 Pass PathAndFileName instead of Specifications to
                   CallOverlayWithContext.
     AJL 19-Sep-89 Substitute keywords into the parameters to called program.
     AJL 21-Sep-89 Moved the form to another overlay, TLDOSFrm.
                   Always substitute for parameters, even if not doing any
                   user dialog.
     KKC 28-Sep-89 Add wait message when exiting to DOS.
     MWP 10-Oct-89 Moved text literals to phrases file.
     KKC 19-Oct-89 Allow exit to dos for DOS < 3.0.
     RSC 29-Oct-89 1) Use the COMSPEC to find COMMAND.COM.
                   2) Call TLDOSFRM.OVL through TLFBASE.  Saves big bytes.
     KKC 04-Jan-90 Subtract the command line char counter by 1 since CR
                   is just an EOL marker.
     KKC 09-Feb-90 Call SendNotices right before and after we exit to dos.
     KKC 07-Mar-90 Search command.com from comspec instead of search path.
                   
     RSC 19-Mar-90 Ajust video re-initialization (as per WKH).  Must
                   re-init before sending out notices, so that the mouse
                   cursor is set to run in full 50 line mode.
     RSC 30-Jan-91 Use Exit2Dos module to notify clients that we are
                   exiting.  This is safer than notices, becuase it takes
                   no heap-style memory (which may not yet be resident on
                   reload).  These are the "ExitingToDOSNotification" calls.
     RSC 21-Feb-91 restore video when an overlay runs.
                   Remove the break detector. All it did was to tell
                   the real break handler that nothing happened.  Instead,
                   I just reset the break after I come back from the external
                   program.
     RSC 21-Feb-91 Found another place where we need to restore video
                   when an overlay runs.  That is, when a file is not found.
     RSC 20-Mar-91 Fixed the cause of exit-2-dos never coming back: I had
                   altered the ORDER of things declared on the stack, so
                   that some strings were on different even/odd boundaries
                   than they were before.  Take heed of warnings by the
                   procedures.

                   Also, now that TLVidMem runs a lot (most of the time),
                   we need to handle setting up the video for exit a
                   little differently.  See DoMessage, LastThingBeforeExit,
                   and FirstThingAfterWeComeBack.

     RSC 10-May-91 Made parameters to CallOverlayWithContext stack resident.
     AJL 12-Jun-91 Moved the cursor to the next clear line before allowing
                   DOS to write its copyright notices.
                   Added a wait message on exit to dos.
     AJL 19-Jun-91 Avoid putting "One moment . . . " on the screen twice
                   when exiting to run a program.
  *)

FROM Boxes         IMPORT
    (* TYPE *)          ABoxAttribute, ABoxType;

FROM Devices    IMPORT
    (* PROCS *)    SaveInterruptVector, RestoreInterruptVector;

FROM Dialog     IMPORT
    (* TYPE  *)    ADialogOption, ABoxHandle,
    (* PROCS *)    Message, Error, WarningBox, ContinuationBox,
                   MultipleChoiceBox, ProgressBox, ReleaseBox;

FROM Directory              IMPORT
        (* CONST *)             MaximumFileNameLength, MaximumExtensionLength,
                                MaximumDeviceNameLength, MaximumPathNameLength,
        (* TYPES *)             AFileNameNode, AFileNameRecord,
                                AFileAttributeSet, ASetOfFileNameParts,
                                AFileNamePart,
        (* PROCS *)             DirectoryIsReachable, ExtractFileNameParts,
                                ParseFileName,
                                GetPathEntry, NormalizeFileName,
                                PathLookupStart,
                                DOSVersion, ExpandPath;


FROM DiskDirectory IMPORT
    (* PROCS *)    CurrentDrive,     SelectDrive,
                   CurrentDirectory, ChangeDirectory;

FROM Exec       IMPORT
    (* PROC *)      DosShell;

FROM Exit2Dos   IMPORT
    (* PROC *)      ExitingToDOSNotification;

FROM FileAux    IMPORT
    (* VAR *)       OverlayPath;

FROM FileOpen   IMPORT
    (* PROC *)      RequestFileFind;

FROM Kbio       IMPORT
    (* CONST *)    maxcol, maxrow,
    (* TYPE *)     ACursorType, avidmode, ascreeny,
    (* PROC *)     SetCursorType, GotoXY, PourText, EraseScreen,
                   PrepareVideoForExit, PrepareVideoForReturn;

IMPORT Keyboard;

FROM KeywdSub   IMPORT
    (* PROC *)      MakeSubstitutions;

FROM LStrings   IMPORT
    (* PROC *)     LStringToTString, TStringToLString, SetString, ConcatS,
                   StringsEqual, ConcatLS, Fill, LengthOf, SetLengthOf, SubStr,
                   CtoS, Insert, Copy, TrimRear;

FROM MsgFile    IMPORT
    (* PROC *)     ConcatMessage, GetMessage;

FROM Notices    IMPORT
    (* TYPE *)     AnOccasion, AStep, ANoticeProc,
    (* PROC *)     RegisterForNotices, UnRegisterForNotices,
                   SendNotices, Permission;

FROM OurPSP     IMPORT
                    OurPSPAddress;

FROM Overlays   IMPORT
    (* PROC *)     OverlayContext, InstallNewProcedure, CallOverlayWithContext;

FROM ParmLine   IMPORT
    (* PROC *)     GetOption;

FROM Rugs       IMPORT
    (* TYPE *)     ARug,
    (* PROC *)     GetRug, PutRug;

FROM SchedKey   IMPORT
    (* PROC *)     GetKeyWordValue;

FROM Space      IMPORT
    (* PROCS *)    HeapAvailable, ALLOCATE, DEALLOCATE, Available;

FROM SwapFile   IMPORT
    (* PROCS *)    InitSwapFileDelete;

FROM SYSTEM     IMPORT
    (* THING *)    ADDRESS, ADR, SWI, ENABLE, TSIZE;

FROM Video      IMPORT
                   ResetVideo,
                   PutStringWithAttribute;

FROM Words      IMPORT
    (* PROC *)     ParseBal;

FROM DoSwap IMPORT KKCDosShell, KKCExecute;


CONST
    ModuleNumber = 22900;   (* For GetMessage *)

    CriticalErrorInterrupt = 24H;   (* vector used by DOS 2.0 *)
    CtrlCInterrupt         = 23H;
    CtrlBreakInterrupt     = 1BH;


TYPE
    Letters    = [ORD("C")..ORD("Z")]; (* Ignore floppies *)

    ADriveInfo = ARRAY [0..79] OF CHAR;

VAR
    OldVector24,
    OldVector23,
    OldVector1B      : ADDRESS;

    Rug              : ARug;

    DriveTable       : ARRAY Letters OF ADriveInfo;
    Done             : BOOLEAN;
    Quickly          : BOOLEAN;
    CurrentDriveChar : CHAR;





        (* 20-Mar-91 RSC Added this as the list of things to do
                         just before exiting to set up the screen.
                         This must come just before the actual exit.
                         Do this always!
        *)
PROCEDURE LastThingBeforeExit(  IsCommandCom : BOOLEAN ) : BOOLEAN;
VAR
    Y           : CARDINAL;
    s           : ARRAY [0..255] OF CHAR;
    OkToExit    : BOOLEAN;
BEGIN
        (* Ask any swappers to swap memory.
        *)
    OkToExit := ExitingToDOSNotification( TRUE );

    IF (OkToExit) THEN
            (* Now, reset video to standard mode, clear the screen, and
               draw the exiting message.
            *)
        PrepareVideoForExit();  (* 13-Jun-89 WKH *)
             (* Clear the screen *)
        Fill(s," ",maxcol+1);
        FOR Y := 0 TO maxrow DO
            PutStringWithAttribute (s,0,Y,BITSET(0007H));
        END;

            (* Put a message with instructions on how to get back to TL. *)
        IF (IsCommandCom) THEN
            GetMessage(ModuleNumber+7,s); (* 20-Mar-91 RSC  *)
        ELSE
            GetMessage(ModuleNumber+24,s); (* 20-Mar-91 RSC  *)   (* One moment . . . *)
        END;
        PourText(s,videonormal,0,0,maxcol,6,Y);
        
            (* Put a "wait" message where it will be overwritten by DOS. *)
        IF (IsCommandCom) THEN
            GetMessage(ModuleNumber+24,s);
            PutStringWithAttribute(s,0,Y+3,BITSET(0007H));
        END;

            (* Move the DOS cursor so it will avoid our main message
               but overwrite the wait message. *)
        GotoXY(0,Y+1);

        SetCursorType(UnderlineCursor);
    END;

    RETURN OkToExit;

END LastThingBeforeExit;


        (* 20-Mar-91 RSC Added this as the first thing to execute
                         when we first come back.  Do this always!
        *)
PROCEDURE FirstThingAfterWeComeBack();
VAR
    ok  : BOOLEAN;
BEGIN
        (* First, put the video card back in order, THEN
           swap memory.
        *)
    PrepareVideoForReturn;

    ok := ExitingToDOSNotification( FALSE ); (* Even if we didn't exit! *)

END FirstThingAfterWeComeBack;




PROCEDURE LocateFile(  VAR Specification : ARRAY OF CHAR;
                       VAR PathAndFileName, Parms : ARRAY OF CHAR;
                       VAR IsModula : BOOLEAN ) : BOOLEAN;
VAR
    i                 : CARDINAL;

    Line              : ARRAY [0..255] OF CHAR;
    FileSpec          : ARRAY [0..255] OF CHAR;
    DeviceName        : ARRAY [0..MaximumDeviceNameLength] OF CHAR;
    PathName          : ARRAY [0..MaximumDeviceNameLength+MaximumPathNameLength  ] OF CHAR;
    FileName          : ARRAY [0..MaximumFileNameLength
                            + 1 + MaximumExtensionLength ] OF CHAR;
    Extension         : ARRAY [0..MaximumExtensionLength ] OF CHAR;

    S                 : ARRAY [0..21] OF CHAR;
BEGIN
    i := 1;
    ParseBal( Specification,i,FileSpec);               (* File Name *)
    ParseBal(Specification,i,Parms);                   (* Parameters *)
    TrimRear(FileSpec);
    TrimRear(Parms);            (* KKC May 12, 89. Remove trailing blanks *)
    Fill(S,15C,1);              (* KKC Add a CR to end. *)
    ConcatLS(Parms,S);                         (* Some programs may need it. *)
    SetLengthOf(Parms, LengthOf(Parms)-1);     (* CR doesn't count as part of command *) (* 4-Jan-90 KKC  *)

        (* If the FileSpec doesn't contain a device or directory,
           search for one using the OverlayPath. *)

    ExtractFileNameParts( FileSpec, DeviceName, PathName, FileName, Extension);

        (* Is this a Modula-2 overlay? *)

    SetString(S,"OVL");
    IsModula := StringsEqual(Extension,S);

    IF (IsModula) THEN
        Copy(FileName,PathAndFileName);    (* Return only the file name. *)
        RETURN TRUE;
    END;
    IF ( SearchForExecutableFile(FileSpec, PathAndFileName) ) THEN
        IF ( ValidExecutableFile(PathAndFileName, PathAndFileName, Parms ) ) THEN
            RETURN TRUE;
        ELSE
            GetMessage( ModuleNumber + 22, Line );  (* Can not execute program ~ *)
            ConcatLS( Line, PathAndFileName );
            Error(Line);
            RETURN FALSE;
        END;
    END;
    GetMessage( ModuleNumber + 17, Line );  (* Cannot find file ~ *)
    ConcatLS( Line, FileSpec );
    Error(Line);
    RETURN FALSE;
END LocateFile;

PROCEDURE ValidExecutableFile(
                                          ProgNameIn : ARRAY OF CHAR;
                              VAR ProgNameRet, Parms : ARRAY OF CHAR
                             ):BOOLEAN;
VAR
    DeviceName        : ARRAY [0..MaximumDeviceNameLength] OF CHAR;
    PathName          : ARRAY [0..MaximumDeviceNameLength+MaximumPathNameLength  ] OF CHAR;
    FileName          : ARRAY [0..MaximumFileNameLength
                            + 1 + MaximumExtensionLength ] OF CHAR;
    Extension         : ARRAY [0..MaximumExtensionLength ] OF CHAR;
    ValidExtension    : ARRAY [0..MaximumExtensionLength ] OF CHAR;
    TmpParms          : ARRAY [0..81] OF CHAR;
    TmpString         : ARRAY [0..10] OF CHAR;
BEGIN
    ParseFileName( ProgNameIn, DeviceName, PathName, FileName, Extension);
    GetMessage ( ModuleNumber + 14 , ValidExtension ); (* COM *)
    IF StringsEqual(Extension, ValidExtension) THEN
        RETURN TRUE;
    END;
    GetMessage ( ModuleNumber + 15 , ValidExtension ); (* EXE *)
    IF StringsEqual(Extension, ValidExtension) THEN
        RETURN TRUE;
    END;
    GetMessage ( ModuleNumber + 16 , ValidExtension ); (* BAT *)
    IF StringsEqual(Extension, ValidExtension) THEN
        Copy(Parms, TmpParms );
        SetString ( Parms, "/c " );
        ConcatLS(Parms, ProgNameIn);
        Fill(TmpString, ' ', 1);
        ConcatLS(Parms, TmpString);
        ConcatLS(Parms, TmpParms);
        GetEnvironmentString( "ComSpec", ProgNameRet );
        RETURN TRUE;
    END;
    RETURN FALSE;
END ValidExecutableFile;

PROCEDURE GetEnvironmentString(
                                            SearchID : ARRAY OF CHAR;
                               VAR EnvironmentString : ARRAY OF CHAR
                              );
TYPE
    PspStruct       =     RECORD
        INT20               :   CARDINAL;
        TOPMEMORY           :   CARDINAL;
        PSPRESERVED1        :   CHAR;
        INT21INST           :   CHAR;
        AVAILMEMORY         :   CARDINAL;
        PSPRESERVED2        :   CARDINAL;
        PSPTERMADDR         :   ADDRESS;
        CTRLBREAKADDR       :   ADDRESS;
        CRITERICALERROR     :   ADDRESS;
        PSPRESERVED201      :   CHAR;
        PSPRESERVED202      :   CHAR;
        PSPRESERVED203      :   CHAR;
        PSPRESERVED204      :   CHAR;
        PSPRESERVED205      :   CHAR;
        PSPRESERVED206      :   CHAR;
        PSPRESERVED207      :   CHAR;
        PSPRESERVED208      :   CHAR;
        PSPRESERVED209      :   CHAR;
        PSPRESERVED210      :   CHAR;
        PSPRESERVED211      :   CHAR;
        PSPRESERVED212      :   CHAR;
        PSPRESERVED213      :   CHAR;
        PSPRESERVED214      :   CHAR;
        PSPRESERVED215      :   CHAR;
        PSPRESERVED216      :   CHAR;
        PSPRESERVED217      :   CHAR;
        PSPRESERVED218      :   CHAR;
        PSPRESERVED219      :   CHAR;
        PSPRESERVED220      :   CHAR;
        PSPRESERVED221      :   CHAR;
        PSPRESERVED222      :   CHAR;
        PSPENVIROMENT       :   CARDINAL;
    END;
VAR
    PspPointer      :   POINTER TO PspStruct;
    ZString         :   RECORD
                            CASE BOOLEAN OF
                              | FALSE: Addr: ADDRESS;
                              | TRUE : CharPtr: POINTER TO CHAR;
                            END;
                        END;
    SearchLen, i    :   CARDINAL;
    EnvironmentPtr  :   ADDRESS;
    found           :   BOOLEAN;
    TmpString       :   ARRAY[0..255] OF CHAR;
BEGIN
    PspPointer := OurPSPAddress;
    EnvironmentPtr.SEGMENT := PspPointer^.PSPENVIROMENT;
    EnvironmentPtr.OFFSET := 0;
    SearchLen := 0;
    WHILE ( (SearchLen <= HIGH(SearchID)) AND (SearchID[SearchLen] <> 0C) ) DO
        TmpString[SearchLen] :=  CAP( SearchID[SearchLen] );
        INC ( SearchLen );
    END;

    ZString.Addr := EnvironmentPtr;
    found := FALSE;
    WHILE ( ( NOT found ) AND (ZString.CharPtr^ <> 0C) ) DO
        i := 0;
        WHILE ( i < SearchLen ) AND (CAP(ZString.CharPtr^) = TmpString[i]) DO
            INC(i);
            INC(ZString.Addr);
        END;

        IF ( i = SearchLen ) THEN
            found := TRUE;
            WHILE ZString.CharPtr^ <> '=' DO (* skip to = *)
                INC(ZString.Addr);
            END;
            INC(ZString.Addr); (* skip = *)
            WHILE ZString.CharPtr^ = ' ' DO (* skip leading spaces *)
                INC(ZString.Addr);
            END;
        ELSE
            WHILE ZString.CharPtr^ <> 0C DO (* skip this set definition *)
                INC(ZString.Addr);
            END;
            INC(ZString.Addr);
        END;
    END;

    IF ( found ) THEN
        i := 0;
        WHILE ZString.CharPtr^ <> 0C DO (* copy path *)
            TmpString[i] := ZString.CharPtr^;
            INC(ZString.Addr);
            INC(i);
        END;
        TmpString[i] := 0C;
        TStringToLString ( TmpString, EnvironmentString );
    ELSE
        SetLengthOf( EnvironmentString, 0 );
    END;
END GetEnvironmentString;

PROCEDURE   SearchForExecutableFile(
                                VAR PrognameIn, ProgNameRet : ARRAY OF CHAR
                                   ):BOOLEAN;
VAR
    i                 : CARDINAL;
    FileLength        : CARDINAL;

    DeviceName        : ARRAY [0..MaximumDeviceNameLength] OF CHAR;
    PathName          : ARRAY [0..MaximumDeviceNameLength+MaximumPathNameLength  ] OF CHAR;
    Directory         : ARRAY [0..MaximumDeviceNameLength+MaximumPathNameLength  ] OF CHAR;
    DirectoryIn       : ARRAY [0..MaximumDeviceNameLength+MaximumPathNameLength  ] OF CHAR;
    FileName          : ARRAY [0..MaximumFileNameLength
                            + 1 + MaximumExtensionLength ] OF CHAR;
    FileNameIn        : ARRAY [0..MaximumFileNameLength
                            + 1 + MaximumExtensionLength ] OF CHAR;
    Extension         : ARRAY [0..MaximumExtensionLength ] OF CHAR;

    PathString        : ARRAY[0..255] OF CHAR;
    S                 : ARRAY [0..21] OF CHAR;
BEGIN
    ParseFileName( PrognameIn, DeviceName, PathName, FileName, Extension);
    Copy(DeviceName, Directory);
    ConcatLS(Directory, PathName);
    ConcatS(FileName,".");
    FileLength := LengthOf(FileName);
    IF ( LengthOf( Extension ) <> 0 ) THEN
        ConcatLS(FileName, Extension);
        IF (PathLookupStart(Directory,FileName,DirectoryIn,FileNameIn)) THEN
            Copy(DirectoryIn, ProgNameRet);
            ConcatLS(ProgNameRet, FileNameIn);
            RETURN TRUE;
        END;
    ELSE
        FOR i := 0 TO 2 DO
            SetLengthOf ( FileName, FileLength );
            ConcatMessage( FileName, ModuleNumber + 14 + i ); (* com *) (* exe *) (* bat *)
            IF (PathLookupStart(Directory,FileName,DirectoryIn,
                                                        FileNameIn)) THEN
                Copy(DirectoryIn, ProgNameRet);
                ConcatLS(ProgNameRet, FileNameIn);
                RETURN TRUE;
            END;
        END;
    END;

(* IF user had specified a path then we return false at this point *)
    IF ( ( LengthOf(DeviceName) + LengthOf(PathName) ) > 0 ) THEN
        RETURN FALSE;
    END;

    GetEnvironmentString( "Path", PathString );
    ConcatS(PathString, ";");               (* KKC Aug 30, 89 *)
    ConcatLS(PathString, OverlayPath);      (* KKC Aug 8, 89 *)

    (* 29-Nov-89 RSC Added this, mainly for COMMAND.COM, but I
                     guess anyone could benefit.
    *)

    GetEnvironmentString( "ComSpec", PathName );

    i := LengthOf( PathName );
    WHILE (i > 0) AND (PathName[i] <> "\") AND (PathName[i] <> ":") DO
        DEC(i);
    END;

    IF (i > 0) THEN
        SetLengthOf(PathName, i);
        ConcatS(PathString, ";");
        ConcatLS(PathString, PathName);
    END;
    (* 29-Nov-89 RSC end of change. *)

    SetLengthOf ( FileName, FileLength );

    IF ( LengthOf( Extension ) <> 0 ) THEN
        ConcatLS(FileName, Extension);
        IF (PathLookupStart(PathString,FileName,DirectoryIn,FileNameIn)) THEN
            Copy(DirectoryIn, ProgNameRet);
            ConcatLS(ProgNameRet, FileNameIn);
            RETURN TRUE;
        END;
    ELSE
        FOR i := 0 TO 2 DO
            SetLengthOf ( FileName, FileLength );
            ConcatMessage( FileName, ModuleNumber + 14 + i ); (* com *) (* exe *) (* bat *)
            IF (PathLookupStart(PathString,FileName,DirectoryIn,
                                                             FileNameIn)) THEN
                Copy(DirectoryIn, ProgNameRet);
                ConcatLS(ProgNameRet, FileNameIn);
                RETURN TRUE;
            END;
        END;
    END;
    RETURN FALSE;
END SearchForExecutableFile;





PROCEDURE DoDosShell() : BOOLEAN;
VAR
    Done        : BOOLEAN;
    ShellName   : ARRAY [0..99] OF CHAR;
BEGIN
    GetEnvironmentString( "ComSpec", ShellName );
    LStringToTString ( ShellName, ShellName );
    IF (ShellName[0] = 0C) THEN
        RETURN FALSE;
    END;

    SendNotices(ExitToDOS,BeforeActing,NIL);   (* Warn people to take cover. *)

    IF (LastThingBeforeExit( TRUE )) THEN
        DosShell( ShellName, Done );
    END;
    FirstThingAfterWeComeBack(); (* Even if we didn't exit! *)

    IF ( Done ) THEN
        SendNotices(ExitToDOS,AfterActing,NIL);
    ELSE
        SendNotices(ExitToDOS,FailureToAct,NIL);
    END;
    RETURN Done;
END DoDosShell;





PROCEDURE DoKKCDosShell(
                          VAR OverlayFile : ARRAY OF CHAR; 
                         VAR  TempFileDir : ARRAY OF CHAR
                       ) : BOOLEAN;
VAR

        (* ******************************************************

                W A R N I N G:  D A N G E R

            YOU MUST ABSOLUTELY, POSITIVELY, NEVER ALTER THE ORDER
            OR NUMBER OR SIZE OF THESE ITEMS ON THIS STACK.  DOING
            SO CAN RENDER EXIT-TO-DOS INOPERABLE (SYMPTOM: YOU CAN
            EXIT TO DOS BUT YOU CAN NEVER COME BACK BECAUSE THE
            STACK IS HOPLESSLY TRASHED)

            NEAR AS I CAN FIGURE, THE ASSEMBLER CODE DEPENDS ON THE
            EVEN-OR-ODDNESS OF SwapStatus AND Done.
            RSC 20-Mar-91.

        ******************************************************** *)
    Done            :   BOOLEAN;
    SwapStatus      :   CARDINAL;
    S2              :   ARRAY[0..255] OF CHAR;
    WaitMsg         :   ARRAY[0..255] OF CHAR;
    WaitBoxHandle   :   ABoxHandle;

        (* ******************************************************

                W A R N I N G:  D A N G E R

        ******************************************************** *)
BEGIN
    GetMessage( ModuleNumber + 26, WaitMsg ); (* Please wait... *)
    WaitBoxHandle := ProgressBox(WaitMsg);
    SendNotices(ExitToDOS,BeforeActing,NIL);   (* Warn people to take cover. *)

    IF (LastThingBeforeExit( TRUE )) THEN
        KKCDosShell( OverlayFile, TempFileDir, Done, SwapStatus);
    END;
    FirstThingAfterWeComeBack(); (* Even if we didn't exit! *)

    IF ( SwapStatus <> 0 ) THEN
        IF ( SwapStatus = 14 ) THEN
            GetMessage( ModuleNumber + 10, S2 ); (* Not enough disk space for swap file *)
        ELSE
            GetMessage( ModuleNumber + 11, S2 ); (* Disk Error *)
        END;
        Error(S2);
    END;
    IF ( Done AND ( SwapStatus = 0 ) ) THEN
        SendNotices(ExitToDOS,AfterActing,NIL);
    ELSE
        SendNotices(ExitToDOS,FailureToAct,NIL);
    END;
    ReleaseBox( WaitBoxHandle );
    RETURN Done;
END DoKKCDosShell;


PROCEDURE DoKKCExecute(
                        VAR PathAndFileName : ARRAY OF CHAR;
                            VAR CommandLine : ARRAY OF CHAR;
                            VAR OverlayFile : ARRAY OF CHAR; 
                           VAR  TempFileDir : ARRAY OF CHAR
                       ) : BOOLEAN;
VAR

        (* ******************************************************

                W A R N I N G:  D A N G E R

            YOU MUST ABSOLUTELY, POSITIVELY, NEVER ALTER THE ORDER
            OR NUMBER OR SIZE OF THESE ITEMS ON THIS STACK.  DOING
            SO CAN RENDER EXIT-TO-DOS INOPERABLE (SYMPTOM: YOU CAN
            EXIT TO DOS BUT YOU CAN NEVER COME BACK BECAUSE THE
            STACK IS HOPLESSLY TRASHED)

            NEAR AS I CAN FIGURE, THE ASSEMBLER CODE DEPENDS ON THE
            EVEN-OR-ODDNESS OF SwapStatus, FileName, and ErrorCode.
            RSC 20-Mar-91.

        ******************************************************** *)
    ErrorCode       :   CARDINAL;
    Done            :   BOOLEAN;
    SwapStatus      :   CARDINAL;
    FileName        :   ARRAY[0..255] OF CHAR;
    S2              :   ARRAY[0..255] OF CHAR;
    WaitMsg         :   ARRAY[0..255] OF CHAR;
    WaitBoxHandle   :   ABoxHandle;

        (* ******************************************************

                W A R N I N G:  D A N G E R

        ******************************************************** *)
BEGIN
    GetMessage( ModuleNumber + 26, WaitMsg ); (* Please wait... *)
    SendNotices(LowMemory,AfterActing,ADDRESS(EnoughFree));   (* Free lots of memory. *)
    LStringToTString(PathAndFileName,FileName);
    WaitBoxHandle := ProgressBox(WaitMsg);
    SendNotices(ExitToDOS,BeforeActing,NIL);   (* Warn people to take cover. *)

    IF (LastThingBeforeExit( FALSE )) THEN
        KKCExecute( ADR(FileName), 0, ADR(CommandLine), NIL, NIL, 
                    OverlayFile, TempFileDir, ErrorCode, SwapStatus );
    END;
    FirstThingAfterWeComeBack(); (* Even if we didn't exit! *)

    IF ( SwapStatus <> 0 ) THEN
        IF ( SwapStatus = 14 ) THEN
            GetMessage ( ModuleNumber + 10, S2 ); (* Not enough disk space for swap file *)
        ELSE
            GetMessage( ModuleNumber + 11, S2 ); (* Disk Error *)
        END;
        Error(S2);
    END;

    IF (ErrorCode <> 0) THEN
        GetMessage( ModuleNumber + 27, FileName );
        (* "Error code " *)
        CtoS(ErrorCode,S2);
        ConcatLS(FileName,S2);
        ConcatMessage ( FileName, ModuleNumber + 28 );
        (* " with file " *)
        ConcatLS(FileName,PathAndFileName);
        Error(FileName);
    END;
    IF ( Done AND ( SwapStatus = 0 ) AND ( ErrorCode = 0 ) ) THEN
        SendNotices(ExitToDOS,AfterActing,NIL);
    ELSE
        SendNotices(ExitToDOS,FailureToAct,NIL);
    END;
    ReleaseBox( WaitBoxHandle );
    RETURN Done;
END DoKKCExecute;

   (* RunDosProgram -- If the overlay context string is null, run
                       the command interpreter.  Otherwise, it should
                       contain a filename (with extension) plus,
                       optionally, parameters in parenthesis.  Run
                       that program.
       *)



PROCEDURE PrepareForSwap(VAR SwapmemFileName : ARRAY OF CHAR;
                         VAR Directory   : ARRAY OF CHAR):BOOLEAN;
VAR
    FileName, FileNameIn    :   ARRAY[0..21] OF CHAR;
    S                       :   ARRAY [0..81] OF CHAR;
    Dir                     :   ARRAY [0..81] OF CHAR;
    Found                   :   BOOLEAN;
BEGIN

    GetMessage( ModuleNumber + 25, S); (* MEMSWAP *) (* KKC Aug 2, 89 *)
    GetOption( S, Found, Dir );
    IF ( NOT Found ) THEN
        SetLengthOf( Dir, 0 );
    ELSE
        SetLengthOf( S, 0 );
        ExpandPath( Dir, S, S );
        IF ( GetPathEntry( S, 0, Dir ) ) THEN
            NormalizeFileName( Dir,
                          ASetOfFileNameParts{DevicePart,DirectoryPart} );
        ELSE
            SetLengthOf( Dir, 0 );
        END;
    END;
    InitSwapFileDelete(Dir);                    (* KKC Aug 2, 89 *)

    SetString( FileName, "TlSwpmem.ovl");

    IF (NOT PathLookupStart(OverlayPath, FileName, Directory, FileNameIn)) THEN
        GetMessage( ModuleNumber + 12, S ); (* Unable to find TLSWPMEM overlay *)
        Error(S);
        RETURN FALSE;
    END;

    Copy( Directory, SwapmemFileName);
    ConcatLS( SwapmemFileName, FileName );

    IF ( ( LengthOf(Dir) > 0 ) AND ( DirectoryIsReachable (Dir ) ) ) THEN (* KKC Aug 8, 89 *)
        Copy( Dir, Directory );
    ELSE
        SetString( Directory, "DK:");
        NormalizeFileName( Directory,
                          ASetOfFileNameParts{DevicePart,DirectoryPart} );
    END;

    RETURN TRUE;
END PrepareForSwap;



PROCEDURE RunDosProgram(VAR Specification : ARRAY OF CHAR;
                            Quick         : BOOLEAN ):BOOLEAN;
VAR
    i                       :   CARDINAL;
    S2                      :   ARRAY [0..255] OF CHAR;
    PathAndFileName         :   ARRAY [0..81] OF CHAR;
    Parms                   :   ARRAY [0..81] OF CHAR;
    Directory               :   ARRAY[0..81] OF CHAR;
    Done                    :   BOOLEAN;
    IsModula                :   BOOLEAN;
BEGIN
    Done := FALSE;

    IF (LengthOf(Specification)=0) THEN
        IF (Quick) THEN
            Done := DoDosShell();
        ELSE
            IF NOT PrepareForSwap(S2,Directory) THEN
                RETURN FALSE;
            END;
            Done := DoKKCDosShell( S2, Directory );
        END;

        IF (NOT Done) THEN
            GetMessage( ModuleNumber + 6, S2 ); (* "For some reason, Command.Com could not start." *)  (* 20-Jul-88 LAA *)
            Error(S2);
            RETURN FALSE;
        END;
    ELSIF LocateFile(Specification,PathAndFileName,Parms,IsModula) THEN
        IF (IsModula) THEN
            Done := CallOverlayWithContext(PathAndFileName, ADR(Parms));
            RETURN Done;
        ELSE
            IF NOT PrepareForSwap(S2,Directory) THEN
                RETURN FALSE;
            END;
            Done := DoKKCExecute
                    (   
                        PathAndFileName,
                        Parms, 
                        S2, 
                        Directory 
                    );
        END;
    ELSE
        RETURN FALSE;
    END;

    RETURN TRUE;
END RunDosProgram;



    (* Get all directories into a local table. *)

PROCEDURE GetDriveTable();
VAR
    Drive       : Letters;
    TStringDir  : ADriveInfo;
BEGIN
    CurrentDrive( CurrentDriveChar );
    FOR Drive := ORD("C") TO ORD("Z") DO
        CurrentDirectory( CHR( Drive ), TStringDir );
        TStringToLString( TStringDir, DriveTable[ Drive ] );
    END;
END GetDriveTable;



    (* Put back all drives that can be found. *)

PROCEDURE PutDriveTable( Done : BOOLEAN );
VAR
    Drive                 : Letters;
    LStringDir,
    TStringDir            : ADriveInfo;
    s                     : ARRAY [0..255] OF CHAR;
    CDrive                : CHAR;
    LocalCurrentDriveChar : CHAR;
BEGIN
    CurrentDrive( LocalCurrentDriveChar );
    IF (LocalCurrentDriveChar <> CurrentDriveChar) THEN
        SetString( s, LocalCurrentDriveChar );
        ConcatS(   s, ":  -->  " );
        ConcatS(   s, CurrentDriveChar );
        ConcatS(   s, ":" );
        Message(   s );
        SelectDrive( CurrentDriveChar, Done );
        IF (NOT Done) THEN
            ConcatMessage( s, ModuleNumber + 5 ); (* ", Can't restore current drive." *)
            Error( s );
        END;
    END;
    FOR Drive := ORD("C") TO ORD("Z") DO
        CDrive := CHR( Drive );
        CurrentDirectory( CDrive, TStringDir );
        TStringToLString( TStringDir, LStringDir );

        IF (NOT StringsEqual( LStringDir, DriveTable[ Drive ])) THEN (* CHANGED! *)
            SetString( s, CDrive );                                  (* RSC 1/2/88 *)
            ConcatS(   s, ":\"   );
            ConcatLS(  s, LStringDir );
            IF (LStringDir[0] > 0C) THEN
                ConcatS(   s, "\" );
            END;
            ConcatS(   s, " --> " );
            ConcatS(   s, CDrive );
            ConcatS(   s, ":\" );
            ConcatLS(  s, DriveTable[ Drive ] );
            IF (DriveTable[ Drive, 0 ] > 0C) THEN
                ConcatS(   s, "\" );
            END;
            Message(   s );

            SetString( LStringDir, CDrive );
            ConcatS(   LStringDir, ":\"   );
            ConcatLS(  LStringDir, DriveTable[ Drive ] );
            IF (DirectoryIsReachable( LStringDir )) THEN
                LStringToTString( LStringDir, TStringDir );
                ChangeDirectory(  TStringDir, Done );
            ELSE
                Done := FALSE;
            END;
            IF (NOT Done) THEN
                ConcatMessage( s, ModuleNumber + 4 ); (* ", Can't restore current directory." *)
                Error( s );
            END;
        END;
    END;
    s[0] := 0C;
    Message(s);  (* Erase command line *)
END PutDriveTable;



    (*  For use by SwapF via notices call.... *)

PROCEDURE EnoughFree() : BOOLEAN;

BEGIN                       (* EnoughFree *)
    RETURN FALSE;  (* We can NEVER get enough memory! *)
END EnoughFree;






PROCEDURE GetSpecification( VAR Specification : ARRAY OF CHAR ) : BOOLEAN;
    (* Must match the one in TLDOSFrm! *)
TYPE
    ASpecification = ARRAY [0..255] OF CHAR;
    AContextRecord =
        RECORD
            Tag  : CARDINAL;
            Spec : POINTER TO ASpecification;
            OK            : BOOLEAN;
        END;
VAR
    ContextRecord : AContextRecord;
    OverlayName   : ARRAY [0..39] OF CHAR;
BEGIN
    ContextRecord.Spec := ADR(Specification);
    ContextRecord.OK   := FALSE;
    ContextRecord.Tag  := 9209;                         (* Secret handshake. *)

        (* Call an overlay to run the actual form. *)

        (* 29-Nov-89 RSC Use TLFBASE. *)
    SetString(OverlayName,"TLFBASE(TLDOSFRM)");
    IF CallOverlayWithContext(OverlayName,ADR(ContextRecord)) THEN
        RETURN ContextRecord.OK;
    ELSE
        RETURN FALSE;
    END;

END GetSpecification;





  (* Tell them that either:

                We are about to enter DOS land, or
                There is not enough memory to continue.
  *)
PROCEDURE DoMessage( VAR Specification : ARRAY OF CHAR;
                     VAR Quickly       : BOOLEAN ) : BOOLEAN;
VAR
    LastY   : ascreeny;
    s       : ARRAY [0..255] OF CHAR;
    Title   : ARRAY [0..39] OF CHAR;
    Prefix  : ARRAY [0..0] OF CHAR;
    Choices : ARRAY [0..81] OF CHAR;
    Choice  : CARDINAL;
    WarnOfCommandComExit  : BOOLEAN;

BEGIN
    Quickly := FALSE;

    WarnOfCommandComExit := LengthOf(Specification) = 0;

    IF (HeapAvailable()) THEN
        IF WarnOfCommandComExit THEN
            GetMessage( ModuleNumber + 0, s     ); (* "You are about to enter DOS.  Type 'EXIT' to leave DOS." *)
            GetMessage( ModuleNumber + 1, Title ); (* "Going into Dos" *)
            Fill(Prefix," ",0);
            GetMessage(ModuleNumber + 9, Choices);
            Choice := 1;
            IF NOT MultipleChoiceBox( s, Title, NoHelp, Prefix, Choices, Choice ) THEN
                RETURN FALSE;
            ELSE
                CASE Choice OF
                    2 : RETURN FALSE;

                  | 3 :
                        IF NOT GetSpecification(Specification) THEN
                            RETURN FALSE;
                        END;
                        WarnOfCommandComExit := FALSE;   (* Give only the brief exit message. *)

                  | 4 : Quickly := TRUE;
                  ELSE
                END;
            END;
        END;
        RETURN TRUE;
     ELSE
        GetMessage( ModuleNumber + 2, s     ); (* "Not enough memory to enter DOS" *)
        GetMessage( ModuleNumber + 3, Title ); (* "No Dice" *)
        WarningBox( s, Title, NoHelp );
    END;
    RETURN FALSE;
END DoMessage;




    (* Allow an Exec'd program to monitor the CTRL-C interrupt.
       We need to interlock against nested calls to us, since the
       BreakHandler may be the same for Ctrl-Break and Ctrl-C.
    *)

    (* ----- Oh, well . . .
       Seems like due to DOS reentrancy problems we cannot signal a
       Ctrl-C without locking up some computers.  So, we will merely
       eat the Ctrl-C so that TL doesn't try to count it as an
       unresponsive program.
    *)

(*VAR*)
(*    InterruptInterlock : BOOLEAN;*)



(*PROCEDURE LocalBreakInterrupt();*)
(*BEGIN*)
(*    IF (NOT InterruptInterlock) THEN*)
(*        InterruptInterlock := TRUE;*)
(*        ENABLE;*)
(*        Keyboard.ClearBreak();              (* We got it.  Stop counting. *)*)
(*      (*  SWI(23H);  *)                         (* CTRL-C *)*)
(*        InterruptInterlock := FALSE;*)
(*    END;*)
(*END LocalBreakInterrupt;*)



PROCEDURE Complain(N:CARDINAL);
VAR
    S           : ARRAY [0..255] OF CHAR;
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    GetMessage(N,S);
    Error(S);
END Complain;



PROCEDURE DoTLDos();
VAR
    SPTR             : POINTER TO ARRAY [0..255] OF CHAR;  (* Context parameters. *)
    Specification    : ARRAY [0..255] OF CHAR;
BEGIN
(*    InterruptInterlock := FALSE;*)

    SPTR := OverlayContext();

       (* Swipe the break handler.  RSC 2-Mar-89. *)

(*    InstallNewProcedure( ADR(Keyboard.BreakHandler),PROC(LocalBreakInterrupt), NIL);*)

    IF GetRug(0,0,maxcol,maxrow,Rug)  THEN

            (* Set up for going into DOS.  Only give the message if
               the context string indicates the Command interpreter. *)

        Copy(SPTR^,Specification);

        IF (DoMessage(Specification,Quickly))  THEN

                (* Substitute keywords. *)
            MakeSubstitutions(Specification,HIGH(Specification),GetKeyWordValue,NIL);


            SendNotices(LowMemory,AfterActing,ADDRESS(EnoughFree));   (* Free lots of memory. *)
            GetDriveTable();  (* Save the state of the directories. *)


            (* Save the interrupts that we stole elsewhere in Time Line.

                   Control-C and Control-Break are stolen in Keyboard.Mod
                   CriticalError is stolen in FileAux.
            *)
            SaveInterruptVector(CtrlCInterrupt,         OldVector23 );
            SaveInterruptVector(CtrlBreakInterrupt,     OldVector1B );
            SaveInterruptVector(CriticalErrorInterrupt, OldVector24 );

            IF (Permission(ExitToDOS,NIL)) THEN
                Done := RunDosProgram(Specification,Quickly);
            ELSE
                Done := FALSE;
                Complain(ModuleNumber+23);
            END;

            RestoreInterruptVector(CriticalErrorInterrupt, OldVector24 );
            RestoreInterruptVector(CtrlBreakInterrupt,     OldVector1B );
            RestoreInterruptVector(CtrlCInterrupt,         OldVector23 );

            Keyboard.ClearBreak();  (* 21-Feb-91 RSC  *)

            PutDriveTable(Done);  (* Return the directories to the way they were. *)
        END;
        ResetVideo;  (* 5/29/89 WKH *)
        PutRug(0,0,maxcol,maxrow,Rug);
    END;


END DoTLDos;





BEGIN
    DoTLDos();
END TLDOS.
