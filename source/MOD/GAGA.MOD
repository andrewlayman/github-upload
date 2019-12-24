IMPLEMENTATION MODULE GaGa;

  (*$S+*)   (* RSC 2/22/88 as per LAA
             *)

   (* GaGa - The first words Time Line knows .....

                This module contains all the text that needs to be
            In the root of TimeLine.  It is all here to make the job
            of internationalizers easier.  Keep in mind that short phrases
            probably have short strings allocated for them, so try not to
            expand phrases too much.

            RSC 12/31/87 - Initial version.
            LAA 01-Feb-88  Changed Error to Attention.
            RSC 04-Feb-88  Added Kbio's "Please serialize" message.
            RSC 10-Feb-88  Changed Breakthru to (snif) Symantec.
                           Farewell, BTS.
            AJL 13-Feb-88  Removed 1800 "File Error:".
                           Added "Fatal Error" as title.
            AJL 14-Feb-88  Added title to "Unexplained DOS file error".
            RSC 22-Feb-88  Added command parameters here.
            EGK  1-Mar-88  Killed 22006 and 22009.
            RSC 9/29/88 to remove references to LStrings.  Helps get this
                           module initialized early.  Added MEMCHECK msg.
            RSC 10/31/88   Tried to make things even more international
                           by padding strings with "~".  By pre-allocating
                           space, we can directly edit the EXE file, avoiding
                           recompiles and relinks.
            RSC 12/16/88   Changed comment on phrases 219xx.
            RSC  6/08/89   Added paths for TimeLine.Mod (4503 & 4504).
            WKH  6/14/89   Added cmdline option for compressed display.
            RSC 19-Jun-89  Added module 7300, the ParmLine module.
            WKH 11-Jul-89  Added cmdline option for user name.
            RSC 24-Jul-89  Added 22203, a message file error.
                           Added 1605 and 1606 from Dialog.Mod
                           Removed 1601, 1602.
            WKH 06-Aug-89  Initial OS/2 edits.
            RSC 29-Nov-89  Updated 1605, as per bug # 1793.
            RSC 13-Dec-89  Added Boxes PseudoPhrases # 2 & 3.
            AJL 13-Dec-89  Changed the box help prompt to remove the 
                           word "Press" which made it too long.
            AJL  8-Jan-89  Made the OK and Cancel buttons larger.
            RSC 14-Sep-90  Added ".T%0" phrases, 4601.
            AJL  6-Oct-90  Added a new phrase, #4, for mouse buttons.
            RSC 23-Oct-90  Changed ".T%0" phrase, 4601, to ".4T0".
            TGS  4-Apr-91  Now it's ".5T0".
            TGS 18-Jun-91  The video mode and line break characters can
                           now be changed.
            LAA 23-Sep-91  Changed the wording of the FatalError text to
                           imply that support is available from non-US
                           offices of Symantec.
   *)


FROM SYSTEM     IMPORT CODE;



    (* Because LStrings EXPORTS their procedures, they become FAR procedures.
       To force ours to be FAR (so the ASSEMBLER code works), set them to
       a proc var.
    *)
TYPE
    ASetStringProc = PROCEDURE ( VAR ARRAY OF CHAR, ARRAY OF CHAR );

VAR
    StupidCompilerVar : ASetStringProc;



  (* From the "Real" LStrings. *)

MODULE LStrings;

    IMPORT CODE;

    EXPORT
        (* PROCS *)     SetString, ConcatLS, ConcatS;

PROCEDURE SetString (VAR Target:ARRAY OF CHAR; Source:ARRAY OF CHAR);
VAR
    i : CARDINAL;
BEGIN
    IF (HIGH(Source) >= HIGH(Target)) THEN
        HALT;
    END;

        CODE (8CH,0D8H,         (* MOV  AX,DS           SAVE THE DS REG.    *)
              50H,              (* PUSH AX                                  *)
              8BH,4EH,0AH,      (* MOV  CX,[BP+0A]      GET HIGH(SOURCE)    *)
              41H,              (* INC  CX              HIGH IS ZERO ORIGIN *)
              0C4H,7EH,0CH,     (* LES  DI,[BP+0C]      TARGET ADDRESS      *)
              0C5H,76H,06H,     (* LDS  SI,[BP+06]      SOURCE ADDRESS      *)
              47H,              (* INC  DI              SKIP PAST LENGTH    *)
              0F3H,0A4H,        (* REP  MOVSB           MOVE THE STRING     *)
              58H,              (* POP  AX              POP THE DS REGISTER *)
              8EH,0D8H);        (* MOV  DS,AX                               *)

    Target[0] := CHR(HIGH(Source)+1);

END SetString;




PROCEDURE ConcatLS (VAR Target:ARRAY OF CHAR; Addend: ARRAY OF CHAR);
VAR
    ti,ai : CARDINAL;
BEGIN
    IF (ORD(Target[0]) + ORD(Addend[0]) > HIGH(Target)) THEN
        HALT;
    END;

    CODE(0FCH,              (* CLD                                              *)
         0C5H, 076H, 006H,  (* LDS     SI,[BP+06]   ; Addend[0]                 *)
         02BH, 0C9H,        (* SUB     CX,CX                                    *)
         08AH, 00CH,        (* MOV     CL,[SI]      ; Length to CX              *)
         046H,              (* INC     SI           ; Skip lstring length       *)
         0C4H, 07EH, 00CH,  (* LES     DI,[BP+0CH]  ; Target[0]                 *)
         02BH, 0C0H,        (* SUB     AX,AX                                    *)
         026H, 08AH, 005H,  (* MOV     AL,ES:[DI]   ; Length of Target          *)
         08BH, 0D8H,        (* MOV     BX,AX                                    *)
         003H, 0D9H,        (* ADD     BX,CX        ; Compute new length        *)
         026H, 088H, 01DH,  (* MOV     ES:[DI],BL                               *)
         047H,              (* INC     DI           ; Skip length               *)
         003H, 0F8H,        (* ADD     DI,AX        ; Position to end of Target *)
         0F3H, 0A4H);       (* REP     MOVSB        ; Move characters           *)

END ConcatLS;





PROCEDURE ConcatS  (VAR Target:ARRAY OF CHAR; Addend: ARRAY OF CHAR);
VAR
    ti,ai : CARDINAL;
BEGIN
    IF (HIGH(Addend)+ORD(Target[0]) >= HIGH(Target)) THEN
        HALT;
    END;

    ti := ORD(Target[0]);

    CODE(8CH,0D8H,      (* MOV    AX,DS       SAVE THE DS CONTENTS           *)
         50H,           (* PUSH   AX                                         *)
         0C4H,7EH,0CH,  (* LES    DI,[BP+0C]  ADDRESS OF TARGET TO ES:DI     *)
(*<DOS*)
         8BH,46H,0FCH,  (* MOV    AX,[BP-4]   GET THE VALUE OF ti            *)
(*DOS>*)
(*<OS2
	     8BH,46H,0FAH,	(* MOV	  AX,[BP-6]   GET THE VALUE OF ti	         *)
OS2>*)
         01H,0C7H,      (* ADD    DI,AX       ES:DI = ADDR. OF TARGET[ti]    *)
         0C5H,76H,06H,  (* LDS    SI,[BP+06]  ADDRESS OF ADDEND TO DS:SI     *)
         8BH,4EH,0AH,   (* MOV    CX,[BP+0A]  HIGH(ADDEND) TO CX             *)
         41H,           (* INC    CX          ACCOUNT FOR THE ZERO ORIGIN    *)
         47H,           (* INC    DI          MOVE PAST LAST CHAR IN TARGET  *)
         0F3H,0A4H,     (* REP    MOVSB       APPEND ADDEND TO TARGET        *)
(*<DOS*)
         8BH,46H,0FCH,  (* MOV    AX,[BP-04]  GET THE VALUE OF ti            *)
(*DOS>*)
(*<OS2
	    8BH,46H,0FAH,	(* MOV	  AX,[BP-06]  GET THE VALUE OF ti	         *)
OS2>*)
         03H,46H,0AH,   (* ADD    AX,[BP+0A]  ADD HIGH(ADDEND)               *)
         40H,           (* INC    AX          ADJUST FOR ZERO ORIGIN OF HIGH *)
(*<DOS*)
         89H,46H,0FCH,  (* MOV    [BP-04],AX  PUT RESULT BACK IN ti          *)
(*DOS>*)
(*<OS2
	    89H,46H,0FAH,	(* MOV	  [BP-06],AX  PUT RESULT BACK IN ti	         *)
OS2>*)
         58H,           (* POP    AX          RESTORE VALUE OF DS            *)
         8EH,0D8H);     (* MOV    DS,AX                                      *)

    Target[0] := CHR(ti);
END ConcatS;


END LStrings;



PROCEDURE GetGaGaMessage( PhraseNumber : CARDINAL;
                      VAR s            : ARRAY OF CHAR );
BEGIN
    CASE PhraseNumber OF

 (* RSC 10/21/88 - Pad strings with "~", up to the max length we will allow
                   for any language, say, German.  I chose to set the string
                   to the max length and then trim back so we can find any
                   Too Long() errors early (ie, while still in English).
 *)

 (* !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ATTENTION!! NOTE!! WARNING!! LISTEN UP!!
    
    When changing any of the text in GaGa, please note that a corresponding
    change must also be made in GAGATEXT.TXT.  This is so we can always 
    easily "internationalize" Time Line or make changes to GaGa text without
    acutally having to re-compile Time Line.
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 *)

  (* MEMCHECK The string MUST TERMINATE WITH A "$" SIGN!! (except for the tilde) *)
          1: SetString( s, "There is not enough FREE memory to run Time Line.$~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    |     2: SetString( s, " Cancel ~~~~" );  (* 13-Dec-89 RSC  *)
    |     3: SetString( s, "   OK   ~~~~" );  (* 13-Dec-89 RSC  *)
                 (* On the following strings, which are the names of the mouse buttons,
                    some begin with "-".  This means put at the right side of the box. 
                    The number following the "-" is the indent from the right,
                    and must be changed if the length of the following items
                    change.  *)
    |     4: SetString( s, "(*)(Help)(Menu)(Edit)(Ins)(Del)(-9   OK   )(-18 Cancel )~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" );

  (* Space *)   (* (May be before msg system is running) *)
    |   500: SetString( s, "There is not enough memory to start Time Line.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" );
    |   501: SetString( s, "Out Of Memory~~~~~~~~~~~~~~~~~" ); (* Title for box <= 31 bytes *)
    |   502: SetString( s, "(Press any key to exit Time Line)~~~~~~~~~~~~~~~~~~~~~~~~~" );
    
  (* Dialog *)  (* (Procedures used perhaps before msg system runs) *)
    |  1600: SetString( s, " Attention ~~~~~~~~~~~~~~~~" );          (* Title for error box. *)  (* 01-Feb-88 LAA *)
    |  1603: SetString( s, "(Fatal Error)Time Line has just had an internal error.  The program will stop.  " );
             ConcatS(   s, "Please report this to Symantec Corporation ");
             ConcatS(   s, "at 415-898-1919 or call the Symantec office in your country.~~" );
    |  1604: SetString( s, "Proceed,Cancel~~~~~~~~~~~~~~~~~" ); (* for Continuation box; NO SPACE SEPARATOR *)
    |  1605: SetString( s, "[F10] or [Esc] to continue.~~~~~~~~~" );
    |  1606: SetString( s, "[Esc] to continue.~~~~~~~~~~~~~~~~~~" );
    |  1607: SetString( s, "  [F1] for Help.~~~~~~~~~~~~~~~~~~" );

  (* FileAux *) (* (Used when file errors occur, like msg file errors) *)
    |  1801: SetString( s, "(DOS File Problem)Unexplained DOS file error: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~" );
    |  1802: SetString( s, "(M2FS File Problem)(from M2 file system): ~~~~~~~~~~~~~~~~~~~~~~~~~~" );

  (* TLMain/TimeLine *) (* (Used in INIT before msg system is working) *)
    |  4501: SetString( s, "RECALC~~~~~~~" ); (* Keywords for command line. *)
    |  4502: SetString( s, "PATH~~~~~~~" );   (* Keywords for command line. *)
    |  4503: SetString( s, "TEXT\~~~~" );   (* Location of text files from the LOAD PATH. *)
    |  4504: SetString( s, "PROGRAMS\" );   (* Location of overlays from the LOAD PATH. *)

  (* Schedule.Mod : The File extension.  Probably does not need to be
                    internationalized.
  *)
    |  4601: SetString( s, ".5T0" );  (* This EXACT format!! *)

  (* ParmLine.  Must include leading and trailing spaces.  Must be UPPER CASE. *)
    |  7301: SetString( s, " IS ~~~~~~~~~~~~~~~~" );

  (* RegForm.  Used as option to indicate what user name is*)
    |  7500: SetString( s, "USER~~~~~~" );

  (* TLStart *) (* (Used in INIT before msg system is working) *)
    | 12301: SetString( s, "PATH~~~~~~~" );   (* Keywords for command line. *)

  (* TimeFormat *) (* (Used in INIT before msg system is working) *)
    | 21900: SetString( s, "am~~~~~~~" );   (* AM/PM designator for time strings *)
    | 21901: SetString( s, "pm~~~~~~~" );   (* AM/PM designator for time strings *)

  (* FileOpen *) (* (Used when you can't open files, so may be msg file...) *)
    | 22000: SetString( s, "Looking for ~~~~~~~~~~~~~~" );            (* Trying to open files ... *)
    | 22001: SetString( s, "Please insert ~~~~~~~~~~~~~~" );          (* ...from a diskette *)
    | 22002: SetString( s, "disk with file ~~~~~~~~~~~~~~~~~" );      (* ...from a diskette *)
    | 22003: SetString( s, " and press [Enter] to retry (or [Esc] to cancel).~~~~~~~~~~~~~~~~~~~~~" );
    | 22004: SetString( s, "ü;Cannot find file ~~~~~~~~~~~~" );  (* Set break char to ';' *)
    | 22005: SetString( s, " in any of these directories:;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" );
    | 22006: s[0] := 0C;

    | 22007: SetString( s, "Cannot find file ~~~~~~~~~~~~~~~~~~~" );
    | 22008: SetString( s, "Cannot find directory ~~~~~~~~~~~~~~~~~~~" );
    | 22009: s[0] := 0C;

  (* RsrcMod *)  (* (Used in init before msg system is working) *)
    | 22100: SetString( s, "Units~~~~~" ); (* Default unit of measure for a resource. <= 10 bytes! *)

  (* MsgFile *)  (* (Used when messages can't be read) *)
    | 22200: SetString( s, "Phrases file~~~~~~~~~~~~~~~~~~" ); (* Complaint about reading the file. *)
    | 22201: SetString( s, "Time Line SYSTEM RUN disk~~~~~~~~~~~~~~~~~~~" ); (* For FileOpen request *)
    | 22202: SetString( s, "Can't read message file!~~~~~~~~~~~~~~~~~~~~" );  (* For file read errors *)
    | 22203: SetString( s, "Message file was not compiled properly.~~~~~~~~~~" );  (* For file read errors *)

  (* LString *)  (* (Used during init too...) *)
    | 22300: SetString( s, "Too long:~~~~~~~~~~~" );

  (* Kbio *)
    | 22700: SetString( s, "You must enter your serial number before Time Line will run." );
             ConcatS(   s, "üüPlease follow the installation procedures outlined in the " );
             ConcatS(   s, "Getting Started Booklet.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" );
    | 22701: SetString( s, "DISPLAY~~~~~");      (* 14-Jun-89 WKH *)
    | 22702: SetString( s, "COMPRESSED~~~~~");   (* 14-Jun-89 WKH *)
    (* Video mode character *)
    | 22703: SetString( s, "ý~~");               (* 18-Jun-91 TGS *)

    ELSE
        HALT; (* Once you go down the dark path,         *)
    END;      (*  forever will it dominate your destiny! *)


    (* Trim off those trailing tildes. *)

    WHILE (ORD(s[0]) > 0) AND (s[ORD(s[0])] = "~") DO
        DEC(   s[0] );
    END;

END GetGaGaMessage;



PROCEDURE ConcatGaGaMessage( PhraseNumber : CARDINAL;
                         VAR s            : ARRAY OF CHAR );
VAR
    s1 : ARRAY [0..99] OF CHAR;  (* Not too big, now; stack is precious! *)
BEGIN

    GetGaGaMessage( PhraseNumber, s1 );
    ConcatLS( s, s1 );

END ConcatGaGaMessage;


  (*$S=*)   (* RSC 2/22/88 as per LAA *)


BEGIN
    StupidCompilerVar := SetString;  (* For these to be FAR calls, do this. *)
    StupidCompilerVar := ConcatLS;
    StupidCompilerVar := ConcatS;
END GaGa.

