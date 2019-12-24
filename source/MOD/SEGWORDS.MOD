IMPLEMENTATION MODULE SegWords;

(*  =========================================================================
    Last Edit : January 22, 1991 7:19PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Get portions of a string.

    MODIFICATION HISTORY:

    19-Dec-89  AJL  Original version; code taken from Menus.mod
    18-May-90  KKC  Add GetStringBeforeWordNumber, 
                    GetStringAfterWordNumber and UpdateWordAtWordNumber.
    22-Oct-90  PFG  Make GetString... functions work with delimiters
                    other than comma.
    17-Jan-91  RSC  Recoded WordNumber for speed.
    22-Jan-91  RSC  Moved WordNumber to Menus to avoid duplications.
    =========================================================================
*)



FROM LStrings               IMPORT
    (* PROC  *)                 LengthOf, Procustes, Remove,
                                Copy, ConcatLS, SubStr;

IMPORT Menus;




    (*
    These replacements for StartOfNextWord and EndOfWord have been modified to
    allow for empty words (e.g. two commas in a row have an empty word between
    them).  To allow WordNumber to keep track of multiple consecutive occurrences
    of these nulls, the convention is that an empty word begins one character
    after it ends.  For example:
    
        "Hello,,there" contains three words.
    
        Word 1 is "Hello",  start = 1, end = 5
        Word 2 is "",       start = 7, end = 6
        Word 3 is "there",  start = 8, end = 12
    *)





    (*  END OF WORD.  Given a string and an index into that string,
                      we will find the end of the word (on the
                      assumption that all words end with ','. *)

PROCEDURE EndOfWord (VAR s:ARRAY OF CHAR; i:CARDINAL; Delim:CHAR):CARDINAL;
BEGIN
    IF (s[i] = Delim) THEN
        RETURN i-1;                 (* 11/29/88 EGK *)
    END;
    WHILE (i < ORD(s[0])) AND (s[i+1] <> Delim) DO
        INC(i);
    END;
    RETURN i;
END EndOfWord;





    (* START OF NEXT WORD.  Finds the start of the next word, or
                            else the start of the last word on the
                            line. Returns FALSE if no next word.*)

PROCEDURE StartOfNextWord(VAR s:ARRAY OF CHAR; VAR i: CARDINAL;Delim:CHAR):BOOLEAN;
BEGIN
    i := EndOfWord(s,i,Delim) + 1;
    WHILE (i < ORD(s[0])) DO
        INC(i);
        IF (s[i-1] = Delim) THEN    (* 11/29/88 EGK *)
            RETURN TRUE;
        END;
    END;
    RETURN FALSE;
END StartOfNextWord;






PROCEDURE SkipBlanks(VAR s:ARRAY OF CHAR; VAR i : CARDINAL);
BEGIN
    WHILE (i <= ORD(s[0])) AND (s[i] = ' ') DO
        INC(i)
    END;
END SkipBlanks;



PROCEDURE GetDelimAndStart( VAR MenuStr : ARRAY OF CHAR;
                            VAR Delim   : CHAR;
                            VAR i       : CARDINAL );
BEGIN
    Delim := ",";    (* Default *)

        (* Menustrings starting with the default delimiter use that
           as a code to change the delimiter. *)

    i := 1;
    IF (ORD(MenuStr[0]) > 2) AND (MenuStr[1] = Delim)  THEN
        Delim := MenuStr[2];
        i := 3;
    END;
END GetDelimAndStart;




    (* We cannot use the versions of EndOfWord or FindNextEndOfWord
       exported from words because they skip over repeated occurrences
       of the delimiter character. *)


    (* WordNumber -- Return the text of the Nth menu item. *)

PROCEDURE WordNumber( VAR Menustr : ARRAY OF CHAR;
                          N       : CARDINAL;
                      VAR Word    : ARRAY OF CHAR );
BEGIN
    Menus.WordNumber( Menustr, N, Word );
END WordNumber;





(***************************************************************************
    GetStringBeforeWordNumber:
        Return a string before given word number including the delimiter
    right before it.
***************************************************************************)

PROCEDURE GetStringBeforeWordNumber(
                                     VAR InString    : ARRAY OF CHAR;
                                         FieldNumber : CARDINAL;
                                     VAR OutString   : ARRAY OF CHAR
                                   );
VAR
    CurrentWordEnd      :       CARDINAL;
    NextDelimiterPos    :       CARDINAL;
    WordCounter         :       CARDINAL;
    Delimiter           :       CHAR;
BEGIN

    GetDelimAndStart( InString, Delimiter, CurrentWordEnd );

    NextDelimiterPos := CurrentWordEnd - 1;         (* 22-Oct-90 PFG *)
    WordCounter := 1;
    LOOP

        IF ( WordCounter = FieldNumber ) THEN
            EXIT
        END;

        NextDelimiterPos := EndOfWord( InString, CurrentWordEnd, Delimiter ) 
                            + 
                            1;

        IF ( NextDelimiterPos >= LengthOf( InString ) ) THEN
            EXIT;
        END;

        CurrentWordEnd := NextDelimiterPos + 1;
        INC( WordCounter );

    END;
    Copy( InString, OutString );
    Procustes( OutString, NextDelimiterPos );
END GetStringBeforeWordNumber;




(***************************************************************************
    GetStringAfterWordNumber:
        Return a string after given word number including the delimiter
    right after it.
***************************************************************************)
PROCEDURE GetStringAfterWordNumber(
                                   VAR InString    : ARRAY OF CHAR;
                                       FieldNumber : CARDINAL;
                                   VAR OutString   : ARRAY OF CHAR
                                  );
VAR
    CurrentWordEnd      :       CARDINAL;
    NextWordEnd         :       CARDINAL;
    WordCounter         :       CARDINAL;
    Delimiter           :       CHAR;

BEGIN

    GetDelimAndStart( InString, Delimiter, CurrentWordEnd );

    NextWordEnd := 1;
    WordCounter := 1;
    LOOP

        NextWordEnd := EndOfWord( InString, CurrentWordEnd, Delimiter );

        IF ( WordCounter = FieldNumber ) THEN
            EXIT
        END;

        IF ( NextWordEnd >= LengthOf( InString ) ) THEN
            EXIT;
        END;

        CurrentWordEnd := NextWordEnd + 2;
        INC( WordCounter );

    END;
    Copy( InString, OutString );
    Remove( OutString, 1, NextWordEnd );
END GetStringAfterWordNumber;





PROCEDURE UpdateWordAtWordNumber( 
                                      VAR Line : ARRAY OF CHAR;
                                   FieldNumber : CARDINAL;
                                          Word : ARRAY OF CHAR
                                );
VAR
    TmpLine         :       ARRAY[0..255] OF CHAR;
    TmpLine2        :       ARRAY[0..255] OF CHAR;
BEGIN

    Copy( Line, TmpLine );
    GetStringBeforeWordNumber( TmpLine, FieldNumber, Line );
    ConcatLS( Line, Word );
    GetStringAfterWordNumber( TmpLine, FieldNumber, TmpLine2 );
    ConcatLS( Line, TmpLine2 );
END UpdateWordAtWordNumber;



END SegWords.
