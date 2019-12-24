IMPLEMENTATION MODULE FormStatic;

    (* MODIFICATION HISTORY:

         1/10/89  RSC   First version, from FormRead.
        13-Jun-89 RSC   Remove "FormFileShared".  It always is in LAZLO.
                        Spiff up "SetFormFileName" to close the forms
                        file in prep for an alternate forms file.  This
                        allows field installing additional forms.
         2-Apr-91 TGS   Look for TLFORMS5.DAT instead of TLFORMS4.DAT.
    *)



FROM FileSystem     IMPORT
    (* PROCS *)         Close;

FROM LStrings       IMPORT
    (* PROCS *)         SetString, Copy;




    (* SetFormFileName -- Supply a file name that is to be used instead
                          of the default file name for the forms file.
                          This allows an alternate file to be used.
                          Call this before the first call to a form.
                          DO NOT INCLUDE A PATH.
    *)



PROCEDURE SetFormFileName( VAR S : ARRAY OF CHAR );
BEGIN
    Copy(S,FormFileName);
    IF (FormFileIsOpen) THEN
        Close(FormFile);
        FormFileIsOpen  := FALSE;
    END;
END SetFormFileName;





BEGIN
    FormFileIsOpen  := FALSE;
    HolderListHead  := NIL;
    SetString( FormFileName, "TLFORMS5.DAT" );
END FormStatic.
