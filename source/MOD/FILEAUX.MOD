    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE FileAux;

(*$S+*)

    (* MODIFICATION HISTORY:

       25 Jul 86  AJL - Modula File System errors were being indexed
                        based on the CriticalError value!.
                      - Add routine DosFlush, which is called on
                        FlushBuffers and also on termination.

       24-Sep-87 LAA    Changed for Logitech Version 3.  Look for V3 comment.
       16-Dec-87 LAA    Commented out TryToOpen, as it's no longer used.
       13-Feb-88 AJL    Added DisplayFileError;
       14-Feb-88 AJL  - Removed extraneous variables from DisplayFileError.
                      - Close file in DisplayFileError.
                      - Change TLDATA in search path to TL3DATA. 
       22-Feb-88 LAA  - Force stack checking on for this module.
        1-Mar-88 AJL  - Check for EOF in DisplayFileError, since often
                        on an error the Logitech file system removes wr
                        from the flag set but turns EOF on. 
       18-Nov-88 LAA    Expanded string s2 in ErrorDescription so we don't get
                        a "Too Long" message.
        2-Feb-89 RSC    Changed the call to ParseBal to reflect new parameters.
       15-Mar-89 EGK    Changed initialization of OverlayPath to use
                        "TL4" instead of "TL3".
        7-Jun-89 RSC    Added init of the new paths.
        5-Aug-89 WKH    Initial edits for OS/2.  DosFlush removed, mapped to
                        corresponding OS/2 call(DosBufReset).  Also scrapped
                        use of CriticalErrorHandler.
       18-Jun-91 RSC    Removed import of "DOS3" to get it out of the root.
                        it is a standard library module with lots of stuff
                        we never use.
    *)



(*<DOS*)
IMPORT Devices;
(*DOS>*)

FROM Dialog      IMPORT FatalError, Error, WarningBox, ADialogOption;

FROM FileOpen    IMPORT RequestFileOpen;

FROM FileSystem  IMPORT File, Response, ReadByte, WriteByte, ReadWord,
                        WriteWord, WriteNBytes, ReadNBytes, Command,
                        Doio, Flag, Lookup, Close;

FROM GaGa        IMPORT GetGaGaMessage;

FROM LStrings    IMPORT ConcatLS, CtoS, Fill, SetString, ConcatS, 
                        LStringToTString, TStringToLString, Remove,
                        Copy;

FROM MsgFile     IMPORT GetMessage, ConcatMessage, DisplayMessage;

IMPORT SYSTEM;

FROM SYSTEM      IMPORT ADDRESS, ADR, BYTE, DOSCALL, DI, SETREG, GETREG,
                        CODE, AX, BX, SWI;

FROM Words   IMPORT       ParseBal;    



CONST
    ModuleNumber            = 1800;    (* For GetMessage *)
    ModuleNumber2           = 19400;   (* for extended error messages *)

CONST
    DiskReset = 0DH;    (* MS-DOS Disk Reset function number. *)


PROCEDURE DosFlush;

(*<OS2
VAR  
    err                     : CARDINAL;
OS2>*)

BEGIN
(* WARNING - Under OS/2, we cannot make doscalls. If we are using
	     the Logitech file API, then we have to come up with another method
	     for flushing. The alternative is to recode all file operations
	     to use the OS/2 file API, and that is a lot of work!
*)

(*<DOS*)
    DOSCALL(DiskReset);   (* Force DOS flush buffers. *)
(*DOS>*)

(*<OS2
    err := DosBufReset(0FFFFH);  (* Force OS/2 flush buffers. *)
OS2>*)
END DosFlush;





PROCEDURE PrepareForIO(VAR f:File);
BEGIN
    CriticalErrorFlag := FALSE;
    f.res := done;
END PrepareForIO;



PROCEDURE CheckIO(VAR f:File):Response;
BEGIN
   IF (CriticalErrorFlag) THEN
       f.res := userdeverror;
   END;
   RETURN f.res;
END CheckIO;


PROCEDURE InitializeFiles():BOOLEAN;
BEGIN
    StartCriticalErrorMonitor;
    CriticalErrorFlag := FALSE;
    RETURN TRUE;
END InitializeFiles;


PROCEDURE TerminateFiles;
BEGIN
    DosFlush;
    StopCriticalErrorMonitor;
END TerminateFiles;










(*<DOS*)
MODULE CriticalErrorHandler;(********************************************)

    FROM SYSTEM IMPORT INBYTE, OUTBYTE, ADR, BYTE, ADDRESS,
		       ENABLE, DISABLE, GETREG, DI;                        (* V3 *)

    FROM Devices IMPORT SaveInterruptVector, RestoreInterruptVector;


    EXPORT StartCriticalErrorMonitor, CriticalErrorFlag, StopCriticalErrorMonitor,
           CriticalErrorDHCB, CriticalErrorCode, CriticalDriveId,
           CriticalWrite, CriticalArea;

    CONST
      CriticalErrorInterrupt = 24H;   (* vector used by DOS 2.0 *)

    VAR
      CriticalErrorFlag : BOOLEAN;
      CriticalErrorDHCB : ADDRESS;
      CriticalErrorCode : CARDINAL;
      CriticalDriveId   : CARDINAL;
      CriticalWrite     : CARDINAL;
      CriticalArea      : CARDINAL;
      ISR : ARRAY [0..30] OF BYTE; (* It will contain the code of the ISR *)
      oldVector0C : ADDRESS;



    PROCEDURE CriticalErrorProcedure;  (* Body of the Interrupt Service Routine *)
    VAR
        DIReg : CARDINAL;                                          (* V3 *)
    BEGIN
        GETREG(DI,DIReg);
        CriticalErrorCode := CARDINAL( BITSET(DIReg) * BITSET(00FFH) );
        CriticalErrorFlag := TRUE;
    END CriticalErrorProcedure;


    PROCEDURE StartCriticalErrorMonitor;
      VAR tempSet : BITSET; ch: CHAR; dummy: BOOLEAN;
	  ISRbody: PROC; p: POINTER TO ADDRESS;
    BEGIN
      DISABLE;
      ISR[ 0] := BYTE (50H);	(* push ax *)
      ISR[ 1] := BYTE (51H);	(* push cx *)
      ISR[ 2] := BYTE (52H);	(* push dx *)
      ISR[ 3] := BYTE (53H);	(* push bx *)
      ISR[ 4] := BYTE (56H);	(* push si *)
      ISR[ 5] := BYTE (57H);	(* push di *)
      ISR[ 6] := BYTE (1EH);	(* push ds *)
      ISR[ 7] := BYTE (06H);	(* push es *)
      ISR[ 8] := BYTE (9AH);	(* call far *)
      ISR[ 9] := BYTE (00H);	(* address will be fixed below *)
      ISR[10] := BYTE (00H);	(* that routine saves and restores bp *)
      ISR[11] := BYTE (00H);
      ISR[12] := BYTE (00H);
      ISR[13] := BYTE (07H);	(* pop es *)
      ISR[14] := BYTE (1FH);	(* pop ds *)
      ISR[15] := BYTE (5FH);	(* pop di *)
      ISR[16] := BYTE (5EH);	(* pop si *)
      ISR[17] := BYTE (5BH);	(* pop bx *)
      ISR[18] := BYTE (5AH);	(* pop dx *)
      ISR[19] := BYTE (59H);	(* pop cx *)
      ISR[20] := BYTE (58H);	(* pop ax *)
      ISR[21] := BYTE (0B0H);	(* mov al *)   (* Ignore the error! *)
      ISR[22] := BYTE (000H);	(*  00    *)
      ISR[23] := BYTE (0CFH);	(* iret *)

      ISRbody := CriticalErrorProcedure;
      p := ADR (ISR[9]);
      p^:= ADDRESS (ISRbody);

      SaveInterruptVector(CriticalErrorInterrupt, oldVector0C );
      RestoreInterruptVector(CriticalErrorInterrupt, ADR(ISR) );
      CriticalErrorFlag := FALSE;
      ENABLE;

    END StartCriticalErrorMonitor;

    PROCEDURE StopCriticalErrorMonitor;
    BEGIN
        DISABLE;
        RestoreInterruptVector(CriticalErrorInterrupt, oldVector0C );
        ENABLE;
    END StopCriticalErrorMonitor;


END CriticalErrorHandler;(*******************************************)
(*DOS>*)



(*<OS2
MODULE CriticalErrorHandler;

    FROM SYSTEM IMPORT INBYTE, OUTBYTE, ADR, BYTE, ADDRESS,
		       ENABLE, DISABLE, GETREG, DI;			   (* V3 *)

    EXPORT StartCriticalErrorMonitor, CriticalErrorFlag, StopCriticalErrorMonitor,
	   CriticalErrorDHCB, CriticalErrorCode, CriticalDriveId,
	   CriticalWrite, CriticalArea;

    VAR
      CriticalErrorFlag : BOOLEAN;
      CriticalErrorDHCB : ADDRESS;
      CriticalErrorCode : CARDINAL;
      CriticalDriveId	: CARDINAL;
      CriticalWrite	    : CARDINAL;
      CriticalArea	    : CARDINAL;

    PROCEDURE CriticalErrorProcedure;  (* Body of the Interrupt Service Routine *)
    BEGIN
    END CriticalErrorProcedure;


    PROCEDURE StartCriticalErrorMonitor;
    BEGIN
      CriticalErrorFlag := FALSE;
    END StartCriticalErrorMonitor;

    PROCEDURE StopCriticalErrorMonitor;
    BEGIN
    END StopCriticalErrorMonitor;

END CriticalErrorHandler;

OS2>*)









PROCEDURE ErrorDescription(VAR f             : File; 
                           VAR s             : ARRAY OF CHAR);

CONST
    DOS = 21H; (* DOS interrupt vector for function calls     *)
VAR
    ErrorCode               : CARDINAL;
    s2                      : ARRAY [0..255] OF CHAR;

BEGIN                       (* FileResultMeans *)
    Fill(s," ",0);

    IF (CriticalErrorFlag) THEN
            (* 19-Jun-91 RSC Remove DOS3 calls
            *)
        SETREG(BX, 0);
        SETREG(AX, 5900H);
        SWI(DOS);
        GETREG(AX, ErrorCode);
        GetMessage(ModuleNumber2 + ErrorCode, s2);
        IF (s2[0] = 0C) THEN
            GetGaGaMessage( ModuleNumber + 1, s ); (* "Unexplained DOS file error: " *)
            CtoS(ErrorCode,s2);
        END;
    ELSE
        GetMessage(ModuleNumber+30+ORD(f.res),s2);
        IF (s2[0] = 0C) THEN
            GetGaGaMessage( ModuleNumber + 2, s ); (* "(from M2 file system): " *)
            CtoS(ORD(f.res),s2);
        END;
    END;

    ConcatLS(s,s2);

END ErrorDescription;




PROCEDURE FileResultMeans(VAR f             : File; 
                          VAR s             : ARRAY OF CHAR);
VAR
    Len : CARDINAL;
    Title : ARRAY [0..60] OF CHAR;
    S2    : ARRAY [0..255] OF CHAR;
BEGIN 
    ErrorDescription(f,S2);
    Len := 1;
    ParseBal(S2,Len,Title);      (* Strip off the box title. *)
    Remove(S2,1,Len - 1);        (* RSC 2/1/89 for new ParseBal. *)
    Copy(S2,s);
END FileResultMeans;





    (*  FlushBuffer -- After writing to a file, this routine will
                       force the actual data transfer to the disk.
                       Due to the current implementation (May 1984)
                       of Doio, which would set <done> to <TRUE>,
                       we must check for existing errors first.  *)


PROCEDURE FlushBuffer(VAR f:File);
BEGIN
    IF (CheckIO(f) = done) THEN
        Doio(f);
        DosFlush;
    END;
END FlushBuffer;



     (* DisplayFileError -- Display a dialog box describing the
                            error.  Description should be the name
                            of the file or some other description of
                            it. *)

PROCEDURE DisplayFileError( VAR f           : File;
                            VAR Description : ARRAY OF CHAR );
CONST
    BreakChar = 374C;
VAR
    S     : ARRAY [0..255] OF CHAR;
BEGIN
        (* Get a description of the error. *)
    ErrorDescription(f,S);
    ConcatS(S,BreakChar);
    ConcatLS(S,Description);
        (* If we were writing to the file, then close the file in order
           to dissuade DOS from writing the FAT table to the wrong disk
           if the user brightly decides to switch diskettes now.   This
           is not perfect, though, since we could get a read error on
           a disk that also had some files open for write access. *)
    IF (wr IN f.flags) OR (f.eof) THEN
        Close(f);                 (* Stop further i/o.  Write FAT table. *)
    END;
    DosFlush();
       (* Display the error box. *)
    Error(S);
END DisplayFileError;







BEGIN

    EXEPath[0]      := 0C;
    OverlayPath[0]  := 0C;
    TextPath[0]     := 0C;

END FileAux.
