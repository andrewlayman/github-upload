MODULE TLTrace;

(*  =========================================================================
    Last Edit : March 28, 1991 3:52PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Write traces when a certain debugging toggle is on.

    MODIFICATION HISTORY:

        RSC 28-Mar-91  First version.

    =========================================================================
*)


FROM LStrings       IMPORT
    (* PROC *)          SetString;

FROM Overlays       IMPORT
    (* TYPE *)          AnOverlayID,
    (* PROC *)          ImALockedOverlay, InstallNewProcedure;

FROM OvTree         IMPORT
    (* TYPE *)          AnOverlayProc;

FROM ParmLine       IMPORT
    (* PROC *)          GetOption;

FROM SYSTEM         IMPORT
    (* PROC *)          DOSCALL, ADR;

FROM Trace          IMPORT
    (* VAR  *)          TraceIsOn,
    (* PROC *)          TraceTString;










(* Write a trace message on the disk file "Trace.Log".
*)
PROCEDURE XTraceTString( s : ARRAY OF CHAR );
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
    s1          : ARRAY [0..13] OF CHAR;


    PROCEDURE WriteByte( B : CHAR );
    VAR
        XferedBytes : CARDINAL;
    BEGIN
        DOSCALL( WriteRecord, LogHandle, 1, ADR(B),
                 XferedBytes, ErrorCode );
    END WriteByte;

BEGIN
    IF (TraceMode) THEN
           (*  0123456789  *)
        s1 := "TRACE.LOG ";
        s1[9] := 0C;

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
            END;
            WriteByte( 15C );
            WriteByte( 12C );
            DOSCALL( CloseFile, LogHandle, ErrorCode );
        END;
    END;
END XTraceTString;


BEGIN

    InstallNewProcedure( ADR(TraceTString),  PROC(XTraceTString), NIL );

    OverlayID := ImALockedOverlay( AnOverlayProc(NIL), SetUpShutDown );

    SetString( s1, "TRACE" );
    GetOption( s1, TraceIsOn, s1 );

END TLTrace.

