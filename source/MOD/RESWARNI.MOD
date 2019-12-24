IMPLEMENTATION MODULE ResWarnings;

(* MODIFICATION HISTORY


    Feb 27, 89 - JES -created by yanking procedures etc from old TlrPlan
                      into here and adding SendErrorMsg.
    Dec 19, 90 - AJL -Improved by actually initializing the WarningsIssued
                      set.
                     -Added MessageWriter.
    Dec. 31, 90  AJL -Add WBS numbers.
    26-Aug-91 TGS/  Andrew's changes to allow substitutable parameters in
              AJL   recalc warnings, and to add a new type of warning when 
                    recalc couldn't allocate all effort exactly as requested.
    28-Jan-92 AJL    -Optional run line command CALCWARNING IS () will
                      turn off all warnings, or can be used to selectively
                      enable some.

*)
FROM Allocs IMPORT 
    (* CONST *)         TskNmLen, WBSLine,
    (* TYPE *)          ATaskPtr,
    (* PROC *)          GetCodingField;


FROM Dialog    IMPORT WarningBox, Message, Error, Burp,
                      ADialogOption, ErrorPhrase;

FROM KeywdSub  IMPORT
    (* PROC *)        MakeSubstitutions;

FROM LStrings  IMPORT Compare, SetString, ConcatLS, ConcatS, SubStr,
                      CtoS, Procustes, TrimRear, LengthOf, StoC, Fill;


FROM MsgFile   IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM ParmLine     IMPORT
       (* PROCS *)    GetOption;

FROM ResConstants IMPORT ModuleNumber;

FROM SYSTEM    IMPORT ADDRESS, ADR;

FROM Text      IMPORT
    (* TYPE *)        AText,
    (* PROC *)        AppendLine;

FROM Words     IMPORT
    (* PROC *)        ParseBal;


VAR
    WarningsIssued  : ASetOfWarnings;
    WarningsEnabled : ASetOfWarnings;


PROCEDURE XMessageWriter ( VAR S: ARRAY OF CHAR;
                             Dup : BOOLEAN );
BEGIN
    IF AppendLine(S,WarningLogText) THEN; END;
    IF NOT (Dup) THEN
        Error(S);
    END;
END XMessageWriter;



    (* GetKeyWordValue -- Extracts parameters for MakeSubstitutions.
                          From the parenthesis-grouped list of 
                          parameters in Context^, interpret Keyword
                          as a number, and retrieve the corresponding (ith)
                          parameter from Context^. 
                          *)


PROCEDURE GetKeyWordValue( VAR Keyword : ARRAY OF CHAR;
                           VAR KeyValue : ARRAY OF CHAR;
                               Context  : ADDRESS );
VAR
    i, j : CARDINAL;
    Parameters : POINTER TO ARRAY [0..255] OF CHAR;
BEGIN
    j := 1;
    i := StoC(Keyword,j);
    IF (j = 1) THEN
        ErrorPhrase(0);
    ELSE
             (* i is a number.  Find the ith phrase in Parameters. *)
        j := 1;
        Parameters := Context;
        WHILE (i > 0) DO
            ParseBal(Parameters^,j,KeyValue);
            DEC(i);
        END; 
    END;
END GetKeyWordValue;





PROCEDURE IssueWarningWithParms(     Warning : AWarning; 
                                     Task    : ATaskPtr;
                                 VAR Parms   : ARRAY OF CHAR);
VAR
    S   : ARRAY [0..255] OF CHAR;
    S2  : ARRAY [0..255] OF CHAR;
    S3  : ARRAY [0..41] OF CHAR;
    Dup : BOOLEAN;  
BEGIN
        (* Some warnings can be turned off. *)
    IF (NOT (Warning IN WarningsEnabled)) THEN
        RETURN;
    END;

        (* Has this warning already been shown on the screen? *)
    Dup := (Warning IN WarningsIssued);

        (* Note that this warning has, or is, being shown. *)

    INCL(WarningsIssued,Warning);

        (* Get the text of the message, with positional tokens. *)

    GetMessage(ModuleNumber+30+ORD(Warning),S);

        (* Add the name of the task, in parenthesis, to the beginning
           of the parameters.  Put into S2.   These are the local
           parameters. *)
    SetString(S2,"(");
    IF (Task <> NIL) THEN
        ConcatLS(S2,Task^.taskname);
        GetCodingField (Task^, WBSLine, S3);
        TrimRear(S3);
        IF (LengthOf(S3) > 0) AND (LengthOf(S2) + LengthOf(S3) < HIGH(S2)) THEN
            ConcatS(S2," (");
            ConcatLS(S2,S3);
            ConcatS(S2,")");
        END;
    END;
    ConcatS(S2,")");
    ConcatLS(S2,Parms);

    MakeSubstitutions(S,HIGH(S),GetKeyWordValue,ADR(S2));

    MessageWriter(S,Dup);
END IssueWarningWithParms;







(*------SendErrorMsg-------------------------------------------
    
        Send an error message to the screen.
*)

PROCEDURE SendErrorMsg(Message: ARRAY OF CHAR);

VAR
    ErrorMsg : ARRAY[0..60] OF CHAR;

BEGIN
    SetString(ErrorMsg, Message);
    MessageWriter(ErrorMsg,FALSE (*Dup *) );
END SendErrorMsg;







PROCEDURE IssueWarning( Warning : AWarning; 
                        Task    : ATaskPtr );
VAR                     
    S     : ARRAY [0..255] OF CHAR;
    Parms : ARRAY [0..0]   OF CHAR;
BEGIN
    Fill(Parms," ",0);
    IssueWarningWithParms(Warning,Task,Parms);
END IssueWarning;


    (* InitWarnings -- Look for a run line parm "CALCWARNING".
                       If it exists, it contains a list of warnings
                       to enable, by index number, as in 
                       CALCWARNING IS (0,1,3,7).
    *)


PROCEDURE InitWarnings( VAR WarningsEnabled : ASetOfWarnings );
VAR
    Warning : AWarning;
    i,j : CARDINAL;
    OptionName : ARRAY [0..29] OF CHAR;
    S : ARRAY [0..81] OF CHAR;
    Exists : BOOLEAN;
BEGIN
        (* Unless the user says otherwise, all warnings are enabled. *)
    FOR Warning := MIN(AWarning) TO MAX(AWarning) DO
        INCL(WarningsEnabled,Warning);
    END;
        

    GetMessage(ModuleNumber+99,OptionName);   (* "CALCWARNING" *)
    GetOption(OptionName,Exists,S);
    IF Exists THEN
        WarningsEnabled := ASetOfWarnings{};
        i := 1;
        WHILE (i < LengthOf(S)) DO
            j := StoC(S,i);
            IF (j <= ORD(MAX(AWarning))) THEN
                INCL( WarningsEnabled, VAL(AWarning, j));
            END;
            INC(i);
        END;
    END;
END InitWarnings;



BEGIN
    WarningsIssued  := ASetOfWarnings{};
    MessageWriter   := XMessageWriter;
    InitWarnings( WarningsEnabled );
END ResWarnings.
