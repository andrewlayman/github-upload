    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE Directory;

(*$S+*)

    (* MODIFICATION HISTORY:

       Aug. 15, 1985  AJL - Lookup files with ReadOnlyAttribute set.
       Sep. 3, 1985   AJL - Support DefaultDateFormat.
       25 Jul 86      Ajl - Use CheckIO in DirectoryIs Reachable to
                            detect file system errors such as open
                            drive doors.
        12/18/86 LAA    Added AFileAttributeSet to the DEF, and as parameters
                        to FileLookup, FileLookupStart and FileLookupContinue.
        12/22/86 LAA    In FileLookup, added code to correctly handle and
                        and return the special filenames "." and "..".
        12/23/86 LAA    Added procedure NumberOfDiskettes, and changed
                        RemovableMedia to use it.  Corrected DiskFreeSpace,
                        which would never have returned Valid as TRUE both
                        because it checked the drive string length incorrectly,
                        and because it Valid parameter wasn't a VAR parameter.
        01/08/87 LAA    Fixed bug in C2toS which would cause a range error for
                        file sizes whose lower cardinal was > 64511.
        06/25/87 RSC    Added FileNameRecord and tried to fix network dir
                        problems.  Specificly, in "DirectoryIsReachable" I
                        look for ANY files after failing to find any
                        subdirectories.  Andrew's idea.  Also, use CheckIO
                        in LookupFileName to detect any critical errors.
        24-Sep-87 LAA   Imported register names from SYSTEM instead of
                        System for Logitech Version 3 compiler.  Look for V3.
        16-Dec-87 LAA   Created local variables for GETREG and SETREG, as
                        required by the Logitech version 3.0 compiler.
       22-Feb-88 LAA  - Force stack checking on for this module.
        09-30-88 WKH    Implemented code from TLDir411(DirectoryIsReachable)
                        that RSC fixed on 6/15/88.
        10-12-88 RSC    Remove references to DISKDIRE.MOD (Logitek).  Heh Heh.
        21-Dec-88 LAA   Changed imports for Laslo reorganization.
         2-Jan-89 RSC   Added references to StringsEqual() rather than Compare().
         2-Feb-89 EGK   Made ExpandPath.WorkPath bigger.  Check for strings too
                        long in ExtractFileNameParts.
         1-May-89 WKH   Changed RemovableMedia so it uses the IOCTL service in
                        DOS(only vers 3.0 and above) to determine precisely if
                        a device is removable.
        21-May-89 KKC   Add new function ParseFileName
        26-May-89 KKC   Extract all codes that are shared by ParseFileName
                        and ExtractFileNameParts.  Create a new function
                        ParseFileNameParts which can be called by
                        ParseFileName and ExtractFileNameParts.
        31-May-89 WKH   Reduce 2 RETURN's into 1 as per EGK's suggestion.
                        This should save a couple of dozen bytes of code.
        06-Aug-89 WKH   Initial OS/2 edits.
        29-Nov-89 WKH   ARRRGH.  Turns out that something like ".DK:" is an
                        allowable device.  Too bad it causes other routines
                        to die!!  So, if in DirectoryIsReachable, we get a
                        device back from ExtractFileNameParts that either is
                        longer than 3 chars(allow for DK:) or if the first
                        character is not an alpha char, then return false.
        30-Nov-89 LAA   Optimized IsAlpha so it's a bit smaller.
        19-Apr-90 KKC   Grouped year, month, day, hour, minute into one
                        date structure, ATimeInfo. 
    *)

(*<DOS*)
FROM SYSTEM    IMPORT ADDRESS, ADR, CODE, GETREG, SETREG, WORD, SWI,
                      DOSCALL, AX, BX, CX, DX;
(*DOS>*)

(*<OS2
FROM SYSTEM    IMPORT ADDRESS, ADR, CODE, GETREG, SETREG, WORD, SWI,
                      DOSCALL, AX, BX, CX, DX, SIZE;
OS2>*)

FROM LStrings  IMPORT Procustes, ConcatS, ConcatLS, LStringToTString,
                      TStringToLString, Fill, Insert, Search, CtoS,
                      SetString, SubStr, Remove, Upshift, TrimRear,
                      LengthOf, Copy, SetLengthOf, RJust, StringsEqual;

FROM TimeFormat IMPORT DtoS;

FROM Timei      IMPORT ATimeInfo;

FROM Dialog    IMPORT Error;

FROM FileSystem IMPORT File, Response;

FROM FileAux   IMPORT PrepareForIO, CheckIO, FileResultMeans, DisplayFileError;

(*<OS2
FROM FileIO    IMPORT
                   DosFindFirst, FileInfoBlock, FileInfoBlockPtr, FileAttrSet,
                   DosFindNext, DosQFSInfo, FSInfoBufType, FSInfoBufPtr,
                   Level1Info, DriveMapSet, DosQCurDisk, DosQCurDir;
OS2>*)

FROM BigTimeU  IMPORT TimeToBigTime;


CONST
    GetDiskFreeSpace = 36H;

    AllFileAttributes = AFileAttributeSet{
                               ReadOnlyAttribute, HiddenAttribute,
                               SystemAttribute, LabelAttribute,
                               SubdirectoryAttribute, ArchiveAttribute,
                               DiskDriveAttribute};




CONST
    PathDelimiter   = "\";
    RadixChar       = ".";
    DeviceDelimiter = ":";
    MaxDeviceLetter = "Z";

TYPE
    AnAddress = RECORD
                  CASE  BOOLEAN OF
                     TRUE :   A : ADDRESS;
                   | FALSE:   WL, WH : WORD;
                  END;
                END;
    AReturnedFileInfo  = RECORD
                             Filler1 : ARRAY [1..21] OF CHAR;
                             Attribute: CHAR;
                             FileTime : CARDINAL;
                             FileDate : CARDINAL;
                             FileSizeLow,
                             FileSizeHigh : CARDINAL;
                             Name : ARRAY [0..12] OF CHAR;
                         END;
VAR
    TempFileRecord : AFileNameRecord;
    ReturnedInfo   : AReturnedFileInfo;
    LookupFileName : ARRAY [0..81] OF CHAR;  (* Used as parameter by FileLookup! *)

(*<OS2
    dirHandle	   : CARDINAL;
    InfoBlk	       : FileInfoBlock;
    resultBufPtr   : FileInfoBlockPtr;
    resultBufLen   : CARDINAL;
    searchCount    : CARDINAL;

    OSFsize        : RECORD
	                   CASE Dummy : INTEGER OF
		                   0 : CardView : ARRAY [0..1] OF CARDINAL;
		               |   1 : LongSize : LONGINT;
	                   END;
	                 END;

    trick          : RECORD
	                   CASE Dummy : INTEGER OF
		                   0 : OS2Rec :  FileAttrSet;
		               |   1 : DOSRec :  AFileAttributeSet;
	                   END;
	                 END;
OS2>*)

    (* C2toK -- Compute the file size in K, each of which is
                1024 bytes long.   This will return the number
                in whole K, because space is always
                allocated in whole-K increments by DOS.   For the
                same reason, we round up. *)

PROCEDURE C2toK( CH,CL : CARDINAL; VAR K : CARDINAL);
CONST
    D = 1024;           (* Cluster size on the disk.   *)
    MAXCARDDIVD = 64;   (* The largest cardinal, div D *)
BEGIN
    K := CL DIV D;                    (* 01/08/87 LAA *)
    IF CL - (K * D) > 0 THEN
        INC(K);
    END;
    INC(K, CH * MAXCARDDIVD);
END C2toK;


PROCEDURE SetDiskTransferAddress(DTA:AnAddress);
BEGIN
(*<DOS*)
   SETREG( DX, DTA.WL );
   SETREG( CX, DTA.WH );
   CODE  (  1EH,                      (*  PUSH  DS       *)
            8EH,  0D9H,               (*  MOV   DS, CX   *)
            0B8H, 00H, 1AH,           (*  MOV   AX, 1A00 *)
            0CDH, 21H,                (*  INT   21       *)
            1FH  );                   (*  POP   DS       *)
(*DOS>*)
END SetDiskTransferAddress;




PROCEDURE FileLookup(    Number             : CARDINAL;
                     VAR TheFileName        : ARRAY OF CHAR;
                     VAR Attributes         : AFileAttributeSet;
                     VAR FileNameRecord     : AFileNameRecord   ):BOOLEAN;
VAR
    Addr,
    OldDTA              : AnAddress;
    i,
    Time, Date          : CARDINAL;
    TimeInfo            : ATimeInfo;
    PrivateAttributes   : AFileAttributeSet;
    f                   : File;  (* Dummy File *)
    C, CH               : CHAR;
    DateString          : ARRAY [0..29] OF CHAR;
    s                   : ARRAY [0..80] OF CHAR;
    s2                  : ARRAY [0..MaximumFileNameLength] OF CHAR;
    dot, dotdot         : ARRAY [0..3] OF CHAR;
(*<OS2
    Ret 		        : CARDINAL;
    MyDateString	    : ARRAY [0..29] OF CHAR;
OS2>*)

BEGIN
(*<DOS*)
    IF (DOSVersion() < 0200H) THEN
        RETURN FALSE;
    END;
(*DOS>*)

(*<OS2
    dirHandle    := 1;
    resultBufPtr := ADR( InfoBlk );
    resultBufLen := SIZE( FileInfoBlock );
    trick.DOSRec := Attributes;
    searchCount  := 1;
OS2>*)

    PrepareForIO(f);   (* Set up to detect critical errors *)
    f.res := done;

(*<OS2
    CASE Number OF
        4E00H :
            Ret := DosFindFirst ( ADR( LookupFileName ),
			                      dirHandle,
			                      trick.OS2Rec,
			                      resultBufPtr,
			                      resultBufLen,
			                      searchCount,
			                      0L );
    |	4F00H :
	        Ret := DosFindNext ( dirHandle,
			                     resultBufPtr,
			                     resultBufLen,
			                     searchCount
			                     );
    ELSE
	    RETURN FALSE;
    END;
OS2>*)

(*<DOS*)
    FindDiskTransferAddress(OldDTA);      (*  Save Current DTA  *)

    Addr.A  := ADR(ReturnedInfo);         (*  Set new DTA       *)
    SetDiskTransferAddress(Addr);


    Addr.A := ADR(LookupFileName);        (*  Lookup file       *)
    PrivateAttributes := Attributes;                              (* 16-Dec-87 LAA *)
    i := CARDINAL(PrivateAttributes);
    SETREG( DX, Addr.WL);
    SETREG( AX, Number );              (*  Function number.  *)
    SETREG( CX, i      );   (*  Normal or directory, etc. *)
    SWI(21H);
    GETREG( AX,C);                     (*  Get return code   *)

    SetDiskTransferAddress(OldDTA);

    IF  (C = 0C)  AND  (CheckIO(f) = done)  THEN
        WITH ReturnedInfo  DO                 (*  Get returned file name *)
            TStringToLString(Name,TheFileName);
            Time       := FileTime;
            Date       := FileDate;
            Attributes := AFileAttributeSet(ORD(Attribute));
        END;
(*DOS>*)

(*<OS2
    IF	( Ret = 0 )  THEN
	    Time	     := resultBufPtr^.lastWriteTime;
	    Date	     := resultBufPtr^.lastWriteDate;
	    trick.OS2Rec := resultBufPtr^.fileAttribute;
	    Attributes   := trick.DOSRec;
	    TStringToLString( resultBufPtr^.fileName.name, TheFileName );
OS2>*)

            (*  Pad out the file name and extension. *)
        FileNameRecord.Attributes := Attributes;
        TrimRear(TheFileName);
        SetString(dot,    ".");
        SetString(dotdot, "..");
        WITH FileNameRecord DO
            IF (StringsEqual(TheFileName, dot   )) OR       (* RSC 1/2/88 *)
               (StringsEqual(TheFileName, dotdot)) THEN
               SetLengthOf(Extension,0);
               Copy(TheFileName,FileName);
            ELSE
               ExtractFileNameParts(TheFileName, Device, Path, FileName, Extension );
            END;
            Copy(TempFileRecord.Device,Device);
            Copy(TempFileRecord.Path,Path);

            Copy(FileName, TheFileName);
            Procustes(TheFileName,MaximumFileNameLength);
            Procustes(Extension,MaximumExtensionLength);
            ConcatS(TheFileName,RadixChar);
            ConcatLS(TheFileName,Extension);

            ConcatS(TheFileName,"  ");

            IF (SubdirectoryAttribute IN Attributes) THEN
                Size := 1; (* Well, SOME size! (Directories return garbage) *)
            ELSE
(*<DOS*)
                C2toK(ReturnedInfo.FileSizeHigh,ReturnedInfo.FileSizeLow, Size);
(*DOS>*)
(*<OS2
		        OSFsize.LongSize := resultBufPtr^.alloc;
		        C2toK( OSFsize.CardView[1],OSFsize.CardView[0], Size );
OS2>*)
            END;

            (* Beware of dates on network directories - they can be 0! *)

            WITH TimeInfo DO
                tiYear   := ( Date DIV 0200H ) + 1980;
                tiMonth  := CARDINAL( BITSET( Date DIV 0020H ) * {0..3});
                IF (tiMonth > 0) THEN
                    DEC(tiMonth);      (* Make it our format *)
                END;
                tiDay    := CARDINAL( BITSET( Date )           * {0..4});
                tiHour   := ( Time DIV 0800H );
                tiMinute := CARDINAL( BITSET( Time DIV 0020H ) * {0..5});
                DtoS( TimeInfo, DateString);
                ConcatLS(TheFileName,DateString);
                TimeToBigTime( tiYear, tiMonth, tiDay, tiHour, tiMinute, 0, TimeStamp );
                CtoS(Size, DateString);
                Procustes(DateString,9);
                RJust(DateString);
                ConcatLS(TheFileName,DateString);
            END;

            RETURN TRUE;
        END;
    ELSE
        RETURN FALSE;
    END;
END FileLookup;





    (*  FileLookupStart  --  Initiate a search for a file on the
                             indicated disk.  Returns a TRUE value if a
                             file was found.  File name returned in "Filename."
                         *)


PROCEDURE DoFileLookupStart(VAR FileNameMask   : ARRAY OF CHAR;
                            VAR Filename       : ARRAY OF CHAR;
                            VAR Attributes     : AFileAttributeSet;
                            VAR FileNameRecord : AFileNameRecord
                           ):BOOLEAN;
VAR
    i                  : CARDINAL;
    s3                 : ARRAY [0..MaximumDeviceNameLength] OF CHAR;
BEGIN
        (*  "DK:" indicates the default drive.  If it is here, ignore it. *)
    SetString(s3,"DK:");
    i := Search(FileNameMask,s3,1);
    IF (i = 1) THEN
        i := 4;
    ELSE
        i := 1;
    END;
    SubStr(FileNameMask,LookupFileName,i,HIGH(LookupFileName));
    WITH TempFileRecord DO
        ExtractFileNameParts(LookupFileName,Device,Path,FileName,Extension);
    END;
    LStringToTString(LookupFileName,LookupFileName);
    RETURN FileLookup(4E00H,Filename, Attributes, FileNameRecord);
END DoFileLookupStart;


    (*  FileLookupStart  --  Initiate a search for a file on the
                             indicated disk.  Returns a TRUE value if a
                             file was found.  File name returned in "Filename."
                         *)


PROCEDURE FileLookupStart(VAR FileNameMask  : ARRAY OF CHAR;
                          VAR Filename      : ARRAY OF CHAR;
                          VAR Attributes    : AFileAttributeSet):BOOLEAN;
VAR FileNameRecord     : AFileNameRecord;
BEGIN
    RETURN DoFileLookupStart(FileNameMask, Filename,
                             Attributes,   FileNameRecord );
END FileLookupStart;





PROCEDURE FileLookupContinue(VAR Filename   : ARRAY OF CHAR;
                             VAR Attributes : AFileAttributeSet):BOOLEAN;
VAR FileNameRecord     : AFileNameRecord;
BEGIN
    RETURN FileLookup(4F00H,Filename,Attributes,FileNameRecord);
END FileLookupContinue;






    (*  DOSVersion -- Returns the version of DOS currently executing.
                      The HIGH ORDER byte has the major version, and the
                      low order byte the minor version (reversed from the
                      PC-DOS returned order.)
                  *)


PROCEDURE DOSVersion():CARDINAL;

VAR
    Version    : CARDINAL;

BEGIN
(*<DOS*)
    CODE (  0B8H, 00H, 30H,           (*  MOV AX, 3000H  *)
            0CDH, 21H,                (*  INT 21         *)
            0B1H, 08H,                (*  MOV CL, 8      *)
            0D3H, 0C8H  );            (*  ROR AX, CL     *)
    GETREG(AX,Version);
    RETURN Version;
(*DOS>*)

(*<OS2
    RETURN 0301H;
OS2>*)
END DOSVersion;



PROCEDURE FindDiskTransferAddress(VAR DTA:AnAddress);
VAR
    PrivateDTA              : AnAddress;

BEGIN
(*<DOS*)
   CODE  (  06H,                      (*  PUSH  ES       *)
            0B8H, 00H, 2FH,           (*  MOV   AX, 2F00 *)
            0CDH, 21H,                (*  INT   21       *)
            8CH, 0C0H,                (*  MOV   AX, ES   *)
            89H, 0D9H,                (*  MOV   CX, BX   *)
            07H );                    (*  POP   ES       *)

   GETREG( AX, PrivateDTA.WH );
   GETREG( CX, PrivateDTA.WL );
   DTA := PrivateDTA;
(*DOS>*)

END FindDiskTransferAddress;



    (*  ExtractDeviceName -- Extract the Device Name within a file or path
                             name.  Return the current drive letter if no device
                             name is found.
                             "i" is set to the index of the next char past the
                             device name. *)



PROCEDURE ExtractDeviceName(VAR From, DeviceName : ARRAY OF CHAR; VAR i:CARDINAL);
CONST
    GetCurrDisk = 19H;
VAR
    s1          : ARRAY [0..3] OF CHAR;
    Drive       : CHAR;
(*<OS2
    DriveNumber : CARDINAL;
    err         : CARDINAL;
    DriveMap    : DriveMapSet;
OS2>*)

BEGIN
    Fill(s1,DeviceDelimiter,1);
    i := Search(From,s1,1);
    IF (i > 0) THEN
        IF (i > MaximumDeviceNameLength) THEN i := MaximumDeviceNameLength; END;
        SubStr(From,DeviceName,1,i-1);
    ELSE
        DeviceName[0] := 0C;     (* No device name found. *)
    END;
    INC(i);                      (* Index of char past device name. *)

    SetString( s1, "DK" );
    IF  (DeviceName[0] = 0C)  OR        (* no disc or DK:? *)
       ((DeviceName[0] = 2C) AND
        (StringsEqual( DeviceName, s1 ))) THEN      (* RSC 1/2/88 *)
        DeviceName[0] := 1C;
(*<DOS*)
        DOSCALL( GetCurrDisk, Drive ); (* Then give them the default drive. *)
        INC( Drive, ORD("A") );
        DeviceName[1] := Drive;
(*DOS>*)
(*<OS2
        err := DosQCurDisk(DriveNumber, DriveMap);
        INC( DriveNumber, ORD("A") );
        DEC( DriveNumber );  (* OS/2 drive A = 1 instead of 0 as in DOS *)
        DeviceName[1] := CHR(DriveNumber);
OS2>*)
    END;
    ConcatS(DeviceName,DeviceDelimiter);
END ExtractDeviceName;




PROCEDURE RemoveAnyBlanks(VAR s : ARRAY OF CHAR);
VAR
    i  : CARDINAL;
    s1 : ARRAY [0..1] OF CHAR;
BEGIN
    Fill(s1," ",1);
    TrimRear(s);

        (*  Remove any blanks. *)
    i := 1;
    WHILE (i <= ORD(s[0])) DO
        IF (s[i] = " ") THEN
            Remove(s,i,1);
        ELSE
            INC(i);
        END;
    END;

END RemoveAnyBlanks;



    (*  Read a segment of a filename from Source, beginning at
        position i.  As many as Max characters will be moved to
        Dest, although i will always be moved to past the
        delimiting character. *)

PROCEDURE GetSegment(VAR Source,Dest:ARRAY OF CHAR; VAR i:CARDINAL;
                     Max : CARDINAL; Delim : CHAR);
VAR
    j,k : CARDINAL;
BEGIN
    j := i;
    WHILE (i <= ORD(Source[0])) AND (Source[i] <> Delim) DO INC(i); END;
    k := i-j;
    IF (k > Max) THEN k := Max; END;
    SubStr(Source,Dest,j,k);
    INC(i);
END GetSegment;



    (*$S+*)

PROCEDURE ParseFileName(
                                        s : ARRAY OF CHAR;
                          VAR DeviceName,
                                PathName,
                                FileName,
                                Extension : ARRAY OF CHAR
                       );
BEGIN
    ParseFileNameParts(s, DeviceName, PathName,FileName,Extension, TRUE);
END ParseFileName;


    (*  Parse the string "s" looking for the parts of a file name.
            The DeviceName will be returned with a ":".
            The FileName and Extension will have no separating ".".
            The PathName, if it exists, will have its trailing "\".
     *)


PROCEDURE ExtractFileNameParts(
                                                  s : ARRAY OF CHAR;
                                  VAR DeviceName,
                                          PathName,
                                          FileName,
                                          Extension : ARRAY OF CHAR
                              );
BEGIN
    ParseFileNameParts(s, DeviceName, PathName,FileName,Extension, FALSE);
END ExtractFileNameParts;


    (*  Parse the string "s" looking for the parts of a file name.
            The DeviceName will be returned with a ":".
            The FileName and Extension will have no separating ".".
            The PathName, if it exists, will have its trailing "\".
            IF NOT NullPathAndDir then return overlay's device and
            path for null path and dir.
     *)

PROCEDURE ParseFileNameParts(
                                             s : ARRAY OF CHAR;
                               VAR DeviceName,
                                     PathName,
                                     FileName,
                                     Extension : ARRAY OF CHAR;
                                NullPathAndDir : BOOLEAN
                            );
VAR
    i, j        : CARDINAL;
    s1          : ARRAY [0..1] OF CHAR;
    FullPath    : ARRAY [0..MaximumDeviceNameLength
                      + 1 + MaximumPathNameLength]  OF CHAR;
BEGIN
    Upshift(s);                             (*  Convert all to upper case. *)
    RemoveAnyBlanks(s);

        (*  Find the beginning of the file name.   Extract path name.
            Exit with i and j as index to beginning of file name.
         *)

    i := ORD(s[0]);
    WHILE (i > 0) AND
          (s[i] <> PathDelimiter)   AND
          (s[i] <> DeviceDelimiter) DO
        DEC(i);
    END;
    INC(i);
    j := i;

        (*  Extract the file name, up to the extension. *)

    GetSegment(s,FileName,i,MaximumFileNameLength,RadixChar);
    GetSegment(s,Extension,i,MaximumExtensionLength,RadixChar);

        (*  Remove the file name and extension from s. *)

    Remove(s,j,HIGH(s));

        (*  Parse and rebuild the pathname. *)

    s1[0] := 0C;
    Copy( s,    FullPath );
    j := HIGH(FullPath);
    IF (LengthOf(s) > j) THEN                  (* 2/2/89 EGK *)
        FullPath[j] := PathDelimiter;
    END;
    IF ( NOT NullPathAndDir ) THEN
        ExpandPath( FullPath, s1, FullPath );
    END;

    i := 1;
    IF ( ( NOT NullPathAndDir )
        OR
         (
            ( LengthOf(FullPath) > 2 )
             AND
            ( FullPath[2] = ':')
         ) ) THEN
        ExtractDeviceName(FullPath,DeviceName,i);  (* Extract device name.  *)
        Remove(FullPath,1,i-1);                    (* Remove device name.   *)
    ELSE
        SetLengthOf(DeviceName, 0 );
    END;
    Copy(  FullPath, PathName );               (* Save final path name. *)

END ParseFileNameParts;




    (*  NormalizeFileName  -- rephrase a file name, correcting for common
                              errors. *)


PROCEDURE NormalizeFileName(VAR s:ARRAY OF CHAR; FileNameParts:ASetOfFileNameParts);
VAR
    DeviceName : ARRAY [0..MaximumDeviceNameLength] OF CHAR;
    PathName   : ARRAY [0..MaximumPathNameLength] OF CHAR;
    FileName   : ARRAY [0..MaximumFileNameLength] OF CHAR;
    Extension  : ARRAY [0..MaximumExtensionLength] OF CHAR;


BEGIN

    ExtractFileNameParts(s,DeviceName,PathName,FileName,Extension);

        (* Make the device name legal. *)

    IF (DeviceName[0] = 1C) AND (DeviceName[1] > MaxDeviceLetter) THEN
        DeviceName[1] := MaxDeviceLetter;
    END;


    s[0] := 0C;   (* Nothing to return, yet. *)


    IF (DevicePart IN FileNameParts) THEN
        ConcatLS(s,DeviceName);
    END;

    IF (DirectoryPart IN FileNameParts) THEN
        ConcatLS(s,PathName);
        IF (NOT (FileNamePart IN FileNameParts)) THEN
            IF (FileName[0] > 0C) THEN
                ConcatLS(s,FileName);     (*  Any "filename" is really a directory. *)
                ConcatS(s,PathDelimiter);
            END;
        END;
    END;

    IF (FileNamePart IN FileNameParts) THEN
        ConcatLS(s,FileName);
        IF (ExtensionPart IN FileNameParts) THEN
            ConcatS(s,RadixChar);
            ConcatLS(s,Extension);
        END;
    END;

END NormalizeFileName;


    (*$S=*)




    (*  GetPathEntry -- Get the nth (starting with 0) substring from
                        PathList where each substring is delimited by
                        semicolons. *)

PROCEDURE GetPathEntry(VAR PathList:ARRAY OF CHAR; n:CARDINAL;
                       VAR PathEntry:ARRAY OF CHAR ) : BOOLEAN;
CONST
     SeparatorChar = ";";
VAR
    Entry, i, j : CARDINAL;
    Separator   : ARRAY [0..1] OF CHAR;
BEGIN
    Fill(Separator,SeparatorChar,1);

        (*  Find the beginning of the nth path entry. *)

    i := 0;
    j := 1;
    WHILE (i < n) DO
        j := Search(PathList,Separator,j);
        IF (j = 0) THEN
            RETURN FALSE;
        ELSE
            INC(j);
        END;
        INC(i);
    END;

        (*  Find the end of the nth path entry. *)

    i := Search(PathList,Separator,j);
    IF (i = 0) THEN
        i := HIGH(PathList)+1;
    END;

    SubStr(PathList,PathEntry,j,i-j);

    RETURN TRUE;

END GetPathEntry;






PROCEDURE PathLookupStart(VAR Path,
                              FileNameMask: ARRAY OF CHAR;
                          VAR Directory,
                              Filename:ARRAY OF CHAR):BOOLEAN;
VAR
    n           : CARDINAL;
    Attributes  : AFileAttributeSet;
    f           : File;
    s           : ARRAY [0..81] OF CHAR;
    s2          : ARRAY [0..140] OF CHAR;
    ok          : BOOLEAN;
BEGIN
    n := 0;
    LOOP
        IF (NOT GetPathEntry(Path,n,Directory)) THEN
            RETURN FALSE;
        END;
        NormalizeFileName(Directory,ASetOfFileNameParts{DevicePart,DirectoryPart});
        PrepareForIO(f);
        f.res := done;
        SubStr(Directory,s,1,HIGH(s));
        ConcatLS(s,FileNameMask);
        Attributes := AFileAttributeSet{};
        ok := FileLookupStart(s,s2, Attributes);
        IF (ok) THEN
            IF (CheckIO(f)=done) THEN
                SubStr(s2,Filename,1,12);    (* Take only the filename *)
                RemoveAnyBlanks(Filename);
                RETURN TRUE;
            ELSE
                DisplayFileError(f,s);
                RETURN FALSE;
            END;
        END;
        INC(n);
    END;
END PathLookupStart;




PROCEDURE NumberOfDiskettes(): CARDINAL;

CONST
    ReadEquipFlags = 11H;

VAR
    EquipmentFlags : BITSET;
    FloppyCount    : CARDINAL;

BEGIN                       (* NumberOfDiskettes *)

 (* *******************************************************************
        (* Count the number of floppy disk drives. *)
    SWI( ReadEquipFlags );
    GETREG(AX,EquipmentFlags);
    IF (0 IN EquipmentFlags) THEN
        IF (7 IN EquipmentFlags) THEN
            IF (6 IN EquipmentFlags) THEN
                FloppyCount := 4;
            ELSE
                FloppyCount := 3;
            END;
        ELSE
            IF (6 IN EquipmentFlags) THEN
                FloppyCount := 2;
            ELSE
                FloppyCount := 1;
            END;
        END;
    ELSE
        FloppyCount := 0;
    END;

  ***************************************************************** *)

    FloppyCount := 2;  (* A: and B: assumed. *)

    RETURN FloppyCount;

END NumberOfDiskettes;



PROCEDURE RemovableMedia(     Media : ARRAY OF CHAR ) : BOOLEAN;

CONST
    IOCTLCall               = 044H;
    QueryRemovableMediaFunc = 008H;

VAR
    FloppyCount             : CARDINAL;
    Removable               : CARDINAL;
    Error                   : CARDINAL;
    Drive                   : CARDINAL;

BEGIN
(*<DOS*)
    IF (DOSVersion() >= 0300H) THEN   (* 5/1/89 WKH *)
        Drive := ORD(CAP(Media[1])) - ORD('A') + 1;

        Removable := 1; (* assume not removable *)

        DOSCALL(IOCTLCall, QueryRemovableMediaFunc, Drive, Removable, Error);

        RETURN (Removable = 0);  (* 5/31/89 WKH *)
    ELSE
(*DOS>*)
        FloppyCount := NumberOfDiskettes();               (* 12/23/86 LAA *)
        IF FloppyCount = 1 THEN
            INC(FloppyCount);       (* DOS reuses A: drive as the B: drive.  *)
        END;

            (* Is the device a floppy drive?  Assume device name is format "X:". *)

        RETURN (ORD(Media[1]) - ORD("A")  < FloppyCount);
(*<DOS*)
    END;
(*DOS>*)

END RemovableMedia;





(*<DOS*)
PROCEDURE DiskFreeSpace(     Media             : ARRAY OF CHAR;
                         VAR FreeClusters,
                             TotalClusters,
                             BytesPerSector,
                             SectorsPerCluster : CARDINAL;
                         VAR Valid             : BOOLEAN );
VAR
    i          : CARDINAL;
    j          : CARDINAL;
    DummyFile  : File;
    DeviceName : ARRAY [0..MaximumFileNameLength] OF CHAR;
    Extension  : ARRAY [0..MaximumFileNameLength] OF CHAR;
    PathName   : ARRAY [0..MaximumPathNameLength] OF CHAR;
    FileName   : ARRAY [0..MaximumFileNameLength+MaximumPathNameLength+4] OF CHAR;
BEGIN
    ExtractFileNameParts(Media, DeviceName, PathName, FileName,
                         Extension);

    IF (DeviceName[0] <> 2C) THEN      (* 12/23/86 LAA *)
        Valid := FALSE;
    ELSE
        i := ORD(DeviceName[1]) - 64;   (* A=1, B=2, etc. *)
        PrepareForIO(DummyFile);
        DOSCALL(GetDiskFreeSpace,i,j,FreeClusters,TotalClusters,BytesPerSector);
        IF (j = 0FFFFH) THEN   (* Signals invalid drive. *)
            Valid := FALSE;
        ELSE
            SectorsPerCluster := j;
            Valid := (CheckIO(DummyFile) = done);    (* Did DOS signal any critical error? *)
        END;
    END;

END DiskFreeSpace;
(*DOS>*)



(*<OS2
PROCEDURE DiskFreeSpace(     Media	          : ARRAY OF CHAR;
			            VAR FreeClusters,
			                TotalClusters,
			                SectorsPerCluster : LONGINT;
			            VAR BytesPerSector    : CARDINAL;
			            VAR Valid	          : BOOLEAN );

VAR
    i	        : CARDINAL;
    j	        : CARDINAL;
    DummyFile   : File;
    DeviceName  : ARRAY [0..MaximumFileNameLength] OF CHAR;
    Extension   : ARRAY [0..MaximumFileNameLength] OF CHAR;
    PathName    : ARRAY [0..MaximumPathNameLength] OF CHAR;
    FileName    : ARRAY [0..MaximumFileNameLength+MaximumPathNameLength+4] OF CHAR;
    LevelStruc	: FSInfoBufType;
    pLevelStruc : FSInfoBufPtr;
    QFSsize	    : CARDINAL;
    Ret 	    : CARDINAL;

BEGIN
    ExtractFileNameParts(Media, DeviceName, PathName, FileName,
			             Extension);

    IF (DeviceName[0] <> 2C) THEN      (* 12/23/86 LAA *)
    	Valid := FALSE;
    ELSE
	    i := ORD(DeviceName[1]) - 64;	(* A=1, B=2, etc. *)
	    PrepareForIO(DummyFile);
	    QFSsize     := SIZE(Level1Info);
	    pLevelStruc := ADR(LevelStruc);

	    Ret := DosQFSInfo ( i,
			                1,
			                pLevelStruc,
			                QFSsize );

	    IF ( Ret <> 0 ) THEN
	        Valid := FALSE;
	    ELSE
	        FreeClusters      := pLevelStruc^.info1.availAllocU;
	        TotalClusters     := pLevelStruc^.info1.allocUnits;
	        SectorsPerCluster := pLevelStruc^.info1.sectPerAlloc;
	        BytesPerSector    := pLevelStruc^.info1.bytesPerSec;
	        Valid             := (CheckIO(DummyFile) = done);
	    END;
    END;
END DiskFreeSpace;
OS2>*)


    (*  DirectoryIsReachable -- Check that the named directory exists and
                                is reachable.   This routine assumes that the
                                directory name is normalized already. *)

(*<DOS*)
PROCEDURE DirectoryIsReachable(VAR Directory:ARRAY OF CHAR):BOOLEAN;
CONST
    DirectoriesOnly  = AFileAttributeSet{HiddenAttribute, SystemAttribute,
                                         SubdirectoryAttribute};
VAR
    i,
    Valid,
    AvailClusters,
    TotalClusters,
    BytesPerSector      : CARDINAL;
    Attributes          : AFileAttributeSet;
    FileNameRecord      : AFileNameRecord;
    ok                  : BOOLEAN;
    s1                  : ARRAY [0..1]   OF CHAR;
    s                   : ARRAY [0..80] OF CHAR;
    DeviceName          : ARRAY [0..MaximumDeviceNameLength] OF CHAR;
    Extension           : ARRAY [0..MaximumExtensionLength]  OF CHAR;
    PathName            : ARRAY [0..MaximumPathNameLength]   OF CHAR;
    FileName            : ARRAY [0..MaximumFileNameLength+1+MaximumExtensionLength] OF CHAR;

    PROCEDURE IsAlpha(c : CHAR) : BOOLEAN;  (* 29-Nov-89 WKH  *)

    BEGIN

        RETURN ( (('A' >= c) AND (c <= 'Z')) OR (('a' >= c) AND (c <= 'z')) );  (* 30-Nov-89 LAA *)

    END IsAlpha;

BEGIN
    ExtractFileNameParts(Directory, DeviceName, PathName, FileName,
                         Extension);

    IF (LengthOf(DeviceName) > 3) OR (NOT IsAlpha(DeviceName[1])) THEN
        RETURN FALSE;  (* 29-Nov-89 WKH  *)
    END;

        (* If this is a root directory, just see if the disc drive is
           available.
        *)

    IF (PathName[0] <= 1C) THEN  (* empty or only "\" *)
        DiskFreeSpace(DeviceName, AvailClusters, TotalClusters, BytesPerSector, Valid, ok);
        RETURN ok;
    END;

    (* Look in the parent directory of this one for this entry.  This is
       preferable to looking for any files in the subject directory, because
       some networks do not put a "." or a ".." entry in their directories,
       so a new or empty directory has NO files.

       Trim off trailing "\" on the path name and add a "." so FileLookup
       thinks it is a file name, as in:
           DK:\ABC\  ===>  DK:\ABC.

       RSC 6/15/88: Only add a dot if this path entry does not already have
                    a dot, as in "A:\TL3.5\" (Well, really done by WKH on
                    9/30/88.
     *)

    DEC( PathName[0] );  (* Shorten by one byte,. *)

    i := ORD(PathName[0]);
    WHILE (i > 0) AND (PathName[i] <> "\") AND (PathName[i] <> RadixChar) DO
        DEC(i);
    END;

    IF (i = 0) OR (PathName[i] = "\") THEN
        ConcatS( PathName, RadixChar );
    END;

    Copy(DeviceName, s );
    ConcatLS(s,PathName);

    LStringToTString(s,LookupFileName);   (* Global parameter to FileLookup. *)
    Attributes := DirectoriesOnly;
    ok         := FileLookup(4E00H,s,Attributes,FileNameRecord);

    (* The entry must exist and must be a subdirectory. *)

    RETURN (ok AND
          ((Attributes * AFileAttributeSet{SubdirectoryAttribute})
                       = AFileAttributeSet{SubdirectoryAttribute}));
END DirectoryIsReachable;
(*DOS>*)





(*<OS2
PROCEDURE DirectoryIsReachable(VAR Directory:ARRAY OF CHAR) : BOOLEAN;

CONST
    DirectoriesOnly  = AFileAttributeSet{HiddenAttribute, SystemAttribute,
					                     SubdirectoryAttribute};

VAR
    i,
    Valid,
    AvailClusters,
    TotalClusters,
    SectorsPerCluster	: LONGINT;
    BytesPerSector	    : CARDINAL;
    Attributes		    : AFileAttributeSet;
    FileNameRecord	    : AFileNameRecord;
    ok			        : BOOLEAN;
    s1		        	: ARRAY [0..1]	 OF CHAR;
    s			        : ARRAY [0..80] OF CHAR;
    DeviceName		    : ARRAY [0..MaximumDeviceNameLength] OF CHAR;
    Extension		    : ARRAY [0..MaximumExtensionLength]  OF CHAR;
    PathName		    : ARRAY [0..MaximumPathNameLength]   OF CHAR;
    FileName		    : ARRAY [0..MaximumFileNameLength+1+MaximumExtensionLength] OF CHAR;

BEGIN
    ExtractFileNameParts(Directory, DeviceName, PathName, FileName,
			             Extension);

	(* If this is a root directory, just see if the disc drive is
	   available.
	*)

    IF (PathName[0] <= 1C) THEN  (* empty or only "\" *)
	    DiskFreeSpace(DeviceName, AvailClusters, TotalClusters, SectorsPerCluster, BytesPerSector, ok);
	    RETURN ok;
    END;

    (* Look in the parent directory of this one for this entry.  This is
       preferable to looking for any files in the subject directory, because
       some networks do not put a "." or a ".." entry in their directories,
       so a new or empty directory has NO files.

       Trim off trailing "\" on the path name and add a "." so FileLookup
       thinks it is a file name, as in:
	   DK:\ABC\  ===>  DK:\ABC.
     *)

    Procustes( PathName, LengthOf( PathName ) - 1 );
    ConcatS(   PathName, "." );

    Copy(DeviceName, s );
    ConcatLS(s,PathName);

    LStringToTString(s,LookupFileName);   (* Global parameter to FileLookup. *)
    Attributes := DirectoriesOnly;
    ok	       := FileLookup(4E00H,s,Attributes,FileNameRecord);

    (* The entry must exist and must be a subdirectory. *)

    RETURN (ok AND ((Attributes * AFileAttributeSet{SubdirectoryAttribute})
		            = AFileAttributeSet{SubdirectoryAttribute}));
END DirectoryIsReachable;
OS2>*)



 (* StartFileNode Lookup - Start a directory search to return FileNameRecords.

        Preconditions  - FileNameMask is the desired file name including
                         wildcards.

        Postconditions - FileNameRecord is the returned, structured, data.
                         RETURN is TRUE iff Ok.
 *)

PROCEDURE StartFileNodeLookup( VAR FileNameMask   : ARRAY OF CHAR;
                               VAR FileNameRecord : AFileNameRecord ): BOOLEAN;
VAR
    Attributes: AFileAttributeSet;
    Filename  : ARRAY [0..79] OF CHAR;
BEGIN
    Attributes := FileNameRecord.Attributes;
    RETURN DoFileLookupStart(FileNameMask, Filename,
                             Attributes,   FileNameRecord );
END StartFileNodeLookup;







 (* ContinueFileNode Lookup - Continue a file search started by
                              StartFileNodeLookup.

        Preconditions  - StartFileNodeLookup was called and returned TRUE.

        Postconditions - FileNameRecord is the returned, structured, data.
                         RETURN is TRUE iff Ok.
 *)

PROCEDURE ContinueFileNodeLookup(
                               VAR FileNameRecord : AFileNameRecord ): BOOLEAN;
VAR
    Attributes: AFileAttributeSet;
    Filename  : ARRAY [0..79] OF CHAR;
BEGIN
    Attributes := FileNameRecord.Attributes;
    RETURN FileLookup(4F00H,Filename,Attributes,FileNameRecord);
END ContinueFileNodeLookup;


  (* Expand Path - Expand a path name.  This includes expanding ".\" and
                   "..\" properly, and filling in a default device and path
                   spec.

       Preconditions  - PathIn      is a device and path string that may
                                    contain dots in the path section.
                        DefaultPath is a default device and path to apply
                                    if the device and path are missing.
                                    If this too is nul (length=0), the default
                                    is the default disc and directory.  This is
                                    provided for command line interpretation.
       Postconditions - PathOut     is the expanded path.  If the expanded
                                    path will not fit in 64 bytes (the limit),
                                    The source path will be returned.
  *)
PROCEDURE ExpandPath( VAR PathIn,
                          DefaultPath,
                          PathOut     : ARRAY OF CHAR );
CONST
    DefaultDir  = 47H;
    GetCurrDisk = 19H;
VAR
    AS             : ADDRESS;
    Result,
    WorkLength,
    PathIndex      : CARDINAL;

    s,
    WorkPath       : ARRAY [0..255] OF CHAR;        (* 2/2/89 EGK *)

    Drive          : CHAR;

    DirectoryStack : ARRAY [0..127] OF CHAR;
(*<OS2
    err            : CARDINAL;
    DriveNumber    : CARDINAL;
    DriveMap       : DriveMapSet;
    PathBufSize    : CARDINAL;
OS2>*)



    PROCEDURE PushDirectory( VAR s : ARRAY OF CHAR );
    BEGIN
        IF (s[1] <> PathDelimiter) THEN
            ConcatS( DirectoryStack, PathDelimiter );
        END;
        ConcatLS( DirectoryStack, s );
    END PushDirectory;


    PROCEDURE PopDirectory();
    VAR i : CARDINAL;
    BEGIN
        i := LengthOf(DirectoryStack);
        WHILE ( i > 0) AND (DirectoryStack[ i ] <> PathDelimiter) DO
            DEC(i);
        END;
        IF ( i > 0 ) THEN
            DEC(i);       (* remove slash. *)
        END;
        SetLengthOf(DirectoryStack,i);
    END PopDirectory;


    (* Given a path fragment, add it or take it away or ignore it.  Fragments
       are:
            .                ignore (same directory as last one)
            ..               pop last dir entry from the directory path.
            <anything else>  add it to the full directory path.
    *)
    PROCEDURE ManageDirectoryStack( VAR s : ARRAY OF CHAR );
    VAR
        dot,
        dotdot : ARRAY [0..2] OF CHAR;
    BEGIN
        SetString(dot   ,"." );
        SetString(dotdot,"..");
        IF (LengthOf(s) = 0) OR (StringsEqual( s, dot )) THEN   (* RSC 1/2/88 *)
           (* Ignore this *)
        ELSIF (StringsEqual( s, dotdot )) THEN                  (* RSC 1/2/88 *)
            PopDirectory();    (* Take away an entry *)
        ELSE
            PushDirectory(s);  (* Add entry to directory *)
        END;
    END ManageDirectoryStack;

BEGIN
    Copy(PathIn, WorkPath);
    Upshift(WorkPath);
    TrimRear(WorkPath);

    IF (LengthOf(WorkPath) = 0) THEN         (* PathIn was null. *)
        IF (LengthOf(DefaultPath) = 0) THEN  (* No default either? *)
            Drive := 0C;
            AS    := ADR(s);
(*<DOS*)
            DOSCALL( DefaultDir, Drive, AS, Result );
            IF (Result = 15) THEN
                s[0] := 0C;
            END;
(*DOS>*)
(*<OS2
            PathBufSize := SIZE(s);
            err := DosQCurDir(0, AS, PathBufSize);
            IF (err <> 0) THEN
                s[0] := 0C;
            END;
OS2>*)
            TStringToLString( s, s );
            WorkLength := LengthOf(s);
            IF (WorkLength > 0) AND (s[WorkLength] <> "\") THEN
                ConcatS(s,"\");
            END;
            PathOut[0] := 1C;
(*<DOS*)
            DOSCALL( GetCurrDisk, Drive );
            INC( Drive, ORD("A") );
            PathOut[1] := Drive;
(*DOS>*)
(*<OS2
            err := DosQCurDisk(DriveNumber, DriveMap);
            INC( DriveNumber, ORD("A") );
            DEC( DriveNumber );
            PathOut[1] := CHR(DriveNumber);
OS2>*)
            ConcatS(      PathOut, ":\" );
            ConcatLS(     PathOut, s );
            RETURN;
        ELSE
            Copy( DefaultPath, WorkPath );  (* Otherwise take caller default *)
        END;
    END;

    (* Get the disc name, substituting default name if none found. *)

    ExtractDeviceName( WorkPath, PathOut, PathIndex );
    IF (PathIndex > LengthOf(WorkPath)) THEN (* Drive but no dir? *)
        SetString(WorkPath,".\");            (* That means <Current dir> *)
        PathIndex := 1;
    END;

    (* See if we start at the root with "\" or not. *)

    IF (WorkPath[PathIndex] <> PathDelimiter) THEN
        Drive := PathOut[1];           (* Get drive. *)
        DEC( Drive, ORD("@") );
        AS    := ADR(s);
(*<DOS*)
        DOSCALL( DefaultDir, Drive, AS, Result );
        IF (Result = 15) THEN
            s[0] := 0C;
        END;
(*DOS>*)
(*<OS2
        PathBufSize := SIZE(s);
        err := DosQCurDir(0, AS, PathBufSize);
        IF (err <> 0) THEN
            s[0] := 0C;
        END;
OS2>*)
        TStringToLString( s, s );
        SetString( DirectoryStack, PathDelimiter );
        ConcatLS(  DirectoryStack, s );
        IF (DirectoryStack[ ORD(DirectoryStack[0]) ] = PathDelimiter) THEN
            DEC( DirectoryStack[ 0 ] ); (* One fewer bytes. *)
        END;
    ELSE
        SetLengthOf(DirectoryStack,0);
    END;

    (* Put a '\' at the end of work path to stop us.  Its ok if this is
       redundant.
    *)

    ConcatS( WorkPath, PathDelimiter );

    (* Now examine each fragment of the passed path and managing it on the
       stack of directory entries.  This allows ".." to be popped off the
       directory list.
    *)
    SetLengthOf(s,0);
    WorkLength := LengthOf(WorkPath);
    WHILE (WorkLength >= PathIndex) DO
        IF (WorkPath[ PathIndex ] = PathDelimiter) THEN
            ManageDirectoryStack( s );
            SetLengthOf(s, 0);
        ELSE
            INC(s[0]);
            s[ ORD(s[0]) ] := WorkPath[ PathIndex ];
        END;
        INC(PathIndex);
    END;

    IF (DirectoryStack[ORD(DirectoryStack[0])] <> PathDelimiter) THEN
        ConcatS( DirectoryStack, PathDelimiter );
    END;

    (* Does the final directory fit? *)

    IF ((LengthOf(PathOut) + LengthOf(DirectoryStack)) <= HIGH(PathOut)) THEN
        ConcatLS( PathOut, DirectoryStack );
    ELSE
        Copy(PathIn, PathOut); (* Give them the benefit of the doubt *)
    END;

END ExpandPath;





BEGIN
END Directory.
