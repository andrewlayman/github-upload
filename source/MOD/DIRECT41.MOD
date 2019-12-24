(*----------------------------------------------------------------------------
    MODIFICATION HISTORY

    09/09/87 RSC    Created from the original.  The bulk of the original
                    Direct41 is now in TLDIR411.MOD as an overlay.
     1/22/88 RSC    call tldir411 through tlfbase.
    02-Mar-88 LAA   TLFBASE is not allowed in the reserve layer.
   19-Apr-90 KKC    Grouped year, month, day, hour, minute into one
                    date structure, ATimeInfo. 
    21-Feb-91 RSC   Call TLDIR411 directly rather than through TLFBASE.

----------------------------------------------------------------------------*)

    (*****************************************************************)
    (*                                                               *)
    (*    Direct411.                                                 *)
    (*                                                               *)
    (*    Give directory assistance by calling the overlay TLDIR411  *)
    (*    which will request files from the customer via forms and   *)
    (*    a directory list.                                          *)
    (*                                                               *)
    (*****************************************************************)

IMPLEMENTATION MODULE Direct411;


FROM Directory              IMPORT
        (* CONST *)             MaximumFileNameLength, MaximumExtensionLength,
                                MaximumDeviceNameLength, MaximumPathNameLength,
        (* TYPES *)             AFileNameNode, AFileNameRecord,
                                AFileAttributeSet,
        (* PROCS *)             ExtractFileNameParts;

FROM SYSTEM                 IMPORT
        (* TYPE *)              ADR;

FROM LStrings               IMPORT
        (* PROCS *)             TrimRear, Copy, SetString, ConcatS,
                                LengthOf, ConcatLS;

FROM Overlays               IMPORT
        (* PROCS *)             CallOverlayWithContext;

FROM BigTimeU               IMPORT
        (* PROCS *)             BigTimeToTime;

FROM TimeFormat             IMPORT
        (* VARS  *)             DefaultDateAndTimeFormat,
        (* PROCS *)             TimeToString;

FROM Timei                  IMPORT
        (* TYPE *)              ATimeInfo;

FROM Kbio                   IMPORT
        (* TYPE *)              ascreeny;




PROCEDURE FileNameToRecord( VAR PathIn, NameIn : ARRAY OF CHAR;
                            VAR Record         : AFileNameRecord );
VAR
    s : ARRAY [0..99] OF CHAR;
BEGIN
    Copy(PathIn, s);
    IF (s[ORD(s[0])] <> "\") THEN
        ConcatS(s,"\");
    END;
    ConcatLS(s,NameIn);
    WITH Record DO
        ExtractFileNameParts( s, Device, Path, FileName, Extension );
    END;
END FileNameToRecord;





PROCEDURE RecordToFileName( VAR Record           : AFileNameRecord;
                            VAR PathOut, NameOut : ARRAY OF CHAR    );
VAR
BEGIN
    WITH Record DO
        Copy(     Device,   PathOut );
        ConcatLS( PathOut,  Path );
        Copy(     FileName, NameOut );
        IF (LengthOf(NameOut) > 0) THEN
            ConcatS(  NameOut,  "." );
            ConcatLS( NameOut,  Extension );
        END;
    END;
END RecordToFileName;



PROCEDURE DoFileAccess(     Function         : AnAssistanceFunction;
                        VAR PathIn,
                            NameIn,
                            PathOut,
                            NameOut          : ARRAY OF CHAR;
                            AllowWildcardsIn,
                            GiveAssistanceIn : BOOLEAN   ) : BOOLEAN;
VAR
    TLDir411Interface : ATLDir411Interface;
    s                 : ARRAY [0..29] OF CHAR;
BEGIN
    WITH TLDir411Interface DO
         FileNameToRecord( PathIn, NameIn, FileNameIn );

         AllowWildcards  := AllowWildcardsIn;
         GiveAssistance  := GiveAssistanceIn;

         WhichFunction   := Function;
         ProcedureReturn := FALSE;
    END;

    SetString(s,"TLDIR411");    (* 21-Feb-91 RSC  *)
    IF (NOT CallOverlayWithContext( s, ADR( TLDir411Interface ) ) ) THEN
        RETURN FALSE;
    END;

    WITH TLDir411Interface DO
        IF (ProcedureReturn) THEN
            RecordToFileName( FileNameOut, PathOut, NameOut );
        END;
        RETURN ProcedureReturn;
    END;

END DoFileAccess;





  (* Get Input File - get a filename from the customer.

      Preconditions  - PathIn          default path for customer
                       FileNameIn      default filename, incl. wildcards.
                       AllowWildcards  do you allow wild file names?
                       GiveAssistance  offer directory assistance?

      Postconditions - PathOut         entered/chosen path
                       FileNameOut        "       "   filename, possibly
                                            with wildcards if allowed.
                       RETURN          FALSE iff <ESC> hit.
  *)
PROCEDURE GetInputFile( VAR PathIn,
                            NameIn,
                            PathOut,
                            NameOut          : ARRAY OF CHAR;
                            AllowWildcardsIn,
                            GiveAssistanceIn : BOOLEAN   ) : BOOLEAN;
BEGIN
    RETURN DoFileAccess( AccessForm,
                         PathIn,
                         NameIn,
                         PathOut,
                         NameOut,
                         AllowWildcardsIn,
                         GiveAssistanceIn );
END GetInputFile;








  (* Get Output File - get a filename from the customer suitable for output.

      Preconditions  - PathIn          default path for customer
                       FileNameIn      default filename, incl. wildcards.
                       GiveAssistance  offer directory assistance?

      Postconditions - PathOut         entered/chosen path
                       FileNameOut        "       "   filename
                       RETURN          FALSE iff <ESC> hit.
  *)
PROCEDURE GetOutputFile( VAR PathIn,
                            NameIn,
                            PathOut,
                            NameOut          : ARRAY OF CHAR;
                            GiveAssistanceIn : BOOLEAN   ) : BOOLEAN;
BEGIN
    RETURN DoFileAccess( ExportForm,
                         PathIn,
                         NameIn,
                         PathOut,
                         NameOut,
                         FALSE,
                         GiveAssistanceIn );
END GetOutputFile;




  (* DontAllowZero - Disallow a zero length schedule from being selected
     4/11/89 WKH
  *)
PROCEDURE DontAllowZero( FileNameRecord : AFileNameRecord ) : BOOLEAN;

VAR

BEGIN
    IF (FileNameRecord.Size > 0) THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END DontAllowZero;


 (* Always Approve - Always approve a file selection. *)

PROCEDURE AlwaysApprove ( FileNameRecord : AFileNameRecord ) : BOOLEAN;
BEGIN
    RETURN TRUE;
END AlwaysApprove;







    (*****************************************************************)
    (*                                                               *)
    (*    Direct411.                                                 *)
    (*                                                               *)
    (*    Give directory assistance by putting a menu of project     *)
    (*    names on the screen and allowing the user to select one.   *)
    (*    The project name chosen is returned in FileName.           *)
    (*    The FileName passed on input is the first one displayed.   *)
    (*        The Qualification Procedure will be called for         *)
    (*    each matching name.  Only approved names will be placed    *)
    (*    on the list.                                               *)
    (*                                                               *)
    (*****************************************************************)

    (*  Input: FirstRow, LastRow : Rows to use for display.
               Title             : Caption for box, and for Help.
               Template          : Device:\Directory\filename.ext mask.
               FileName          : Name to highlight if on list.
               Qualifies         : Check for approved files.

        Output:Template          : The actual file name and extension,
                                   preceded by the device and directory.
               FileName          : The time of last update to the file.
                                   DD-MMM-YY HH:MMam

         Returns TRUE iff a file name was chosen.

        CAUTION:  Both Template and FileName are both input and output!

    *)

PROCEDURE GiveDirectoryAssistance ( FirstRow,
                                    LastRow       : ascreeny;
                                    VAR TitleIn,
                                        Template,
                                        FileName  : ARRAY OF CHAR;
                                        Qualifies : AQualificationProcedure
                                  ):BOOLEAN;
VAR
    TimeInfo          : ATimeInfo;
    TLDir411Interface : ATLDir411Interface;
    s                 : ARRAY [0..MaximumDeviceNameLength
                                + MaximumPathNameLength  ] OF CHAR;
    s1                : ARRAY [0..MaximumPathNameLength  ] OF CHAR;
    s2                : ARRAY [0..MaximumFileNameLength
                            + 1 + MaximumExtensionLength ] OF CHAR;
    s3                : ARRAY [0..MaximumExtensionLength ] OF CHAR;
BEGIN
    ExtractFileNameParts( Template, s, s1, s2, s3 );
    ConcatLS(s ,s1);
    ConcatS (s2,".");
    ConcatLS(s2,s3);

    WITH TLDir411Interface DO
         FileNameToRecord( s, s2, FileNameIn );

         Qualification   := Qualifies;
         FirstY          := FirstRow;
         LastY           := LastRow;

         Copy( TitleIn,  Title );
         Copy( FileName, CursorName );

         AllowWildcards  := TRUE;
         GiveAssistance  := FALSE; (* from the access form *)

         WhichFunction   := DirectoryAssistance;

         ProcedureReturn := FALSE;
    END;

    SetString(s,"TLDIR411");    (* 21-Feb-91 RSC  *)
    IF (NOT CallOverlayWithContext( s, ADR( TLDir411Interface ) ) ) THEN
        RETURN FALSE;
    END;

    WITH TLDir411Interface DO
        IF (ProcedureReturn) THEN
            RecordToFileName( FileNameOut, Template, s2 );
            ConcatLS(Template, s2);
            BigTimeToTime
            (
                FileNameOut.TimeStamp,
                TimeInfo.tiYear,
                TimeInfo.tiMonth,
                TimeInfo.tiDay,
                TimeInfo.tiHour,
                TimeInfo.tiMinute,
                TimeInfo.tiSecond
            );
            TimeToString( TimeInfo, DefaultDateAndTimeFormat, FileName );
        END;
        RETURN ProcedureReturn;
    END;

END GiveDirectoryAssistance;


BEGIN
END Direct411.
