IMPLEMENTATION MODULE Searcher;

    (*  MODIFICATION HISTORY --
        14-Aug-89 LAA   Added support of the new match type ItMatches to
                        StringMatch.
        23-Sep-90 LAA   Changed StringMatch to upshift the pattern, since
                        the match string is being upshifted, to correct a 
                        problem with filters.  Also copied the two string
                        parameters before upshifting, so that "real" values
                        would not be altered by this comparison.  Bug 3161.
    *)

FROM FilterRc               IMPORT
    (* TYPE *)                  AFilterMatch;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, Search, LengthOf, Remove, Upshift,
                                Copy;




    (* See if and where the string S contains the pattern Pattern.
       Allow the wildcard character "?". *)

PROCEDURE PatternSearch (   S           : ARRAY OF CHAR;
                            Pattern     : ARRAY OF CHAR ) : INTEGER;
CONST
    WildCard = "?";
VAR
    i,l,lp,j : CARDINAL;
    s1          : ARRAY [0..1] OF CHAR;
BEGIN
    Fill(s1,WildCard,1);
    IF (Search(Pattern,s1,1) = 0) THEN      (* Is the pattern simple or complicated? *)
        RETURN Search(S,Pattern,1);         (* Simple *)
    END;

        (* Contains wild card. *)

    i := 1;
    l := LengthOf(S) + 1;
    lp := LengthOf(Pattern);
    WHILE (i + lp <= l) DO
        j := 1;
        WHILE (j <= lp) AND ((Pattern[j] = WildCard) OR (Pattern[j] = S[i+j-1])) DO
            INC(j); 
        END;
        IF (j > lp) THEN
            RETURN(INTEGER(i));
        END; 
        INC(i);
    END;
    RETURN 0;
END PatternSearch;


    (*  StringMatch  -- Compare the string s2 to the sample string pattern. 
        
        This matching is case-insensitive.
    *)


PROCEDURE StringMatch ( VAR pattern     : ARRAY OF CHAR;
                        VAR s2          : ARRAY OF CHAR;
                            matchplace  : AFilterMatch  ) : BOOLEAN;

VAR
    i           : CARDINAL;
    UpString2   : ARRAY [0..255] OF CHAR;
    UpPattern   : ARRAY [0..255] OF CHAR;

BEGIN

        (* If we are checking the end of s2, remove all
           but the end. *)

    IF (matchplace = ItEnds) AND
       (ORD(s2[0]) > ORD(pattern[0])) THEN
            Remove(s2,1,ORD(s2[0])-ORD(pattern[0]));
    END;

    Copy( s2, UpString2 );
    Upshift( UpString2 );
    Copy( pattern, UpPattern );
    Upshift( UpPattern );

    i := PatternSearch(UpString2, UpPattern);   (* Complicated *)

    IF (matchplace = ItBegins) THEN
        RETURN (i=1);
    ELSIF (matchplace = ItMatches) THEN                           (* 14-Aug-89 LAA *)
        RETURN ((i <> 0) AND (LengthOf(UpString2) = LengthOf(UpPattern)));
    ELSE
        RETURN (i<>0);
    END

END StringMatch;



END Searcher.
