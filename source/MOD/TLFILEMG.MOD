MODULE TLFileMg;

  (* MODULE HISTORY:

         RSC Nov  2, 1987 - Ajusted for SPIKE:
                            Expect overlay context from our caller.
                            Context contains LString with filespec to
                            delete (from TLWHAT.CFG).  Preserve directory
                            path in the loop for deletion.
         RSC Feb  3, 1988 - Expand project media so it gets a trailing '/'.
         RSC May  4, 1988 - If you choose No on "really erase", dont exit
                            the overlay.
         WKH May 25, 1989 - Don't let the shadow files be erased.
         KKC Jul 31, 1989 - Call ContinuationBox instead of NoYes.
         KKC Aug 10  1989 - Add copyright message.
   *)

FROM Codes        IMPORT EmptyCodeSet;

FROM Dialog       IMPORT
    (* TYPE *)           ADialogOption,
    (* PROC *)           Message, FatalError, Error, ContinuationBox;

FROM Direct411    IMPORT GiveDirectoryAssistance;

FROM Directory    IMPORT ExtractFileNameParts, NormalizeFileName,
                         ExpandPath, AFileNamePart, ASetOfFileNameParts,
                         AFileNameRecord;

FROM FileSystem   IMPORT Delete, File, Response;

FROM FileAux      IMPORT PrepareForIO, CheckIO, FileResultMeans;

FROM Layout       IMPORT MenuEnd, GanttWEnd;

FROM LStrings     IMPORT SetString, ConcatLS,
                         Copy, SetLengthOf, LStringToTString, Insert;

FROM MsgFile      IMPORT GetMessage, ConcatMessage;

FROM Overlays     IMPORT OverlayContext;

FROM Schedule     IMPORT ProjectMedia;





CONST
    ModuleNumber = 11900;    (* For GetMessage *)




PROCEDURE DontAllowShadow( FileNameRecord : AFileNameRecord ) : BOOLEAN;
BEGIN
    IF (FileNameRecord.Extension[3] = '_') THEN
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END;
END DontAllowShadow;


PROCEDURE DeleteFiles;
VAR
    FilespecP   : POINTER TO ARRAY [0..255] OF CHAR;
    f           : File;
    Path        : ARRAY [0..127] OF CHAR;
    s           : ARRAY [0..255] OF CHAR;
    Menu        : ARRAY [0..255] OF CHAR;
    Title       : ARRAY [0..29]  OF CHAR;
    Ignore      : ARRAY [0..99]  OF CHAR;
    NullString  : ARRAY [0..0] OF CHAR;
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    FilespecP := OverlayContext();
    IF (FilespecP = NIL) THEN
        SetString(s,"TLWhat.Cfg is not set up properly; missing filespec.");
        Error(s);  (* TLWHAT NOT SET UP PROPERLY; NO CONTEXT PASSED! *)
        RETURN;
    END;
    SetLengthOf( s, 0 );
    ExpandPath(  ProjectMedia, s, Path );
    SetLengthOf( Ignore, 0 );

                          (*  Look up the projects and archives.  *)
    LOOP
        Copy( Path, s );
        ConcatLS( s, FilespecP^ );
        NormalizeFileName(s,ASetOfFileNameParts{DevicePart..ExtensionPart});
        GetMessage(ModuleNumber+1,Title);   (* "Directory List" *)
        IF (NOT GiveDirectoryAssistance(MenuEnd + 1, GanttWEnd,
                                        Title,
                                        s, Ignore,
                                        DontAllowShadow))  THEN
            EXIT;
        END;
        GetMessage(ModuleNumber+4,Menu);      (* "Last chance.  Delete ' " *)
        ConcatLS( Menu, s );                  (* <path\name> *)
        ConcatMessage(Menu, ModuleNumber+5);  (* " ' from the disk?" *)
        SetLengthOf(NullString, 0);
        IF ( ContinuationBox (Menu, NullString, NoHelp) ) THEN
            ExtractFileNameParts( s, Path, Menu, Ignore, Title );
            ConcatLS( Path, Menu );  (* Save path for next pass through. *)
            LStringToTString(s,s);
            f.res := done;
            PrepareForIO(f);
            Delete(s,f);
            IF (CheckIO(f) <> done) THEN
                FileResultMeans(f,Menu);
                Error(Menu);
            END;
        END;
    END;

END DeleteFiles;






BEGIN
    DeleteFiles();
END TLFileMg.
