
IMPLEMENTATION MODULE MsgLog;


FROM ImPorTable     IMPORT
                           ImportNote;


FROM LStrings       IMPORT
    (* PROC *)              TStringToLString,
                            SetString, SetLengthOf,
                            ConcatLS,
                            ConcatS,
                            LengthOf,
                            CtoS;

FROM Text           IMPORT
    (* PROC *)              AppendLine, DiscardText,
    (* PROC *)              Compress,   CreateText;


CONST
    ModuleNumber            = 29300; (* Same as TLIMPORT *)
    EOSF                    = 0FFH;
    MaxCardinal             = 65535;                              (* 27-Aug-89 MWP *)



PROCEDURE LogAMessage ( VAR Msg : ARRAY OF CHAR );
VAR
    ok   :   BOOLEAN;
BEGIN

    ok := AppendLine( Msg, ImportNote );

END LogAMessage;

BEGIN
END MsgLog.
