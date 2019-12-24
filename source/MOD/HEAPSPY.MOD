MODULE HeapSpy;

(*  =========================================================================
    Last Edit : August 13, 1990 3:30PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        check the heap numbers.

    MODIFICATION HISTORY:

    =========================================================================
*)


FROM BTStorage      IMPORT
                        AStorageProc, ALLOCATE, DEALLOCATE;

FROM Dialog         IMPORT
    (* PROC *)          Message, Error, Barf;

FROM Edges          IMPORT
    (* TYPE *)          AnEdge;

FROM FlexData       IMPORT
    (* TYPE *)          ACellBlock;

FROM Kbio           IMPORT
    (* TYPE *)          avidmode,
    (* PROC *)          PutString;

IMPORT Keyboard;

FROM LStrings       IMPORT
    (* PROC *)          SetString, ConcatS, ConcatLS, CtoS, Procustes, RJust;

FROM Overlays       IMPORT
    (* TYPE *)          AnOverlayID,
    (* PROC *)          ImALockedOverlay, InstallNewProcedure;

FROM OvTree        IMPORT
    (* TYPE *)          AnOverlayProc;

FROM RsrcMod        IMPORT
    (* TYPE *)          AResource;

FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS, BYTE,
    (* PROC *)          ADR, TSIZE, DOSCALL;



CONST
    SmallPointOfThingsToWatch = 50;
    MidPointOfThingsToWatch   = 500;

    MagicModeKey      = 253;
    ResetKey          = 251;

    CreateAFile       = 3CH;
    OpenAFile         = 3DH;
    NormalAttribute   = 00H;
    CloseFile         = 3EH;
    WriteRecord       = 40H;
    SetPos            = 42H;

  ReadWriteMode       =  2H;
  ExclusiveAccessMode = 10H; (* network functions available only in DOS 3.0 *)



TYPE
    AThingToWatch = (Resources, Edges, Flexstor, TreeNodes, Trees,
                     OtherSmall, OtherMedium, OtherLarge);

    ASizeToWatch  = (LessThan, Equal, GreaterThan);



(*$A+*)
    AWatchRecord = RECORD
        SizeOfItem  : CARDINAL;
        SizeToWatch : ASizeToWatch;
        Allocates   : CARDINAL;
        Deallocates : CARDINAL;
        TotalBytes  : REAL;
    END;
(*$A=*)


    XTreeRecord       =       RECORD
                                Methods     : ADDRESS;
                                Header      : ADDRESS;
                                Parent      : ADDRESS;
                              END;


    ATreeNodeAttribute = (Select0, Select1, Select2, Select3,
                          SelfVisible, PrivateSelfVisible, ChildrenVisible,
                          TypeThroughEnable, SelfMatch, ChildrenMatch,
                          TempFlag1, TempFlag2, TempFlag3, TempFlag4,
                          TempFlag5, TempFlag6);

    AnAttributeSet = SET OF ATreeNodeAttribute;

    XTreeNodeRecord   =       RECORD
                                Methods     : ADDRESS;
                                HeaderFlag  : BOOLEAN;
                                Level       : BYTE;
                                Next        : ADDRESS;
                                Prev        : ADDRESS;
                                DataObject  : ADDRESS;
                                Subtree     : ADDRESS;
                                Attributes  : AnAttributeSet;
                              END;

VAR
    OverlayID               : AnOverlayID;

    OldALLOCATE,
    OldDEALLOCATE           : AStorageProc;
    OldGetCode              : Keyboard.AGetCodeProcedure;

    ThingsToWatchFor        : ARRAY AThingToWatch OF AWatchRecord;

    LogHandle               : CARDINAL;
    Logging                 : BOOLEAN;




PROCEDURE OurGetCode():CARDINAL;
VAR
    Code          : CARDINAL;
BEGIN
    LOOP
        Code := OldGetCode();
        IF (Code = MagicModeKey) THEN
            DoMenu();
        ELSIF (Code = ResetKey) THEN
            Init();
            Barf; Barf;
        ELSE
            RETURN Code;
        END;
    END;
END OurGetCode;




PROCEDURE WriteLog( VAR s            : ARRAY OF CHAR;
                        AlsoToScreen : BOOLEAN;
                    VAR ScreenY      : CARDINAL );
CONST
    BreakLineDefault = 374C;
VAR
    i,
    ErrorCode,
    XferedBytes : CARDINAL;
    s1          : ARRAY [0..5] OF CHAR;


    PROCEDURE WriteByte( B : CHAR );
    BEGIN
        IF (Logging) THEN
            DOSCALL( WriteRecord, LogHandle, 1, ADR(B),
                     XferedBytes, ErrorCode );
            IF (ErrorCode <> 0) OR (XferedBytes < 1) THEN
                CtoS( ErrorCode, s1 );
                SetString(s, "Error writing to LOG:");
                ConcatLS( s, s1 );
                Error(s);
                CloseLog();
            END;
        END;
    END WriteByte;


BEGIN
    IF (AlsoToScreen) THEN
        INC(ScreenY);
        PutString( s, 0, ScreenY, videonormal );
    END;
    IF (Logging) THEN
        WriteByte( 15C );
        WriteByte( 12C );
        FOR i := 1 TO ORD(s[0]) DO
            IF (s[i] = BreakLineDefault) THEN
                WriteByte( 15C );
                WriteByte( 12C );
            ELSE
                WriteByte( s[i] );
            END;
        END;
    END;
END WriteLog;





PROCEDURE CloseLog();
VAR
    ErrorCode  : CARDINAL;
BEGIN
    IF (Logging) THEN
        DOSCALL( CloseFile, LogHandle, ErrorCode );
        Logging := FALSE;
    END;
END CloseLog;






PROCEDURE OpenLog();
VAR
    OHigh, OLow,
    High, Low,
    ErrorCode  : CARDINAL;
    s, s1      : ARRAY [0..23] OF CHAR;
BEGIN
    IF (NOT Logging) THEN
          (*  012345678901 *)
        s := "HEAPSPY.LOG ";
        s[11] := 0C;

        DOSCALL( OpenAFile, ADR( s ), ReadWriteMode + ExclusiveAccessMode, LogHandle, ErrorCode );
        IF (ErrorCode = 2) THEN
            DOSCALL( CreateAFile, ADR( s ), NormalAttribute, LogHandle, ErrorCode );
        ELSIF (ErrorCode = 0) THEN
            DOSCALL( SetPos, LogHandle, 2, 0, 0, High, Low, ErrorCode );
            DOSCALL( SetPos, LogHandle, 0, High, Low, OHigh, OLow, ErrorCode );
        END;
        IF (ErrorCode <> 0) THEN
            CtoS( ErrorCode, s1 );
            SetString(s, "Error opening LOG:");
            ConcatLS( s, s1 );
            Error(s);
            Logging := FALSE;
        ELSE
            Logging := TRUE;
        END;
    END;
END OpenLog;






PROCEDURE DoMenu();
CONST
    AlsoToScreen  = TRUE;
VAR
    ScreenY       : CARDINAL;
    i             : AThingToWatch;
    s             : ARRAY [0..255] OF CHAR;

    PROCEDURE CtoR( VAR Text : ARRAY OF CHAR; C : CARDINAL; Width : CARDINAL );
    VAR
        s1        : ARRAY [0..19] OF CHAR;
    BEGIN
        CtoS( C, s1 );
        Procustes( s1, Width );
        RJust(s1);
        ConcatLS( Text, s1 );
    END CtoR;

BEGIN

    ScreenY := 0;
    OpenLog();

    SetString( s, "(Press ALT-251 to reset counters)" );
    Message(s);

    SetString( s, "Heap Items   Allocates  Deallocates  Size each  Paragraphs " );
    WriteLog( s, AlsoToScreen, ScreenY );
    SetString( s, "----------   ---------  -----------  ---------  ---------- " );
    WriteLog( s, AlsoToScreen, ScreenY );

    FOR i := MIN(AThingToWatch) TO MAX(AThingToWatch) DO
        WITH ThingsToWatchFor[i] DO
            CASE i OF
                Resources   : SetString( s, "Resources" );
              | Edges       : SetString( s, "Edges" );
              | Flexstor    : SetString( s, "Flexstor" );
              | TreeNodes   : SetString( s, "TreeNodes" );
              | Trees       : SetString( s, "Trees    " );
              | OtherSmall  : SetString( s, "  <  50" );
              | OtherMedium : SetString( s, "  < 500" );
              | OtherLarge  : SetString( s, " >= 500" );
            ELSE
                HALT;
            END;
            Procustes( s, 12 );
            ConcatS( s, ":" );
            CtoR( s, Allocates, 9 );
            ConcatS( s, "  " );
            CtoR( s, Deallocates, 11 );
            ConcatS( s, "  " );
            CtoR( s, SizeOfItem, 9 );
            ConcatS( s, "  " );
            CtoR( s, TRUNC( (TotalBytes / 16.0) + 0.51), 10 );
        END;
        WriteLog( s, AlsoToScreen, ScreenY );
    END;

    CloseLog();

END DoMenu;






PROCEDURE CountSize( Allocate : BOOLEAN;  Size : CARDINAL );
VAR
    i   : AThingToWatch;


    PROCEDURE Matches( i : AThingToWatch ) : BOOLEAN;
    BEGIN

        WITH ThingsToWatchFor[i] DO

            RETURN

                (((SizeOfItem  = Size) AND
                  (SizeToWatch = Equal)) OR
                 ((SizeOfItem  < Size) AND
                  (SizeToWatch = LessThan)) OR
                 ((SizeOfItem  > Size) AND
                  (SizeToWatch = GreaterThan)));
        END;

    END Matches;


BEGIN
    (* This algorithem assumes all cases possible are covered.
    *)
    i := MIN(AThingToWatch);
    WHILE (i < MAX(AThingToWatch)) AND
          (NOT Matches( i ))       DO
        INC(i);
    END;

    WITH ThingsToWatchFor[i] DO
        IF (Allocate) THEN
            INC(Allocates);
            TotalBytes := TotalBytes + FLOAT(Size);
        ELSE
            INC(Deallocates);
            TotalBytes := TotalBytes - FLOAT(Size);
        END;
    END;
END CountSize;






PROCEDURE XALLOCATE( VAR A : ADDRESS; size : CARDINAL );
BEGIN
    CountSize( TRUE, size );

    OldALLOCATE( A, size );

END XALLOCATE;


PROCEDURE XDEALLOCATE( VAR A : ADDRESS; size : CARDINAL );
BEGIN
    CountSize( FALSE, size );

    OldDEALLOCATE( A, size );

END XDEALLOCATE;




PROCEDURE ShutDown();
BEGIN
END ShutDown;




(* THIS PROC IS CALLED WHENEVER AN ALT-251 IS PRESSED !!!
*)
PROCEDURE Init();
VAR
    i   : AThingToWatch;
BEGIN
    FOR i := MIN(AThingToWatch) TO MAX(AThingToWatch) DO
        WITH ThingsToWatchFor[i] DO
            Allocates   := 0;
            Deallocates := 0;
            SizeToWatch := Equal;
            TotalBytes  := 0.0;
        END;
    END;
    ThingsToWatchFor[Resources].SizeOfItem   := TSIZE(AResource);
    ThingsToWatchFor[Edges].SizeOfItem       := TSIZE(AnEdge);
    ThingsToWatchFor[Flexstor].SizeOfItem    := TSIZE(ACellBlock);
    ThingsToWatchFor[TreeNodes].SizeOfItem   := TSIZE(XTreeNodeRecord);
    ThingsToWatchFor[Trees].SizeOfItem       := TSIZE(XTreeRecord);

    ThingsToWatchFor[OtherSmall].SizeOfItem  := SmallPointOfThingsToWatch;
    ThingsToWatchFor[OtherSmall].SizeToWatch := LessThan;

    ThingsToWatchFor[OtherMedium].SizeOfItem  := MidPointOfThingsToWatch;
    ThingsToWatchFor[OtherMedium].SizeToWatch := LessThan;

    ThingsToWatchFor[OtherLarge].SizeOfItem  := MidPointOfThingsToWatch-1;
    ThingsToWatchFor[OtherLarge].SizeToWatch := GreaterThan;

END Init;




BEGIN
    InstallNewProcedure(ADR(Keyboard.GetAnyCode),PROC(OurGetCode), ADR(OldGetCode));
    InstallNewProcedure( ADR(ALLOCATE),  PROC(XALLOCATE),  ADR(OldALLOCATE));
    InstallNewProcedure( ADR(DEALLOCATE),PROC(XDEALLOCATE),ADR(OldDEALLOCATE));
    OverlayID := ImALockedOverlay( AnOverlayProc(NIL), ShutDown );
    Init();
    Logging := FALSE;
END HeapSpy.

