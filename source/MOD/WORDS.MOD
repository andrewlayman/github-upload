IMPLEMENTATION MODULE Words;

    (* MODIFICATION HISTORY

        9/15/87  AJL - Fixed MaxWordstringOnLine so that it works,
                       somewhat.
        9/19/87  AJL - Added ParseBal.
        6/01/89  WKH - Somehow, a bad index was being used....
    *)

FROM LStrings IMPORT
    (* PROC *)            SubStr, Fill, Search;


PROCEDURE StartOfWord(VAR s:ARRAY OF CHAR;
                          i:CARDINAL;
                          BreakChar : CHAR):BOOLEAN;
BEGIN
    IF (i <= 1) OR (i > ORD(s[0])) THEN RETURN TRUE; END;
    IF (s[i-1] = BreakChar) AND (s[i] <> BreakChar) THEN RETURN TRUE; END;
    RETURN FALSE;
END StartOfWord;


PROCEDURE EndOfWord(VAR s:ARRAY OF CHAR;
                        i:CARDINAL;
                        BreakChar : CHAR
                   ):BOOLEAN;
BEGIN
    IF (i <= 1) OR (i > ORD(s[0])) THEN RETURN TRUE; END;
    IF (s[i+1] = BreakChar) AND (s[i] <> BreakChar) THEN RETURN TRUE; END;
    RETURN FALSE;
END EndOfWord;




PROCEDURE FindNextWord(VAR s:ARRAY OF CHAR;
                       VAR i:CARDINAL;
                           BreakChar : CHAR );
VAR
    j : CARDINAL;
BEGIN
    j := i;
    LOOP
        IF (i >= ORD(s[0])) THEN
                (* Back up to end of word + 1 *)
            WHILE (i > j) AND (s[i-1] = BreakChar) DO DEC(i); END;
            EXIT;
        END;
        INC(i);
        IF (StartOfWord(s,i,BreakChar)) THEN
            EXIT;
        END;
    END;
END FindNextWord;





PROCEDURE FindPriorWord(VAR s:ARRAY OF CHAR;
                        VAR i:CARDINAL;
                            BreakChar : CHAR );
BEGIN
    LOOP
        IF (i <= 1) THEN
            i := 1;
            EXIT;
        END;
        DEC(i);
        IF (StartOfWord(s,i,BreakChar)) THEN
            EXIT;
        END;
    END;
END FindPriorWord;



PROCEDURE FindNextEndOfWord(VAR s:ARRAY OF CHAR;
                            VAR i:CARDINAL;
                                BreakChar : CHAR );
VAR
    j : CARDINAL;
BEGIN
    j := i;
    LOOP
            (* Out of range counts as end of word. *)
        IF (i >= ORD(s[0])) THEN
            EXIT;
        END;
        INC(i);
        IF (EndOfWord(s,i,BreakChar)) THEN
            EXIT;
        END;
    END;
END FindNextEndOfWord;



    (* MaxWordstringThatFits --

       Find the longest substring of s, starting at position
       StartAt, that is <= MaxLen characters long and contains
       only whole words.

       Preconditions -- (1) s is a valid LString.
                        (2) StartAt is <= LengthOf(s).
                        (3) StartAt >= 1 or LengthOf(s) = 0;

       PostConditions -- The value returned is <= MaxLen and the
                         substring of s from positions StartAt to
                         StartAt + the value returned - 1 contains
                         only whole words, and is the longest such
                         substring.
    *)



PROCEDURE MaxWordstringThatFits(VAR s       :ARRAY OF CHAR;
                                    StartAt : CARDINAL;
                                    MaxLen  : CARDINAL;
                                    BreakChar : CHAR;
                                    HardEnd   : CHAR
                               ) : CARDINAL;
VAR
    Limit, i : CARDINAL;
    s1 : ARRAY [0..1] OF CHAR;
BEGIN
    IF (StartAt > ORD(s[0])) THEN
        RETURN 0;
    END;

        (* Find the first hard end, or the end of the string. *)

    Fill(s1,HardEnd,1);
    i := Search(s,s1,StartAt);
    IF (i = 0) THEN
       i := ORD(s[0])+1;
    END;
    IF (i-StartAt <= MaxLen) THEN
        RETURN ( i - StartAt );
    END;

        (* Failing that being within range, find the last BreakChar. *)

    Limit := StartAt+MaxLen-1;
    IF (Limit > ORD(s[0])) THEN Limit := ORD(s[0]); END;

    i := Limit;

    REPEAT
        IF (EndOfWord(s,i,BreakChar)) THEN
            RETURN ( i + 1 - StartAt );
        END;
        DEC(i);
    UNTIL (i <= StartAt);

        (* Failing that, return the most that will fit. *)

    RETURN Limit;


END MaxWordstringThatFits;






    (*---------------------------------------------------------------

        RSC 2/1/89

        ParseBal With Delimiter

        Parse the string S matching a parenthesis-balanced string, or
                  matching up to the delimiter.

        Preconditions:
            S          is a valid LString.
            i          is where to start.
            Skip       is what to skip before scanning.
            Delimit    is what to look for if not a parenticised string,
                           and while it is a VAR parameter, that is just
                           to keep things zipping along.

        PostConditions:
            IF S[i] = "(" then Bal will be set to the shortest substring
                               of S, beginning at i, that contains a
                               balanced set of parenthesis.  However, the
                               leading and final parenthesis are removed.
                               If there is no such string, then the
                               entire string beginning at S[i] is
                               returned.
            ELSE Bal will return the substring of S beginning at the first
                               char after i that is NOT a delimiter, and
                               continuing to the end of S or the first
                               Char that IS a Delimiter.

            i is the NEXT charactor to look at.  If > LengthOf(S), you
                    are done.

       --------------------------------------------------------------*)
PROCEDURE ParseBalWithDelimiter( VAR S          : ARRAY OF CHAR;
                                 VAR i          : CARDINAL;
                                 VAR Skip,
                                     Delimit    : ASetOfDelimiters;
                                 VAR Bal        : ARRAY OF CHAR );
VAR
    Count,
    LenS,
    j,k          : CARDINAL;
    C            : CHAR;
BEGIN

    LenS := ORD(S[0]);
    k    := i;

    (* Skip past leading trivial charactors *)

    WHILE (k <= LenS) AND (S[k] IN Skip) DO
        INC(k);
    END;

    IF (k > LenS) THEN
        Bal[0] := 0C;
    ELSE

        IF (S[k] <> "(") THEN  (* 6/1/89 WKH  (used to be S[i]) *)

            (* Find trailing delimiter, and therefore the returned string. *)

            j := k;
            REPEAT
                INC(j);
            UNTIL (j > LenS) OR (S[j] IN Delimit);

            i := j;     (* Reset i for next time. *)
        ELSE
            INC(k);
            j       := k;
            Count   := 0;
            LOOP
                IF (j > LenS) THEN
                    EXIT;    (* End of string *)
                END;
                C := S[j];
                IF (C = "(") THEN
                    INC(Count);
                ELSIF (C = ")") THEN
                    IF (Count = 0) THEN
                        EXIT;
                    ELSE
                        DEC(Count);
                    END;
                END;
                INC(j);
            END;
            i := j + 1;     (* Reset i for next time.  Skip trailing paren. *)
        END;

        IF (j <= k) THEN
            Bal[0] := 0C;
        ELSE
            SubStr(S,Bal,k,j-k);
        END;
    END;

END ParseBalWithDelimiter;






    (*---------------------------------------------------------------

        ParseBal

        Parse the string S matching a parenthesis-balanced string.

        Preconditions:
            S is a valid LString.
            i is the char to start at.

        PostConditions:
            i is the NEXT char in the string.
            IF S[1] = "(" then Bal will be set to the shortest substring
                               of S, beginning at i, that contains a
                               balanced set of parenthesis.  However, the
                               leading and final parenthesis are removed.
                               If there is no such string, then the
                               entire string beginning at S[i] is
                               returned.
            ELSE Bal will return the substring of S beginning at i and
                               continuing to the end of S or the first
                               "(".
       --------------------------------------------------------------*)
PROCEDURE ParseBal( VAR S         : ARRAY OF CHAR;
                    VAR i         : CARDINAL;
                    VAR Bal       : ARRAY OF CHAR );
VAR
    Skip,
    Delimit : ASetOfDelimiters;
BEGIN
    Skip    := ASetOfDelimiters{};
    Delimit := ASetOfDelimiters{"("};
    ParseBalWithDelimiter( S, i, Skip, Delimit, Bal );
END ParseBal;





    (*---------------------------------------------------------------

        ParseString

        Parse the string S matching a parenthesis-balanced string.

        Preconditions:
            S is a valid LString.
            i is the char to start at.

        PostConditions:
            i is the NEXT char in the string.
            IF S[1] = "(" then Bal will be set to the shortest substring
                               of S, beginning at i, that contains a
                               balanced set of parenthesis.  However, the
                               leading and final parenthesis are removed.
                               If there is no such string, then the
                               entire string beginning at S[i] is
                               returned.
            ELSE Bal will return the substring of S beginning at the
                               first nonblank char after i and
                               continuing to the end of S or the first
                               "(" or " ".
       --------------------------------------------------------------*)
PROCEDURE ParseString( VAR S         : ARRAY OF CHAR;
                       VAR i         : CARDINAL;
                       VAR Bal       : ARRAY OF CHAR );
VAR
    Skip,
    Delimit : ASetOfDelimiters;
BEGIN
    Skip    := ASetOfDelimiters{" "};
    Delimit := ASetOfDelimiters{"("," "};
    ParseBalWithDelimiter( S, i, Skip, Delimit, Bal );
END ParseString;





END Words.
