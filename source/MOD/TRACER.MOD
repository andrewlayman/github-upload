IMPLEMENTATION MODULE Tracer;


FROM Codes        IMPORT ACode;
FROM Dialog IMPORT MessageBox, ContinuationBox, ADialogOption;
FROM Kbio   IMPORT KeyPress, GetAnyCode;
FROM Keys   IMPORT CancelKey;
FROM LStrings  IMPORT   SetString, ConcatS, ConcatLS, CtoS, Compare,
                        SubStr, Fill, TrimFront, Copy, Procustes;
FROM PrintSupport           IMPORT
    (* VAR   *)                 Stopped,
    (* PROC  *)                 AllowLeftMargin, PageWidth, PrintLine,
                                PrintText, EndReport, StartReport,
                                RowsLeft, AllowUnlimitedPageLength,
                                GetCurrentPrintRow, StartPage;


VAR
   Displaying : BOOLEAN;
   Printing   : BOOLEAN;
   Initialized : BOOLEAN;
   Title : ARRAY [0..15] OF CHAR;
PROCEDURE Init();
VAR 
    S : ARRAY [0..255] OF CHAR;
BEGIN
    SetString(S,"Display trace messages on the screen?");
    Displaying := ContinuationBox(S,Title,NoHelp);
    SetString(S,"Print trace messages?");
    Printing := ContinuationBox(S,Title,NoHelp);
    IF (Printing) THEN
        Printing := StartReport();
    END;
    Initialized := TRUE;
END Init;





PROCEDURE PrintString( VAR S : ARRAY OF CHAR );
VAR
    C : ACode;
BEGIN
    IF (NOT Initialized) THEN
        Init();
    END;

    IF (Displaying) THEN
        MessageBox(S,Title);
        C := GetAnyCode();
        IF (C = CancelKey) THEN
            EndTrace();
            Init();
        END;
    END;

    IF (Printing) THEN
       PrintLine(S,0);
    END;
END PrintString;    
    




PROCEDURE EndTrace();
BEGIN
    IF (Initialized) THEN
       IF (Printing) THEN
           EndReport(); 
       END;
    END;
    Initialized := FALSE;
END EndTrace;






BEGIN
    Initialized := FALSE;
    SetString(Title,"Tracer");
END Tracer.
