IMPLEMENTATION MODULE MsgFileAux;

(*  =========================================================================
    Last Edit : January 19, 1990 11:13AM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Auxiliary functions for dealing with phrases.

    MODIFICATION HISTORY:
        19-Jan-90 WKH   Initial version.

    =========================================================================
*)

FROM LStrings      IMPORT
        (* PROCS *)     SetLengthOf;

FROM SegWords      IMPORT
        (* PROCS *)     WordNumber;

FROM MsgFile       IMPORT
        (* PROCS *)     GetMessage;

VAR
        (* For the Get Message Word procedure: *)

        GlobalPhrase        : CARDINAL;
        GlobalPhraseString  : ARRAY [0..255] OF CHAR;


  (* Get Message Word - Get the nth word (0...m) from a phrase.

        Preconditions  - Phrase  is the phrase to get from the phrases file.
                         WordNumber is the Nth substring to return, N starting
                                        with 0 (for ORD(Enumeration)).  Substrings
                                        are delimited by commas.
        Postconditions - LString is the phrase.

   Note: This procedure uses a one-phrase cache, so if the requested phrase
         is the same as the last requested phrase, we do not re-ask the
         message processor for it.
  *)
PROCEDURE GetMessageWord(    Phrase,
                             Word       : CARDINAL;
                         VAR LString    : ARRAY OF CHAR );

BEGIN
    IF (Phrase <> GlobalPhrase) THEN
        GlobalPhrase := Phrase;
        GetMessage( Phrase, GlobalPhraseString );
    END;
    WordNumber( GlobalPhraseString, Word + 1, LString );
END GetMessageWord;

BEGIN  (* module MsgFileAux *)
    GlobalPhrase    := 0;
    SetLengthOf(GlobalPhraseString, 0); (* 19-Jan-90 WKH  *)
END MsgFileAux.


