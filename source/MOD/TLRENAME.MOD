MODULE TLRename;



FROM Dialog        IMPORT
        (* PROCS *)     Error;

FROM Direct411    IMPORT
        (* PROCS *)     GetOutputFile;

FROM ExportLinkage   IMPORT
    (* VAR *)           InterFile, InterFileOpen;

FROM LStrings     IMPORT ConcatLS, SetString, LStringToTString;

FROM TempFile               IMPORT
    (* PROC *)                  RenameTempFile;



PROCEDURE RenameIt();
VAR
    s, s1 : ARRAY [0..79] OF CHAR;
BEGIN
    SetString(s,  "DK:.\" );
    SetString(s1, "*.DAT"   );
    IF (GetOutputFile( s, s1, s, s1, TRUE )) THEN
        ConcatLS( s, s1 );
        IF (NOT RenameTempFile (s, InterFile)) THEN
            SetString (s1, "Rename failed");
            Error (s1);
        END;
        InterFileOpen := FALSE;
    END;
END RenameIt;

BEGIN
    RenameIt();
END TLRename.
