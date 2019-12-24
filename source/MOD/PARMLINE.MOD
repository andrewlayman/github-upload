    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE ParmLine;
(*  =========================================================================
    Last Edit : February 7, 1991 11:17AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        
        Get Parameter Line (from COMMAND.COM)

         FORMAT OF THE COMMAND LINE ARGUMENT IS:

         [<Prog name>] [FileName] [Option1] [Option2] [Option3]

         [FileName] is <text> (no spaces)
         [Optionx]  is <text> "=" <text>

                   for examples,
                         NAME = ROGER
                         EMS  = 147
                         TIME = NO
                         DATE=TRUE
                         REAL   =123.456


    MODIFICATION HISTORY:

     Based on ProgArg by Roger Collins 8/14/87

     11/9/87 RSC ajusted innerworkings so that
                 - All parameters require '=', so we can determine
                   what the file name is.
                 - the scans are non-destructive, so you can ask for a
                   parameter over and over.
                 - There is no way to syntax check commands, as misspellings
                   are ignored.  PATC is not seens as PATH and is not flaged.
     3/8/88  AJL - Modified our parsing to allowing text inside parenthesis 
                   to count as a single item, even if empty or contains
                   spaces.
    10/7/88  RSC - Remove imports of Dialog and LStrings, because this module
                   is needed early in TimeLine initalization by MsgFile.Mod.

     6/19/89 RSC - 1) Allow " IS " in addition to "=".  This is in GaGa.
                   2) Look for the SET command "TimeLine" and append it
                      to the command line.  For example:

                      SET TimeLine=(SwapVol IS E:\ Display=Compressed)

     3-Aug-89 RSC Fixed a bug in my 19-Jun fix that took ALL 8 byte SET
                  variables as the TIMELINE variable.  Also upgraded to
                  new module header format.

     5-Aug-89 WKH Initial OS/2 edits.  Get parmline from new place.
    11-Sep-89 WKH Get PSP address from OurPSP instead of RTSMain.
     7-Feb-91 RSC Allow Option and Param to be the same var in GetOption.

    =========================================================================
*)



FROM GaGa       IMPORT
    (* PROC *)      GetGaGaMessage;

FROM OurPSP     IMPORT
    (* VAR *)       OurPSPAddress;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS;


CONST
    ModuleNumber    = 7300;

VAR
    ParameterLine     : ARRAY [0..255] OF CHAR;


  (* GetToken - look for the next token in the parameter line. *)

PROCEDURE GetToken( VAR s : ARRAY OF CHAR;
                    VAR i : CARDINAL );
VAR j,
    ParamCount : CARDINAL;
    C          : CHAR;
BEGIN
    j := 0;

    (* Skip leading blanks *)

    WHILE (i <= ORD(ParameterLine[0])) AND
          (ParameterLine[i] = " ")     DO
        INC(i);
    END;


        (* Absorb token until a blank or an "=" sign after balanced parenthesis *)

    ParamCount := 0;

    LOOP
        IF (i > ORD(ParameterLine[0])) OR (j >= HIGH(s)) THEN EXIT; END;
        C := ParameterLine[i];
        IF (C="(") THEN INC(ParamCount)
        ELSIF (C=")") AND (ParamCount > 0) THEN DEC(ParamCount)
        ELSIF (ParamCount = 0) AND ((C=" ") OR (C="=")) THEN
            EXIT;
        END;
        INC(j);
        s[j] := C;
        INC(i);
    END;

    (* Was the '=' sign the token? *)

    IF (i <= ORD(ParameterLine[0])) AND  (* still in param line? *)
       (j = 0)                      AND  (* no previous chars found? *)
       (ParameterLine[i] = "=")     THEN (* '=' sign found? *)
        INC(j);
        s[j] := ParameterLine[i];   (* Save it *)
        INC(i);
    END;

    s[0] := CHR(j);
END GetToken;



 (* Get Option - Get one option.  

        Preconditions  - Option is the text you want, upshifted.
        Postconditions - Found  is TRUE if found, FALSE if not found.
                         Param  is the text parameter, if any.

      syntax for an option is

          <Option> = [<Param>]
  *)
PROCEDURE GetOption( VAR POption: ARRAY OF CHAR;
                     VAR Found  : BOOLEAN;
                     VAR Param  : ARRAY OF CHAR );
VAR 
    Newi,
    i, j   : CARDINAL;
    Option,
    Token  : ARRAY [0..128] OF CHAR;
    ok     : BOOLEAN;

BEGIN
        (* 7-Feb-91 RSC Allow POption and Param to be the same var. *)
    FOR i := 0 TO ORD(POption[0]) DO
        Option[i] := POption[i];
    END;

    Found    := FALSE;
    Param[0] := 0C;

    i        := 1;
    GetToken( Token, i ); (* Get first 'real' token *)

    (* Look for the option.  Options MUST have an '=' sign after them.  This
       distinguishes them from file names. so TIMELINE PATH PATH = DK: is
       legal and means 'set path to dk: and load the schedule path.t#0'.
    *)
    LOOP
        IF (Token[0] = 0C) THEN
            RETURN;
        END;
        ok := TRUE;
        j  := 0;
        WHILE (j <= ORD(Token[0])) AND (ok) DO  (* Two strings exactly the same? *)
            ok := (Token[j] = Option[j]);
            INC(j);
        END;
        IF (ok) THEN (* Found it? *)
            Newi  := i;
            GetToken( Token, Newi ); (* Don't destroy i in case this is not it. *)
            IF (Token[0] = 1C) AND (Token[1] = "=") THEN (* '=' found? *)
                GetToken( Param, Newi );
                    (* Remove any leading and trailing parenthesis. *)
                i := ORD(Param[0]);       (* Reuse i. *)
                IF (i>=2) AND (Param[1]="(") AND (Param[i]=")") THEN
                    FOR j := 2 TO i-1 DO
                        Param[j-1] := Param[j];
                    END;
                    FOR j := i+1 TO ORD(Param[0]) DO
                        Param[j-1] := Param[j];
                    END;
                    DEC(Param[0],2);
                END;
                Found := TRUE;
                RETURN;
            END;
        END;
        GetToken( Token, i );
    END;

END GetOption;



 (* Get File Name - get the file name frlom the command string.

        Preconditions  - none.
        Postconditions - filename, if found, is returned in s.
                         filename is not checked for validity.
                         filename is the first token and must not be
                             followed by an equals sign.
 *)
PROCEDURE GetFileName( VAR s : ARRAY OF CHAR );
VAR 
    i      : CARDINAL;
    s1     : ARRAY [0..11] OF CHAR;
BEGIN
    i := 1;
    GetToken( s, i ); (* get very first parameter. *)

    GetToken( s1, i ); (* get next param, insure it is NOT an '=' *)

    IF (s1[0] = 1C) AND (s1[1] = "=") THEN
        s[0] := 0C;
    END;
END GetFileName;






PROCEDURE GetParmLine();

(*<DOS*)
TYPE PSP = RECORD
                stuff: ARRAY [1..128] OF CHAR;
                text : ARRAY [0..127] OF CHAR
           END;

VAR PSPPtr : POINTER TO PSP;
    i      : CARDINAL;
(*DOS>*)

(*<OS2
VAR
    i      : CARDINAL;
    Len    : CARDINAL;
OS2>*)

BEGIN 

(*<DOS*)
    PSPPtr := OurPSPAddress; 

    WITH PSPPtr^ DO
        FOR i := 1 TO ORD(text[0]) DO
            ParameterLine[i] := CAP(text[i]);
        END;
        ParameterLine[0]     := text[0];
    END;
(*DOS>*)

(*<OS2
    i   := 0;
    Len := 0;

    WHILE (cmdLinePtr.str^[i] <> 0C) DO
	    INC(i);
    END;

    INC(i);

    WHILE (cmdLinePtr.str^[i] <> 0C) AND (cmdLinePtr.str^[i] <> 15C) DO
	    ParameterLine[Len+1] := CAP(cmdLinePtr.str^[i]);
    	INC(i);
	    INC(Len);
    END;

    ParameterLine[Len + 1] := 0C;
    ParameterLine[0]       := CHR(Len);
OS2>*)

END GetParmLine;




(* This code stolen from Overlay.Mod.  Logitek's, not ours.
   RSC Converted to LStrings.
*)
PROCEDURE GetTimeLineSet();
(*<DOS*)
VAR
    PSPPtr: RECORD
               CASE CARDINAL OF
                  0: addr: ADDRESS;
                | 1: offset, base: CARDINAL;
               END;
           END;
    Level,
    i    : CARDINAL;
    env  : POINTER TO ARRAY [0..10000] OF CHAR;
    pos  : CARDINAL;
    k    : CARDINAL;
    var  : ARRAY [0..255] OF CHAR;
    val  : ARRAY [0..255] OF CHAR;
    temp : ARRAY [0..9] OF CHAR;
    KeepIt: BOOLEAN;
       
    PROCEDURE Match(VAR v : ARRAY OF CHAR):BOOLEAN;
    VAR i : CARDINAL;
    BEGIN
        FOR i := 0 TO ORD(v[0]) DO
            IF (v[i] <> temp[i]) THEN
                RETURN FALSE;
            END;
        END;
        RETURN TRUE;
    END Match;
(*DOS>*)

BEGIN
(*<DOS*)
    temp := ' TIMELINE';
    temp[0] := 10C;  (* LEN("TimeLine") MAKE THIS AN LSTRING! *)

    PSPPtr.addr := OurPSPAddress;
    INC(PSPPtr.addr,44); (*now we point to the address of the environment*)
    PSPPtr.base := CARDINAL(PSPPtr.addr^);
    PSPPtr.offset := 0; (*now, we are pointing to the environment*)
    env := PSPPtr.addr;

    pos := 0;
    WHILE env^[pos] <> 0C DO

        (* Get the variable *)

        k := 0;
        WHILE (env^[pos] <> 0C) & (env^[pos] <> '=') DO
            IF env^[pos] <> ' ' THEN
                INC(k);
                var[k] := CAP(env^[pos]);
            END;
            INC (pos);
        END;
        var [0] := CHR(k);

        (* Get the value *)

        IF env^[pos] = '=' THEN
            k := 0;
            INC (pos);

            IF env^[pos] = '(' THEN
                INC(pos);
                Level := 1;
            ELSE
                Level := 0;
            END;

            WHILE (env^[pos] <> 0C)  AND
                  (env^[pos] <> '=') DO

                KeepIt := TRUE;
                IF (env^[pos] = "(") THEN
                    INC(Level);
                ELSIF (env^[pos] = ")") THEN
                    DEC(Level);
                    KeepIt := (Level > 0);
                ELSIF (env^[pos] = " ") THEN
                    KeepIt := (Level > 0);
                END;

                IF (KeepIt) AND (Level >= 0) THEN
                    INC(k);
                    val[k] := CAP(env^[pos]);
                END;

                INC (pos);
            END;
            val[0] := CHR(k);

            IF Match(var) THEN
                k := ORD(ParameterLine[0]);
                INC(k);
                ParameterLine[k] := " ";
                FOR i := 1 TO ORD(val[0]) DO
                    IF (k < HIGH(ParameterLine)) THEN
                        INC(k);
                        ParameterLine[k] := val[i];
                    END;
                END;
                ParameterLine[0] := CHR(k);
                RETURN;
            END;
        END;
        INC (pos);
    END;
(*DOS>*)
END GetTimeLineSet;



PROCEDURE FilterParmLine();
VAR
    i, j, k : CARDINAL;
    s       : ARRAY [0..99] OF CHAR;
BEGIN

    GetGaGaMessage( ModuleNumber + 1, s );  (* " IS " *)

    (* Replace all occurances of " IS " with "   =".
       The length remains the same.
    *)
    j := 1;
    i := 1;
    WHILE (i < ORD(ParameterLine[0])) DO
        IF (s[j] = ParameterLine[i]) THEN
            INC(j);
            IF (j > ORD(s[0])) THEN
                FOR k := ((i + 1 ) - ORD(s[0])) TO (i - 1) DO
                    ParameterLine[k] := " ";
                END;
                ParameterLine[i] := "=";
                j := 1; (* Go on to the next occurance. *)
            END;
        ELSE
            j := 1;
        END;
        INC(i);
    END;
    
END FilterParmLine;





BEGIN
    GetParmLine();
    GetTimeLineSet();
    FilterParmLine();
END ParmLine.
