IMPLEMENTATION MODULE KeywdSub;

    (* Substitutes the text in a string according to keywords within it. *)

    (* MODIFICATION HISTORY

       Aug-22-89  AJL -Original version of the DEF.  Most of the coding is
                       taken from earlier work by Ken Chiu.
       Aug 24 89  AJL -Removed Upshift.
                      -Added ParseBal.
                      -Corrected some bugs.
       Sep 20 89  AJL -MakeSubstitutions will no longer add padding blanks
                       to the end of strings.  It may return lines shorter
                       than the maximum length.
                      -StoreKeyWordValueInLine checks HIGH(Line) rather than
                       MaxWidth so that a substitution can expand
                       the length of a string without crashing. 
       Sep-27-89  KKC -If there are blanks after the key specifier, one blank
                       space is left to separate the key and the rest of the
                       line in StoreKeyWordValueInLine.
       Jan-03-90  KKC -Initialize variable 'start' to 1 in MakeSubstitutions.
        9-Feb-91  AJL -Added right and left tab justification.
                      -Added width specs.  Justification code "W".
    *)




FROM Dialog     IMPORT
    (* PROC *)         Error, FatalError;

FROM LStrings   IMPORT SetString, SubStr, ConcatLS, Fill,
                       RJust, LJust, Overlay, LengthOf, StoC,
                       Search, Upshift, StringsEqual, Compare,
                       TrimRear, CtoS, ConcatS, Copy, Remove,
                       TrimFront, Insert, Procustes, SetLengthOf;

FROM MsgFile    IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM RealFormat IMPORT DefaultAmountFormat;

FROM SYSTEM     IMPORT
    (* TYPE *)         ADDRESS;

FROM Words      IMPORT
    (* PROC *)         ParseBal;    


CONST
    ModuleNumber        =   8500;    (* For GetMessage *)
    MaxWidth            =   255;


TYPE
    AKeyJustification   =  (None, Left, Right);
    KeyWordInfo     =   RECORD
        KeywordValue:   ARRAY [0..MaxWidth] OF CHAR;
        KeyLength     :   CARDINAL;
        ReplaceLength :   CARDINAL;
        KeyJustify    :   AKeyJustification;
        TabWidth      :   CARDINAL;
    END;

PROCEDURE Numeric( C : CHAR ) : BOOLEAN;
BEGIN
    RETURN (C >= "0") AND (C <= "9"); 
END Numeric;



PROCEDURE StoreKeyWordValueInLine( VAR Line : ARRAY OF CHAR;
                                   VAR KeyInfo : KeyWordInfo;
                                   VAR start, stop : CARDINAL
                                 );
VAR
    FillStart, FillStop     :   CARDINAL;
    LineLen, KeyLen, MaxKeyLen :   CARDINAL;
    TabPoint, RightTabPoint, i : CARDINAL;
    s                       :   ARRAY[0..MaxWidth] OF CHAR;
    s1                      : ARRAY [0..MaxWidth] OF CHAR;
BEGIN
    FillStart := start - 1;
    FillStop := stop + 1;
    WITH KeyInfo DO
        Copy( KeywordValue, s );
        IF ( KeyJustify = None ) THEN
                (* Remove the key specifier and any two consecutive
                   blanks following the key.  
                *)
            LineLen := LengthOf( Line );
            IF ( Line[FillStop] = ' ' )  THEN
                WHILE ( ( FillStop <= LineLen  - 1 )
                    AND
                        ( Line[FillStop + 1 ] = ' ' ) 
                ) DO
                    INC (FillStop );
                END;
            END;
            KeyLen := FillStop - FillStart;
            Remove(Line, FillStart, KeyLen );
                (* Make sure the replacement string isn't too long. *)
            MaxKeyLen := HIGH(Line) - LengthOf(Line);
            IF (LengthOf(s) > MaxKeyLen) THEN
                Procustes(s,MaxKeyLen);
            END;
                (* Insert the replacement string. *)
            Insert(Line, s, FillStart);
        ELSE
                (* Drop into place without changing string length. *) 
            IF (TabWidth <> 0) THEN
                    (* Locate the end of the whole number. *)
                TabPoint := 1;
                WHILE (TabPoint <= LengthOf(s))
                       AND (s[TabPoint] <> " ")
                       AND (s[TabPoint] <> DefaultAmountFormat.RadixSymbol)
                      DO
                    INC(TabPoint);
                END;
                IF ( KeyJustify = Left ) THEN
                    TabPoint := LengthOf(s) - RightTabPoint + 1;
                    IF (TabPoint < TabWidth) THEN
                        Procustes(s,ReplaceLength-(TabWidth-TabPoint));
                        Fill(s1," ",(TabWidth-TabPoint));
                        Insert(s,s1,1);
                    END;
                ELSE (* Right justify. *)
                    RightTabPoint := LengthOf(s) - TabPoint + 1;
                    IF (RightTabPoint < TabWidth) THEN
                        Procustes(s,ReplaceLength-(TabWidth-RightTabPoint));
                        Fill(s1," ",(TabWidth-RightTabPoint));
                        ConcatLS(s,s1);
                    END;
                END;
            ELSIF ( KeyJustify = Left )  THEN
                Procustes( s, ReplaceLength );
                LJust(s);
            ELSE
                Procustes( s, ReplaceLength );
                RJust(s);
            END;
            Remove( Line, FillStart, KeyLength);
            Insert( Line, s, FillStart );
        END;
        stop := FillStart + LengthOf(s) - 1;
    END;
END StoreKeyWordValueInLine;


    (* -------------------------------------------------------------
       ParseKeyWord

       Purpose:  Given a key word phrase that is a key word optionally
                 followed by a justification code, decode it into a 
                 KeyInfo structure identifying the key word, justification,
                 and replacement length. 



       ------------------------------------------------------------- *)




PROCEDURE ParseKeyWord (
                        VAR KeyPhrase :  ARRAY OF CHAR;
                        VAR KeyInfo : KeyWordInfo
                       );
VAR
    StartPattern                 :   ARRAY[0..2] OF CHAR;
    EndPattern                   :   ARRAY[0..2] OF CHAR;
    JustificationControlString   :   ARRAY[0..MaxWidth] OF CHAR;
    S                            :   ARRAY[0..MaxWidth] OF CHAR;
    S5                           :   ARRAY [0..5] OF CHAR; 
    S1                           :   ARRAY [0..1] OF CHAR;
    start, stop, i,j,Index, k    :   CARDINAL;
BEGIN

    Copy(KeyPhrase, S);       (* Move to a working string. *)
    TrimFront(S);
    TrimRear(S);

    WITH KeyInfo DO
        KeyJustify := None;
        TabWidth   := 0;
        KeyLength  := MaxWidth;
        ReplaceLength  := MaxWidth;

        GetMessage(ModuleNumber + 2, StartPattern); (* '(' *)
        GetMessage(ModuleNumber + 3, EndPattern);   (* ')' *)
        start := 1;
        stop := 1;
 
            (* If the key phrase begins with a "(" take the contents up to
               the matching ")" as the keyword.  *)
        ParseBal(S,start,KeywordValue);
        TrimRear(KeywordValue);
          
        SetLengthOf(JustificationControlString, 0);

            (* Look for a (L) or (R) justification code. *)

        IF SearchKeyWord(S, JustificationControlString,
                         StartPattern, EndPattern, start, stop) THEN
                (* A justification code forces a specific length. *) 
            KeyLength := LengthOf(KeyPhrase) + 2;   (* +2 for the "*" at ends. *)
            ReplaceLength := KeyLength;
                (* Determine the type of justification. *) 
            Upshift(JustificationControlString);
            Index := 1;
                (* Determine which justification code it is. *)
                (* Format is { "R" | "L" | "W" (Number) }    *)
            WHILE (Index <= LengthOf(JustificationControlString)) DO
                GetMessage(ModuleNumber + 0, S5 );  (* RLW *)
                Fill(S1,JustificationControlString[Index],1);
                INC(Index);
                IF (Index <= LengthOf(JustificationControlString)) AND
                   (Numeric(JustificationControlString[Index])) THEN
                    k := StoC(JustificationControlString,Index);
                ELSE
                    k := 0;
                END;
                CASE Search(S5,S1,1) OF 
                    1 : 
                         KeyJustify := Right;
                         TabWidth   := k;
                  | 2 :
                         KeyJustify := Left;
                         TabWidth   := k;

                  | 3 :     (* Field Width *)
                         ReplaceLength := k;
                    ELSE
                END;       
            END;

        END;
    END;
END ParseKeyWord;





    (* -------------------------------------------------------------
       SearchKeyWord

       Purpose: Searches the Source string for a substring bracketted by
                the StartPattern and EndPattern.  
                Searching begins at position KeyStart.
                If found, TRUE is returned
                and the substring is returned in KeyWord, while its starting
                and ending position is returned in KeyStart, KeyEnd.

    -------------------------------------------------------------   *)


PROCEDURE SearchKeyWord(
                        VAR Source, KeyWord : ARRAY OF CHAR;
                        VAR StartPattern, EndPattern : ARRAY OF CHAR;
                        VAR KeyStart, KeyEnd : CARDINAL
                    ) : BOOLEAN;
VAR
    Len     :   CARDINAL;
BEGIN
    KeyEnd := Search (Source, StartPattern, KeyStart);
    IF ( KeyEnd = 0 ) THEN RETURN FALSE; END;
    KeyStart := KeyEnd + LengthOf(StartPattern);
    KeyEnd := Search (Source, EndPattern, KeyStart);
    IF ( KeyEnd = 0 ) THEN RETURN FALSE; END;
    Len := KeyEnd - KeyStart;
    SubStr( Source, KeyWord, KeyStart, Len);
    RETURN TRUE;
END SearchKeyWord;




PROCEDURE MakeSubstitutions( VAR S : ARRAY OF CHAR;
                                 MaxLength : CARDINAL;
                                 GetKeyWordValue : AGetKeyWordValueProc;
                                 Context  : ADDRESS );
VAR
    KeyWord             :   ARRAY[0..MaxWidth] OF CHAR;
    start, stop         :   CARDINAL;
    PrintLineWidth      :   CARDINAL;
    KeyInfo             :   KeyWordInfo;
    Pattern1, Pattern2  :   ARRAY[0..2] OF CHAR;
BEGIN
    IF ( MaxLength > HIGH(S) ) THEN MaxLength := HIGH(S); END;
    start := 1;
    stop := 1;
    GetMessage( ModuleNumber + 4, Pattern1 ); (* '*' *)
    GetMessage( ModuleNumber + 5, Pattern2 ); (* '*' *)
    WHILE SearchKeyWord(S, KeyWord, Pattern1, Pattern2, start, stop) DO
        ParseKeyWord( KeyWord, KeyInfo);
            (* Replace KeyInfo.KeywordValue by its value. *)
        Copy(KeyInfo.KeywordValue,KeyWord);                        (* KeyWord <- the key word. *)
        GetKeyWordValue(KeyWord, KeyInfo.KeywordValue, Context);   (* KeyInfo.KeywordValue <- value. *)
            (* Replace in original string. *)
        StoreKeyWordValueInLine(S, KeyInfo, start, stop);
        start := stop + 1;
    END;
    IF (LengthOf(S) > MaxLength) THEN
        Procustes ( S, MaxLength );
    END;
END MakeSubstitutions;


END KeywdSub.
