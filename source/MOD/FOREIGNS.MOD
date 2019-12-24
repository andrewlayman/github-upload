IMPLEMENTATION MODULE ForeignSubfiles;


    (*  Foreign Subfiles  - track all data records in subfiles that we
                            do not recognize.

        Modification History:

            RSC  1/10/89    Initial cut.  Is that like a circumcision?
            RSC 29-Jun-89   Revised the gameplan for this module.
                            "Finished" implementing this.
            RSC 31-Aug-89   Finished and integrated this module.
    *)



FROM Dialog         IMPORT
    (* PROC *)          Error, FatalError;

FROM FileSystem     IMPORT
    (* TYPE *)          Response, File;

FROM FileAux        IMPORT
    (* TYPE *)          CheckIO;

FROM FlexStor       IMPORT
    (* TYPE *)          AnExtStoragePreference, AnExtHandle, AnExtStatus,
    (* PROCS *)         CreateExtObjectWithSize, LockObject,
                        DiscardExtObject, ReleaseObject,
                        ReleaseUnchangedObject, GetExtStatus;

FROM Holder         IMPORT
    (* TYPE *)          AHoldTypeSet, AHoldType,
    (* PROC *)          HoldThis, ForAllHeldItems, DeleteHeldItem;

FROM LStrings       IMPORT
    (* PROC *)          SetString, CtoS, StoC, ConcatS, ConcatLS, Search,
                        LengthOf, Copy;

FROM Menus          IMPORT
    (* PROCS *)         WordNumber;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage;

FROM RecordIO       IMPORT
    (* PROCS *)         ReadRecordPreface, ReadRecordBody, WriteRecord;

FROM Space          IMPORT
    (* PROC *)          HeapAvailable, ALLOCATE, DEALLOCATE;

FROM Subfiles       IMPORT
    (* PROCS *)         StartSubfileInput, StartSubfileOutput,
                        EndSubfileOutput;

FROM SYSTEM         IMPORT
    (* THINGS *)        ADR, SIZE, TSIZE, ADDRESS;





CONST
    ModuleNumber    = 8700;   (* Phrase file number *)
    HoldClass       = 1125;   (* Julia's birthday. *)

    MaxReasonableSize = 3000; (* Foreign records cannot be bigger than this. *)

TYPE
    AHolderRecord   = POINTER TO RECORD
        SubfileNumber   : CARDINAL;
        Version         : CARDINAL;
        FirstHandle     : AnExtHandle;
    END;


    ASubFileRecord = RECORD
        NextHandle : AnExtHandle;
        RecordType : CARDINAL;
        DataSize   : CARDINAL;
        TheData    : ARRAY [1..MaxReasonableSize] OF CHAR;
    END;

    ASubFileRecordPtr = POINTER TO ASubFileRecord;



VAR
    GOutputFile   : POINTER TO File;  (* Output file when writing subfiles. *)

    ForeignName   : ARRAY AFileType OF ARRAY [0..19] OF CHAR;

    GFileType     : AFileType;






    (* Do Error  - put out an error message. *)

PROCEDURE DoError( Which : CARDINAL );
VAR
    s   : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage( ModuleNumber + Which, s );
    Error( s );     (* Can't absorb foreign items. *)
END DoError;








PROCEDURE WriteOneSubfile( VAR OutputFile       : File;
                               SubfileNumber,
                               Version          : CARDINAL;
                               Handle           : AnExtHandle );
VAR
    Size                : CARDINAL;
    TheNextHandle       : AnExtHandle;
    SubFileRecordPtr    : ASubFileRecordPtr;
    Stop                : BOOLEAN;
BEGIN

    IF (CheckIO( OutputFile ) <> done) THEN
        RETURN;
    END;

    StartSubfileOutput( OutputFile, SubfileNumber, Version );
    Stop := (CheckIO( OutputFile ) <> done);


    WHILE (NOT Stop) AND (Handle <> AnExtHandle(NIL)) DO
        Size        := LockObject( Handle, SubFileRecordPtr );
        WITH SubFileRecordPtr^ DO
            WriteRecord( OutputFile,
                         RecordType,
                         ADR(TheData),
                         DataSize );
            TheNextHandle := NextHandle;
        END;
        Stop        := (CheckIO( OutputFile ) <> done);
        ReleaseUnchangedObject( Handle );
        Handle      := TheNextHandle;
    END;

    EndSubfileOutput( OutputFile, SubfileNumber );

END WriteOneSubfile;







(* MaybeWriteOneSubfile
*)
PROCEDURE MaybeWriteOneSubfile(    Name     : ARRAY OF CHAR;
                                   Class    : CARDINAL;
                                   Category : AHoldTypeSet;
                                   Where    : ADDRESS;
                                   Size     : CARDINAL );
VAR
    HolderRecord    : AHolderRecord;
BEGIN

    IF (Class = HoldClass) AND (Search( Name, ForeignName[GFileType], 1 ) = 1) THEN
        HolderRecord := AHolderRecord(Where);
        WriteOneSubfile( GOutputFile^,
                         HolderRecord^.SubfileNumber,
                         HolderRecord^.Version,
                         HolderRecord^.FirstHandle );
    END;

END MaybeWriteOneSubfile;









PROCEDURE MaybeDeleteOneSubfile(    Name     : ARRAY OF CHAR;
                                    Class    : CARDINAL;
                                    Category : AHoldTypeSet;
                                    Where    : ADDRESS;
                                    Size     : CARDINAL );
VAR
    HolderRecord        : AHolderRecord;
    Handle,
    NextHandle          : AnExtHandle;
    SubFileRecordPtr    : ASubFileRecordPtr;
BEGIN

    IF (Class = HoldClass) AND (Search( Name, ForeignName[GFileType], 1 ) = 1) THEN
        HolderRecord := AHolderRecord(Where);
        Handle       := HolderRecord^.FirstHandle;

        WHILE (Handle <> AnExtHandle(NIL)) DO
            Size        := LockObject( Handle, SubFileRecordPtr );
            NextHandle  := SubFileRecordPtr^.NextHandle;
            ReleaseUnchangedObject( Handle );
            DiscardExtObject( Handle );
            Handle      := NextHandle;
        END;

        DISPOSE( HolderRecord );

        DeleteHeldItem( Name, Class );

    END;

END MaybeDeleteOneSubfile;









(* Write All Foreign Subfiles - Write out all previously stored subfiles.

    Preconditions   - A File of Subfiles has been created/opened, and is
                      passed in as the file variable.

    Postconditions  - Any "foreign" subfiles read for the specified file
                      type in earlier in this run of Time Line have been
                      written out to the file.

    Input Parameters  - TheFile     An Open file of subfiles to be written to.
                        FileType    Which kind of subfile to be written.

    Output Parameters - TheFile     An Open file of subfiles.
*)
PROCEDURE WriteAllForeignSubfiles( VAR TheFile  : File;
                                       FileType : AFileType );
BEGIN

    GOutputFile   := ADR(TheFile);
    GFileType     := FileType;
    ForAllHeldItems( MaybeWriteOneSubfile );

END WriteAllForeignSubfiles;






(* Delete All Foreign Subfiles - remove stored files from memory.

    Preconditions  - Client wants to remove all foreign subfiles of
                     type "FileType".  This is generally used during
                     schedule erase on schedule file foreigners.

                     Holder system is running.

    Postconditions - all space taken by the foreigns of type FileType
                     have been freed up.

    Input Parameters - FileType   is the kind of subfile you want
                                  deleted.

    Output Parameters - none.
*)
PROCEDURE DeleteAllForeignSubfiles(    FileType : AFileType );
BEGIN

    GFileType     := FileType;
    ForAllHeldItems( MaybeDeleteOneSubfile );

END DeleteAllForeignSubfiles;







PROCEDURE SubfileNumberIsForeign(     SubfileNumber : CARDINAL;
                                      FileType      : AFileType ) : BOOLEAN;
VAR
    WordNum : CARDINAL;
    s1      : ARRAY [0..9]   OF CHAR;
    Phrase  : ARRAY [0..255] OF CHAR;


    PROCEDURE Card( VAR s : ARRAY OF CHAR ) : CARDINAL;
    VAR
        i   : CARDINAL;
    BEGIN
        i := 1;
        RETURN StoC( s, i );
    END Card;

BEGIN
    IF (SubfileNumber = 65535) THEN     (* This should be in SUBFILES! *)
        RETURN FALSE;                   (* So this is temporary.       *)
    END;

    (* We will get this phrase once for each subfile read, but it should be
       in a cache, so we won;t worry about the overhead.
    *)
    GetMessage( ModuleNumber + 50 + ORD(FileType), Phrase );

    WordNum := 1;
    WordNumber( Phrase, WordNum, s1 );
    WHILE (LengthOf(s1) <> 0) AND
          (SubfileNumber <> Card( s1 )) DO
        INC( WordNum );
        WordNumber( Phrase, WordNum, s1 );
    END;

    RETURN (LengthOf(s1) = 0);  (* Foreign if we cannot find it. *)

END SubfileNumberIsForeign;







(* Digest Subfile - ASubfileTraverseProc to gobble up one subfile.

    Preconditions - TraverseSubfiles has been called, and this procedure
                    has been given to it as the "ASubfileTraverseProc".
                    TraverseSubfiles reads the directory of a file of
                    subfiles and calls this procedure once for each
                    subfile found.

                    The client wants any foreign subfiles read from the
                    file and stored for later.

    Postconditions - The subfile has been scooped up into Holder and
                     FlexStor.

    Input Parameters    - TheFile       The file containing subfiles.
                                        Open, and no errors pending.
                          SubfileNumber the subfile to read from the file.
                          Version       the subfile's version number.
                          Context       POINTER TO AFileType; the type
                                        of file we are digesting.

    Output Parameters   - TheFile       The file containing subfiles.
                          RETURN        TRUE if file read ok.
                                        FALSE if an error was reported.

*)
PROCEDURE DigestSubfile( VAR TheFile        : File;
                             SubfileNumber,
                             Version        : CARDINAL;
                             Context        : ADDRESS ) : BOOLEAN;
VAR
    FileTypePtr  : POINTER TO AFileType;
    PriorHandle,
    Handle       : AnExtHandle;
    Data         : ASubFileRecordPtr;
    Size,
    Type, Length : CARDINAL;
    Stop,
    FirstTime    : BOOLEAN;




    PROCEDURE CreateHolderRecord(     Handle : AnExtHandle );
    VAR
        HolderRecord    : AHolderRecord;
        s               : ARRAY [0..5]  OF CHAR;
        HoldName        : ARRAY [0..29] OF CHAR;

    BEGIN
        Copy( ForeignName[FileTypePtr^], HoldName );

        CtoS(      SubfileNumber, s );
        ConcatLS(  HoldName, s );

        NEW(HolderRecord);  (* We did a HeapAvailable above, remember? *)

        HolderRecord^.SubfileNumber := SubfileNumber;
        HolderRecord^.Version       := Version;
        HolderRecord^.FirstHandle   := Handle;

        HoldThis( HoldName, HoldClass,
                  AHoldTypeSet{HoldsAddress,AllowDuplicates},
                  HolderRecord, TSIZE(AHolderRecord) );

    END CreateHolderRecord;




    PROCEDURE ReadARecordHeader( VAR ErrorFound : BOOLEAN;
                                 VAR Length     : CARDINAL;
                                 VAR Handle     : AnExtHandle ) : BOOLEAN;
    CONST
        DataOverhead = TSIZE(ASubFileRecord) - MaxReasonableSize;
    BEGIN
        ReadRecordPreface( TheFile, Type, Length );
        ErrorFound := (CheckIO(TheFile) <> done);

        IF (NOT ErrorFound) AND
           (Type <> 0FFH)   THEN
            ErrorFound := (Length > MaxReasonableSize);
            IF (ErrorFound) THEN
                DoError(3);     (* Record too long *)
            ELSE
                ErrorFound := ((GetExtStatus() <> ExtGood) OR
                           (NOT CreateExtObjectWithSize( Handle, ExtSlow,
                                             Length + DataOverhead )));
                IF (ErrorFound) THEN
                    DoError(4);     (* No flex room *)
                END;
            END;
        END;

        RETURN ((NOT ErrorFound) AND (Type <> 0FFH));

    END ReadARecordHeader;

BEGIN
    IF ((NOT HeapAvailable()) OR (GetExtStatus() <> ExtGood)) THEN
        RETURN FALSE;
    END;

    Stop        := FALSE;
    FirstTime   := TRUE;
    FileTypePtr := Context;
    PriorHandle := AnExtHandle(NIL);
    Data        := NIL;

    IF (SubfileNumberIsForeign( SubfileNumber, FileTypePtr^ ) AND
        StartSubfileInput( TheFile, SubfileNumber, Version )) THEN
        WHILE (NOT Stop) AND
              (ReadARecordHeader( Stop, Length, Handle )) DO
            IF (FirstTime) THEN
                CreateHolderRecord( Handle );
                FirstTime := FALSE;
            ELSE
                Data^.NextHandle := Handle; (* Point forward. *)
                ReleaseObject( PriorHandle );
            END;
            PriorHandle      := Handle;
            Size             := LockObject( Handle, Data );
            Data^.RecordType := Type;
            Data^.DataSize   := Length;
            ReadRecordBody( TheFile, Length, ADR(Data^.TheData), Length );
            Stop             := (CheckIO(TheFile) <> done);
        END;
        IF (Data <> NIL) THEN
            Data^.NextHandle := AnExtHandle(NIL);
        END;
        IF (PriorHandle <> AnExtHandle(NIL)) THEN
            ReleaseObject( PriorHandle );
        END;
    END;

    RETURN (NOT Stop);

END DigestSubfile;








PROCEDURE Init();
VAR
    FileType    : AFileType;
BEGIN

    FOR FileType := MIN(AFileType) TO MAX(AFileType) DO
        SetString( ForeignName[FileType], "ALIEN-" );
        CASE FileType OF
            ScheduleFile    :
                ConcatS(ForeignName[FileType],"SCHED-" );
          | ConfigFile      :
                ConcatS(ForeignName[FileType],"CNFG-" );
        ELSE
            FatalError();  (* Somebody added a new type, and forgot about me! *)
        END;
    END;

END Init;






BEGIN

    Init();

END ForeignSubfiles.
