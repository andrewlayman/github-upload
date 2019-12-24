IMPLEMENTATION MODULE Fits;


    (* MODIFICATION HISTORY:

       21-Jul-86  AJL  - Removed the unnecessary test from Within that
                         called a FatalError if its Low <= High.
                         These should be output only.
       19-Jul-90  AJL  - Fixed an arithmetic error that prevented 
                         Within from working.

    *)

FROM Dialog    IMPORT FatalError;


    (* Within -- Adjust Low,High so that
                     (a) High-Low is unchanged, but
                     (b) High <= Max and
                     (c) Low >= Min.       *)


PROCEDURE Within( VAR   Low, High   : CARDINAL;
                        Min, Max    : CARDINAL  );
VAR
    Delta : CARDINAL;
BEGIN
    IF (Min > Max) OR
       (Low > High) OR
       (High-Low > Max-Min) THEN FatalError;
    END;

    IF (Low < Min) THEN
        Delta := Min - Low;
        Low := Min;
        INC(High,Delta);
    END;

    IF (High > Max) THEN
        Delta := High - Max;
        High := Max;
        DEC(Low,Delta);
    END;

END Within;






    (* Without -- Return Low, High so that
                      (a) MinSize <= High-Low+1 <= MaxSize,
                      (b) High <= Max,
                      (c) Low >= Min,
                      (d) If possible, Low > IHigh, or
                      (e) if possible, High < ILow.   *)



PROCEDURE Without(       MinSize,
                         MaxSize     : CARDINAL;
                         ILow, IHigh : CARDINAL;
                         Min, Max    : CARDINAL;
                   VAR   Low, High   : CARDINAL );
VAR
    RoomLowSide, RoomHighSide : CARDINAL;
BEGIN
    IF (Min > Max) OR
       (ILow < Min) OR
       (IHigh > Max) OR
       (MinSize > Max-Min+1) THEN FatalError;
    END;

    RoomLowSide  := ILow - Min;
    RoomHighSide := Max - IHigh;

        (* If it will fit on the high side, or fit better, then
           put it on the high side. *)

    IF (RoomHighSide >= MinSize) OR (RoomHighSide >= RoomLowSide) THEN
        IF (RoomHighSide >= MinSize) THEN
            IF (MaxSize > RoomHighSide) THEN
                MaxSize := RoomHighSide;
            END;
            Low := IHigh + 1;
            High := Low + MaxSize - 1;
         ELSE
            High := Max;
            Low := High - MinSize + 1;
         END;
    ELSE
        IF (RoomLowSide >= MinSize) THEN
            IF (MaxSize > RoomLowSide) THEN
                MaxSize := RoomLowSide;
            END;
            High := ILow - 1;
            Low  := High - MaxSize + 1;
        ELSE
            Low := Min;
            High := Low + MinSize - 1;
        END;
    END;

END Without;










END Fits.
