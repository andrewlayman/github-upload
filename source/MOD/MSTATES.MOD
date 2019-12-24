IMPLEMENTATION MODULE MStates;
(*V2=PRINT WITH debugging printouts. *)
(*V3=DEBUG adds error testing *)

(* Gets the next mouse event and determines the new state. 

    MODIFICATION HISTORY:

        Dec 15, 89 - JES - created.
        Dec 19, 89 - RSC - Minor speed improvements.
        May 30, 90 - AJL - Changed to get the raw screen coordinates from
                           GetMouseEvent.  This way, we can filter out small
                           amounts of jitter from turning a double click into 
                           two clicks.

*)

FROM Dialog   IMPORT
    (* PROC *)          FatalError;    

FROM Kbio     IMPORT
    (* TYPE *)          ascreenx, ascreeny;

FROM LMouse   IMPORT
    (* TYPE *)          EventSet, Event, ButtonSet, LeftButton;

FROM MouseInt IMPORT
    (* PROC *)          GetMouseEvent;

FROM Mouse    IMPORT
    (* CONST *)         DoubleClickRate, AMouseTime;

(*  ------------------------ Import if tracing ------------------*)
(*<PRINT
FROM Kbio IMPORT PutString, avidmode;
FROM LStrings IMPORT SetString, ConcatS, ConcatLS, CtoS, Procustes;
PRINT>*)

CONST
    PixelsPerChar       = 8;      (* Reported position is this * <col/row> *)
    DoubleClickMaxDistance = 3;

TYPE

    AMouseEvent = 
      RECORD
           TheEvents  : EventSet;
           TheButtons : ButtonSet;
           MouseX     : INTEGER;
           MouseY     : INTEGER;
           EventTime  : AMouseTime;
      END;

VAR
    CurrentMouseState  : AMouseState;    
    LastMouseEvent     : AMouseEvent;
    LastMouseState     : AMouseState;
    LastReleaseTime    : AMouseTime;
    LastClickX         : ascreenx;
    LastClickY         : ascreeny;
    InMouse            : BOOLEAN; (* for debugging - to prevent FatalError
                                        from calling GetNewMouseState
                                        and thus making pmd data obsolete *)
(*<PRINT
PROCEDURE DisplayMouseState(MouseState: AMouseState);
VAR
   S: ARRAY[0..40] OF CHAR;     
   S2: ARRAY[0..25] OF CHAR;     
   i : CARDINAL;
BEGIN
        CASE MouseState OF
            Neutral: 
                SetString(S,"Neutral       ");  
         |  DownOnce:
                SetString(S,"DownOnce      ");  
         |  ClickedOnce:
                SetString(S,"ClickedOnce   ");  
         |  ClickedAndDown:
                SetString(S,"ClickedAndDown");  
         |  DoubleClicked:
                SetString(S,"DoubleClicked ");  
        END;
        CtoS(LastMouseEvent.MouseX,S2);   Procustes(S2,4);  ConcatLS(S,S2);
        CtoS(LastMouseEvent.MouseY,S2);   Procustes(S2,4);  ConcatLS(S,S2);
        PutString(S,0,22,videoreverse);
END DisplayMouseState;
PRINT>*)

(*-------------GetCurrentMouseState ----------------- exported --------*)

PROCEDURE GetCurrentMouseState (VAR MouseState : AMouseState);

BEGIN
        MouseState := CurrentMouseState;
END GetCurrentMouseState;



(* --------GetNewMouseState --------- exported ------------*)

PROCEDURE GetNewMouseState (VAR NewMouseState : AMouseState;
                            VAR X             : ascreenx;
                            VAR Y             : ascreeny;
                            VAR TimeStamp     : AMouseTime) : BOOLEAN;
VAR
        MouseEvent: AMouseEvent;
        FoundEvent: BOOLEAN;
        Down      : BOOLEAN;
        Up        : BOOLEAN;
        VeryLittleMotion : BOOLEAN;
        XDistance, YDistance : INTEGER;

BEGIN
    IF (InMouse) THEN RETURN FALSE; END;

    InMouse := TRUE;
    FoundEvent := GetMouseEvent(MouseEvent.TheEvents,
                                MouseEvent.TheButtons,    
                                MouseEvent.MouseX,
                                MouseEvent.MouseY,
                                MouseEvent.EventTime);

    IF (FoundEvent) THEN

          (* for readability: *)
        Down := (LeftButton IN MouseEvent.TheButtons);
        Up   := (NOT Down);


        (* set some return variables: *)
        X         := MouseEvent.MouseX  DIV PixelsPerChar;
        Y         := MouseEvent.MouseY  DIV PixelsPerChar;
        TimeStamp := MouseEvent.EventTime;

            (* Did we move only a very little, or enough to 
               measure? *)

        XDistance := INTEGER(LastClickX) - INTEGER(X);
        YDistance := INTEGER(LastClickY) - INTEGER(Y);
        IF (XDistance < 0) THEN XDistance := -XDistance; END;
        IF (YDistance < 0) THEN YDistance := -YDistance; END;
            (* VeryLittleMotion means that not much time has passed,
               nor has much movement occurred. *)
        VeryLittleMotion := (MouseEvent.EventTime <= LastReleaseTime + DoubleClickRate) AND
                            (XDistance+YDistance <= DoubleClickMaxDistance);

        (* make the transition to the next state: *)
        CASE CurrentMouseState OF

            Neutral:                            (* Button was up. *)
                IF Down THEN                
                    NewMouseState := DownOnce;        
                ELSE
                    NewMouseState := CurrentMouseState;
                END;


          | DownOnce:                           (* Button was down. *)
                IF Up THEN                                   (* Coming up. *)
                    NewMouseState     := ClickedOnce;
                       (* Save the location of the click.  We will report
                          it as the location of any subsequent double click. *)
                   LastClickX    :=  X;
                   LastClickY    :=  Y;
                ELSE                                         (* Still down. *)
                    (* still down - therefore it's a move *)
                    NewMouseState := CurrentMouseState;
                    (* test assertion re events passed to us by MouseInt: *)
                    (*<DEBUG
                    IF NOT (Motion IN MouseEvent.TheEvents) THEN    
                        FatalError();
                    END;
                    DEBUG>*)
                END;

          | ClickedOnce:                        (* Button was up. *)
                IF Up THEN                           (* Still up. *)
                   IF (VeryLittleMotion) THEN                    (* A very small motion.  Ignore it. *)
                        NewMouseState := CurrentMouseState;
                        FoundEvent := FALSE;
                   ELSE
                           (* a move while the button was up - go back to neutral *)
                        NewMouseState    := Neutral;
                   END;
                       (* test assertion re events passed to us by MouseInt: *)
                    (*<DEBUG
                   IF NOT (Motion IN MouseEvent.TheEvents) THEN
                        FatalError();
                   END;
                    DEBUG>*)
                ELSE
                   (* check if we're on the way to potential double click -
                      i.e., down with small delay, and didn't move: *)
                   IF (VeryLittleMotion) THEN
                        (* could be part of a double click *)
                        NewMouseState := ClickedAndDown;
                        X := LastClickX;
                        Y := LastClickY;
                   ELSE
                        NewMouseState := DownOnce; (* backtrack *)
                   END;
                END;

          | ClickedAndDown:
                IF Down THEN
                       (* it's a move *)                
                       (* test assertion re events passed to us by MouseInt: *)
                    IF NOT (Motion IN MouseEvent.TheEvents) THEN
                        FatalError();
                    END;
                    IF (VeryLittleMotion) THEN                    (* A very small motion.  Ignore it. *)
                        NewMouseState := CurrentMouseState;
                        FoundEvent := FALSE;
                    ELSE
                        NewMouseState := DownOnce;
                    END;
                ELSE                
                   (* test for double click: *)
                   IF (VeryLittleMotion) THEN
                        NewMouseState := DoubleClicked;
                        X := LastClickX;
                        Y := LastClickY;
                   ELSE     
                        NewMouseState := ClickedOnce;
                   END;
                END;

          | DoubleClicked:
                IF Down THEN
                    NewMouseState := DownOnce;
                ELSE
                    NewMouseState := Neutral;
                END;
       ELSE
          FatalError();
       END;
       (*<PRINT
        DisplayMouseState(NewMouseState);
        PRINT>*)
        (* set last button release time: *)
        IF (LeftUp IN MouseEvent.TheEvents) THEN
            LastReleaseTime := MouseEvent.EventTime;
        END;

        (* set global variables: *)
       LastMouseEvent := MouseEvent;
       LastMouseState := CurrentMouseState;
       CurrentMouseState := NewMouseState;

    END;
    InMouse := FALSE;

    RETURN FoundEvent;

END GetNewMouseState;

BEGIN
    InMouse := FALSE;
    CurrentMouseState := Neutral;
    LastReleaseTime := VAL(AMouseTime,0);
    LastMouseEvent.MouseX := 0;
    LastMouseEvent.MouseY := 0;
    LastClickX            := 0;
    LastClickY            := 0;
END MStates.
