IMPLEMENTATION MODULE MouseInt;


    (* MODIFICATION HISTORY

       30 May 90  AJL - Return raw mouse coordinates, rather than 
                        screen coordinates.
       27-Jun-91  RSC - Added the cursor control to remove the possibility
                        of the Microsoft mouse driver messing up video
                        memory with its graphical cursor.
       05-Sep-91  LAA - Call GetPosBut from LMouse rather than doing the
                        SWI here.
     *)

FROM LMouse     IMPORT
    (* TYPE *)      Button, ButtonSet, Event, EventSet,
    (* PROC *)      GetPosBut;

FROM Mouse      IMPORT
    (* TYPE *)      AMouseTime; 

FROM SYSTEM     IMPORT
    (* CONST *)     AX, BX, CX, DX,
    (* TYPE *)      ADDRESS,
    (* PROC *)      ENABLE, DISABLE, SETREG, GETREG;

FROM Video      IMPORT
    (* VAR *)       VideoAddress;

(*$R-*)
(*$S-*)
(*$T-*)


CONST
    MAXCARDINAL =   65535;



    (* This module turns off interrupts during access to the queue of
       mouse events for two reasons:

       1.  We need to make sure that we do not interrupt the critical 
           sections of the procedures which access the queue index n.
           That is, the procedures which remove items from the queue
           must be protected against the MouseHandler procedure increasing
           the queue count while the removing procedure is decreasing it.
           And, the MouseHandler is not reentrant, because the variables
           n and In need to be protected.

       2.  We need to protect against the stack being used much.  The
           MouseHandler procedure needs to be very sparing in its use
           of the stack, and cannot be reentrantly called since the 
           DOS stack would be reused.

       If turning off all interrupts is too severe, we could just temporarily
       turn off the mouse interrupt by updating the interrupt controller's
       priority mask.

       It is not feasible to interlock based on some flag variable, because
       (a) we still need to protect against rentrant use of that flag 
       variable, and (b) we would need to loop waiting for the flag to be
       cleared or risk ignoring events.  This could lead to reentrant proc
       calls, violating goal number 2, above.

    *)



CONST
    N = 8;                  (* Queue size.    For efficiency, should be
                               a power of 2. *)
    PixelsPerChar = 8;      (* Reported position is this * <col/row> *)

TYPE
    ARawMouseChange = RECORD
                          Events  : EventSet;
                          Buttons : ButtonSet;
                          X,Y     : INTEGER;
                          TimeStamp : LONGINT;
                      END;  
VAR
    i : CARDINAL;
    n, In, Out : CARDINAL;                    
    Queue : ARRAY [0..N-1] OF ARawMouseChange;
    LastX : INTEGER;        (* Used by GetMouseEvent *)
    LastY : INTEGER;
    LastButtons : ButtonSet;

    ShowTheCursor  : CARDINAL;


    LastMouseCursor : RECORD
        X, Y : CARDINAL;
        On   : BOOLEAN;
    END;

    LastMouseX              : CARDINAL;     (* Used by interrupt routine *)
    LastMouseY              : CARDINAL;


    (* Redisply the old cursor position as "normal", if there was an
       old one.  Display the cursor in the NewX, NewY position.

       Added 28-Jun-91 by RSC.
    *)
PROCEDURE ShowCursorAt( NewX, NewY : CARDINAL );
CONST
    ScreenWidth = 80;    (* Physical offset in words from one line to next. *)
VAR
    A   : ADDRESS;
    P   : POINTER TO CHAR;
    B   : BITSET;
    yx  : CARDINAL;
BEGIN
    WITH LastMouseCursor DO

        IF (On) THEN
            (* Put back the old char
            *)
            yx := (((ScreenWidth*Y) + X) * 2) + 1;  (*  Offset on screen. *)
            A  := VideoAddress;
            A.OFFSET := yx;
            P  := A;
            B  := BITSET(ORD(P^));
            P^ := CHR(CARDINAL(B / {0..15}));
            On := FALSE;
        END;

        X  := NewX;
        Y  := NewY;
        IF (ShowTheCursor > 0) THEN
            On := TRUE;
                 (* Set new char
                 *)
            yx := (((ScreenWidth*Y) + X) * 2) + 1;  (*  Offset on screen. *)
            A  := VideoAddress;
            A.OFFSET := yx;
            P  := A;
            B  := BITSET(ORD(P^));
            P^ := CHR(CARDINAL(B / {0..15}));
        END;
    END;

END ShowCursorAt;




PROCEDURE CursorOn();
VAR
    X, Y                    : CARDINAL;
    Buttons                 : ButtonSet;
BEGIN
    INC(ShowTheCursor);

    GetPosBut( Buttons, X, Y );
    ShowCursorAt( X DIV PixelsPerChar, Y DIV PixelsPerChar );

END CursorOn;




PROCEDURE CursorOff();
BEGIN
    IF (ShowTheCursor > 0) THEN
        DEC(ShowTheCursor);
    END;
    IF (ShowTheCursor = 0) THEN
        ShowCursorAt( 0, 0 );   (* it is off, so reset old pending char *)
    END;
END CursorOff;




PROCEDURE MouseHandler(     TheEvents   : EventSet;
                            TheButtons  : ButtonSet;
                            MouseX      : INTEGER;
                            MouseY      : INTEGER );
VAR
    SystemTime[0:046CH] :   LONGINT;
BEGIN
    IF (Motion IN TheEvents) THEN
        LastMouseX := CARDINAL(MouseX) DIV PixelsPerChar;
        LastMouseY := CARDINAL(MouseY) DIV PixelsPerChar;
        ShowCursorAt( LastMouseX, LastMouseY );
    END;

    (* Can't do this in the interrupt handler.    IF (n = N) THEN 
       --------------------------->                   Wait(NonFull);
       See point 2 in discussion above.           END;
    *)

    (* We do not turn off interrupts here because all mouse handlers
       we have seen are interlocked to prevent reentrancy. *)


        (* i := In-1 MOD N;  Prior element in queue. *)
    IF (In = 0) THEN i := N-1 ELSE i := In-1; END;

        (* If the only thing changed is the position, and we are not
           about to update the queue item being consumed (n > 1) then
           touch up the position to save queue length. *)

    IF (n > 1) 
        AND (TheEvents = EventSet{Motion})
        AND (Queue[i].Events = EventSet{Motion}) THEN
        WITH Queue[i] DO
            X         := MouseX;         (* Just update the position. *)
            Y         := MouseY;
            TimeStamp := SystemTime;     (* Read directly from memory. *)
        END;
    ELSIF n < N THEN                     (* Add event to queue. *)
        INC(n);
        WITH Queue[In] DO
            Events    := TheEvents;  
            Buttons   := TheButtons;
            X         := MouseX;
            Y         := MouseY;
            TimeStamp := SystemTime;     (* Read directly from memory. *)
        END;
        In := (In + 1) MOD N;
    END;

END MouseHandler;




PROCEDURE GetMouseEvent( VAR TheEvents   : EventSet;
                         VAR TheButtons  : ButtonSet;
                         VAR MouseX      : INTEGER;
                         VAR MouseY      : INTEGER;
                         VAR Time        : AMouseTime ) : BOOLEAN;
VAR
    cx,dx     : CARDINAL;
    RawChange : ARawMouseChange;
BEGIN
    LOOP
        DISABLE;
    
        IF (n > 0) THEN
                (* Fetch item from queue. *)
            DEC(n);
            RawChange := Queue[Out];
            Out := (Out + 1) MOD N;
            ENABLE;
    
            WITH RawChange DO
                TheButtons     := Buttons;
                MouseX         := X;
                MouseY         := Y;
                Time           := VAL(AMouseTime,TimeStamp);
            END;
                (* Figure out what the event was, if anything. *)
            TheEvents := EventSet{}; 
                (* If the position has not changed measurably, then do not
                   admit to a movement.   This prevents us from acting on
                   motions too small to be seen. *)
            IF (MouseX <> LastX) OR (MouseY <> LastY) THEN
                INCL(TheEvents,Motion);
            END;
                 (* Only pay attention to the left button.   See if 
                    it changed. *) 
            TheButtons := TheButtons * ButtonSet{LeftButton};
            IF (TheButtons <> LastButtons) THEN
                IF (LeftButton IN TheButtons) THEN
                    INCL(TheEvents,LeftDown);
                ELSE  
                    INCL(TheEvents,LeftUp);
                END;
            END;
            LastX := MouseX;
            LastY := MouseY;
            LastButtons := TheButtons;
                (* If nothing has happened, the event doesn't count. *)
            IF (TheEvents <> EventSet{}) THEN
                RETURN TRUE;
            END;
        ELSE
            ENABLE;
            RETURN FALSE;
        END;
    END;
END GetMouseEvent;



(*
PROCEDURE MouseQueueIsEmpty():BOOLEAN;
BEGIN
    RETURN (n = 0);
END MouseQueueIsEmpty;
*)






BEGIN
    n             := 0;
    In            := 0;
    Out           := 0;
    LastX         := 0;
    LastY         := 0;
    LastButtons   := ButtonSet{};
    ShowTheCursor := 0;

    LastMouseCursor.On := FALSE;
    LastMouseCursor.X  := 40;
    LastMouseCursor.Y  := 12;

(*$T-*)
(*$S-*)
(*$R-*)
END MouseInt.
