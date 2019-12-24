IMPLEMENTATION MODULE FileOpen;

    (*  MODIFICATION HISTORY
        25-Jan-88 LAA   Put in exclusive access for file opens under dos 3.0.
        06-Apr-89 WKH   Changed FileOpenReadOnly to work with networks.
    *)

FROM FileSystem  IMPORT File, Response, OpenFile, ReadOnlyMode, ReadWriteMode,
                        ExclusiveAccessMode, ReadOnlyAccessMode, FullAccessMode;

FROM Codes       IMPORT ACode,
                        ASetOfCodes,
                        SetCodeBits, MaxCode;

FROM GaGa        IMPORT
        (* PROCS *)     GetGaGaMessage, ConcatGaGaMessage;

FROM Keys        IMPORT CancelKey, HelpKey;

FROM LStrings    IMPORT SetString, ConcatLS, LStringToTString,
                        TStringToLString, LJust, TrimRear, SubStr,
                        Remove, ConcatS;

FROM FileAux     IMPORT OverlayPath, PrepareForIO, CheckIO,
                        FileResultMeans, DisplayFileError;

FROM Directory   IMPORT PathLookupStart, NormalizeFileName,
                        AFileNamePart, ASetOfFileNameParts,
                        DirectoryIsReachable, RemovableMedia,
                        GetPathEntry, DOSVersion;

FROM Dialog      IMPORT ContinuationBox, Error, ADialogOption, WarningBox;




CONST  ModuleNumber = 22000;  (* For GetGaGaMessage *)




     (*  RequestFileFind -- Attempt to find the file using the
                            given path.  If the file cannot
                            be found, put up a dialog box asking the
                            user to insert the disk.

                            FALSE is returned if the user cancels the
                            operation or if a serious error occurs.
                            *)


PROCEDURE RequestFileFind(VAR Path        : ARRAY OF CHAR;
                          VAR FileName    : ARRAY OF CHAR;
                          VAR Description : ARRAY OF CHAR;
                          VAR DirectoryIn : ARRAY OF CHAR;
                          VAR FileNameIn  : ARRAY OF CHAR
                         ):BOOLEAN;
BEGIN
    LOOP
        IF (PathLookupStart(Path,FileName,DirectoryIn,FileNameIn)) THEN
            RETURN TRUE;
        ELSIF (NOT TryAgain(Path,FileName,Description)) THEN
            RETURN FALSE;
        END;
    END;
END RequestFileFind;










     (*  RequestFileOpen -- Attempt to open the file using the
                            given path.  If the file cannot
                            be found, put up a dialog box asking the
                            user to insert the disk.

                            FALSE is returned if the user cancels the
                            operation or if a serious error occurs.
                            *)


PROCEDURE FileOpenCommon( VAR Path        : ARRAY OF CHAR;
                          VAR FileName    : ARRAY OF CHAR;
                          VAR Description : ARRAY OF CHAR;
                          VAR f           : File;
                              Mode        : CARDINAL
                         ):BOOLEAN;
VAR
    s         : ARRAY [0..200] OF CHAR;
    s2        : ARRAY [0..60] OF CHAR;
BEGIN
    IF (RequestFileFind(Path,FileName,Description,s,s2)) THEN
        ConcatLS(s,s2);
        LStringToTString(s,s);
        PrepareForIO(f);
        OpenFile( f, s, Mode );
        IF (CheckIO(f) <> done) THEN
            TStringToLString(s,s);
            DisplayFileError(f,s);
        ELSE
            RETURN TRUE;
        END;
    END;
    RETURN FALSE;
END FileOpenCommon;


CONST
    DOS3PointZero           = 0300H;


PROCEDURE RequestFileOpen(VAR Path        : ARRAY OF CHAR;
                          VAR FileName    : ARRAY OF CHAR;
                          VAR Description : ARRAY OF CHAR;
                          VAR f           : File
                         ):BOOLEAN;

VAR
    Mode                    : CARDINAL;

BEGIN
    Mode := ReadWriteMode;
    IF (DOSVersion() >= DOS3PointZero) THEN
        INC(Mode, ExclusiveAccessMode);
    END;
    RETURN FileOpenCommon( Path, FileName, Description, f, Mode );
END RequestFileOpen;



PROCEDURE RequestFileOpenReadOnly(VAR Path        : ARRAY OF CHAR;
                                  VAR FileName    : ARRAY OF CHAR;
                                  VAR Description : ARRAY OF CHAR;
                                  VAR f           : File
                                 ):BOOLEAN;
VAR
    Mode                    : CARDINAL;

BEGIN
    Mode := ReadOnlyMode;
    IF (DOSVersion() >= DOS3PointZero) THEN
        INC(Mode, FullAccessMode);  (* 4/6/89 WKH *)
    END;
    RETURN FileOpenCommon( Path, FileName, Description, f, Mode );
END RequestFileOpenReadOnly;











PROCEDURE TryAgain(VAR Path        : ARRAY OF CHAR;
                   VAR FileName    : ARRAY OF CHAR;
                   VAR Description : ARRAY OF CHAR):BOOLEAN;
VAR
    S         : ARRAY [0..255] OF CHAR;
    Title     : ARRAY [0..39]  OF CHAR;
    MultiPath : BOOLEAN;
    Directory : ARRAY [0..80] OF CHAR;
BEGIN
        (* Is there more than 1 directory in the path? *)

    MultiPath := GetPathEntry(Path,1,Directory);

        (* Locate the first directory in the Path. *)

    IF (GetPathEntry(Path,0,Directory)) THEN; END;

    GetGaGaMessage( ModuleNumber + 0, Title ); (* "Looking for " *)
    ConcatLS(Title,FileName);

    IF (RemovableMedia(Directory)) THEN
        GetGaGaMessage( ModuleNumber + 1, S ); (* "Please insert " *)
        LJust(Description);
        TrimRear(Description);
        IF (Description[0] = 0C) THEN
            ConcatGaGaMessage( ModuleNumber + 2, S ); (* "disk with file " *)
            ConcatLS(S,FileName);
        ELSE
            ConcatLS(S,Description);
        END;
        ConcatGaGaMessage( ModuleNumber + 3, S );
                 (* "$and press [Enter] to retry (or [Esc] to cancel)." *)
        RETURN ContinuationBox(S,Title,NoHelp);
    ELSIF (MultiPath) THEN
        GetGaGaMessage( ModuleNumber + 4, S ); (* "ü;Cannot find file " *)
        ConcatLS(S,FileName);
        ConcatGaGaMessage( ModuleNumber + 5, S ); (* " in any of these directories:;" *)
        ConcatLS(S,Path);
        ConcatGaGaMessage( ModuleNumber + 6, S ); (* ";Press [Esc]." *)
    ELSE
        IF (DirectoryIsReachable(Directory)) THEN
            GetGaGaMessage( ModuleNumber + 7, S ); (* "Cannot find file " *)
            ConcatLS(S,Directory);
            ConcatLS(S,FileName);
        ELSE
            GetGaGaMessage( ModuleNumber + 8, S ); (* "Cannot find directory " *)
            ConcatLS(S,Directory);
        END;
        ConcatGaGaMessage( ModuleNumber + 9, S ); (* "üPress [Esc]." *)
    END;

    WarningBox(S,Title,NoHelp);
    RETURN FALSE;
END TryAgain;



BEGIN
END FileOpen.
