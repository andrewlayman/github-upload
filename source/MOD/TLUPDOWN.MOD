MODULE TLUpDown;

FROM Chainer                IMPORT 
    (* PROC *)                  Chain;

FROM Dialog                 IMPORT
                                Barf;

FROM Foreign                IMPORT
                                ACharacterConversionTable, 
                                ExpandStringToXLAT, ConvertedCharacter;

FROM LStrings               IMPORT
                                SetString;

FROM Overlays      IMPORT
    (* TYPE *)          AnOverlayID,  
    (* PROC *)          ImALockedOverlay, InstallNewProcedure;

FROM OvTree        IMPORT
    (* TYPE *)          AnOverlayProc;


FROM SYSTEM                 IMPORT
                                ADR, ADDRESS;

IMPORT Video;


TYPE
    AVideoOutputProc  = PROCEDURE ( VAR ARRAY OF CHAR, CARDINAL, CARDINAL, BITSET );
    AVideoCaptureProc = PROCEDURE ( CARDINAL,CARDINAL,CARDINAL,ADDRESS );
    AVideoPutAttributeProc = PROCEDURE( CARDINAL, CARDINAL, CARDINAL, BITSET );
VAR
    OverlayID                  : AnOverlayID;
    OldPutStringWithAttribute  : AVideoOutputProc;
    OldPutAttribute            : AVideoPutAttributeProc;
    OldGetImageLine            : AVideoCaptureProc;
    OldPutImageLine            : AVideoCaptureProc;
    TranslateTable             : ACharacterConversionTable;


CONST
    maxcol = 79;
    maxrow = 24;




                            
PROCEDURE Init();
CONST
    Reversed = "\0..\39)(\42..\90]\92[\94..\179ÃÆÇÓÔÌºÈÉÖÕÀ¿ÂÁ´ÄÅµ¶»¼ËÊ¹ÍÎÑÒÏÐ·¸¾½×ØÚÙ\219..\255";
VAR
    S : ARRAY [0..255] OF CHAR;
BEGIN
    SetString(S,Reversed);
    ExpandStringToXLAT(S,TranslateTable);

    InstallNewProcedure(ADR( Video.PutStringWithAttribute ),PROC(XPutStringWithAttribute),ADR(OldPutStringWithAttribute));
    InstallNewProcedure(ADR( Video.PutAttribute ),PROC(XPutAttribute),ADR(OldPutAttribute));
    InstallNewProcedure(ADR( Video.GetImageLine ),PROC(XGetImageLine),ADR(OldGetImageLine));
    InstallNewProcedure(ADR( Video.PutImageLine ),PROC(XPutImageLine),ADR(OldPutImageLine));
                                       
END Init;



PROCEDURE XPutStringWithAttribute     ( VAR s : ARRAY OF CHAR;
                                            x : CARDINAL;
                                            y : CARDINAL;
                                            a : BITSET );
VAR
    i,Len : CARDINAL;
    S : ARRAY [0..maxcol+1] OF CHAR;
BEGIN

        (* Reverse the string. *)
    Len := ORD(s[0]);
    IF (Len > HIGH(S)) THEN Len := HIGH(S); END; 
    S[0] := CHR(Len);
    FOR i := 1 TO Len DO
        S[i] := ConvertedCharacter(s[Len+1-i],TranslateTable);
    END;
    OldPutStringWithAttribute( S, maxcol+1-x-Len, maxrow-y, a); 
END XPutStringWithAttribute;


PROCEDURE XPutAttribute ( x     : CARDINAL;
                          y     : CARDINAL;
                          Count : CARDINAL;
                          a     : BITSET );
BEGIN
    OldPutAttribute( maxcol+1-Count-x, maxrow-y, Count, a);
END XPutAttribute;




PROCEDURE XGetImageLine(x:CARDINAL; y:CARDINAL; Count:CARDINAL;
                         Line : ADDRESS);
BEGIN
    OldGetImageLine( maxcol+1-Count-x, maxrow-y, Count, Line);
END XGetImageLine;


PROCEDURE XPutImageLine(x:CARDINAL; y:CARDINAL; Count:CARDINAL;
                         Line : ADDRESS);
BEGIN
    OldPutImageLine( maxcol+1-Count-x, maxrow-y, Count, Line);
END XPutImageLine;









PROCEDURE ShutDown();
BEGIN
    Barf();
END ShutDown;




BEGIN

    OverlayID := ImALockedOverlay( Init, ShutDown );

END TLUpDown.
