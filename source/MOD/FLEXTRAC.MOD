IMPLEMENTATION MODULE FlexTrace;

(*
    MODIFICATION HISTORY:

    12-Dec-89 RSC   Added MODAL parameter to menus.
    15-Dec-89 RSC   Removed GetAnyCode.
*)
FROM LStrings IMPORT
    (* PROC *)      SetString, ConcatS, ConcatLS, CtoS,
                    Overlay, Fill, Copy, Procustes, LengthOf, Search,
                    Remove, StoC;

FROM Dialog  IMPORT
    (* PROC *)      Error, FatalError, NotYetImplemented, Burp;


FROM Boxes          IMPORT ABoxAttribute, ABoxType, DrawBox,
                           GetInnerBoxSize;

FROM Events         IMPORT
    (* TYPE *)              AnEvent,
    (* PROC *)              GetNextEvent;

FROM Kbio           IMPORT ascreenx, ascreeny, avidmode,
                           PutString, maxrow, maxcol;

FROM Keys           IMPORT DoIt, CancelKey, ExitKey, HelpKey;

FROM Menus          IMPORT Menu, WordNumber;

FROM Codes          IMPORT
                           MaxCode, ACode, ASetOfCodes, SetCodeBits;

FROM Rugs           IMPORT ARug, GetRug, PutRug;

FROM SYSTEM         IMPORT ADDRESS;



    CONST
        MaxTrace = 20;
    CONST
        StartX = 39;
        StartY = 3;
        EndX   = 79;
        EndY   = 23;

    TYPE
        ATraceRecord = RECORD
                           Seq  : CARDINAL;
                           What : ARRAY [0..40] OF CHAR;
                           Seen : BOOLEAN;
                       END;
    VAR
        In, N       : [0..MaxTrace-1];
        TraceQ      : ARRAY [0..MaxTrace-1] OF ATraceRecord;
        StepMode    : BOOLEAN;
        StepsBetweenPauses,
        StepsToGo   : CARDINAL; 
        StepTakeRug : BOOLEAN;
        TraceCount  : CARDINAL;
        TraceSequence : CARDINAL;
        TraceMatchString   : ARRAY [0..60] OF CHAR;


    PROCEDURE QuickMenu(VAR Prefix,
                            Choices:ARRAY OF CHAR;
                        VAR Choice:CARDINAL;
                            AllowHelp : BOOLEAN
                            ):BOOLEAN;
    VAR
        CodeSet : ASetOfCodes;
        Code : ACode;
    BEGIN
        SetCodeBits(CodeSet,0,MaxCode,FALSE);
        IF (NOT AllowHelp) THEN
            SetCodeBits(CodeSet,HelpKey,HelpKey,TRUE);
        END;

        LOOP
            Code := Menu(Prefix,Choices,0,0,maxcol,StartY-1,CodeSet,
                         FALSE,     (* 12-Dec-89 RSC MODAL *)
                         Choice);   (* 3/26/87 EGK *)
            IF (Code = DoIt) THEN
                RETURN TRUE;
            ELSIF (Code = CancelKey) THEN
                RETURN FALSE;
            ELSE
                Burp;
            END;
        END;
    END QuickMenu;



    PROCEDURE DumbMenu(VAR Prefix,Choices:ARRAY OF CHAR; VAR Choice:CARDINAL);
    BEGIN
        REPEAT
        UNTIL (QuickMenu(Prefix,Choices,Choice,FALSE));
    END DumbMenu;




    PROCEDURE CtoH     (Card:CARDINAL; VAR String:ARRAY OF CHAR);
    CONST
        RADIX = 16;
        Size  = 4;
    VAR
        i,j,k : CARDINAL;
    BEGIN
        j := Size;
        REPEAT
            k := Card MOD RADIX;
            IF (k < 10) THEN
                String[j] := CHR(ORD("0")+k);
            ELSE
                String[j] := CHR(ORD("A")+(k-10));
            END;
            Card := Card DIV RADIX;
            DEC(j);
        UNTIL (j = 0);
        String[0] := CHR(Size);
    END CtoH;
(* ****************************
    PROCEDURE AtoS( A : ADDRESS; VAR S : ARRAY OF CHAR);
    VAR
        S2  : ARRAY [0..40] OF CHAR;
    BEGIN
        CtoH(A.SEGMENT,S);
        ConcatS(S,":");
        CtoH(A.OFFSET,S2);
        ConcatLS(S,S2);
    END AtoS;
****************************** *)

    PROCEDURE HtoS( A : ADDRESS; VAR S : ARRAY OF CHAR);
    VAR
        S2  : ARRAY [0..40] OF CHAR;
    BEGIN
        CtoH(A.SEGMENT,S);
        CtoH(A.OFFSET MOD 16,S2);
        Remove(S2,1,3);
        ConcatLS(S,S2);
        ConcatS(S,".");
        CtoH(A.OFFSET DIV 256,S2);
        Remove(S2,1,2);
        ConcatLS(S,S2);
    END HtoS;


    PROCEDURE TraceOn;
    BEGIN
        IF (TraceCount > 0) THEN DEC(TraceCount); END;
    END TraceOn;

    PROCEDURE TraceOff;
    BEGIN
        INC(TraceCount);
    END TraceOff;



    PROCEDURE TraceLS( What : ARRAY OF CHAR );
    VAR
        Rug : ARug;
        Event  : AnEvent;
        GotRug : BOOLEAN;
        Matched : BOOLEAN;
    BEGIN

        IF (TraceCount = 0) THEN
            INC(TraceCount);    (* Suppress internal usage. *)
            TraceSequence := (TraceSequence + 1) MOD 1000;
            TraceQ[In].Seq := TraceSequence;
            Copy(What,TraceQ[In].What);
            TraceQ[In].Seen := FALSE;
            In := (In+1) MOD MaxTrace;
            IF (N < MaxTrace-1) THEN
                INC(N);
            END;

            Matched := (LengthOf(TraceMatchString)=0) OR (Search(What,TraceMatchString,1)=0);


            IF (StepMode) AND (Matched) THEN
                IF (StepTakeRug) THEN 
                    GotRug := GetRug(StartX,StartY,EndX,EndY,Rug);
                ELSE
                    GotRug := FALSE;
                END;
 
                ShowTrace(StartX,StartY,EndX,EndY);
                
                IF (StepsToGo > 0) THEN 
                    DEC(StepsToGo);
                    IF (StepsToGo = 0) THEN
                        GetNextEvent( Event );
                        StepsToGo := StepsBetweenPauses;
                    END;
                END;

                IF (GotRug) THEN
                    PutRug(StartX,StartY,EndX,EndY,Rug);
                END;
            END;

            DEC(TraceCount);  (* End suppression of internal use. *)
        END;
    END TraceLS;


    PROCEDURE Trace ( What : ARRAY OF CHAR );
    VAR
        S  : ARRAY [0..40] OF CHAR;
    BEGIN
        SetString(S,What);
        TraceLS(S);
    END Trace;


    PROCEDURE TraceSize( What : ARRAY OF CHAR;  Size : CARDINAL );
    VAR
        S  : ARRAY [0..40] OF CHAR;
        S2 : ARRAY [0..5] OF CHAR;
    BEGIN
        SetString(S,What);
        CtoS(Size,S2);
        Procustes(S,20);
        ConcatLS(S,S2);
        TraceLS(S);
    END TraceSize;



    PROCEDURE TraceHandle( What : ARRAY OF CHAR;  A : ADDRESS );
    VAR
        S  : ARRAY [0..40] OF CHAR;
        S2 : ARRAY [0..20] OF CHAR;
    BEGIN
        SetString(S,What);
        HtoS(A,S2);
        Procustes(S,20);
        ConcatLS(S,S2);
        TraceLS(S);
    END TraceHandle;





    PROCEDURE TraceHandleAndSize( What : ARRAY OF CHAR;
                                   A : ADDRESS; Size : CARDINAL );
    VAR
        S  : ARRAY [0..40] OF CHAR;
        S2 : ARRAY [0..20] OF CHAR;
    BEGIN
        SetString(S,What);
        Procustes(S,20);
        HtoS(A,S2);
        ConcatLS(S,S2);
        ConcatS(S," ");
        CtoS(Size,S2);
        ConcatLS(S,S2);
        TraceLS(S);
    END TraceHandleAndSize;




    PROCEDURE ShowTrace( ULX : ascreenx; ULY : ascreeny;
                         LRX : ascreenx; LRY : ascreeny );
    VAR
        Y  : ascreeny;
        i, Count  : CARDINAL;
        S,S2  : ARRAY [0..60] OF CHAR;
    BEGIN
        SetString(S,"FlexStor Trace");
        DrawBox(ULX,ULY,LRX,LRY,ABoxType{SingleBox},S,videonormal);
        GetInnerBoxSize(ULX,ULY,LRX,LRY,ABoxType{SingleBox});

        Y := ULY;
        i := In;
        Count := 0;
        WHILE ( Y <= LRY ) AND (Count < N) DO
            i := (i + MaxTrace - 1) MOD MaxTrace;
            Fill(S," ",LRX-ULX+1);
            CtoS(TraceQ[i].Seq,S2);
            Overlay(S,S2,1,5);
            Overlay(S,TraceQ[i].What,5,ORD(TraceQ[i].What[0]));
            IF (TraceQ[i].Seen) THEN
                PutString(S,ULX,Y,videonormal);
            ELSE
                PutString(S,ULX,Y,videobright);
            END;
            TraceQ[i].Seen := TRUE;
            INC(Y);
            INC(Count);
        END;
    END ShowTrace;


    PROCEDURE GetStepMode():BOOLEAN;
    BEGIN
        RETURN StepMode;
    END GetStepMode;


    PROCEDURE SetStepMode( On : BOOLEAN );
    VAR
        Prefix, S : ARRAY [0..40] OF CHAR;
        Choices : ARRAY [0..80] OF CHAR;
        Choice, i : CARDINAL;
    BEGIN
        StepMode := On;

        IF (NOT On) THEN RETURN; END; 
        
        StepsBetweenPauses := 1;

        SetString(Prefix,"STEPS BETWEEN PAUSES");
        SetString(Choices,"1,5,50,500,2000,65000,0 (Unlimited)");
        Choice := 1;
        DumbMenu(Prefix,Choices,Choice);
        WordNumber(Choices,Choice,S);
        i := 1;
        StepsBetweenPauses := StoC(S,i);

        SetString(Prefix,"TAKE RUG ON EACH STEP");
        SetString(Choices,"Yes,No");
        Choice := 1;
        DumbMenu(Prefix,Choices,Choice);
        StepTakeRug := (Choice = 1); 

        StepsToGo := StepsBetweenPauses;
    END SetStepMode;

    PROCEDURE GetTraceMatchString( VAR MatchString : ARRAY OF CHAR );
    BEGIN
        Copy(TraceMatchString,MatchString);
    END GetTraceMatchString;


    PROCEDURE SetTraceMatchString( VAR MatchString : ARRAY OF CHAR );
    BEGIN
        Copy(MatchString,TraceMatchString);
    END SetTraceMatchString;






BEGIN
    In := 0;
    N  := 0;
    StepMode := FALSE;
    TraceCount := 0;
    TraceSequence := 0;
    TraceMatchString[0] := 0C; 
END FlexTrace.
