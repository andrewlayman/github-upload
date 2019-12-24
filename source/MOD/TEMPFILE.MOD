IMPLEMENTATION MODULE TempFile;

  (* Temp File - Implement a cheesy temporary file scheme.

        17-Jun-88 RSC Initial version.
        21-Jun-88 EGK Changed RenameTempFile to accept a different directory.
        21-Sep-89 RSC Ajusted size passed to Holder.  NEW(FileName) created
                      110 bytes, we told holder there were 109 bytes (we
                      used HIGH(FileName)).  I changed this to SIZE(FileName).
        22-Sep-89 RSC Oops.  Missed one check against HIGH() rather than
                      SIZE().
        10-Nov-89 EGK In CopyFile, use Reset() rather than SetPos(0,0).
                      Fixes bug which made FromFile look empty before
                      anything was read from it.  (Looks like Reset causes
                      the buffer to be updated to the beginning of the file,
                      but the SetPos does not.)
        23-Oct-90 RSC Changed %'s to TMP in filenames for Dos batch.

      HISTORY:
      ========

                The Logitek Create() call from FileSystem used to be used
                for File/Save and File/Export because:

                        1) When the file was created, it was created with
                           a dummy name, and so would not clobber existing
                           files.
                        2) When the file was closed (explicitly or by an
                           overlay exit) it was deleted.
                        3) If the file was RENAMED, and then closed, it
                           stayed permanent.

                Thus we could create the file temporarily, and then, if all
                was done properly, we would rename/delete any old file with
                the target name, and then rename the TEMP (created) file to
                the target name.

      PROBLEM:
      ========

                After we shipped the product, we discovered that some network
                users had errors because of the following:

                        1) Create() puts the temp file in the CURRENT
                           directory of the target drive, not the TARGET
                           directory of the target drive.

                        2) Some network users do not bother to set their
                           CURRENT network directory to the directory
                           they have access to.

                        For example:

                           Kris logs into the network and is given a new
                           drive F: to use.  She does not change the default
                           path of F:\ to the path she has access to,
                           F:\USERS\KGOMPPER\

                           The Create() call tries to create the temp file on
                           F:\ and fails, even though Kris wanted the saved
                           file to end up on F:\USERS\KGOMPPER\.

      THIS MODULE:
      ============

                We can't patch the Create() call, because it is in the ROOT
                and we can't change that yet.

                We can't put global data in the root or in TLPUTIT, because
                we can't change that yet.

                Ta ta!  Enter this module!

                        > Creates temp files in a specified directory.
                        > Deletes and closes in one step.
                        > Rename and closes in one step.
                        > Context is saved in HOLDER, so this module does
                          not have to have its data shared across the file
                          creator/renamer (as in the case of the exporters).

  *)

FROM AsciiIO            IMPORT
        (* PROCS *)        FileComplaint;

FROM Dialog             IMPORT
        (* PROCS *)        FatalError;

FROM Directory          IMPORT
        (* PROCS *)        ExtractFileNameParts;

FROM FileAux            IMPORT
        (* PROCS *)        PrepareForIO, CheckIO;

FROM FileSystem         IMPORT
        (* TYPE *)         File, Response,
        (* PROCS *)        Delete, Lookup, Close, Rename, SetRead, SetWrite,
                           SetPos, ReadNBytes, WriteNBytes, Reset;

FROM Holder             IMPORT
        (* TYPES *)        AHoldType, AHoldTypeSet,
        (* PROCS *)        HoldThis, LocateHeldItem, DeleteHeldItem;

FROM LStrings           IMPORT
        (* PROCS *)        Copy, ConcatS, ConcatLS, SetString,
                           LStringToTString;

FROM Space              IMPORT
        (* PROCS *)        HeapAvailable, ALLOCATE, Available;

FROM SYSTEM             IMPORT
        (* THINGS *)       ADR, SIZE;





CONST
    HoldCategory = AHoldTypeSet{HeapNoOwner,ErrorIfDuplicate,HoldsLString};
    HoldClass    = 34;

VAR
    HoldName    : ARRAY [0..9] OF CHAR;
    FileName    : POINTER TO ARRAY [0..109] OF CHAR; (* Name of file *)





  (* CopyFile - Copy the contents of FromFile to ToFile.

        Preconditions  - Both parameters must be valid handles to open files.
        Postconditions - Contents of FromFile copied to ToFile, or else
                         FALSE is returned.
  *)
PROCEDURE CopyFile  (  VAR  FromFile        : File;
                       VAR  ToFile          : File  )   : BOOLEAN;

CONST
    BufferSize          = 512;
VAR
    Buffer              : ARRAY [0..BufferSize-1] OF CHAR;
    WriteCount          : CARDINAL;
    ReadCount           : CARDINAL;
    ok                  : BOOLEAN;

BEGIN
    Reset (FromFile);                   (* 11/10/89 EGK *)
    Reset (ToFile);                     (* 11/10/89 EGK *)
    SetRead (FromFile);
    SetWrite (ToFile);
    PrepareForIO (FromFile);
    PrepareForIO (ToFile);

    ok := FALSE;
    WHILE (CheckIO (FromFile) = done) AND
            (CheckIO (ToFile) = done) AND
            (NOT FromFile.eof)        DO
        ReadNBytes (FromFile, ADR(Buffer), BufferSize, ReadCount);
        IF (ReadCount = 0) THEN
            RETURN FALSE;
        END;
        WriteNBytes (ToFile, ADR(Buffer), ReadCount, WriteCount);
        IF (WriteCount <> ReadCount) THEN
            RETURN FALSE;
        END;
        ok := TRUE;
    END;
    RETURN ok;
END CopyFile;






  (* Create Temp File - Create a temporary file in the specified directory.

        Preconditions  - FilePath contains a directory path (DK: is ok).
        Postconditions - FileHandle is opened, file must be closed via
                         either RenameTempFile or DeleteTempFile.
                         TRUE means "ok".
  *)
PROCEDURE CreateTempFile( VAR FilePath   : ARRAY OF CHAR;
                          VAR FileHandle : File           ) : BOOLEAN;
VAR
    Size     : CARDINAL;
    Category : AHoldTypeSet;
    s        : ARRAY [0..109] OF CHAR;
    Device   : ARRAY [0..5]   OF CHAR;
    Path     : ARRAY [0..99]  OF CHAR;
    Name     : ARRAY [0..9]   OF CHAR;
    Ext      : ARRAY [0..3]   OF CHAR;
    ok       : BOOLEAN;
BEGIN
    IF (LocateHeldItem( HoldName, HoldClass, Category, FileName, Size )) THEN
        DeleteHeldItem( HoldName, HoldClass );
    END;
    IF (Available(1024)) THEN  (* Enough for us to run. *)
        ExtractFileNameParts( FilePath, Device, Path, Name, Ext );
        NEW( FileName );
        Copy( Device, FileName^ );
        ConcatLS( FileName^, Path );
        ConcatS(  FileName^, "TEMPFILE.TMP" );
        HoldThis( HoldName, HoldClass, HoldCategory, FileName, SIZE(FileName^) );
        LStringToTString( FileName^, s );
        PrepareForIO( FileHandle );
        Lookup( FileHandle, s, TRUE );
        IF (CheckIO( FileHandle ) = done) THEN
            RETURN TRUE;
        END;
        FileComplaint( FileName^, FileHandle );
    ELSE
        ok := HeapAvailable();  (* This should give an "out of memory" error. *)
    END;
    RETURN FALSE;
END CreateTempFile;




  (* Rename Temp File  -  Rename and close the temp file to a new name.

        Preconditions  - FileName is what to rename the file to.  Only the
                                  file name and extension is needed, as the
                                  path MUST be the same as the path used to
                                  create the file.
                         FileHandle is the active handle returned from the
                                  CreateTempFile call.
        Postconditions - File has been renamed and closed, or else FALSE
                                  is returned.
  *)
PROCEDURE RenameTempFile( VAR LFileName  : ARRAY OF CHAR;
                          VAR FileHandle : File           ) : BOOLEAN;
VAR
    Category : AHoldTypeSet;
    Size     : CARDINAL;
    s, s1    : ARRAY [0..109] OF CHAR;
    ok       : BOOLEAN;
    NewFile  : File;

BEGIN

 (* If the item is not found, then it was closed already. *)

    IF (LocateHeldItem( HoldName, HoldClass, Category, FileName, Size )) THEN
        IF (Size <> SIZE(FileName^)) THEN
            FatalError;
        END;

            (* Try to create the new file. *)

        LStringToTString (LFileName, s);
        PrepareForIO (NewFile);
        Lookup (NewFile, s, TRUE);
        ok := (CheckIO(NewFile) = done);

            (* Try to copy from the temp file to the new file. *)

        ok := ok AND (CopyFile (FileHandle, NewFile));

            (* Now delete the temp file, whether or not the copy succeeded. *)

        PrepareForIO (NewFile);
        Close (NewFile);
        PrepareForIO (FileHandle);
        Close (FileHandle);
        PrepareForIO (FileHandle);
        LStringToTString (FileName^, s);
        Delete (s, FileHandle);
        IF (CheckIO( FileHandle ) <> done) THEN
            FileComplaint( FileName^, FileHandle );
        END;
        DeleteHeldItem( HoldName, HoldClass );

            (* How did we do? *)

        RETURN ok;
    END;
    RETURN FALSE;
END RenameTempFile;





  (* Delete Temp File - Delete and close the temp file.

        Preconditions  - FileHandle is the active handle returned by the
                                  CreateTempFile call.
        Postconditions - File is deleted and closed.
  *)
PROCEDURE DeleteTempFile( VAR FileHandle : File           );
VAR
    Category : AHoldTypeSet;
    Size     : CARDINAL;
    s        : ARRAY [0..109] OF CHAR;
BEGIN

 (* If the item is not found, then it was closed already. *)

    IF (LocateHeldItem( HoldName, HoldClass, Category, FileName, Size )) THEN
        IF (Size <> SIZE(FileName^)) THEN
            FatalError;
        END;
        PrepareForIO( FileHandle );
        Close( FileHandle );
        PrepareForIO( FileHandle );
        LStringToTString( FileName^, s );
        Delete( s, FileHandle );
        IF (CheckIO( FileHandle ) <> done) THEN
            FileComplaint( FileName^, FileHandle );
        END;
        DeleteHeldItem( HoldName, HoldClass );
    END;
END DeleteTempFile;




    (* MAIN *)

BEGIN
    SetString( HoldName, "TempFile" );
END TempFile.
