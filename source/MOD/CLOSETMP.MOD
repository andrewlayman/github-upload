MODULE CloseTmp;


FROM ExportLinkage          IMPORT
    (* VAR *)                   InterFile, InterFileOpen;

FROM FileSystem             IMPORT
    (* PROC *)                  Close;



BEGIN
    IF (InterFileOpen) THEN
        Close(InterFile);
        InterFileOpen := FALSE;
    END;
END CloseTmp.
