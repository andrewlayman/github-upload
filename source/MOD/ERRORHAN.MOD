IMPLEMENTATION MODULE ErrorHandler;

    (*  MODIFICATION HISTORY
        28-Dec-89 LAA   Initialize all fields in NewMarker.
        22-Jan-91 RSC   Added a high water mark for stats checking.
                        Can we lower StackSize below 50?
    *)

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;



CONST
    StackSize = 50;

TYPE
    AStackElement = RECORD
                        MarkerNo    : [0..255];
                        Category    : CARDINAL;
                        Code        : CARDINAL;
                        Valid       : BOOLEAN;
                    END;

VAR
    Stack: ARRAY [1..StackSize] OF AStackElement;
    StackTop: CARDINAL;

    HighWaterMark : CARDINAL;   (* 22-Jan-91 RSC test *)

(*  Internal Marker check procedure *)

PROCEDURE ValidateMarker (Marker: AnErrorMarker);
BEGIN
    IF (Marker = 0) OR (Marker > StackTop) THEN
        FatalError ();
    ELSIF (Stack[Marker].MarkerNo <> Marker) OR (NOT Stack[Marker].Valid) THEN
        FatalError ();
    END;
END ValidateMarker;




(* Internal procedure; returns array index of error at given offset from
    marker (skipping other markers and unposted errors), or 0 if not found.
*)

PROCEDURE FindError (Marker: AnErrorMarker;
                     Offset: CARDINAL)  : CARDINAL;
BEGIN
    INC (Marker);
    LOOP
        IF (Marker > StackTop) THEN
            RETURN 0;
        ELSIF (Stack[Marker].MarkerNo <> 0) OR (NOT Stack[Marker].Valid) THEN
            INC (Marker);
        ELSIF (Offset = 0) THEN
            RETURN Marker;
        ELSE
            DEC (Offset);
            INC (Marker);
        END;
    END;
END FindError;




PROCEDURE NewMarker(): AnErrorMarker;

BEGIN           (* NewMarker *)

    IF (StackTop >= StackSize) THEN
        FatalError ();
    END;

    INC (StackTop);
    WITH Stack[StackTop] DO
        MarkerNo := StackTop;
        Category := 0;                                         (* 28-Dec-89 *)
        Code := 0;
        Valid := TRUE;
    END;

    IF (StackTop > HighWaterMark) THEN  (* 22-Jan-91 RSC *)
        HighWaterMark := StackTop;
    END;

    RETURN StackTop;

END NewMarker;




PROCEDURE PopToMarker(VAR Marker            : AnErrorMarker);

BEGIN           (* PopToMarker *)

    ValidateMarker (Marker);
    StackTop := Marker - 1;
    Marker := 0;

END PopToMarker;




PROCEDURE PostError(    ErrorCategory       : CARDINAL;
                        ErrorCode           : CARDINAL);

BEGIN           (* PostError *)

    IF (StackTop >= StackSize) THEN
        FatalError ();
    END;

    INC (StackTop);
    WITH Stack[StackTop] DO
        MarkerNo := 0;
        Category := ErrorCategory;
        Code := ErrorCode;
        Valid := TRUE;
    END;

END PostError;



PROCEDURE ErrorPosted(    Marker            : AnErrorMarker)
                                                            : BOOLEAN;
BEGIN           (* ErrorPosted *)

    ValidateMarker (Marker);
    RETURN (FindError (Marker, 0) <> 0);
   
END ErrorPosted;





PROCEDURE GetErrorDetails(    Marker        : AnErrorMarker;
                              Offset        : CARDINAL;
                          VAR ErrorCategory : CARDINAL;
                          VAR ErrorCode     : CARDINAL     );
VAR
    Posn: CARDINAL;

BEGIN           (* GetErrorDetails *)

    ValidateMarker (Marker);
    Posn := FindError (Marker, Offset);
    IF (Posn = 0) THEN
        ErrorCategory := 0;
        ErrorCode := 0;
    ELSE
        ErrorCategory := Stack[Posn].Category;
        ErrorCode := Stack[Posn].Code;
    END;

END GetErrorDetails;





PROCEDURE UnPostError(    Marker            : AnErrorMarker;
                          Offset            : CARDINAL     );
VAR
    Posn: CARDINAL;

BEGIN           (* UnPostError *)

    ValidateMarker (Marker);
    Posn := FindError (Marker, Offset);
    IF (Posn <> 0) THEN
        Stack[Posn].Valid := FALSE;
    ELSE
        FatalError ();
    END;

END UnPostError;





BEGIN           (* ErrorHandler *)

    StackTop      := 0;
    HighWaterMark := 0;

END ErrorHandler.



