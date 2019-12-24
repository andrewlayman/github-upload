MODULE TLTrace;

(*  =========================================================================
    Last Edit : June 26, 1991 5:52PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Write traces when a certain debugging toggle is on.

    MODIFICATION HISTORY:

        RSC 28-Mar-91  First version.
        RSC 17-Apr-91  Add stack tracing.
        RSC 26-Apr-91  Rather than use Trace in the root, install vectors
                       to monitor overlay activity.
        RSC  7-May-91  Beefed up some reporting:
                        - Report "overlay" id number on Term proc, which
                          could be 1 or 2, 1 in DeInstall, 2 otherwise
                        - Added hook for TermProc.
        RSC 12-Jun-91  Check on TermProc s when disposing.
        RSC 26-Jun-91  Added ALT-252 as a "take a stack dump" key.
        LAA 13-Aug-91  Added a time stamp to each report of a notice.
    =========================================================================
*)

FROM Clock          IMPORT
    (* TYPE *)          ASystemTime,
    (* PROC *)          GetDateAndTime;

FROM Dialog         IMPORT
    (* PROC *)          Error, Barf, FatalError;

FROM FileAux        IMPORT
    (* PROC *)          EXEPath;

FROM Kbio           IMPORT
    (* PROC *)          BreakRequested;

FROM Keyboard       IMPORT
    (* TYPE *)          AGetCodeProcedure,
    (* PROC *)          GetAnyCode;

FROM Kluges         IMPORT
    (* PROC *)          ThingsWeForgot;

FROM LStrings       IMPORT
    (* PROC *)          SetString, CtoS, LStringToTString, ConcatLS,
                        SetLengthOf, StringsEqual, Upshift, ConcatS,
                        TStringToLString, Insert, Copy, Procustes, RJust;

FROM Notices        IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          RegisterForNotices;

FROM Overlays       IMPORT
    (* TYPE *)          AnOverlayID,
    (* PROC *)          ImALockedOverlay, InstallNewProcedure;

FROM OVSwap         IMPORT
    (* TYPE *)          AFlushOverlayProc, ASwapInProc, ASwapOutProc,
    (* PROC *)          FlushOverlay, SwapOut, SwapIn;

FROM OvTree         IMPORT
    (* TYPE *)          AnOverlayProc, AContextListEntry, AResidenceWhere,
                        AResidence,
    (* VAR *)           OverlayTree,
    (* PROC *)          FindWhere;

FROM ParmLine       IMPORT
    (* PROC *)          GetOption;

FROM Stack          IMPORT
    (* PROC *)          Dump;

FROM RTSMain        IMPORT
    (* TYPE *)          RTDProc, OverlayPtr,
    (* VAR  *)          debuggerRecord;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATreeNode;

FROM SYSTEM         IMPORT
    (* TYPE *)          PROCESS, ADDRESS,
    (* PROC *)          DOSCALL, ADR;




CONST
    FileName = "TRACE.LOG";


VAR
    OverlayID       : AnOverlayID;

    OldFlushOverlay : AFlushOverlayProc;
    OldSwapOut      : ASwapOutProc;
    OldSwapIn       : ASwapInProc;
    OldGetCode      : AGetCodeProcedure;

    OldbeforeInit   : RTDProc;
    OldbeforeExit   : RTDProc;
    OldbeforeTermProc : RTDProc;

    Depth           : CARDINAL;
    Pushes          : CARDINAL;
    DumpString      : ARRAY [0..79] OF CHAR;




PROCEDURE XGetCode():CARDINAL;
CONST
    DeathKey = 252;
VAR
    Code    : CARDINAL;
BEGIN
    LOOP
        Code := OldGetCode();
        IF (Code <> DeathKey) THEN
            EXIT;
        END;
        DumpStack();
    END;

    RETURN Code;

END XGetCode;





    (* Trace T String  - Given a null-terminated string, write it out
                         to the trace log if tracing is on.

        Preconditions  - none.
        Postconditions - the message has been written to the trace log
                         file if tracing is on.
    *)
PROCEDURE TraceTString( s   : ARRAY OF CHAR );
VAR
    LString : ARRAY [0..255] OF CHAR;
BEGIN

    TStringToLString( s, LString );
    TraceLString( LString );

END TraceTString;





    (* Trace T And L String - Given a TString and an LString,
               print the TString followed
               by the LString to the trace log if tracing is on.

        Preconditions  - none.
        Postconditions - the message has been written to the trace log
                         file if tracing is on.
    *)
PROCEDURE TraceTAndLString(     TString    : ARRAY OF CHAR;
                            VAR LString    : ARRAY OF CHAR );
VAR
    String : ARRAY [0..255] OF CHAR;
BEGIN

    TStringToLString( TString, String );
    ConcatLS(         String, LString );
    TraceLString( String );

END TraceTAndLString;




PROCEDURE DumpStack();
VAR
    i   : CARDINAL;
    s1  : ARRAY [0..9] OF CHAR;
BEGIN
    FOR i := 1 TO 2 DO
        s1[i] := EXEPath[i];
    END;
    s1[0] := 2C;
    ConcatS( s1, "\MAP\" );
    Barf();
    Dump(s1,TraceLString);   (* 17-Apr-91 RSC YYEEEEAAAAHOOOOO!! *)
    Barf();
    IF (BreakRequested()) THEN
        HALT;
    END;
END DumpStack;




(* Write a trace message on the disk file "Trace.Log".
*)
PROCEDURE TraceLString( VAR s : ARRAY OF CHAR );
CONST
    CreateAFile         = 3CH;
    OpenAFile           = 3DH;
    CloseFile           = 3EH;
    WriteRecord         = 40H;
    SetPos              = 42H;
    NormalAttribute     = 00H;
    ReadWriteMode       =  2H;
    ExclusiveAccessMode = 10H;

VAR
    High, Low,
    OHigh, OLow,
    i,
    LogHandle,
    ErrorCode   : CARDINAL;
    s1          : ARRAY [0..99] OF CHAR;


    PROCEDURE WriteByte( B : CHAR );
    VAR
        XferedBytes : CARDINAL;
    BEGIN
        DOSCALL( WriteRecord, LogHandle, 1, ADR(B),
                 XferedBytes, ErrorCode );
    END WriteByte;

BEGIN
    INC(Depth);

    SetString( s1, FileName );
    LStringToTString( s1, s1 );

    DOSCALL( OpenAFile, ADR( s1 ), ReadWriteMode + ExclusiveAccessMode, LogHandle, ErrorCode );
    IF (ErrorCode = 2) THEN
        DOSCALL( CreateAFile, ADR( s1 ), NormalAttribute, LogHandle, ErrorCode );
    ELSIF (ErrorCode = 0) THEN
        DOSCALL( SetPos, LogHandle, 2, 0, 0, High, Low, ErrorCode );
        DOSCALL( SetPos, LogHandle, 0, High, Low, OHigh, OLow, ErrorCode );
    END;
    IF (ErrorCode <> 0) THEN
        CtoS( ErrorCode, s1 );
        SetString(s, "Error opening LOG:");
        ConcatLS( s, s1 );
        Error(s);
    ELSE
        FOR i := 1 TO ORD(s[0]) DO
            WriteByte( s[i] );
            s1[i] := CAP(s[i]);  (* upshift a copy *)
        END;
        s1[0] := s[0];
        WriteByte( 15C );
        WriteByte( 12C );
        DOSCALL( CloseFile, LogHandle, ErrorCode );
        IF (Depth = 1) AND (StringsEqual( s1, DumpString )) THEN
            DumpStack();
        END;
    END;

    DEC(Depth);

END TraceLString;


PROCEDURE GetCurrentTime( VAR TimeString    : ARRAY OF CHAR );

VAR
    Time                    : ASystemTime;
    s                       : ARRAY [0..15] OF CHAR;

BEGIN                       (* GetCurrentTime *)

    GetDateAndTime( Time );
    CtoS( Time.SysHour, TimeString );
    ConcatS( TimeString, ":" );
    CtoS( Time.SysMinute, s );
    ConcatLS( TimeString, s );
    ConcatS( TimeString, ":" );
    CtoS( Time.SysSecond, s );
    ConcatLS( TimeString, s );

END GetCurrentTime;
 



PROCEDURE NoticeCatcher ( Occasion : AnOccasion;
                          Step     : AStep;
                          Context  : ADDRESS ) : BOOLEAN;
VAR
    OvContext : AContextListEntry;
    s         : ARRAY [0..99] OF CHAR;
    s1        : ARRAY [0..15]  OF CHAR;
BEGIN
    IF (Context <> NIL) THEN
        OvContext := Context;
        s[0] := 0C;
        IF (Step = BeforeActing) THEN
            SetString( s, "Call  :" );
        ELSIF (Step = AfterActing) THEN
            SetString( s, "Return:" );
        ELSIF (Step = FailureToAct) THEN
            SetString( s, "FAILED:" );
        END;
        IF (s[0] <> 0C) THEN
            ConcatLS( s, OvContext^.OverlayName );
            CtoS( OvContext^.UseCount, s1 );
            ConcatS( s, " (" );
            ConcatLS( s, s1 );
            ConcatS( s, ")" );
            ConcatS( s, " at " );
            GetCurrentTime( s1 );
            ConcatLS( s, s1 );
            TraceLString(s);
        END;
    END;

    RETURN TRUE;

END NoticeCatcher;






PROCEDURE AtoH( A : ADDRESS; VAR s : ARRAY OF CHAR );
VAR
    SLen,
    i   : CARDINAL;
    Hex : ARRAY [0..17] OF CHAR;
    s1  : ARRAY [0..1]  OF CHAR;

    PROCEDURE CtoH(C : CARDINAL);
    VAR
        i   : CARDINAL;
    BEGIN
        FOR i := 1 TO 4 DO
            s1[1] := Hex[(C MOD 16)+1];
            C     := (C DIV 16);
            Insert( s, s1, 1 );
        END;
    END CtoH;

BEGIN
    SetLengthOf(s,0);
    SetLengthOf(s1,1);
    SetString(Hex,"0123456789ABCDEF" );
    CtoH( A.OFFSET  );
    s1[1] := ":";
    Insert( s, s1, 1 );
    CtoH( A.SEGMENT );
END AtoH;








PROCEDURE XSwapOut(     Critical         : BOOLEAN;
                    VAR Where            : AResidenceWhere;
                        TheSizeToSwap    : CARDINAL;
                        FromHere         : ADDRESS ) : BOOLEAN;
VAR
    s1  : ARRAY [0..19] OF CHAR;
    ok  : BOOLEAN;


    PROCEDURE GetOverlayName(     LayerAddr : ADDRESS;
                              VAR Name      : ARRAY OF CHAR );

    VAR
        ContextPtr          : AContextListEntry;
        CurrentNode         : ATreeNode;


        PROCEDURE InLayer(     Node             : ATreeNode;
                               LayerAddr        : ADDRESS   ) : BOOLEAN;

        VAR
            ContextPtr          : AContextListEntry;

        BEGIN                   (* InLayer *)

            IF (Node <> ATreeNode(NIL)) THEN
                ContextPtr := Node^.Methods^.GetDataObject( Node );
                IF (ContextPtr = NIL) THEN FatalError(); END;
                WITH ContextPtr^ DO
                    IF ((Residence = InMainMemory)
                       AND (ADDRESS(OverlayLayerAddr) = LayerAddr)) THEN
                        RETURN TRUE;
                    END;
                END;
            END;

            RETURN FALSE;

        END InLayer;

    BEGIN                   (* GetOverlayName *)
        CurrentNode := OverlayTree^.Methods^.GetFirst (OverlayTree);
        WHILE (CurrentNode <> NIL) DO
            IF (InLayer( CurrentNode, LayerAddr )) THEN
                ContextPtr := CurrentNode^.Methods^.GetDataObject( CurrentNode );
                Copy( ContextPtr^.OverlayName, Name );
                RETURN;
            END;
            CurrentNode := CurrentNode^.Methods^.NextPreOrder( CurrentNode );
        END;

        SetString( Name, "UNKNOWN" );

    END GetOverlayName;

    PROCEDURE Trace( Text : ARRAY OF CHAR );
    VAR
        s   : ARRAY [0..99] OF CHAR;
        s2  : ARRAY [0..13] OF CHAR;
    BEGIN
        SetString( s, Text );
        GetOverlayName( FromHere, s2 );
        Procustes( s2, 13 );
        ConcatLS( s, s2 );
        ConcatS( s, " From " );
        AtoH( FromHere, s1 );
        Procustes( s1, 10 );
        RJust( s1 );
        ConcatLS( s, s1 );
        ConcatS( s, ", Size: " );
        CtoS( TheSizeToSwap, s1 );
        ConcatLS( s, s1 );

        TraceLString( s );

    END Trace;

BEGIN
    IF (Critical) THEN
        Trace( "Push     " );
    ELSE
        Trace( "Cache    " );
    END;

    ok := OldSwapOut( Critical, Where, TheSizeToSwap, FromHere );

    IF (ok) THEN
        CASE Where.Residence OF
            InXms       : TraceTString( "(into Xms)" );
          | InEms       : TraceTString( "(into Ems)" );
          | InFlexStor  : TraceTString( "(into FlexStor)" );
          | InMainMemory: TraceTString( "(into MainMem)" );
        ELSE
            TraceTString( "(into ????)" );
        END;
    ELSE
        TraceTString( "(FAILED (not enough room?))" );
    END;

    RETURN ok;

END XSwapOut;







PROCEDURE XSwapIn(     Discard          : BOOLEAN;
                   VAR Where            : AResidenceWhere;
                   VAR TheSizeSwapped   : CARDINAL;
                       ToHere           : ADDRESS );
VAR
    s1  : ARRAY [0..19] OF CHAR;


    PROCEDURE GetOverlayName(     Where     : AResidenceWhere;
                              VAR Name      : ARRAY OF CHAR  );

    VAR
        ContextPtr          : AContextListEntry;
        CurrentNode         : ATreeNode;


        PROCEDURE ItMatches(     ContextPtr : AContextListEntry ;
                                 Where      : AResidenceWhere    ) : BOOLEAN;

        VAR
            Match               : BOOLEAN;

        BEGIN                   (* ItMatches *)

            Match := FALSE;
            IF (ContextPtr = NIL) THEN FatalError(); END;
            WITH ContextPtr^ DO
                IF (Where.Residence = ResidentWhere.Residence) THEN
                    CASE Where.Residence OF
                        InMainMemory :
                            Match := (Where.Address 
                                      = ResidentWhere.Address);
                    |   InEms :
                            Match := (Where.EMSHandle 
                                      = ResidentWhere.EMSHandle);
                    |   InXms :
                            Match := (Where.XMSStartingByte 
                                      = ResidentWhere.XMSStartingByte);
                    |   InFlexStor :
                            Match := (Where.FlexStorHandle
                                      = ResidentWhere.FlexStorHandle);
                    ELSE
                        FatalError();
                    END;
                END;
            END;

            RETURN Match;

        END ItMatches;

    BEGIN                   (* GetOverlayName *)

        CurrentNode := OverlayTree^.Methods^.GetFirst (OverlayTree);
        WHILE (CurrentNode <> NIL) DO
            ContextPtr := CurrentNode^.Methods^.GetDataObject( CurrentNode );
            IF (ItMatches( ContextPtr, Where )) THEN
                Copy( ContextPtr^.OverlayName, Name );
                RETURN;
            END;
            CurrentNode := CurrentNode^.Methods^.NextPreOrder( CurrentNode );
        END;

        IF (FindWhere( Where, ContextPtr )) THEN
            Copy( ContextPtr^.OverlayName, Name );
            RETURN;
        END;

        SetString( Name, "UNKNOWN" );

    END GetOverlayName;

    PROCEDURE Trace( Text : ARRAY OF CHAR );
    VAR
        s   : ARRAY [0..99] OF CHAR;
        s2  : ARRAY [0..13] OF CHAR;
    BEGIN
        SetString( s, Text );
        GetOverlayName( Where, s2 );
        Procustes( s2, 13 );
        ConcatLS( s, s2 );
        ConcatS( s, " To    " );
        AtoH( ToHere, s1 );
        ConcatLS( s, s1 );
        ConcatS( s, ", (from " );
        CASE Where.Residence OF
            InXms   : ConcatS( s, "Xms" );
          | InEms   : ConcatS( s, "Ems" );
          | InFlexStor : ConcatS( s, "FlexStor" );
          | InMainMemory : ConcatS( s, "MainMem" );
        ELSE
            ConcatS( s, "UNKNOWN RESIDENCE (" );
            CtoS( ORD(Where.Residence), s1 );
            ConcatLS( s, s1 );
            ConcatS( s, ")" );
        END;
        ConcatS( s, ")" );

        TraceLString( s );

    END Trace;

BEGIN
    IF (Discard) THEN
        Trace( "Pop      " );
    ELSE
        Trace( "Swap     " );
    END;

    OldSwapIn( Discard, Where, TheSizeSwapped, ToHere );

END XSwapIn;








PROCEDURE ExitAndTermCommon( OP : OverlayPtr; WhichProc : ARRAY OF CHAR );
VAR
    A1, A2  : ADDRESS;
    s       : ARRAY [0..79] OF CHAR;
    s1      : ARRAY [0..9]  OF CHAR;
BEGIN
    TStringToLString( OP^.overlayName, s );

    CASE OP^.overlay OF
        1: ConcatS(s, ": De Install" );
           A1 := OP^.termProc;
           IF (A1 <> NIL) THEN
               ConcatS(s, ", TERM PROC(S): First is " );
               AtoH( A1, s1 );
               ConcatLS( s, s1 );
               A2 := ADDRESS( InstallNewProcedure );
               IF (A1.SEGMENT = A2.SEGMENT) THEN
                   ConcatS( s, " (in Overlay.Mod)" );
               END;
           END;

      | 2: (* NOTHING *)
    ELSE
        ConcatS( s, ":" );
        CtoS( OP^.overlay, s1 );
        ConcatLS( s, s1 );
    END;

    TraceTAndLString( WhichProc, s );

END ExitAndTermCommon;


PROCEDURE XbeforeTermProc( P : PROCESS; A : ADDRESS );
BEGIN
    ExitAndTermCommon( OverlayPtr(A), "Term " );
    OldbeforeTermProc( P, A );
END XbeforeTermProc;


PROCEDURE XbeforeExit( P : PROCESS; A : ADDRESS );
BEGIN
    ExitAndTermCommon( OverlayPtr(A), "Exit " );
    OldbeforeExit( P, A );
END XbeforeExit;


PROCEDURE XbeforeInit( P : PROCESS; A : ADDRESS );
BEGIN
    ExitAndTermCommon( OverlayPtr(A), "Init " );
    OldbeforeInit( P, A );
END XbeforeInit;





PROCEDURE OurThingsWeForgotProc( Message : CARDINAL;
                             VAR Context : ADDRESS   ) : BOOLEAN;
VAR
    Entry   : AContextListEntry;
    String  : POINTER TO ARRAY [0..255] OF CHAR;
    s       : ARRAY [0..99] OF CHAR;
    s1      : ARRAY [0..9]  OF CHAR;
BEGIN
    Entry := Context;

    CASE Message OF
        1: SetString( s, "PUSH (" );
           INC(Pushes);
           CtoS( Pushes, s1 );
           ConcatLS(  s, s1 );
           ConcatS(   s, ") ");
           ConcatLS(  s, Entry^.OverlayName );
           TraceLString( s );

      | 2: SetString( s, "POP (" );
           CtoS( Pushes, s1 );
           ConcatLS(  s, s1 );
           ConcatS(   s, ") ");
           DEC(Pushes);
           ConcatLS(  s, Entry^.OverlayName );
           ConcatS(   s, "  (making room...)" );
           TraceLString( s );

      | 3: SetString( s, "   done making room for " );
           ConcatLS(  s, Entry^.OverlayName );
           TraceLString( s );

      | 4: String := Context;
           TraceLString( String^ );
    ELSE
    END;

    RETURN TRUE;

END OurThingsWeForgotProc;







PROCEDURE InitTLTrace();
CONST
    DeleteFile  = 41H;
VAR
    ErrorCode   : CARDINAL;
    s1          : ARRAY [0..255] OF CHAR;
    Found       : BOOLEAN;
BEGIN

    OverlayID := ImALockedOverlay( AnOverlayProc(NIL), AnOverlayProc(Shutdown) );
    InstallNewProcedure( ADR(FlushOverlay), PROC(XFlushOverlay), ADR(OldFlushOverlay) );
    InstallNewProcedure( ADR(SwapOut),      PROC(XSwapOut),      ADR(OldSwapOut)      );
    InstallNewProcedure( ADR(SwapIn),       PROC(XSwapIn),       ADR(OldSwapIn)       );

    (* 26-Jun-91 RSC Added this:
    *)
    InstallNewProcedure( ADR(GetAnyCode),   PROC(XGetCode),      ADR(OldGetCode)      );

    RegisterForNotices(OverlayCall, NoticeCatcher );

    SetString( s1, FileName );
    LStringToTString( s1, s1 );

        (* Delete any old version of the file.  Ignore any errors,
           as the file may not exist anyway.
        *)
    DOSCALL( DeleteFile, ADR(s1), ErrorCode );

    Depth       := 0;
    Pushes      := 0;

    SetString( s1, "DUMP" );
    GetOption( s1, Found, DumpString );
    IF (NOT Found) THEN
        SetLengthOf( DumpString, 0 );
    END;

    WITH debuggerRecord DO
        OldbeforeInit   := beforeInitCode;
        beforeInitCode  := XbeforeInit;
        OldbeforeExit   := beforeExit;
        beforeExit      := XbeforeExit;
(*        OldbeforeTermProc := beforeTermProc;*)
(*        beforeTermProc  := XbeforeTermProc;*)
    END;

    ThingsWeForgot := OurThingsWeForgotProc;    (* 8-May-91 RSC *)

    SetString(s1, "TLTRACE Active - Use ALT-252 to take a stack dump" );
    ConcatS(  s1, " without halting the program.üStack dumps take a while; wait" );
    ConcatS(  s1, " for the second 'barf'.üYou need access to MAPs in ");
    ConcatS(  s1, "<EXEDrive>\MAP\" );
    Error(s1);

END InitTLTrace;







PROCEDURE Shutdown();
BEGIN
    WITH debuggerRecord DO
        beforeInitCode    := OldbeforeInit;
        beforeExit        := OldbeforeExit;
(*        beforeTermProc    := OldbeforeTermProc;*)
    END;
END Shutdown;








(* 26-Apr-91 RSC Added these routines, stolen from the root.
*)
PROCEDURE XFlushOverlay( OverlayEntry : ATreeNode );
VAR
    Context                 : AContextListEntry;
BEGIN
    Context := OverlayEntry^.Methods^.GetDataObject( OverlayEntry );
    TraceTAndLString( "Flush:", Context^.OverlayName );

    OldFlushOverlay(OverlayEntry);  (* bye bye! *)

END XFlushOverlay;




BEGIN

    InitTLTrace();

END TLTrace.

