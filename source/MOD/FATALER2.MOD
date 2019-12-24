IMPLEMENTATION MODULE FatalErr;

(*$S+*)

    (* MODIFICATION HISTORY:

        03-Oct-88 RSC       - Split off from Dialog.Mod.  Shares Module #!
        11-Oct-88 RSC       - This source, FatalEr2.Mod, is for utility programs
                              that don't want all the stuff in TimeLine.
                              COMPILE IT LOCALLY AND LET THE COMPILER GRAB THIS
                              BEFORE THE DEFAULT ONE.
    *)


FROM Codes        IMPORT  ACode, ASetOfCodes, SetCodeBits, MaxCode;

FROM GaGa         IMPORT
        (* PROCS *)       GetGaGaMessage;

FROM Keyboard     IMPORT
        (* PROCS *)       GetAnyCode;

FROM RTSMain      IMPORT  Terminate, Status;

FROM Video        IMPORT
        (* PROCS *)       PutStringWithAttribute, TerminateVideoHardware,
                          MakeTone;








CONST
    ModuleNumber = 1600;  (* SAME AS DIALOG.MOD !! *)






PROCEDURE LocalNotify();
BEGIN
END LocalNotify;





PROCEDURE LocalFatalError();
CONST
    LineLength  = 52;
    CLineLength = VAL(CHAR,LineLength);
VAR
    i, j, k,
    Code    : CARDINAL;
    s       : ARRAY [ 0..71  ] OF CHAR;
    s1      : ARRAY [ 0..255 ] OF CHAR;

    PROCEDURE AddWordToMessage( Start, End : CARDINAL );
    VAR
        m,
        Length : CARDINAL;
    BEGIN
        Length := End - Start;

        INC(s[0]);  s[ORD(s[0])] := " "; (* Add a space *)

        IF ((Length + ORD(s[0])) > (LineLength - 2)) THEN
            WHILE (ORD(s[0]) < (LineLength - 1)) DO INC(s[0]); s[ORD(s[0])] := " "; END;
            s[LineLength] := "บ";
            s[0]          := CLineLength;
            PutStringWithAttribute( s, 15, i, BITSET( 07H ) );
            INC(i);
            s    := " บ";
            s[0] := 1C;
        END;

        FOR m := Start TO (End - 1) DO
            INC(s[0]);
            s[ORD(s[0])] := s1[m];
        END;
    END AddWordToMessage;

BEGIN
    FatalErrorNotify();

       (*  123456789 123456789 123456789 123456789 123456789 12 *)
    s := " ษออออออออออออออออออออออออออออออออออออออออออออออออออป";
    s[0] := CLineLength; (* Must match the above line! *)
    PutStringWithAttribute( s, 15, 7, BITSET( 07H ) );
    s := " บ                                                  บ";
    s[0] := CLineLength;
    PutStringWithAttribute( s, 15, 8, BITSET( 07H ) );

    i := 9;  (* Starting at row 9 *)
    s := " บ";
    s[0] := 1C;

    j := 1;

    GetGaGaMessage( ModuleNumber + 3, s1 ); (* <fatal error message> *)

    WHILE (j <= ORD(s1[0])) DO

        k := j;
        REPEAT INC(j) UNTIL (j > ORD(s1[0])) OR (s1[j]=" ");

        AddWordToMessage( k, j );

    END;

    WHILE (ORD(s[0]) < (LineLength - 1)) DO INC(s[0]); s[ORD(s[0])] := " "; END;
    s[LineLength] := "บ";
    s[0]          := CLineLength;
    PutStringWithAttribute( s, 15, i, BITSET( 07H ) );
    INC(i);

    s := " บ                                                  บ";
    s[0] := CLineLength;
    PutStringWithAttribute( s, 15,i, BITSET( 07H ) );
    INC(i);
    s := " ศออออออออออออออออออออออออออออออออออออออออออออออออออผ";
    s[0] := CLineLength;
    PutStringWithAttribute( s, 15,i, BITSET( 07H ) );

    MakeTone( 1000, 20 );
    MakeTone(  550, 40 );
    MakeTone(  300, 60 );

    Code := FatalErrorGetCode();

    TerminateVideoHardware();
    Terminate(Warning);

END LocalFatalError;











BEGIN
    FatalErrorGetCode := GetAnyCode;       (* Defaults *)
    FatalErrorNotify  := LocalNotify;
    FatalError        := LocalFatalError;
END FatalErr.
