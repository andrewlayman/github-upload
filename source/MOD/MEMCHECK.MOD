IMPLEMENTATION MODULE MemCheck;


    (* RSC 9/23/88: Mem Check : Insure that there is enough DOS memory
                                available to run TimeLine.EXE.

        This module:

            > Checks that there is enough memory to load TimeLine.
            > Prints out a message if it fails and terminates.

            > MUST RUN FIRST, BEFORE ANY OF OUR MODULES THAT ALLOCATE MEMORY
              OR USE FILES!!
            > MUST THEREFORE NOT IMPORT ANYTHING THAT COULD OPEN FILES OR
              ALLOCATE MEMORY!!

       WKH 11/10/88: Die more gracefully when no memory.
       WKH 11/23/88: Die less gracefully when no memory.  No, ha, ha.  Just
                     kidding Wayne.  Cleared the screen before the message.
                     Did a CR+LF after the message.
    *)

FROM  Endings   IMPORT
                    EndWithErrorLevel;
FROM  GaGa      IMPORT
    (* PROCS *)     GetGaGaMessage;

FROM  RTSMain   IMPORT
    (* TYPE  *)     Status,
(*    (* VAR   *)     errorCode,*)
    (* PROCS *)     Terminate;

FROM  SYSTEM    IMPORT
    (* PROCS *)     DOSCALL, ADR, ADDRESS, SETREG, SWI, AX, BX, CX, DX;


CONST
    ModuleNumber      = 0;
    KPara             = 1024 DIV 16;  (* 1 KB in paragraphs *)
    SizeNeededToStart =
            KPara *
             (  42       (* Size of reserved layer *)
              + 32       (* TLMAIN, TLEMS, TLSWAPF, TLBTSMAC *)
              + 12       (* 3 TLSwapF buffers *)
              + 32       (* 2 HEAP Buffers *)
              + 32);     (* Miscellanious buffers and such *)


PROCEDURE CheckMemoryAvailable();
VAR
    Segment,
    Error,
    Size    : CARDINAL;
    Message : ARRAY [0..255] OF CHAR;
BEGIN
    Size := 0FFFFH;  (* All of it. *)
    DOSCALL( 48H, Size, Segment, Error );
    IF (Error = 8) AND (Size > 1) THEN  (* No room to allocate, but ... *)
        IF (Size < SizeNeededToStart) THEN

            SETREG( AX, 0200H );  (* AH = 2, SET CURSOR. *)
            SETREG( BX, 0000H );  (* page zero *)
            SETREG( CX, 0000H );  (* unused *)
            SETREG( DX, 1800H );  (* LRX = 0, LRY = 24 *)
            SWI(10H);             (* SET CURSOR *)

            SETREG( AX, 0619H );  (* AH = 6, SCROLL.  AL = 25 lines. *)
            SETREG( BX, 0700H );  (* videonormal *)
            SETREG( CX, 0000H );  (* ULX = 0,  ULY = 0  *)
            SETREG( DX, 184FH );  (* LRX = 79, LRY = 24 *)
            SWI(10H);             (* SCROLL! *)

            GetGaGaMessage( ModuleNumber + 1, Message ); (* "Not enough memory" *)
            DOSCALL( 09H, ADR(Message[1]) );

            SETREG( AX, 0605H );  (* AH = 6, SCROLL.  AL = 5 lines. *)
            SETREG( BX, 0700H );  (* videonormal *)
            SETREG( CX, 0000H );  (* ULX = 0,  ULY = 0  *)
            SETREG( DX, 184FH );  (* LRX = 79, LRY = 24 *)
            SWI(10H);             (* SCROLL! *)

            SETREG( AX, 0200H );  (* AH = 2, SET CURSOR. *)
            SETREG( BX, 0000H );  (* page zero *)
            SETREG( CX, 0000H );  (* unused *)
            SETREG( DX, 1800H );  (* LRX = 0, LRY = 24 *)
            SWI(10H);             (* SET CURSOR *)

            EndWithErrorLevel(2);  (* 11/10/88 WKH *)
        END;
    END;
END CheckMemoryAvailable;



BEGIN
    CheckMemoryAvailable();
END MemCheck.
