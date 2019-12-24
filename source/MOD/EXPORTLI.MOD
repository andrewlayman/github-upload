IMPLEMENTATION MODULE ExportLinkage;

 (* Export Linkage - common linkage area for exporters and tlputit.

     MODIFICATION HISTORY:

        RSC  11/10/87  First version.
        RSC 02-Jun-88  Expanded to allow a flag of "!".
        RSC  2-Feb-89  Removed "ParseCallChain".  Use ParseString instead.
        AJL 25-Dec-90  Initialize some variables, rather than leaving them
                       unitialized.
 *)


FROM LStrings        IMPORT
        (* PROCS *)     Upshift;

FROM Words           IMPORT
        (* PROCS *)     ParseString;



 (* Parse A Flag - Parse a Y/N/? flag from the string in In.

        Preconditions  - In is the source string
                         StartAt is where the flag starts.

        Postconditions - Out is the flag char or 0C if not found.
                         StartAt has been updated to be past Out.
  *)
PROCEDURE ParseAFlag( VAR In      : ARRAY OF CHAR;
                      VAR Out     : CHAR;
                      VAR StartAt : CARDINAL );
VAR
    s : ARRAY [0..255] OF CHAR;
BEGIN
    ParseString( In, StartAt, s );
    Upshift(s);
    IF (s[0] = 0C) OR
       ((s[1] <> "Y") AND (s[1] <> "N") AND
        (s[1] <> "?") AND (s[1] <> "!")) THEN
        Out := 0C;
    ELSE
        Out := s[1];
    END;
END ParseAFlag;



BEGIN
    ExportMedia := "";
    ExportName  := "";
END ExportLinkage.


