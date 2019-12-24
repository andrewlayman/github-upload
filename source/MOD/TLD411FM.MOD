MODULE TLD411FM;

(*  =========================================================================
    Last Edit : June 25, 1991 11:58AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        TLDir411's forms.


    MODIFICATION HISTORY:

        21-Feb-91 RSC  First Version, from TLDir411.  This
                       makes TLDir411 not dependant on TLFBase, which is
                       important because TLGETIT, which shares the same
                       reserved overlay layer as TLFBASE, passes TLDir411
                       a procedure to call in him.  Also, this makes TLDir411
                       smaller, which is nice because it does NOT go into the
                       reserved layer.

        25-Jun-91 RSC  Moved some stack items onto global memory.  This will
                       cut down on stack usage, which can be precious when
                       we are saving a note text from within macros or
                       some other very nested function.  See bug 4600.

    =========================================================================
*)

FROM Codes                  IMPORT ACode;

FROM Dir411                 IMPORT
    (* TYPE *)                  AnOverlayContext,
                                AGiveDirectoryAssistanceProc;

FROM FormCon                IMPORT AFieldNo;

FROM Forms                  IMPORT AForm, ACheckReason, AFieldValue,
                                   ACursorAttribute, AStringValue,
                                   HighlightField, ShowValue,
                                   DoForm, NullCheckProc, SetFieldProtection;

FROM Dialog                 IMPORT Message, Burp, Error, ProgressBox,
                                   Barf, ContinuationBox, ABoxHandle,
                                   ReleaseBox,
                                   WarningBox, ADialogOption, FatalError;

FROM Direct411              IMPORT
        (* TYPES *)             AnAssistanceFunction, ATLDir411Interface,
                                AQualificationProcedure,
        (* PROCS *)             AlwaysApprove;

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

FROM LStrings               IMPORT SetString, ConcatS, ConcatLS, SubStr,
                                   StringsEqual, CtoS, Fill, Insert, TrimRear,
                                   TrimFront, Procustes, Remove, Search,
                                   LengthOf, SetLengthOf, Upshift, Copy,
                                   Compare, RJust, LStringToTString;

FROM MsgFile                IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM Overlays               IMPORT
    (* PROC *)                  OverlayContext;

FROM SchedLocks             IMPORT
        (* PROC *)              NameAndLockSchedule;

FROM Schedule               IMPORT
    (* VARS *)                  ProjectName, ProjectMedia,
                                CurrentFileExtension;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADR, ADDRESS;



CONST
    ModuleNumber            = 14500;    (* For GetMessage, SAME AS TLDIR411 *)
    ExportFormID            = 28;  (* 11/10/88 WKH *)
    PathFormID              = 17;  (* 11/10/88 WKH *)
    Dot                     = ".";
    IncludingDirectories    = AFileAttributeSet{SubdirectoryAttribute,
                                                ReadOnlyAttribute};

VAR
    GiveDirectoryAssistance : AGiveDirectoryAssistanceProc;




PROCEDURE ContainsWildCard( VAR Name : ARRAY OF CHAR ) : BOOLEAN;
VAR
    i : CARDINAL;
    s : ARRAY [0..1] OF CHAR;
BEGIN
    SetString(s,"*");
    i := Search( Name, s, 1 );
    SetString(s,"?");
    RETURN ( (i <> 0) OR (Search( Name, s, 1 ) <> 0) );
END ContainsWildCard;



(* 25-Jun-91 RSC Package this here, and make its strings global.
*)
VAR
    DoWarningBoxString  : ARRAY [0..255] OF CHAR;
    DoWarningBoxTitle   : ARRAY [0..99]  OF CHAR;

PROCEDURE DoWarningBox( StringMessageNumber,
                        TitleMessageNumber  : CARDINAL );
BEGIN
    GetMessage( StringMessageNumber, DoWarningBoxString );
    GetMessage( TitleMessageNumber,  DoWarningBoxTitle  );

    WarningBox( DoWarningBoxString, DoWarningBoxTitle, NoHelp );

END DoWarningBox;

PROCEDURE DoContinuationBox( StringMessageNumber,
                             TitleMessageNumber  : CARDINAL ) : BOOLEAN;
BEGIN
    GetMessage( StringMessageNumber, DoWarningBoxString );
    GetMessage( TitleMessageNumber,  DoWarningBoxTitle  );

    RETURN ContinuationBox( DoWarningBoxString, DoWarningBoxTitle, OfferHelp );

END DoContinuationBox;





  (* Edit the file name entered on a form. *)

PROCEDURE EditFileName( VAR Name           : ARRAY OF CHAR;
                            AllowWildcards : BOOLEAN       ) : BOOLEAN;
VAR
    i : CARDINAL;
    s : ARRAY [0..1] OF CHAR;
BEGIN
    TrimFront(Name);
    TrimRear(Name);
    SetString(s,Dot);
    i := Search( Name, s, 1 );
    IF (i > 0) THEN  (* extension? *)
        IF (i = 1)                      OR   (* Dot first (or only) byte? *)
           (Search( Name, s, i+1 ) > 0) THEN (* Another dot? *)
            DoWarningBox( ModuleNumber+15, ModuleNumber+16 );
               (* "Illegal filename" *)
               (* "filename AFU" *)
            RETURN FALSE;
        END;
    END;
    IF (NOT AllowWildcards) THEN
        IF ( ContainsWildCard( Name ) ) THEN
            DoWarningBox( ModuleNumber+17, ModuleNumber+16 );
              (* "wildcards not allowed" *)
              (* "filename AFU" *)
            RETURN FALSE;
        END;
    END;
    RETURN TRUE;
END EditFileName;




 (* Verify File Exists - Insure that the file name passed exists. *)

VAR
    VerifyFileExistsFile       : File;
    VerifyFileExistsFileString : ARRAY [0..199] OF CHAR;

PROCEDURE VerifyFileExists( VAR FileName : ARRAY OF CHAR ) : BOOLEAN;
BEGIN
    LStringToTString(FileName,VerifyFileExistsFileString);
    PrepareForIO(VerifyFileExistsFile);
    Lookup( VerifyFileExistsFile, VerifyFileExistsFileString, FALSE );

    IF (CheckIO(VerifyFileExistsFile) <> done) THEN
        Close(VerifyFileExistsFile);

        DoWarningBox( ModuleNumber+20, ModuleNumber+21 );
            (* "No file by that name" *)
            (* "File doesn't Exist!" *)
        RETURN FALSE;
    END;
    Close(VerifyFileExistsFile);

    RETURN TRUE;

END VerifyFileExists;






 (* Verify File Clean - Insure that the file name passed either does NOT
                        exist or the customer has said that that is ok.
 *)
VAR
    VerifyFileCleanGlobals : RECORD
        Attribute       : AFileAttributeSet;
        ReturnName      : ARRAY [0..127] OF CHAR;
        TempExt         : ARRAY [0..2]   OF CHAR;
        PName           : ARRAY [0..99]  OF CHAR;
        FName           : ARRAY [0..12]  OF CHAR;
        Ext             : ARRAY [0..3]   OF CHAR;
    END;

PROCEDURE VerifyFileClean( VAR FileName : ARRAY OF CHAR ) : BOOLEAN;
BEGIN
        (* 14-Sep-90 RSC was hardcoded. *)

    TrimRear(ProjectName);

    WITH VerifyFileCleanGlobals DO
        SetLengthOf(TempExt, 2);
        TempExt[1] := CurrentFileExtension[2]; (* ".4T0" *)
        TempExt[2] := CurrentFileExtension[3];

        Attribute := IncludingDirectories;

        IF (NOT DirectoryIsReachable (FileName)) THEN

            DoWarningBox( ModuleNumber+11, ModuleNumber+12 );
             (* "No such directory" *)
             (* "Can't find it" *)
            RETURN FALSE;

        ELSIF ((Search(FileName, TempExt, 1) > 0) AND
               (LengthOf(ProjectName) = 0)) THEN

            ExtractFileNameParts(FileName, ReturnName, PName, FName, Ext); (* 4/18/89 WKH *)
            ConcatLS(ReturnName, PName);

            ConcatS(FName, ".");
            ConcatLS(FName, Ext);

            RETURN NameAndLockSchedule(ReturnName, FName);

        ELSIF (FileLookupStart (FileName, ReturnName, Attribute)) THEN

            RETURN DoContinuationBox( ModuleNumber+18, ModuleNumber+19 );
              (* "Found a file, go ahead anyway?" *)
              (* "File Exists!" *)
        END;
    END;

    RETURN TRUE;

END VerifyFileClean;






PROCEDURE PathCheck(    Form                : AForm;
                        FieldNo             : AFieldNo;
                    VAR FormValue           : ARRAY OF AFieldValue;
                        Reason              : ACheckReason;
                    VAR Code                : CARDINAL)
                                                       : BOOLEAN;
CONST
    TopY    = 2;

VAR
    i,
    ExtField,
    FileField,
    PathField  : CARDINAL;
    BottomY    : CARDINAL;
    FileRecord : AFileNameRecord;
    ok         : BOOLEAN;
    s          : ARRAY [0..255] OF CHAR;
    DefaultFN,
    DefaultExt,
    Title      : ARRAY [0..39]  OF CHAR;
    TempExt    : ARRAY [0..3] OF CHAR;

    PROCEDURE Squish( VAR s : ARRAY OF CHAR );
    VAR
        i,
        Loop : CARDINAL;
    BEGIN
        i := 0;
        FOR Loop := 1 TO ORD(s[0]) DO
            IF (s[Loop] <> " ") THEN
                INC(i);
                IF (i <> Loop)  THEN
                    s[i] := s[Loop];
                END;
            END;
        END;
        SetLengthOf(s,i);
        ShowValue( Form, FieldNo, FormValue );
    END Squish;

BEGIN                       (* PathCheck *)
    Code := 0;

    BottomY := maxrow - 6;      (* 21-Sep-89 WKH  *)

    Squish( FormValue[FieldNo].CharValue^ );

    (* This check proc is used for two forms.  The main difference is that
       one form has field 0 being the path, the other has field 2 the path.
       we differentiate by the REAL VALUE.
    *)
    PathField := TRUNC(FormValue[ 0 ].RealValue);
    ExtField  := 1; (* Always *)
    IF (PathField = 0) THEN
        FileField := 1;
    ELSE
        FileField := 0;
    END;

    IF (Reason = CheckFieldEntry) THEN
        IF (FileField <> ExtField) THEN  (* 11/15/88 WKH *)
                (* 14-Sep-90 RSC was hardcoded. *)

            SetLengthOf(TempExt, 2);
            TempExt[1] := CurrentFileExtension[2]; (* ".4T0" *)
            TempExt[2] := CurrentFileExtension[3];

            IF (Search(FormValue[ExtField].CharValue^, TempExt, 1) = 1) THEN
                SetFieldProtection(Form, ExtField, FormValue, TRUE);
            ELSE
                    (* 14-Sep-90 RSC Make "4M0" from ".4T0" *)
                Copy( CurrentFileExtension, TempExt );
                Remove( TempExt, 1, 1 );
                TempExt[2] := "M";  (* 23-Oct-90 RSC  *)

                IF (Search(FormValue[ExtField].CharValue^, TempExt, 1) = 1) THEN
                    SetFieldProtection(Form, ExtField, FormValue, TRUE);
                END;
            END;
        END;
        RETURN TRUE;
    ELSIF (Reason = CheckFieldKey) THEN
        IF (FormValue[ PathField ].CardValue > 0) THEN (* GiveAssistance? *)
            HighlightField(Form,FormValue,FieldNo, CursorResting );
            WITH FormValue[ PathField ] DO
                SetLengthOf(DefaultFN, 0);
                ExpandPath( CharValue^, DefaultFN, s );
                IF (NOT DirectoryIsReachable(s)) THEN  (* Current dir invalid? *)
                    ExpandPath( DefaultFN, DefaultFN, s );
                    IF (NOT DirectoryIsReachable(s)) THEN  (* DK: bad? *)
                        SetString( s, "A:\" );
                    END;
                END;
                WITH FileRecord DO
                    ExtractDeviceName( s, Device, i );
                    SubStr( s, Path, i, ORD(s[0]) - i + 1 );
                    IF (FileField = ExtField) THEN
                        ExtractFileNameParts( FormValue[FileField].CharValue^, s, s,
                                              FileName,
                                              Extension );
                    ELSE
                        Copy(FormValue[FileField].CharValue^,FileName);
                        Copy(FormValue[ ExtField].CharValue^,Extension);
                    END;
                    Copy(Extension,DefaultExt);
                    Copy(FileName, DefaultFN);
                    SetString(FileName,"*");
                    IF (LengthOf(Extension)=0) THEN
                        SetString( Extension, "*" )
                    END;
                END;

                GetMessage( ModuleNumber + 0, Title );

                IF (NOT GiveDirectoryAssistance( TopY, BottomY, Title,
                                                 FileRecord,
                                                 DefaultFN, (* CURSOR NAME *)
                                                 AlwaysApprove, FALSE, FALSE )) THEN
                    HighlightField(Form,FormValue,FieldNo, CursorOff );
                    RETURN FALSE;
                END;
                WITH FileRecord DO
                    TrimRear( FileName  );
                    TrimRear( Extension );
                    SetString( s, "*" );
                    IF (LengthOf(   FileName ) = 0)  OR
                       (StringsEqual( s, FileName )) THEN
                        Copy( DefaultFN, FileName );
                    END;
                    IF (LengthOf( Extension ) = 0) THEN
                        Copy( DefaultExt, Extension );
                    END;
                    Copy( Device, CharValue^ );
                    ConcatLS( CharValue^, Path );
                    SetLengthOf(    FormValue[ ExtField].CharValue^, 0 );
                    Copy( FileName, FormValue[FileField].CharValue^ );
                    IF (FileField = ExtField)  AND  (LengthOf(Extension) > 0) THEN
                        ConcatS( FormValue[FileField].CharValue^, Dot );
                    END;
                    ConcatLS( FormValue[ExtField].CharValue^, Extension );
                    ShowValue( Form, FileField, FormValue );
                    ShowValue( Form,  ExtField, FormValue );
                    ShowValue( Form, PathField, FormValue );
                END;
            END;
            HighlightField(Form,FormValue,FieldNo, CursorOff );
            RETURN TRUE;
        ELSE
            Burp;
            RETURN FALSE; (* No assistance possible *)
        END;
    ELSIF (Reason = CheckFormExit)  AND  (FieldNo = 0)  THEN
        IF (
             ( FormValue[ PathField ].CardValue > 0 )
               AND
             ( ContainsWildCard( FormValue[ FileField ].CharValue^ ) )
           ) THEN
            WITH FileRecord DO
                SetLengthOf(DefaultFN, 0);
                ExpandPath( FormValue[ PathField ].CharValue^, DefaultFN, s );
                ExtractDeviceName( s, Device, i );
                SubStr( s, Path, i, ORD(s[0]) - i + 1 );
                IF (FileField = ExtField) THEN
                    ExtractFileNameParts( FormValue[FileField].CharValue^, s, s,
                                          FileName,
                                          Extension );
                ELSE
                    Copy(FormValue[FileField].CharValue^,FileName);
                    Copy(FormValue[ ExtField].CharValue^,Extension);
                END;
                Copy(Extension,DefaultExt);
                Copy(FileName, DefaultFN);
                IF (LengthOf(Extension)=0) THEN
                    SetString( Extension, "*" )
                END;

                GetMessage( ModuleNumber + 0, Title );

                IF (NOT GiveDirectoryAssistance( TopY, BottomY, Title,
                                                 FileRecord,
                                                 DefaultFN, (* CURSOR NAME *)
                                                 AlwaysApprove, FALSE, FALSE )) THEN
                    RETURN FALSE;
                END;
                TrimRear( FileName  );
                TrimRear( Extension );
                SetString( s, "*" );
                IF (LengthOf(   FileName ) = 0)  OR
                   (StringsEqual( s, FileName )) THEN
                    Copy( DefaultFN, FileName );
                END;
                IF (LengthOf( Extension ) = 0) THEN
                    Copy( DefaultExt, Extension );
                END;
                Copy( Device, FormValue[ PathField ].CharValue^ );
                ConcatLS( FormValue[ PathField ].CharValue^, Path );
                SetLengthOf( FormValue[ ExtField].CharValue^, 0 );
                Copy( FileName, FormValue[FileField].CharValue^ );
                IF (FileField = ExtField)  AND  (LengthOf(Extension) > 0) THEN
                    ConcatS( FormValue[FileField].CharValue^, Dot );
                END;
                ConcatLS( FormValue[ExtField].CharValue^, Extension );
                ShowValue( Form, FileField, FormValue );
                ShowValue( Form,  ExtField, FormValue );
                ShowValue( Form, PathField, FormValue );
            END;
        END;
        WITH FormValue[ PathField ] DO
            TrimRear( CharValue^ );
            TrimRear( FormValue[ FileField ].CharValue^ );
            IF (LengthOf( CharValue^ ) = 0) OR
               (LengthOf( FormValue[ FileField ].CharValue^ ) = 0) THEN
                RETURN ((FormValue[FileField].CardValue <> 0) AND
                        (PathField = 0));
                    (* Wildcards ok AND Access form, OK; export form:NO! *)
            END;
            SetLengthOf( DefaultFN, 0 );
            ExpandPath(CharValue^, DefaultFN, s );
        END;
        ConcatLS( s, FormValue[FileField].CharValue^ );
        IF (FileField=ExtField) THEN
            (* Return true if wildcards allowed or if file is there. *)

            WITH FormValue[FileField] DO
                ok := (EditFileName( CharValue^, (CardValue <> 0) ));
                ok := (ok AND
                      ((CardValue <> 0) OR (VerifyFileExists(s))));
                RETURN ok;
            END;
        ELSE
            ConcatS ( s, Dot );
            ConcatLS( s, FormValue[ExtField].CharValue^ );
            WITH FormValue[FileField] DO
                ok := (EditFileName( CharValue^, (CardValue <> 0) ));
                ok := (ok AND VerifyFileClean(s));
                RETURN ok;
            END;
        END;
    ELSIF (Reason <> CheckFieldChange) THEN
        RETURN TRUE;
    END;

    WITH FormValue[FieldNo] DO
        TrimFront( CharValue^ );
        TrimRear(  CharValue^ );
        IF (LengthOf(CharValue^) > 0) THEN
            IF (FieldNo = PathField) THEN
                SetLengthOf(Title,0);
                ExpandPath( CharValue^, Title, s );
                IF (NOT DirectoryIsReachable(s)) THEN
                    DoWarningBox( ModuleNumber+11, ModuleNumber+12 );
                         (* "No such directory" *)
                         (* "Can't find it" *)
                    RETURN FALSE;
                END;
            ELSE
    (* KKC Aug 30,89 - Allow wildcards for file name and extension *)
                IF (NOT EditFileName( CharValue^, TRUE)) THEN
                    RETURN FALSE;
                END;
            END;
        END;
    END;

    ShowValue( Form, FieldNo, FormValue );

    RETURN TRUE;

END PathCheck;



CONST
    MaxFieldsOnForm   =  2;  (* 0..this *)

VAR
    FormValue         : ARRAY [0..MaxFieldsOnForm] OF AFieldValue;
    StringValue       : ARRAY [0..MaxFieldsOnForm] OF AStringValue;
    FileFormTempString: ARRAY [0..99]              OF CHAR;

  (* DoAFileForm - Handle one of the two forms for filing.  They are almost
                   the same but the field layout is different.
  *)
PROCEDURE DoAFileForm( VAR FileNameRecord : AFileNameRecord;
                           AllowWildcards,
                           GiveAssistance : BOOLEAN;
                           FileNameField,
                           ExtensionField,
                           PathField,
                           FormNumber     : CARDINAL  ): ACode;

VAR
    Code              : ACode;
    i                 : CARDINAL;
    TempExt           : ARRAY [0..3] OF CHAR;
    DotExists         : BOOLEAN;

BEGIN    (* DoExportForm *)

    FOR i := 0 TO MaxFieldsOnForm DO
        FormValue[i].CharValue := ADR(StringValue[i]);
    END;

    FormValue[ 0 ].RealValue := FLOAT( PathField ); (* For check proc *)

    WITH FormValue[ FileNameField ] DO
        Copy(FileNameRecord.FileName, CharValue^ );

        CardValue := ORD( AllowWildcards );  (* Save for check proc. *)
    END;

    WITH FormValue[ ExtensionField ] DO
        IF (FileNameField = ExtensionField) THEN
            IF (AllowWildcards) AND (LengthOf(CharValue^) = 0) THEN
                ConcatS( CharValue^, "*" );
            END;
            ConcatS(  CharValue^, Dot );
            ConcatLS( CharValue^, FileNameRecord.Extension );
        ELSE
            Copy( FileNameRecord.Extension, CharValue^ );
        END;
    END;

    WITH FormValue[ PathField ] DO
        Copy( FileNameRecord.Device, CharValue^ );
        ConcatLS( CharValue^, FileNameRecord.Path );
        SetLengthOf( FileFormTempString, 0 );
        ExpandPath( CharValue^, FileFormTempString, CharValue^ );

        CardValue := ORD( GiveAssistance );  (* Save for check proc. *)
    END;

    Code := DoForm(0, 0, maxcol, GanttWEnd, FormNumber,
                   TRUE, FormValue, PathCheck);

    IF (Code <> CancelKey) THEN
        WITH FileNameRecord DO
            WITH FormValue[ ExtensionField ] DO                   (* 23-Aug-89 LAA *)
                IF (FileNameField <> ExtensionField) THEN
                    Copy(CharValue^, Extension);
                END;
            END;
            WITH FormValue[ FileNameField ] DO
                TrimRear( CharValue^ );
                IF (LengthOf(CharValue^) = 0) THEN
                    SetLengthOf(FileName, 0);
                    SetLengthOf(Extension,0);
                ELSIF (FileNameField = ExtensionField) THEN
                    SetString(FileFormTempString,Dot);
                    DotExists := (Search(CharValue^, FileFormTempString, 1) > 0);
                    ExtractFileNameParts( CharValue^,
                                          FileFormTempString,
                                          FileFormTempString,
                                          FileName,
                                          TempExt );
                    IF (DotExists) THEN
                        Copy( TempExt, Extension );
                    END;
                ELSE
                    Copy( CharValue^, FileName );
                END;
            END;
            WITH FormValue[ PathField ] DO
                IF (LengthOf(CharValue^) = 0) THEN
                    SetLengthOf(Device, 0);
                    SetLengthOf(Path,   0);
                ELSE
                    SetLengthOf(FileFormTempString,0);
                    ExpandPath( CharValue^, FileFormTempString, CharValue^ );
                    ExtractDeviceName( CharValue^, Device, i );
                    SubStr( CharValue^, Path, i, ORD(CharValue^[0]) - i + 1 );
                    TrimRear(Path);
                END;
            END;
        END;
    END;

    RETURN Code;

END DoAFileForm;







(*PROCEDURE DoTLD411FM();*)
VAR
    Context : POINTER TO AnOverlayContext;
BEGIN
    Context := OverlayContext();
    WITH Context^ DO
        GiveDirectoryAssistance := DirectoryAssistanceProc;
        
        IF (DoPathForm) THEN
            ReturnValue := DoAFileForm( TheFileNameRecordPtr^,
                                        DoWeAllowWildcards,
                                        DoWeGiveAssistance,
                                        1,   (* File Name Field *)
                                        1,   (* Extension field *)
                                        0,   (* Path field *)
                                        PathFormID );  (* 11/10/88 WKH *)
        ELSE
            ReturnValue := DoAFileForm( TheFileNameRecordPtr^,
                                        DoWeAllowWildcards,
                                        DoWeGiveAssistance,
                                        0,   (* File Name Field *)
                                        1,   (* Extension field *)
                                        2,   (* Path field *)
                                        ExportFormID );  (* 11/10/88 WKH *)
        END;
    END;

END TLD411FM.

