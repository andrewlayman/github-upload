    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

(*  =========================================================================
    Last Edit : February 21, 1991 2:14PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:
    (*****************************************************************)
    (*                                                               *)
    (*    TLDir411.                                                  *)
    (*                                                               *)
    (*    Give directory assistance by putting a menu of project     *)
    (*    names on the screen and allowing the user to select one.   *)
    (*    The project name chosen is returned.                       *)
    (*                                                               *)
    (*****************************************************************)



    MODIFICATION HISTORY:

    12/22/86 LAA    Extensive modifications to permit moving around the
                    directory structure while selecting a file.
    12/29/86 LAA    When loading files of the pick list, only one loop is now
                    used, which picks up subdirectories also.
    12/30/86 LAA    Reorganized this whole bloody thing!
    05/28/87 EGK    Rewrote to use LinkedListObjects instead of Lists.
    04-Jun-87 LAA   Changed parameters for the ForAll method.
    24-Jun-87 RSC   Make this module use NameLists/NameViews object oriented
                    routines, and use the new improved routines from Directory.
    07/24/87 EGK    Rewrote to use TreeObjects instead of LinkedListObjects.
    09/08/87 RSC    Misc. bug fixes and rework forms and editing routines.
                    MADE INTO TLDIR411 OVERLAY.
    10/05/87 RSC    ReValidate directories after being selected, to catch,
                    for example, a missing floppy.
    10/20/87 RSC    Sort on name and extension, not just name.
    11/03/87 RSC    don't assume file ext on input form, allow empty form.
    02-Feb-88 LAA   Removed usage of LowFuel.
    10-Jun-88 RSC   Added new request type "Directories only" and a new
                    requestor PICKDIRS.MOD.  This was done in a klugy manner
                    due to the problem that it must be upwardly compatible
                    with other overlays in the field.  Also fixed bug where
                    the cursor does not show up on directories.
    14-Jun-88 RSC   Bug fixes: 1) If starting directory is no good and we
                                  can't put up the access form, don't loop
                                  forever.  Instead try DK:.\*.* and then
                                  put up an error box.
                               2) Allow directories with extensions, like
                                  \TL3.5
                               3) (2) required cloning and fixing "Directory
                                  is reachable" from Director.Mod due to a
                                  bug in it.  This should be removed when
                                  we can fix the root!!

    30-Sep-88 WKH   Finally fixed Directory is reachable in Director.Mod.
                    So it's gone from here for good!!!

    15-Nov-88 WKH   Changed File Save Form so that we can edit the extension
                    non-schedule files.
    06-Dec-88 EGK   Fixed up VerifyFileClean to check for bad directories, and
                    to use FileLookupStart instead of Lookup, which is flaky
                    on networks.
     2-Jan-89 RSC   Added references to StringsEqual() rather than Compare().
    23-Jan-89 RSC   Changed Storage to Space.
    10-Feb-89 RSC   Changed special default extension to T$0.
    10-Mar-89 RSC   The returned file size in KB and date were not being
                    set, causing occasional crashes in Timeu if range
                    checking was not on.  The size and date are now
                    returned properly.  No caller was using the date and
                    size, but this will support potential future callers.
    18-Apr-89 WKH   Call NameAndLockSchedule in PathCheck if we are indeed
                    dealing with a schedule file.
    14-Jun-89 RSC   1) Resized the message box to be relative to GanttWStart.
                    2) When dir is unreachable, assume current dir rather
                       than putting up a form.  Just like the "Directory
                       Only" lookups did.
    15-Jun-89 RSC   Changed the message box to a progress box.
    25-Jul-89 RSC   When GetOutputFile gets an extension of "M#0", make
                    the extension field protected.  This is for saving
                    MACROS.
    09-Aug-89 KKC   Add copyright message.
    10-Aug-89 WKH   Initial OS/2 edits.
    23-Aug-89 LAA   DoAFileForm was allowing the extension to be edited, but
                    then not returning any changes made to that field.  It
                    now returns the changes.
    30-Aug-89 KKC   If file name starts with a wildcard character, pop up
                    picking list when user pressed F10
     5-Sep-89 RSC   Allow 4 digits for file size.
    21-Sep-89 WKH   Make pick list bigger for compressed video
    29-Sep-89 RSC   As per Larry Keopke's request, change M#0 to M$0.
    10-Nov-89 RSC   Fixed TooLong() error.  Bug # 1732.
     9-Jan-90 MWP   Allow mouse double clicks on a filename to select
                    that file rather than bringing up the file access form.
                    The way that this is implemented is fairly kludgy, so
                    some justification is given here for this. All list
                    processing of mouse events is handled by Listviews.
                    Listviews interprets mouse double clicks by translating
                    them into 'Editkey' values. What we want the to happen
                    on the file form is for a mouse double click to mean
                    'DoIt'. We have to have some way for the Goto check proc
                    here interpret the ley codes in order to know when the
                    the mouse double click happened. As we only have the key code
                    and not the full Event information, we keep track of the
                    last code entered. If we see an 'Editkey' and the LastCode
                    was a mouse double click, we turn the keycode into a
                    'DoIt' code.
                    There - isn't that precious?
    19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                    date structure, ATimeInfo.

    14-Sep-90 RSC   Import the file extension rather than hardcoding it.
    23-Oct-90 RSC   File extension format change.
    21-Feb-91 RSC   Moved the form out to another overlay, TLD411FM.  This
                    makes this overlay not dependant on TLFBase, which is
                    important because TLGETIT, which shares the same reserved
                    overlay layer as TLFBASE, passes us a procedure to call
                    in him.  Also, this makes this overlay smaller, which
                    is nice because this overlay does NOT go into the
                    reserved layer.

     3-Feb-92 LAA   Allow the Enter key (DoItKey) to act like a + key when
                    it's on a directory, and we're looking for a file.  It
                    seems a whole bunch of people continually try to do this
                    anyway, so let's make it do what they expect!
    19-Feb-92 LAA   Oops.  Forgot to get an updated CursorNode.

    Requests come to this module from only two sources:

                DIRECT411.MOD
                PICKDIRS.MOD

   PickDirs.Mod should be a part of Direct411.Mod, but, alas, due to field
   upgrade problems, ended up as a seperate module.

    =========================================================================
*)

(*<DOS*)
MODULE TLDir411;
(*DOS>*)

(*<OS2
IMPLEMENTATION MODULE TLDir411;
OS2>*)


FROM Overlays               IMPORT
        (* PROCS *)             OverlayContext, CallOverlayWithContext;

FROM Dir411                 IMPORT
    (* TYPE *)                  AnOverlayContext,
                                AGiveDirectoryAssistanceProc;

FROM Direct411              IMPORT
        (* TYPES *)             AnAssistanceFunction, ATLDir411Interface,
                                AQualificationProcedure,
        (* PROCS *)             AlwaysApprove;

FROM Boxes                  IMPORT ABoxType, ABoxAttribute;

FROM Codes                  IMPORT ACode;

FROM Dialog                 IMPORT Message, Burp, Error, ProgressBox,
                                   Barf, ContinuationBox, ABoxHandle,
                                   ReleaseBox,
                                   WarningBox, ADialogOption, FatalError;

FROM Directory              IMPORT
        (* CONST *)             MaximumFileNameLength, MaximumExtensionLength,
                                MaximumDeviceNameLength, MaximumPathNameLength,
        (* TYPES *)             AFileNameRecord,
                                ASetOfFileNameParts, AFileNamePart,
                                AFileAttribute, AFileAttributeSet,
        (* PROCS *)             StartFileNodeLookup, ContinueFileNodeLookup,
                                ExtractDeviceName, NumberOfDiskettes,
                                ExtractFileNameParts, DiskFreeSpace,
                                FileLookupStart, ExpandPath,
                                NormalizeFileName,
                                DirectoryIsReachable;

FROM FileAux                IMPORT FileResultMeans, PrepareForIO, CheckIO;

FROM FileSystem             IMPORT File, Close, Lookup, Response;

FROM Kbio                   IMPORT ascreeny, GetAnyCode,
                                   maxcol, maxrow, ascreenx, PutString,
                                   avidmode, EraseLn;

FROM Keys                   IMPORT EditKey, DoIt, AnteKey, CancelKey,
                                   ExitKey, OpenKey, CloseKey, MouseDouble;

FROM Layout                 IMPORT GanttWStart, GanttWEnd;

FROM TreeObjects      IMPORT
    (* TYPE *)                  ATree, ATreeOrder, ATreeNode,
    (* PROC *)                  ValidateTreeNode, CreateTree,
                                CreateTreeNode;

FROM LStrings               IMPORT SetString, ConcatS, ConcatLS, SubStr,
                                   StringsEqual, CtoS, Fill, Insert, TrimRear,
                                   TrimFront, Procustes, Remove, Search,
                                   LengthOf, SetLengthOf, Upshift, Copy,
                                   Compare, RJust, LStringToTString;

FROM MsgFile                IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM Space                  IMPORT SetHeapLevels, HeapAvailable,
                                   ALLOCATE, DEALLOCATE;

FROM GoTo                   IMPORT
    (* TYPES *)                 AGoToCheckProc,
    (* PROCS *)                 DoGoTo;

FROM OutlineViews           IMPORT
    (* TYPE *)                  AnOutlineView;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  GetNextEvent;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADR, ADDRESS;

FROM BigTimeU               IMPORT
    (* TYPE *)                  ABigTime,
    (* PROCS *)                 BigTimeToTime, TimeToBigTime;

FROM TimeFormat             IMPORT
    (* VARS *)                  DefaultDateAndTimeFormat,
    (* PROCS *)                 TimeToString;

FROM Timei                  IMPORT
    (* TYPE *)                  ATimeInfo;

FROM Schedule               IMPORT
    (* VARS *)                  ProjectName, ProjectMedia,
                                CurrentFileExtension;

FROM VersionConflict        IMPORT
    (* PROC *)                  ConflictProc;  (* 29-Nov-89 WKH *)





CONST
    ModuleNumber            = 14500;    (* For GetMessage *)

    Dot                     = ".";

    FirstCol                = 12;
    LastCol                 = maxcol - FirstCol + 1;

    DriveOrDir              = AFileAttributeSet{SubdirectoryAttribute,DiskDriveAttribute};
    DriveAttr               = AFileAttributeSet{DiskDriveAttribute};
    DirAttr                 = AFileAttributeSet{SubdirectoryAttribute};
    EmptyAttr               = AFileAttributeSet{};
    IncludingDirectories    = AFileAttributeSet{SubdirectoryAttribute,
                                                ReadOnlyAttribute};

TYPE AContext = RECORD

            KidNames,
            Names                : ATree;
            CursorNode           : ATreeNode;
            QualificationProc    : AQualificationProcedure;
            ContextFileName      : AFileNameRecord;
            MoreNames            : BOOLEAN;
            AllowPathForm        : BOOLEAN;
            DirectorySelectionOK : BOOLEAN;
            DirectoryOnly        : BOOLEAN;
            CursorName           : ARRAY [0..MaximumFileNameLength
                                           + 2
                                           + MaximumExtensionLength] OF CHAR;
    END;

    ATLDir411InterfaceP = POINTER TO ATLDir411Interface;

    ANameViewDisplayRecord = POINTER TO
        RECORD
            UseThisMuchPath : CARDINAL;
            FileSize        : CARDINAL;
            TimeStamp       : ABigTime;
            Attributes      : AFileAttributeSet;
            SortName        : ARRAY [0..MaximumFileNameLength
                                      + 2
                                      + MaximumExtensionLength] OF CHAR;
            DisplayString   : ARRAY [0..41]                     OF CHAR;
        END;
VAR
     GoToContext          : POINTER TO AContext;
     OriginalExtension    : ARRAY [0..MaximumExtensionLength] OF CHAR;
     OriginalFileName     : ARRAY [0..MaximumFileNameLength]  OF CHAR;

     LastCode             : ACode;                                (* 9-Jan-90 MWP *)




    (* DefaultLS - Set an LString to a default LString if it is empty. *)

PROCEDURE DefaultLS( VAR s,s1 : ARRAY OF CHAR );
BEGIN
    TrimRear(s);
    IF (LengthOf(s) = 0) THEN
       Copy(s1,s);
    END;
END DefaultLS;





    (* StoFileRecord - convert a filename to a FileNameRecord.  *)

PROCEDURE StoFileRecord( VAR s              : ARRAY OF CHAR;
                         VAR FileNameRecord : AFileNameRecord );
VAR
    i             : CARDINAL;
    DeviceAndPath : ARRAY [0..99] OF CHAR;
    s1            : ARRAY [0..1]  OF CHAR;
BEGIN
    NormalizeFileName( s, ASetOfFileNameParts{DevicePart..ExtensionPart} );
    WITH FileNameRecord DO
        ExtractFileNameParts( s, Device, Path, FileName, Extension);
        DefaultLS(FileName,OriginalFileName);
        DefaultLS(Extension,OriginalExtension);
        Size            := 1;
        Attributes      := AFileAttributeSet{};
        TimeStamp.High  := 0;
        TimeStamp.Low   := 0;
        SetLengthOf(s1,0);
        Copy( Device, DeviceAndPath );
        ConcatLS(     DeviceAndPath, Path );
        ExpandPath( DeviceAndPath, s1, DeviceAndPath );
        ExtractDeviceName( DeviceAndPath, Device, i );
        SubStr( DeviceAndPath, Path, i, ORD(DeviceAndPath[0]) - i + 1 );
    END;
END StoFileRecord;





PROCEDURE NormalizeFileRecord( VAR FileNameRecord : AFileNameRecord );
VAR
    i : CARDINAL;
    s : ARRAY [0..99] OF CHAR;
BEGIN
    WITH FileNameRecord DO
        IF (DiskDriveAttribute IN Attributes) THEN
            Copy(Device,FileName);
            SetString(Path,"\");
            SetLengthOf(Extension,0);
        END;
    END;
END NormalizeFileRecord;




   (* FileRecordToS - Convert a file record into a full file name string. *)

PROCEDURE FileRecordToS( VAR FileNameRecord : AFileNameRecord;
                         VAR s              : ARRAY OF CHAR   );
BEGIN
    WITH FileNameRecord DO
        Copy(Device,s);
        ConcatLS(s,Path);
        IF (DiskDriveAttribute IN Attributes) THEN
            ConcatLS(s,OriginalFileName);
            ConcatS (s,Dot);
            ConcatLS(s,OriginalExtension);
        ELSE
            ConcatLS(s,FileName);
            ConcatS (s,Dot);
            ConcatLS(s,Extension);
        END;
    END;
END FileRecordToS;






  (* Display the trailer - Display the "And More" message, or blanks where
                           "And More" would have been.
  *)

PROCEDURE DisplayTrailer( MoreNames            : BOOLEAN;
                      VAR FileName             : ARRAY OF CHAR;
                          ActualFileNamesFound : CARDINAL );
VAR
    s    : ARRAY [0..255] OF CHAR;
BEGIN
    CtoS(ActualFileNamesFound,s);
    ConcatMessage(s,ModuleNumber+13); (* " files selected." *)
    ConcatLS( s, FileName );
    IF (MoreNames) THEN
        ConcatMessage(s,ModuleNumber+4);   (*  "  (Plus others)"  *)
    END;
    Message(s);
END DisplayTrailer;






    (* Try to match the cursor to the passed-in name.  If not found, place
       at the top of the list.  NameToMatch is a SORT NAME, not just the name.
    *)

PROCEDURE SetCursorName(     Names        : ATree;
                         VAR CursorNode   : ATreeNode;
                         VAR NameToMatch  : ARRAY OF CHAR );
VAR NameNode     : ATreeNode;
    FirstNode    : ATreeNode;
    NamePtr      : ANameViewDisplayRecord;
    s, s1        : ARRAY [0..19] OF CHAR;
BEGIN
    SubStr( NameToMatch, s1, 2, 8 ); (* Drop lead byte and ext *)
    TrimRear( s1 );
    FirstNode := Names^.Methods^.GetFirst( Names );
    NameNode  := FirstNode;
    WHILE (NameNode <> NIL) DO
        NamePtr := NameNode^.Methods^.GetDataObject( NameNode );
        SubStr( NamePtr^.SortName, s, 2, 8 ); (* Drop lead byte and ext *)
        TrimRear( s );
        IF (StringsEqual(s, s1)) THEN   (* RSC 1/2/88 *)
            CursorNode := NameNode;
            RETURN;
        END;
        NameNode := NameNode^.Methods^.NextForDisplay( NameNode );
    END;
    CursorNode := FirstNode;
END SetCursorName;




PROCEDURE GoToCheckProc(    Outline     : AnOutlineView;
                            Tree        : ATree;
                        VAR Code        : ACode         );
VAR
    FirstNode       : ATreeNode;
    FileName        : AFileNameRecord;
    LoadNamesNeeded : BOOLEAN;
    NewCursorName   : ARRAY [0..19] OF CHAR;

  PROCEDURE CheckDir( VAR FileName : AFileNameRecord ) : BOOLEAN;
  VAR
      s : ARRAY [0..255] OF CHAR;   (* 10-Nov-89 RSC was 99. *)
  BEGIN
      Copy( FileName.Device, s );
      ConcatLS( s, FileName.Path );
      IF (NOT DirectoryIsReachable( s )) THEN
          GetMessage( ModuleNumber+11, s );  (* "Directory not found" *)
          Error(s);
          RETURN FALSE;
      END;
      RETURN TRUE;
  END CheckDir;

    PROCEDURE ProcessExitKey();

    BEGIN                   (* ProcessExitKey *)

         (* Only pay attention to the select key if this is not a drive or
            directory, or if selecting directories is ok.
         *)
        WITH GoToContext^ DO
            CursorNode := Outline^.Methods^.GetCursorNode( Outline );
            FileName   := ContextFileName;
            ResolveCursorNode( FileName, CursorNode, TRUE, NewCursorName );
            IF ((DriveOrDir * FileName.Attributes) <> EmptyAttr) AND
               ( NOT DirectorySelectionOK )                      THEN
                    Burp();
                    Code := 0; (* this key not allowed here *)
            END;
        END;

    END ProcessExitKey;

    PROCEDURE ProcessOpenCloseKeys(     Open: BOOLEAN );

    BEGIN                   (* ProcessOpenCloseKey *)

         (* Only pay attention to the key if this is a drive or
            directory, otherwise we end here.
         *)
        WITH GoToContext^ DO
            CursorNode := Outline^.Methods^.GetCursorNode( Outline );
            FileName   := ContextFileName;
            ResolveCursorNode( FileName, CursorNode, Open, NewCursorName );
            IF ((DriveOrDir * FileName.Attributes) <> EmptyAttr)  AND
                (CheckDir( FileName ))                            THEN
                LoadNamesNeeded := TRUE;
                ContextFileName := FileName;
                Copy( NewCursorName, CursorName );
            END;
        END;

    END ProcessOpenCloseKeys;


    PROCEDURE IsDriveOrDirectory(     Node         : ATreeNode ) : BOOLEAN;

    VAR
        NamePtr             : ANameViewDisplayRecord;

    BEGIN                   (* IsDirectory *)

        NamePtr := Node^.Methods^.GetDataObject( Node );
        RETURN ((DriveOrDir * NamePtr^.Attributes) <> EmptyAttr);

    END IsDriveOrDirectory;


BEGIN
    LoadNamesNeeded := FALSE;

    IF ( Code = EditKey ) AND                                     (* 9-Jan-90 MWP *)
       ( LastCode = MouseDouble ) THEN
       Code := DoIt;
       LastCode := 0;
    ELSE
       LastCode := Code;
    END;

    WITH GoToContext^ DO
        IF ((Code = AnteKey)  OR
            (Code = EditKey)) AND
            (AllowPathForm)   THEN

             Copy( OriginalFileName,  ContextFileName.FileName  );
             Copy( OriginalExtension, ContextFileName.Extension );
             IF (DoPathForm(ContextFileName,TRUE,FALSE) <> CancelKey) THEN
                 WITH ContextFileName DO
                     TrimRear(FileName);
                     TrimRear(Extension);
                     IF (LengthOf(FileName)=0) THEN
                         SetString(FileName,"*");
                         IF (LengthOf(Extension)=0) THEN
                             SetString(Extension,"*");
                         END;
                     END;
                     Copy(FileName,  OriginalFileName );
                     Copy(Extension, OriginalExtension);
                 END;
                 LoadNamesNeeded := TRUE;
             END;

             Code := 0;

        ELSIF (Code = ExitKey) THEN

            ProcessExitKey();

        ELSIF (Code = OpenKey)   OR
              (Code = CloseKey)  THEN

            ProcessOpenCloseKeys( Code = OpenKey );

            Code := 0;

        ELSIF (Code = DoIt) THEN

            CursorNode := Outline^.Methods^.GetCursorNode( Outline );
            IF ((NOT IsDriveOrDirectory( CursorNode )) 
               OR DirectorySelectionOK) THEN
                ProcessExitKey();
            ELSE
                ProcessOpenCloseKeys( TRUE );
                Code := 0;
            END;
        END;

  (* Do we need to reload the names? *)

        IF (LoadNamesNeeded)       AND
           (LoadNames( GoToContext^ ))  THEN
            Outline^.Methods^.SetObject (Outline, Names);
            Outline^.Methods^.SetCursor (Outline, TRUE);
            FirstNode := Tree^.Methods^.GetFirstVisible (Tree);
            Outline^.Methods^.SetFirst (Outline, FirstNode);
            SetCursorName( Names, CursorNode, CursorName );
            Outline^.Methods^.SetCursorNode( Outline, CursorNode );
            Code := 511; (* RESYNCH ME, PLEASE, Mr. GoTo! *)
        END;
    END;

END GoToCheckProc;






  (* Rebuild a ContextFileName from the cursor node. *)

PROCEDURE ResolveCursorNode( VAR ContextFileName : AFileNameRecord;
                             VAR CursorNode      : ATreeNode;
                                 PlusKeyOrEnter  : BOOLEAN;
                             VAR NewCursorName   : ARRAY OF CHAR );
VAR
    i               : CARDINAL;
    NamePtr         : ANameViewDisplayRecord;
    s, s1           : ARRAY [0..9] OF CHAR;
BEGIN
    NamePtr := CursorNode^.Methods^.GetDataObject( CursorNode );
    SetLengthOf(s1,0);
    WITH NamePtr^ DO
        ContextFileName.Attributes := Attributes;
        ContextFileName.Size       := FileSize;
        ContextFileName.TimeStamp  := TimeStamp;
        IF (DiskDriveAttribute    IN Attributes)  THEN
            WITH ContextFileName DO
                ExtractDeviceName( DisplayString, Device, i );
                MakeSortName( Device, s1, NewCursorName, DriveAttr );
                SetLengthOf(Path     ,0);
                IF (PlusKeyOrEnter) THEN
                    SetString(Path,"\");
                END;
                Copy( OriginalFileName,  FileName  );
                Copy( OriginalExtension, Extension );
            END;
        ELSIF (SubdirectoryAttribute IN Attributes)  THEN
            WITH ContextFileName DO
                (* LEAVE DRIVE AS IT WAS *)
                Procustes( Path, UseThisMuchPath );
                SubStr( DisplayString, s, 1, 8 ); (* Extract name *)
                TrimRear(s);
                SubStr( DisplayString, s1, 10, 3 ); (* Extract extension *)
                TrimRear(s1);
                IF (PlusKeyOrEnter) THEN
                    ConcatLS(Path, s);
                    IF (s1[0] <> 0C) THEN
                        ConcatS( Path, Dot );
                        ConcatLS(Path, s1);
                    END;
                END;
                IF (Path[ LengthOf(Path) ] <> "\") THEN
                    ConcatS( Path, "\" );
                END;
                MakeSortName( s, s1, NewCursorName, DirAttr );
                Copy( OriginalFileName,  FileName  );
                Copy( OriginalExtension, Extension );
            END;
        ELSE
             (* LEAVE DRIVE AND PATH AS THEY WERE *)
            SubStr( DisplayString, s, 1, 8 ); (* Extract name *)
            TrimRear(s);
            MakeSortName( s, s1, NewCursorName, EmptyAttr );
            Copy(s,ContextFileName.FileName);
            SubStr( DisplayString, ContextFileName.Extension, 10, 3 ); (* Extract ext *)
        END;
    END;
END ResolveCursorNode;






  (* ProcessFileSelection - process the visible list of file names.

        1- Create a NameView to manage the screen for us.
        2- Get current directory.
        3- get a user selection.
        4- If they want a subdirectory or a root, go back to 2.
        5- return the desired file node.
  *)

PROCEDURE ProcessFileSelection( VAR Context    : AContext;
                                    FirstRow,
                                    LastRow    : CARDINAL;
                                VAR Title      : ARRAY OF CHAR
                              ) : BOOLEAN;
VAR
   ok              : BOOLEAN;
BEGIN
    GoToContext := ADR( Context );  (* GoTo does not support contexts. *)

    WITH Context DO
        ok := FALSE;

    (* Load the first set of names. *)

        IF (LoadNames( Context ))  THEN

    (* Setup the cursor file name. *)

            SetCursorName( Names, CursorNode, CursorName );

    (* Do the GoTo box.  The check proc does further directory lookups. *)

            IF (DoGoTo( Names,
                        FirstCol, FirstRow, LastCol, LastRow,
                        Title,
                        FALSE,
                        GoToCheckProc,
                        GetFileName,
                        CursorNode )) THEN
                ResolveCursorNode( ContextFileName, CursorNode, TRUE, Title );
                ok := TRUE;
            END;
        END;

    (* Dispose of the Names tree. *)

        IF (Names <> NIL) THEN
            Names^.Methods^.TraverseTree(Names,
                                         ParentAfterChild,
                                         65535,
                                         DisposeName, NIL );
            Names^.Methods^.Discard(Names);
        END;
    END;

    RETURN ok;

END ProcessFileSelection;



  (* SetupContext - Setup the context passed around.  Specificly this means
                    setting up the file template in a resonable way.
  *)
PROCEDURE SetupContext( VAR Context    : AContext;
                        VAR CursorName : ARRAY OF CHAR ) : BOOLEAN;
VAR
    i              : CARDINAL;
    s              : ARRAY [0..80]  OF CHAR;
    s1             : ARRAY [0..150] OF CHAR;
    FirstTime,
    Done           : BOOLEAN;
BEGIN
    FirstTime     := TRUE;
    Done          := FALSE;
    Context.Names := NIL;
    SetLengthOf(s,0);
    MakeSortName( CursorName, s, Context.CursorName, EmptyAttr );

    REPEAT
        WITH Context DO
            Copy(ContextFileName.FileName,  OriginalFileName );
            Copy(ContextFileName.Extension, OriginalExtension);

                (* Now see if the directory is even reachable.
                   if it is not, then try the default.
                *)

            FileRecordToS( ContextFileName, s );
            IF (DirectoryIsReachable( s )) THEN
                Done := TRUE;

            (* RSC 14-Jun-89  Reworked this a little:  *)

            ELSIF (FirstTime) THEN  (* Try again. *)
                FirstTime := FALSE;
                SetString(s,"DK:.\*.");
                ConcatLS( s, OriginalExtension );
                StoFileRecord( s, ContextFileName );
            ELSE
                GetMessage(ModuleNumber+1,s1); (* "Can't find dir:" *)
                ConcatLS(s1,s);
                Error(s1);
                RETURN FALSE;
            END;
        END;
    UNTIL (Done);
    RETURN TRUE;
END SetupContext;



PROCEDURE GetFileName   (       Node       : ATreeNode;
                            VAR s          : ARRAY OF CHAR );
VAR
    DisplayRecord : ANameViewDisplayRecord;

BEGIN               (* FileViewGetTitle *)

    DisplayRecord := Node^.Methods^.GetDataObject( Node );
    Copy( DisplayRecord^.DisplayString, s );

END GetFileName;




    (* Give Directory Assistance - Get a file name from the customer.

        Input: FirstRow, LastRow : Rows to use for display.
               Title             : Caption for box, and for Help.
               Template          : Device:\Directory\filename.ext mask.
               FileName          : Name to highlight if on list.
               Qualifies         : Check for approved files.
               AllowForm         : Allow the path form?

        Output:Template          : The actual file name and extension,
                                   preceded by the device and directory.
               FileName          : The time of last update to the file.
                                   DD-MMM-YY HH:MMam

         Returns TRUE iff a file name was chosen.

        CAUTION:  Both Template and FileName are both input and output!

    *)

PROCEDURE GiveDirectoryAssistance(    FirstRow,
                                      LastRow     : ascreeny;
                                  VAR Title       : ARRAY OF CHAR;
                                  VAR Template    : AFileNameRecord;
                                  VAR Filename    : ARRAY OF CHAR;
                                      Qualifies   : AQualificationProcedure;
                                      OnlyDirectories,
                                      AllowForm   : BOOLEAN )
                                                                    :BOOLEAN;
VAR  Context      : AContext;
     i            : CARDINAL;
     Ok           : BOOLEAN;
BEGIN
    WITH Context DO
        QualificationProc    := Qualifies;  (* Save qualification proc. *)
        ContextFileName      := Template;   (* and searched-for file name. *)
        AllowPathForm        := AllowForm;  (* and if we can put up a form.*)
        DirectorySelectionOK := NOT AllowForm; (* must select file if entered via FILE RETRIEVE *)
        DirectoryOnly        := OnlyDirectories;

        Ok := SetupContext( Context, Filename );

        Ok := (Ok AND ProcessFileSelection( Context, FirstRow, LastRow, Title ));
        IF (Ok) THEN
            Template := ContextFileName;
        END;
    END;

    RETURN Ok;

END GiveDirectoryAssistance;










PROCEDURE DOSMatch(    Pattern              : ARRAY OF CHAR;
                       Name                 : ARRAY OF CHAR)
                                                            : BOOLEAN;

VAR
    i                   : CARDINAL;

BEGIN                   (* DOSMatch *)

    TrimRear(Pattern);

    IF (LengthOf(Pattern) = 0) THEN
        RETURN FALSE;
    END;

    TrimRear(Name);
    WHILE (LengthOf(Name) < LengthOf(Pattern)) DO
        ConcatS( Name, "?" );
    END;

    i := 1;
    WHILE (i <= LengthOf(Pattern)) DO (* two strings are at least this long. *)
        IF Pattern[i] = "?" THEN
            Name[i] := "?";
        ELSIF Pattern[i] = "*" THEN
            Name[i] := "*";
            Procustes(Name, i);
            Procustes(Pattern, i);
        END;
        INC(i);
    END;

    RETURN (StringsEqual(Name, Pattern));

END DOSMatch;












PROCEDURE DoTheForm( VAR FileNameRecord : AFileNameRecord;
                         AllowWildcards,
                         GiveAssistance,
                         PathForm       : BOOLEAN ) : ACode;
VAR
    Context     : AnOverlayContext;
    Name        : ARRAY [0..79] OF CHAR;
    ok          : BOOLEAN;

BEGIN

    WITH FileNameRecord DO
        TrimRear(FileName);
        Copy( FileName,  OriginalFileName  );
        Copy( Extension, OriginalExtension );
    END;

    WITH Context DO
        TheFileNameRecordPtr    := ADR(FileNameRecord);
        DirectoryAssistanceProc := GiveDirectoryAssistance;
        DoWeAllowWildcards      := AllowWildcards;
        DoWeGiveAssistance      := GiveAssistance;
        DoPathForm              := PathForm;
        ReturnValue             := CancelKey;
    END;

    SetString(Name, "TLFBASE(TLD411FM)" );
    ok := CallOverlayWithContext( Name, ADR(Context) );

    RETURN Context.ReturnValue;

END DoTheForm;



PROCEDURE DoPathForm( VAR FileNameRecord : AFileNameRecord;
                          AllowWildcards,
                          GiveAssistance : BOOLEAN   ): ACode;

BEGIN    (* DoPathForm *)

    RETURN DoTheForm( FileNameRecord, AllowWildcards, GiveAssistance, TRUE );

END DoPathForm;








PROCEDURE DoExportForm( VAR FileNameRecord : AFileNameRecord;
                            AllowWildcards,
                            GiveAssistance : BOOLEAN   ): ACode;

BEGIN    (* DoExportForm *)

    RETURN DoTheForm( FileNameRecord, AllowWildcards, GiveAssistance, FALSE );

END DoExportForm;










PROCEDURE DisposeName (VAR Node     : ATreeNode;
                           Context  : ADDRESS        );
VAR
    NamePtr   : ANameViewDisplayRecord;

BEGIN                   (* DisposeList *)

    NamePtr := Node^.Methods^.GetDataObject (Node);
    DISPOSE (NamePtr);
    Node^.Methods^.Discard (Node);

END DisposeName;




PROCEDURE LoadNames( VAR Context : AContext ): BOOLEAN;

VAR
    ActualFileNamesFound,
    i              : CARDINAL;
(*<OS2
    Dummy	   : LONGINT;
OS2>*)
    Node           : ATreeNode;
    FileNameRecord : AFileNameRecord;
    BoxHandle      : ABoxHandle;
    ok             : BOOLEAN;
    s              : ARRAY [0..80] OF CHAR;

    PROCEDURE InsertIt() : BOOLEAN;
    BEGIN
        Message(s);
        InsertNameIntoList(Context,FileNameRecord);
        RETURN (NOT Context.MoreNames);
    END InsertIt;

    PROCEDURE InsertDrive() : BOOLEAN;
    BEGIN
        FileNameRecord.Attributes := AFileAttributeSet{DiskDriveAttribute};
        NormalizeFileRecord(FileNameRecord);
        FileRecordToS(FileNameRecord,s);
        RETURN (InsertIt());
    END InsertDrive;

    PROCEDURE InsertDirectory() : BOOLEAN;
    BEGIN
        FileNameRecord.Attributes := AFileAttributeSet{SubdirectoryAttribute};
        NormalizeFileRecord(FileNameRecord);
        FileRecordToS(FileNameRecord,s);
        RETURN (InsertIt());
    END InsertDirectory;


    (* Create a tree node, copy 's' into the display string.  If we can't,
       abort, as we already checked HeapAvailable(), and we are only
       adding a few of these records.
     *)

    PROCEDURE CreateANode( VAR Node : ATreeNode;
                               Path : CARDINAL;
                               Attr : AFileAttributeSet;
                               Size : CARDINAL;
                               When : ABigTime;
                           VAR s    : ARRAY OF CHAR );
    VAR
        NamePtr   : ANameViewDisplayRecord;
        s1        : ARRAY [0..3] OF CHAR;
    BEGIN
        IF (CreateTreeNode( Node )) THEN
            NEW( NamePtr );
            WITH NamePtr^ DO
                Copy( s, DisplayString );
                Attributes      := Attr;
                FileSize        := Size;
                TimeStamp       := When;
                UseThisMuchPath := Path;
                TrimRear(s);
                SetLengthOf(s1, 0);
                MakeSortName( s, s1, SortName, Attr );
            END;
            Node^.Methods^.SetDataObject( Node,  NamePtr );
        ELSE
            FatalError();
        END;
    END CreateANode;



    (* Given a squished file name that may contain a period, expand it to
       "Name    .Ext"
    *)
    PROCEDURE AjustName( VAR FileName : ARRAY OF CHAR );
    VAR
        i : CARDINAL;
        s : ARRAY [0..15] OF CHAR;
    BEGIN
        SetString(s, Dot);
        i := Search(FileName,s,1);
        IF (i > 0) THEN
            SubStr( FileName, s, i+1, HIGH(FileName));
            Procustes( FileName, i-1 );
            Procustes( FileName, 8   );
            ConcatS(   FileName, Dot );
            ConcatLS(  FileName, s   );
        END;
    END AjustName;



    (* To make the display look nice, we add each section of the path
       as a tree node whose (visible) kids follow.  This way you get a
       box like:
            F:
              USERS
                RCOLLINS
                  TLDATA
                    Filename.EXT  12-Aug-87 14:32  12K RO
    *)
    PROCEDURE StartTreeWithPath( VAR FileNameRecord : AFileNameRecord );
    VAR
        MomNode,
        Node       : ATreeNode;
        PathStart,
        PathEnd,
        PathLength : CARDINAL;
        TimeStamp  : ABigTime;
        s          : ARRAY [0..19] OF CHAR;
    BEGIN
        WITH FileNameRecord DO

            (* As Drives don't have timestamps and as we don't know the
               time of dir creation (because we don't look each one up
               individually), create a date out of thin air.  This is
               my Niece's birthdate.  (Deanna Green).  RSC  10-Mar-89
            *)
            TimeToBigTime( 1984, 8, 15, 4, 30, 0, TimeStamp );

        (* First create the root node with the drive name. *)

            CreateANode( MomNode, 0, DriveAttr, 4, TimeStamp, Device );
            Context.Names^.Methods^.AddFirst( Context.Names, MomNode );

        (* Now parse the path into pieces,  adding each piece. *)

            PathLength := LengthOf( Path );
            PathStart  := 1;
            IF (Path[ PathStart ] = "\") THEN
                INC(PathStart);
            END;
            PathEnd := PathStart;

            WHILE (PathEnd <= PathLength) DO
                WHILE  (PathEnd <= PathLength)  AND
                       (Path[ PathEnd ] <> "\")  DO
                    INC(PathEnd);
                END;
                IF (PathStart <> PathEnd) THEN
                    SubStr(Path,s, PathStart, (PathEnd - PathStart) );
                    AjustName( s );

            (* The name of the piece is in 's'.  The piece starts at
               'PathStart', so 'UseThisMuchPath' should be one before
               'PathStart'.  Create a node and add it as the child of the
               last node.  Make it visible and remember that this is the
               parent of the next child node.
            *)
                    CreateANode( Node, (PathStart - 1), DirAttr, 4, TimeStamp, s );
                    MomNode^.Methods^.AddAsFirstChild(    MomNode, Node );
                    MomNode^.Methods^.SetChildrenVisible( MomNode, TRUE );
                    MomNode   := Node;
                    PathStart := PathEnd + 1;
                    PathEnd   := PathStart;
                END;
            END;
        END;

      (* Finally, set up a subtree to our last tree created here and set
         it up as 'KidNames' so that all subsequent name additions will
         go in to the lowest level tree.
      *)
         IF (NOT CreateTree (Context.KidNames)) THEN
             FatalError();  (* Vicious brute! *)
         END;
         MomNode^.Methods^.SetSubtree( MomNode, Context.KidNames );

    END StartTreeWithPath;




    (* Look for some files.  Any files.  Or only directories if
       "DirectoryOnly" is set.
    *)
    PROCEDURE LookupSomeFiles( VAR FileNameRecord : AFileNameRecord );
    VAR
        CurrentPath    : ARRAY [0..80] OF CHAR;
        OneDot, DotDot : ARRAY [0..2] OF CHAR;
    BEGIN
        SetString(OneDot,Dot);
        SetString(DotDot,"..");
        WITH FileNameRecord DO
            SetString(FileName, "*");
            SetString(Extension,"*");
            Attributes := IncludingDirectories;
            FileRecordToS( FileNameRecord, CurrentPath );
            ok := StartFileNodeLookup(CurrentPath, FileNameRecord);
            LOOP
                IF (NOT ok) THEN
                    EXIT;
                END;

                IF (SubdirectoryAttribute IN Attributes) THEN
                    TrimRear(FileName);
                    IF (NOT StringsEqual(FileName, OneDot))  AND
                       (NOT StringsEqual(FileName, DotDot))  THEN
                        ok          := InsertDirectory();
                    END;
                ELSIF ((NOT Context.DirectoryOnly)            AND
                       DOSMatch(OriginalExtension, Extension) AND
                       DOSMatch(OriginalFileName,  FileName)  AND
                       Context.QualificationProc(FileNameRecord)) THEN

                    FileRecordToS(FileNameRecord,s);
                    ok := InsertIt();
                    INC(ActualFileNamesFound);
                END;

                Attributes := IncludingDirectories;
                ok := (ok AND ContinueFileNodeLookup(FileNameRecord));
            END;
        END;
    END LookupSomeFiles;


    (* In desperation, or by request, look for disc drives. *)

    PROCEDURE LookupDiskDrives(VAR FileNameRecord : AFileNameRecord);
    VAR
        DefaultDrive : CHAR;
    BEGIN
        WITH FileNameRecord DO
            SetString(Device, "@:"); (* Will become "A:" *)
            ok := TRUE;
            FOR i := 1 TO 2 DO
                INC(Device[1]);
                IF ((ORD(Device[1]) - 64) <= NumberOfDiskettes()) THEN
                    ok := (ok AND InsertDrive());
                END;
            END;

            WHILE (Device[1] < "Z") DO
                INC(Device[1]);
(*<OS2
		        DiskFreeSpace(Device, Dummy, Dummy, Dummy, i, ok);
OS2>*)
(*<DOS*)
                DiskFreeSpace(Device, i, i, i, i, ok);
(*DOS>*)
                ok := (ok AND InsertDrive());
            END;
        END;
    END LookupDiskDrives;

BEGIN
    WITH Context DO
        MoreNames := FALSE;

     (* Put up the "One moment please ..." box *)

        SetLengthOf(s,0);
        Message(s);
        GetMessage(ModuleNumber+10, s);     (* "One Moment Please ..." *)

        BoxHandle := ProgressBox( s );

     (* Dispose any old names *)

        IF (Names <> NIL) THEN
            Names^.Methods^.TraverseTree(Names,
                                         ParentAfterChild,
                                         65535,
                                         DisposeName, NIL );

     (* Create the name tree.  If trouble, put the rug back and exit. *)

        ELSIF (NOT HeapAvailable())    OR                         (* 02-Feb-88 LAA *)
              (NOT CreateTree (Names)) THEN
            ReleaseBox( BoxHandle );
            RETURN FALSE;
        END;
        KidNames := Names;  (* For now, kids are at the top level. *)

     (* Search for filenames.  If we are searching for disc drives, do that.
        otherwise search for actual files and/or directories.
     *)
        ActualFileNamesFound := 0;

        TrimRear( ContextFileName.Path );
        FileNameRecord := ContextFileName;

        IF (LengthOf(FileNameRecord.Path) = 0) THEN
            LookupDiskDrives( FileNameRecord );
        ELSE
            StartTreeWithPath(FileNameRecord );  (* Tree tops *)
            LookupSomeFiles(  FileNameRecord );
        END;

        FileRecordToS(  ContextFileName, s );
        DisplayTrailer( MoreNames, s, ActualFileNamesFound );
    END;

  (* Put the message rug back and exit. *)

    ReleaseBox( BoxHandle );

    RETURN TRUE;

END LoadNames;




    (* To sort things properly, we put an indicator of directory or name
       at the front of the sort name, followed by the file name.  This
       lets file names percolate to the top.
    *)

PROCEDURE MakeSortName( VAR FileName,
                            Extension,
                            SortName    : ARRAY OF CHAR;
                            Attributes  : AFileAttributeSet );
BEGIN
    IF (SubdirectoryAttribute IN Attributes) THEN
        SetString(SortName, "B");
    ELSE
        SetString(SortName, "A");
    END;
    ConcatLS(  SortName, FileName );
    Procustes( SortName, MaximumFileNameLength + 1 );
    ConcatS(   SortName, Dot );
    ConcatLS(  SortName, Extension );
    TrimRear(  SortName );
END MakeSortName;






  (* Format up the file name into the name view display record.

      Preconditions  - FileNameRecord has valid data in it
                       NamePtr        has been NEW()d.

      Postconditions - NamePtr        has displayable data in it.

   Note: the GoTo box may be forced to truncate the last few bytes, so
         organize the data so that the least important stuff is at the end.
  *)
PROCEDURE FormatName( VAR FileNameRecord : AFileNameRecord;
                      VAR NamePtr        : ANameViewDisplayRecord );
VAR
    TimeInfo     : ATimeInfo;
    s1           : ARRAY [0..29] OF CHAR;
    s            : ARRAY [0..99] OF CHAR;
BEGIN
    WITH FileNameRecord DO
        NamePtr^.UseThisMuchPath  := LengthOf( Path );
        NamePtr^.Attributes       := Attributes;
        NamePtr^.FileSize         := Size;
        NamePtr^.TimeStamp        := TimeStamp;

        MakeSortName( FileName, Extension, NamePtr^.SortName, Attributes );

        (* FORMAT:
                         8 FILE NAME  (thats all if drive or directory)
                         1 DOT
                         3 EXTENSION
                         1 SPACE
                         4 "nnnK"
                         1 SPACE
                         ? Date and Time  (US standard = 17 bytes)
                         3 " RO"      (optional - if DOS Read-Only)
                         ------
                         21 + <Date size>, or about 38 bytes US.
        *)
        Copy( FileName, s );
        Procustes( s, 8 );
        Copy( Extension, s1 );
        TrimRear( s1 );
        IF (s1[0] <> 0C) THEN
            ConcatS(  s, Dot );
            ConcatLS( s, s1  );
        END;
        IF ((DriveOrDir * Attributes) <> EmptyAttr) THEN
            Copy( s, NamePtr^.DisplayString );
            RETURN;
        END;
        Procustes( s, 13 );
        CtoS(Size,s1);
        Procustes(s1,4); (* Allow 9999K *)
        RJust(s1);
        ConcatLS(s,s1);
        ConcatS(s, "K ");
        BigTimeToTime
        (
            TimeStamp,
            TimeInfo.tiYear,
            TimeInfo.tiMonth,
            TimeInfo.tiDay,
            TimeInfo.tiHour,
            TimeInfo.tiMinute,
            TimeInfo.tiSecond
        );
        TimeToString(  TimeInfo, DefaultDateAndTimeFormat, s1 );
        ConcatLS( s, s1 );
        IF (ReadOnlyAttribute IN Attributes) THEN
            ConcatS(s, " RO");
        END;
    END;

    Copy( s, NamePtr^.DisplayString ); (* May truncate if big date formats. *)

END FormatName;




PROCEDURE MaybeAddIllegitimateChild( Node : ATreeNode );
VAR
    OtherNode       : ATreeNode;
    KidPtr,
    NamePtr         : ANameViewDisplayRecord;
BEGIN

  (* If this is a directory or disc drive entry, add a phantom kid to
     the tree node so that GoTo puts a "+" sign after this entry.  Make the
     kid invisible so that GoTo will not display him.
  *)
    NamePtr := Node^.Methods^.GetDataObject (Node);
    WITH NamePtr^ DO
        IF ((DriveOrDir * Attributes) <> EmptyAttr) THEN
            IF (CreateTreeNode (OtherNode)) THEN
                NEW( KidPtr );
                SetString( KidPtr^.DisplayString, "INVISIBLE" );
                OtherNode^.Methods^.SetDataObject (OtherNode, KidPtr);
                Node^.Methods^.AddAsFirstChild   ( Node, OtherNode );
                Node^.Methods^.SetChildrenVisible( Node, FALSE );
            END;
        END;
    END;
END MaybeAddIllegitimateChild;



PROCEDURE InsertNameIntoList(VAR Context        : AContext;
                             VAR FileNameRecord : AFileNameRecord );
VAR
    Node            : ATreeNode;
    OtherNode       : ATreeNode;
    NamePtr         : ANameViewDisplayRecord;
    i               : CARDINAL;
    SortName        : ARRAY [0..MaximumFileNameLength
                              + 2
                              + MaximumExtensionLength ] OF CHAR;
BEGIN
    IF (NOT HeapAvailable())   OR                                 (* 02-Feb-88 LAA *)
       (NOT CreateTreeNode (Node)) THEN
        Context.MoreNames := TRUE;
        RETURN;
    END;

    NEW (NamePtr);
    FormatName( FileNameRecord, NamePtr );
    Copy( NamePtr^.SortName, SortName );
    Node^.Methods^.SetDataObject (Node, NamePtr);

    OtherNode := Context.KidNames^.Methods^.GetFirst(Context.KidNames);
    WHILE (OtherNode <> NIL) DO
        NamePtr := OtherNode^.Methods^.GetDataObject (OtherNode);
        IF (Compare (SortName, NamePtr^.SortName) < 0) THEN
            OtherNode^.Methods^.AddBefore (OtherNode, Node);
            MaybeAddIllegitimateChild( Node );
            RETURN;
        ELSE
            OtherNode := OtherNode^.Methods^.NextForDisplay (OtherNode);
        END;
    END;

    Context.Names^.Methods^.AddLast (Context.KidNames, Node);
    MaybeAddIllegitimateChild( Node );

END InsertNameIntoList;





PROCEDURE HandleDirectoryRequest();
VAR
    TLDir411Interface : ATLDir411InterfaceP;
    s                 : ARRAY [0..1] OF CHAR;
    ProcessingOK,
    DirectoriesOnly   : BOOLEAN;
    Copyright         : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF (NOT HeapAvailable()) THEN RETURN; END;

    TLDir411Interface := ATLDir411InterfaceP(OverlayContext());

    (* Kluge for PICKDIRS.MOD:

        "Procedure Return" is always set to FALSE by DIRECT411.MOD, so that
        it can detect if all went ok in this module.  If this module failed
        to run due to memory problems or some such, ProcedureReturn would
        still be FALSE, and Direct411 could take appropriate action.

        As a hook (read kluge) for the new module PickDirs.Mod, If the
        ProcedureReturn is TRUE, then we will do directory lookups only.
        In order to insure failure detection, ProcedureReturn will be set
        to FALSE if it was TRUE and things went OK, TRUE if it was FALSE,
        and if something fails, do not change it.

        In other words,

            ProcedureReturn := NOT (ProcedureReturn = ProcessingOK)

            or:

            ProcedureReturn  ProcessingOK  Desired NEW ProcedureReturn
            ---------------  ------------  ---------------------------
                TRUE            TRUE            FALSE
                FALSE           TRUE            TRUE
                TRUE            FALSE           TRUE
                FALSE           FALSE           FALSE
    *)

    SetLengthOf(s,0);

    WITH TLDir411Interface^ DO
        DirectoriesOnly := ProcedureReturn;
        FileNameOut     := FileNameIn;
        CASE WhichFunction OF
           DirectoryAssistance : ProcessingOK := GiveDirectoryAssistance(
                                                        FirstY, LastY, Title,
                                                        FileNameOut,
                                                        CursorName,
                                                        Qualification,
                                      (* Dirs only? *)  DirectoriesOnly,
                                      (* Allow form? *) (NOT DirectoriesOnly));

         | AccessForm          : ProcessingOK := (DoPathForm( FileNameOut,
                                                              AllowWildcards,
                                                              GiveAssistance )
                                                           <> CancelKey);

         | ExportForm          : ProcessingOK := (DoExportForm( FileNameOut,
                                                                AllowWildcards,
                                                                GiveAssistance )
                                                             <> CancelKey);
        ELSE
            FatalError(); (* Out of range function *)
        END;
        ProcedureReturn := NOT (ProcedureReturn = ProcessingOK);
    END;

    Message(s);

END HandleDirectoryRequest;





(*<OS2
PROCEDURE TLDir411Bind();
OS2>*)

BEGIN
    LastCode := 0;                                                (* 9-Jan-90 MWP *)
    HandleDirectoryRequest();

(*<OS2
END TLDir411Bind;
OS2>*)

END TLDir411.

