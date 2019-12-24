MODULE ViReport;

    (* MODIFICATION HISTORY:

         2-Jan-89  RSC  Removed references to Compare() (not used).
        10-Aug-89  KKC  Add copyright message.
    *)

    FROM Dialog     IMPORT Burp, Message, Error, FatalError,
                           ContinuationBox, ADialogOption;

    FROM Kbio       IMPORT ascreenx, ascreeny, maxrow, maxcol, avidmode,
                           vidctrl;

    FROM LStrings   IMPORT SetString, SubStr, Procustes, CtoS, StoC,
                           ConcatS, ConcatLS, Insert, Remove, Fill,
                           LJust, RJust, Overlay, LStringToTString,
                           Upshift, Copy, SetLengthOf;

    FROM PrintSupport IMPORT StartReport, PrintLine, EndReport;

    FROM SYSTEM     IMPORT ADR, TSIZE;

    FROM Video      IMPORT PutStringWithAttribute, InitializeVideoHardware, (* 3/26/87 EGK *)
                           GetCursorType, SetCursorType;




PROCEDURE HexChar( N : CARDINAL ) : CHAR;
BEGIN
    IF (N <= 9) THEN
        RETURN CHR( ORD("0") + N );
    ELSIF (N <= 15) THEN
        RETURN CHR( ORD("A") + N - 10 );
    ELSE
        FatalError;
    END;
END HexChar;



PROCEDURE FormatHex( N : CARDINAL; VAR S: ARRAY OF CHAR);
BEGIN
  S[0] := 2C;
  S[2] := HexChar(N MOD 16);
  S[1] := HexChar(N DIV 16);
END FormatHex;




PROCEDURE ShowAllModes();
VAR
    S : ARRAY [0..2] OF CHAR;
    M : avidmode;
    i : CARDINAL;
    Attribute : BITSET;
    S80 : ARRAY [0..80] OF CHAR;
    Copyright               :   ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF (StartReport()) THEN ; END;

    Fill(S80," ",0);
    FOR i := 0 TO (ORD(MAX(avidmode)) DIV 2) DO
        M := VAL(avidmode,(i*2));
        FormatHex(CARDINAL(vidctrl[M]),S);
        ConcatLS(S80,S);
    END;
    PrintLine(S80,0);

    Fill(S80," ",0);
    FOR i := 0 TO (ORD(MAX(avidmode)) DIV 2) DO
        M := VAL(avidmode,(i*2)+1);
        FormatHex(CARDINAL(vidctrl[M]),S);
        ConcatLS(S80,S);
    END;
    PrintLine(S80,0);

    EndReport();

END ShowAllModes;




    (* --------- END MODULE CustomizedVideo  ---------------------*)



BEGIN
    ShowAllModes();

END ViReport.
