IMPLEMENTATION MODULE Trace;

(*  =========================================================================
    Last Edit : March 28, 1991 5:30PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Tracing functions.  Root version, stolen by TLTrace.

        TO Turn on the tracing, use ADDIN IS TLTRACE.


    MODIFICATION HISTORY:

    RSC 29-Mar-91   First version.
    LAA 28-Aug-91   This had become somewhat obsolete, with further
                    improvements to TLTrace.  I've made the TraceLString
                    a procedure which depends on ThingsWeForgot (which is
                    subclassed by TLTrace), and I added TraceOn.
                    The default is On.  TraceIsOn is now a procedure which
                    returns the current status.

    =========================================================================
*)

FROM Kluges         IMPORT
    (* PROC *)          ThingsWeForgot;

FROM LStrings       IMPORT
    (* PROC *)          TStringToLString, ConcatLS;

FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS,
    (* PROC *)          ADR;


VAR
    LTraceIsOn              : BOOLEAN;


    (* Trace T String  - Given a null-terminated string, write it out
                         to the trace log if tracing is on.

        Preconditions  - none.
        Postconditions - the message has been written to the trace log
                         file if tracing is on.
    *)
PROCEDURE TraceTString( s   : ARRAY OF CHAR );
VAR
    LString : ARRAY [0..255] OF CHAR;
BEGIN

    TStringToLString( s, LString );
    TraceLString( LString );

END TraceTString;





    (* Trace T And L String - Given a TString and an LString,
               print the TString followed
               by the LString to the trace log if tracing is on.

        Preconditions  - none.
        Postconditions - the message has been written to the trace log
                         file if tracing is on.
    *)
PROCEDURE TraceTAndLString(     TString    : ARRAY OF CHAR;
                            VAR LString    : ARRAY OF CHAR );
VAR
    String : ARRAY [0..255] OF CHAR;
BEGIN

    TStringToLString( TString, String );
    ConcatLS(         String, LString );
    TraceLString( String );

END TraceTAndLString;



    (* Trace L String  - Given an LString, write it out
                         to the trace log if tracing is on.

        Preconditions  - none.
        Postconditions - the message has been written to the trace log
                         file if tracing is on.
    *)
PROCEDURE TraceLString( VAR s : ARRAY OF CHAR );

VAR
    a                       : ADDRESS;

BEGIN

    IF (LTraceIsOn) THEN
        a := ADR( s );
        IF (ThingsWeForgot( 4, a )) THEN END;
    END;

END TraceLString;



    (* Is tracing on?  This is TRUE if there is a good chance that a
       call to TraceTString or TraceLString will do anything.

    *)
PROCEDURE TraceIsOn()   : BOOLEAN;

BEGIN                       (* TraceIsOn *)

    RETURN LTraceIsOn;

END TraceIsOn;



    (*  If On is TRUE, make sure tracing is turned on.  If it's FALSE,
        the turn tracing off (which inhibits any action by TraceLString,
        TraceTString, etc.).
    *)
PROCEDURE TraceOn(    On : BOOLEAN );

BEGIN                       (* TraceOn *)

    LTraceIsOn := On;

END TraceOn;



BEGIN  (* module Trace *)

    LTraceIsOn    := TRUE;

END Trace.


