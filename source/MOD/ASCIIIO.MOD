IMPLEMENTATION MODULE AsciiIO;


  (* ASCII IO - READ AND WRITE ASCII FILES.

        This module contains some low level routines to read an write
        ascii text files.  This will be in the root of Time Line, so it
        is the minimum needed for the root.

        This module also contains some general file complaint procedures.

        11/10/87 RSC - First version - consolidated code from a few areas.

  *)


FROM ASCII           IMPORT
        (* CONST *)     EOL;

FROM Dialog          IMPORT
        (* PROCS *)     Error;

FROM FileAux         IMPORT
        (* PROCS *)     PrepareForIO, CheckIO, FileResultMeans, OverlayPath,
                        DisplayFileError;

FROM FileOpen        IMPORT
        (* PROC *)      RequestFileOpenReadOnly;

FROM FileSystem      IMPORT
        (* TYPES *)     File,
        (* PROCS *)     Response, ReadChar, Close, Reset;

FROM LStrings        IMPORT
        (* PROCS *)     ConcatLS, ConcatS, Copy;



 (* File Complaint - Complain about the file that just had an error.

        Preconditions  - File Name is the text name of the file.
                         f is the file structure that just had an error.

        Postconditions - f is closed and user has been warned.
 *)
PROCEDURE FileComplaint( VAR FileName : ARRAY OF CHAR;
                         VAR f        : File            );
VAR
    s  : ARRAY [0..255] OF CHAR;
    s2 : ARRAY [0..255] OF CHAR;
BEGIN
    DisplayFileError(f,FileName);
    Close(f);
END FileComplaint;



 (* Read Character - Read a character from the file.

        Preconditions  - FileName is the text name of the file for error reporting.
                         f must be open and positioned properly.
        Postconditions - C contains the character read.
                         If there was an error reading the file,
                         RETURN is FALSE and the file has been closed.
                         error could have been EOF.  If not, user has been
                         warned of error via FileComplaint.
 *)
PROCEDURE ReadCharacter( VAR FileName : ARRAY OF CHAR;
                         VAR f        : File; 
                         VAR C        : CHAR ) : BOOLEAN;
BEGIN
    PrepareForIO( f );
    ReadChar( f, C );
    IF ( f.eof ) THEN
        Close( f );
        RETURN FALSE;
    ELSIF ( CheckIO( f ) <> done ) THEN
        FileComplaint( FileName, f );
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END;
END ReadCharacter;



 (* ReadString -- Read up to the terminator or EOL.

        Preconditions  - File Name is the text name for error reporting.
                         f is the opend file structure, positioned ok.
                         Terminator is the terminating char to read for,
                            0 means 'look only for EOL'.
        Postconditions - String is filled in with the resulting string.
                         RETURN is TRUE iff string read ok, else, the
                         file in f has been closed and the user warned.
  *)
PROCEDURE ReadString( VAR FileName   : ARRAY OF CHAR;
                      VAR f          : File;
                          Terminator : CHAR;
                      VAR String     : ARRAY OF CHAR ) : BOOLEAN;
VAR
    i : CARDINAL;
    C : CHAR;
BEGIN
    i := 0;
    C := 0C;
    LOOP
        IF (i <= HIGH(String)) THEN
            String[i] := C;
            String[0] := CHR(i);
        END;
        IF (NOT ReadCharacter( FileName, f, C )) THEN
            RETURN FALSE;
        ELSIF (C = Terminator) OR (C = EOL) THEN
            EXIT;
        END;
        INC(i);
    END;
    RETURN TRUE;
END ReadString;


 (* Open Input File - Open a file for input.

        Preconditions  - FileName is the text name to open.
                         Description is the description for RequestFileOpen.

        Postconditions - f is the opened file iff RETURN is TRUE.
 *)

PROCEDURE OpenInputFile(VAR FileName    : ARRAY OF CHAR;
                        VAR Description : ARRAY OF CHAR;
                        VAR f           : File          ) : BOOLEAN;
BEGIN
    RETURN RequestFileOpenReadOnly(OverlayPath, FileName, Description, f);
END OpenInputFile;




BEGIN

END AsciiIO.
