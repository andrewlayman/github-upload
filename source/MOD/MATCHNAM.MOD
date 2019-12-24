IMPLEMENTATION MODULE MatchNames;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* PROC *)                  PutString;

FROM LStrings               IMPORT
    (* PROC *)                  LengthOf, SubStr;




PROCEDURE PutMatchedString  (   VAR s           : ARRAY OF CHAR;
                                    x           : ascreenx;
                                    y           : ascreeny;
                                    MatchCount  : CARDINAL;
                                    VideoMode   : avidmode;
                                    CursorMode  : avidmode; 
                                    CursorOn    : BOOLEAN       );
VAR
    mode1           : avidmode;
    mode2           : avidmode;
    s2              : ARRAY [0..79] OF CHAR;
    Length          : CARDINAL;

BEGIN
    mode1 := VideoMode;
    mode2 := VideoMode;
    IF (MatchCount > 0) THEN
        mode1 := videobright;
    END;

    IF (CursorOn) THEN
        IF (CursorMode = videorestingcursor) THEN
            mode1 := CursorMode;
            mode2 := CursorMode;
        ELSIF (MatchCount > 0) THEN
            mode1 := videoenhance;
            mode2 := cvideoenhance;
        ELSE
            INC (mode2);
        END;
    END;

    Length := LengthOf(s);

    SubStr (s, s2, 1, MatchCount);
    PutString (s2, x, y, mode1);
    SubStr (s, s2, 1+MatchCount, Length-MatchCount);
    PutString (s2, x+MatchCount, y, mode2);

END PutMatchedString;




BEGIN
END MatchNames.
