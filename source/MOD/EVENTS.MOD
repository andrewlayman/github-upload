IMPLEMENTATION MODULE Events;

    (*

        7/9/87   AJL - Removed import of Video.
        6-Dec-89 RSC - Added mouse support, and implemented the
                       PushEvent() procedure.

    *)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Kbio                   IMPORT
    (* PROC *)                  GetAnyCode;

FROM Keys                   IMPORT
    (* TYPE *)                  MouseUp, MouseDown, MouseDouble,
                                MouseStillDown;

FROM Paranoia               IMPORT
    (* TYPE *)                  AnAnxietyLevel,
    (* VAR *)                   AnxietyLevel;

(*
FROM Video                  IMPORT
    (* PROC *)                  GetCursorLocation;
*)


CONST
    ModuleNumber            = 15500;


VAR
    SavedEvent      : AnEvent;
    EventWaiting    : BOOLEAN;





(*----------------------------------------------------------------------------
    GetNextEvent --

    Return the next event which happens (or has happened).

    Preconditions:
        None.

    Postconditions:
        The next available event will be returned.  If no event is available, 
        this procedure will wait for one, and then return it.
----------------------------------------------------------------------------*)

PROCEDURE GetNextEvent(VAR Event            : AnEvent);
CONST
    ASCIIZero   = ORD("0");

BEGIN                       (* GetNextEvent *)

    IF (EventWaiting) THEN
        Event := SavedEvent;
        EventWaiting := FALSE;
    ELSE
        WITH Event DO
            EventCode := GetAnyCode();

            (* 6-Dec-89 RSC  Added mouse support. *)

            CASE EventCode OF
              MouseUp, MouseDouble, MouseDown, MouseStillDown :
                EventType := MouseEvent;
                EventX    := (GetAnyCode() - ASCIIZero);
                EventY    := (GetAnyCode() - ASCIIZero);
            ELSE
                EventType := KeyboardEvent;
            END;
        END;
    END;

END GetNextEvent;










(*----------------------------------------------------------------------------
    PushEvent --

    Force the indicated event to be the next one returned by GetNextEvent.

    Preconditions:
        None.

    Postconditions:
        The indicated event will be pushed onto an internal 1-deep stack so
        that the next call to GetNextEvent will return it.  Only one event
        may be pushed between calls to GetNextEvent, or data will be lost.
----------------------------------------------------------------------------*)

PROCEDURE PushEvent(    Event               : AnEvent);

BEGIN                       (* PushEvent *)

    IF (EventWaiting) THEN
        FatalError();
    ELSE
        SavedEvent   := Event;
        EventWaiting := TRUE;
    END;

END PushEvent;




BEGIN                       (* Events *)

    EventWaiting := FALSE;

END Events.
