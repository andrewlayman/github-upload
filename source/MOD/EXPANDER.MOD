IMPLEMENTATION MODULE Expander;


    (*  Expander -- A module that supports reading compressed files. *)

    (* This module has local memory, and will produce bad results if
       files are switched while any expansion is incomplete. *)

    (* MODIFICATION HISTORY

       14-Sep-88  AJL -Use ReadByte rather than read char.  This prevents
                       RS from being translated into CR-LF. 

    *) 


FROM FileSystem             IMPORT
    (* TYPE *)                  File,
    (* PROC *)                  ReadByte;


CONST
    RCODE     = 2C;    (*  Signals a repeating series of characters. *)
    SCODE     = 3C;    (*  Signals a repeating series of spaces. *)
    BIAS      = 31;
VAR
    ExpansionToGo  : CARDINAL;
    ExpansionChar  : CHAR;

PROCEDURE ReadUncompressedChar(VAR f:File; VAR c:CHAR);
BEGIN
    IF (ExpansionToGo > 0) THEN
        c := ExpansionChar;
        DEC(ExpansionToGo);
    ELSE
        ReadByte(f,c);
        IF (c = RCODE) OR (c = SCODE) THEN
            IF (c = SCODE) THEN
                ExpansionChar := " ";
            ELSE
                ReadByte(f,ExpansionChar);
            END;
            ReadByte(f,c);
            ExpansionToGo := ORD(c) + 1 - BIAS;
            ReadUncompressedChar(f,c);
        END;
    END;
END ReadUncompressedChar;


PROCEDURE InitExpansion;
BEGIN
    ExpansionToGo := 0;
END InitExpansion;



BEGIN
    InitExpansion;
END Expander.
