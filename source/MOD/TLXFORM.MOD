MODULE TLXForm;

    (* TL X Form  - This module runs the form that builds the table used
                    to drive the exporters.  This table has a series of
                    "Front Ends", or kinds of data, and one "Back End", or
                    kind of output.

          RSC  6/7/88   - Initial version.
          WKH  11/14/88 - Added a ShowValue of the filename fields whenever
                          we select a new export format.  This is so that any
                          overlapping helptext will be removed.
          18-Nov-88 LAA   In BuildFormRecord, took the form record off of the
                          stack, and allocated it off of the heap.  In spite
                          of the check for stack space in Overlays, having
                          this large a stack variable would sometimes cause
                          a stack overflow.
           2-Jan-89 RSC   Added references to StringsEqual() rather than Compare().
           2-Feb-89 EGK   Removed "patch" in AjustPath.  Added GetStartupName
                          procedure to get the name of an overlay to run before
                          exporting begins (to allow back ends to set up
                          parameters).
           2-Mar-89 AJL   Use MinIndex within FindFieldXY so that we don't
                          crash with range errors on the string fields.
          23-Mar-89 RSC   Upgrade for "Better Reports".
           3-Apr-89 LAA   XPort for was crashing because the "first" column
                          of back ends had been hard-coded as 0, but was
                          changed to 1 to conform to other columns.
          12-Apr-89 EGK   Replaced calls to ColumnHeadings with calls to
                          GetBEndInfo for each data item needed.  Removed
                          GetStartupName, since GetBEndInfo can give us the
                          same information now.
          13-Apr-89 EGK   For Andrew's change of 2-Mar-89, changed offset
                          between the beginning of the string fields
                          (now 1, not 0) and the file extensions.
          24-Apr-89 AJL   Highlight the table names as captions on the form
                          as we move over the form.
          28-Jun-89 MWP   On form entry setup, we are using an uninitialized
                          variable, Column, to decide whether Extension
                          field is protected or not. Kind of incorrect.
           1-Jul-89 MWP   If the file format field is empty, place a message
                          to the user.
          09-Aug-89 KKC   Add copyright message.
          20-Aug-89 MWP   Large amount of changes to accomodate new Export
                          form.
          23-Aug-89 MWP   Fixed not displaying the file extension after file
                          format change.
           4-Sep-89 MWP   Fixed bug where default xtab file names where not
                          being displayed.
           7-Sep-89 MWP   Set default file format to 123 V 2.
          11-Sep-89 MWP   Set XTAB defaults to not displayed.
          12-Sep-89 MWP   If export format is plain CSV, make sure that
                          Is Importable flag is set to No. Vice versa also.
          14-Sep-89 EGK   Added HoldInConfig to the HoldTypeSet.
          25-Sep-89 MWP   Added constants to make handling file formats
                          a little clearer.
          30-Nov-89 MWP   Fixed bug caused by on form exit, if we tested
                          the Dir entry before the files entry, we would
                          automatically overwrite any existing files without
                          informing the  user that we were going to.
          19-Jan-90 WKH   Import GetMessageWord from MsgFileAux instead of
                          RptCommon.
          23-Jan-91 RSC   Put Holder item in FlexStor.
           9-Apr-91 RSC   Removed unused imports.
          24-Apr-91 TGS   Moved XTab exports to own form; added new tables to
                          export.
          24-Jul-91 TGS   Love those literals. Replace these with the CONST
                          names that they should have been in the first place.
          11-Sep-91 LAA   Changed DisplayOverwriteMessage to keep track of
                          whether it's been called or not, and therefore only
                          ask the user once.
    *)

FROM BEndColumns    IMPORT
    (* PROC *)          CreateBEndColumnsTree, DisposeBEndColumnsTree,
                        PickBEndColumn,        SearchForBEndColumn;

FROM BEndFormat     IMPORT
    (* PROC *)          GetBEndInfo;

FROM Boxes          IMPORT
    (* TYPE *)          ABoxAttribute, ABoxType;

FROM Captions       IMPORT
    (* TYPE *)          AColumnInfoChoice, AColumnDataRecord;

FROM Dialog         IMPORT
    (* TYPE *)           ADialogOption,
    (* PROCS *)          Burp, Error, FatalError,
                         MultipleChoiceBox, Message;

FROM Directory      IMPORT
    (* TYPE *)           AFileNamePart, ASetOfFileNameParts,
    (* PROCS *)          NormalizeFileName, DirectoryIsReachable,
                         ExpandPath;

FROM FileAux        IMPORT
                            PrepareForIO, CheckIO;

FROM FileSystem     IMPORT
                            File, Close, Lookup, Response;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle, AnExtStoragePreference,
    (* PROC *)              CreateExtObjectWithSize, GetExtData,
                            SetExtData;

FROM Forms          IMPORT
        (* TYPE *)       AFieldValue, AForm, ACheckReason, AStringValue,
        (* PROCS *)      DoForm, ShowValue, SetFieldProtection,
                         SetFieldHidden;

FROM FormCon        IMPORT
    (* TYPE *)          AFieldType, AFieldNo;

FROM Holder       IMPORT
    (* TYPE *)            AHoldType, AHoldTypeSet,
    (* PROC *)            LocateHeldItem, HoldThis, DeleteHeldItem;

(*FROM IntFileIO    IMPORT*)
(*    (* TYPE *)            AFormat;*)

FROM Kbio         IMPORT
    (* TYPE *)            maxcol,
                          maxrow;
FROM Keys         IMPORT
    (* CONST *)           ExitKey, EditKey;

FROM Layout       IMPORT
    (* CONST *)           GanttWStart, GanttWEnd;

FROM LStrings     IMPORT
    (* PROCS *)           TrimFront, SubStr, SetString, ConcatLS,
                          StringsEqual, Overlay, TrimRear, Procustes, LJust,
                          ConcatS, Search, Insert, StoC, Remove, Copy,
                          LengthOf, SetLengthOf, LStringToTString;

FROM MsgFile      IMPORT
    (* PROCS *)           GetMessage;

FROM Overlays     IMPORT
    (* PROC *)            OverlayContext;

FROM PickDirs     IMPORT
        (* PROCS *)      PickDirectory;

FROM MsgFileAux   IMPORT
        (* PROCS *)      GetMessageWord;

FROM Schedule     IMPORT
    (* VAR *)            ProjectMedia;

FROM Space        IMPORT
    (* PROCS *)          Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM       IMPORT
    (* THING *)          TSIZE, ADR, ADDRESS;

FROM XPorTable    IMPORT
        (* TYPES *)      ADriverTable;



CONST
    ModuleNumber            = 24200;
    MAXCARDINAL             = 65535;
    EXPORTFORMID            = 90;


    (*  Our back ends are defined as "columns", but really they aren't.
        These define what we're REALLY using as column definitions.   *)

    ColumnExt               = ColumnFormalName;
    ColumnExtOptional       = ColumnUniqueId;
    ColumnBackEnd           = ColumnHeading1;
    ColumnBackEndContext    = ColumnHeading2;
    ColumnBackEndName       = ColumnName;
    ColumnBackEndStartup    = ColumnNarrowHeading1;


    LinkDataRows            = 8;
    NoYes                   = 0;
    FileName                = 1;
    ColsPerLinkGrp          = 2;
    ShowExtensionOffset     = 16;
    ReImportable            = 17;
    FormatOffset            = 18;
    ExtensionOffset         = 19;
    DirOffset               = 20;
    MaxLinkDataField        = 15;

    ReimportableField       = 17;   (* 24-Jul-91 TGS *)
    ExportFormatField       = 18;

    Lotus1a                 = 1;                                  (* 25-Sep-89 MWP *)
    Lotus2                  = 2;
    Symphony1               = 3;
    Symphony2               = 4;
    Quattro                 = 5;
    Excel                   = 6;
    dBase3                  = 7;
    dBase4                  = 8;
    PlainCSV                = 9;
    TimeLineCSV             = 10;


VAR
    ROWS                    : CARDINAL;
    OverWriteFiles          : BOOLEAN;
    FileDuplicateFldNo      : CARDINAL;
    DirEntryProcessed       : BOOLEAN;



  (* Given a form field no,
     Return a number corresponding to one of my constants, like
     NY or DIR.
  *)
PROCEDURE FieldNumber( FieldNo : AFieldNo ) : CARDINAL;
BEGIN
    IF ( FieldNo <= MaxLinkDataField ) THEN
        RETURN ( FieldNo MOD ColsPerLinkGrp );
    END;

    RETURN (FieldNo);

END FieldNumber;


    (*  OverwriteMessageModule --
        This module emcapsulates the procedure which asks the user if he/she
        wants to overwrite existing export files.  It also contains static
        variables which allow this procedure to be called several times, but
        only show up to the user once.

        ResetOverwriteMessage will re-initialize the module, so that reuse
        of an already loaded overlay will not cause problems.
    *)

MODULE OverwriteMessageModule;

IMPORT          SetLengthOf, GetMessage, ModuleNumber, MultipleChoiceBox,
                OfferHelp, Burp;

EXPORT          DisplayOverwriteMessage, ResetOverwriteMessage;


VAR
    OverwriteOk             : BOOLEAN;


PROCEDURE DisplayOverwriteMessage () : BOOLEAN;

VAR
    Title                   : ARRAY [0..1] OF CHAR;
    Choices                 : ARRAY [0..255] OF CHAR;
    s                       : ARRAY [0..1]   OF CHAR;
    ok                      : BOOLEAN;
    Choice                  : CARDINAL;
    Prefix                  : ARRAY [0..255] OF CHAR;

BEGIN

    IF (NOT OverwriteOk) THEN
        SetLengthOf ( Title, 0 );
        SetLengthOf ( s, 0 );
        GetMessage( ModuleNumber + 51, Prefix ); (* "Some or all of the filenames exist *)
        GetMessage( ModuleNumber + 52, Choices); (* "Proceed, Cancel *)

        Choice := 1; (* Default is Proceed *)

        Burp ();
        OverwriteOk := MultipleChoiceBox( Prefix, Title, OfferHelp, s, 
                                          Choices, Choice);

        IF ( OverwriteOk ) THEN
            OverwriteOk := (Choice = 1);
        END;
    END;

    RETURN OverwriteOk;

END DisplayOverwriteMessage;


PROCEDURE ResetOverwriteMessage();

BEGIN                       (* ResetOverwriteMessage *)
    OverwriteOk := FALSE;
END ResetOverwriteMessage;


BEGIN                       (* OverwriteMessageModule *)
    ResetOverwriteMessage();
END OverwriteMessageModule;




 (* Check The Form - Standard Form Check procedure.

        Complicated by the dynamic nature of the form.
  *)

PROCEDURE CheckTheForm(    Form         : AForm;
                           FieldNo      : AFieldNo;
                       VAR FormValue    : ARRAY OF AFieldValue;
                           CheckReason  : ACheckReason;
                       VAR Code         : CARDINAL
                                                      ) : BOOLEAN;
VAR
    Column,
    i, j, k  : CARDINAL;
    On, ok   : BOOLEAN;
    s        : ARRAY [0..79] OF CHAR;
    s1       : ARRAY [0..39] OF CHAR;


    (* Squish all spaces out of a text field. *)
    PROCEDURE Squish( VAR s : ARRAY OF CHAR );
    VAR
        i  : CARDINAL;
        s1 : ARRAY [0..1] OF CHAR;
    BEGIN
        TrimFront(s);
        TrimRear(s);
        SetString(s1," ");
        i := Search(s,s1,1);
        WHILE (i > 0) DO
            Remove(s,i,1);
            i := Search(s,s1,1);
        END;
    END Squish;

    (* When the back-end format changes, we need to refresh the EXT fields.
    *)
    PROCEDURE SetOtherFields( Column : CARDINAL );
    VAR
        ok          : BOOLEAN;
        DataRecord  : AColumnDataRecord;
        ExtField    : CARDINAL;
        ExtOptional : BOOLEAN;
        i,j         : CARDINAL;
    BEGIN

        ok := GetBEndInfo ( Column,
                            ColumnExt,
                            HIGH(FormValue[ExtensionOffset].CharValue^),
                            DataRecord );

        Copy (DataRecord.StringValue, FormValue[ExtensionOffset].CharValue^);

        ok := GetBEndInfo (Column, ColumnExtOptional, 0, DataRecord);

        ExtOptional := DataRecord.BooleanValue;

        ShowValue( Form, ExtensionOffset, FormValue );

        (* Set link data field *)
        Copy ( FormValue[ExtensionOffset].CharValue^,
                FormValue[ShowExtensionOffset].CharValue^ );
        ShowValue(Form, ShowExtensionOffset, FormValue);

        SetFieldProtection( Form, ExtensionOffset, FormValue, NOT ExtOptional);
    END SetOtherFields;

    PROCEDURE SetUserExt();
    VAR
        ok          : BOOLEAN;
        DataRecord  : AColumnDataRecord;
        ExtField    : CARDINAL;
        ExtOptional : BOOLEAN;
        i,j         : CARDINAL;
    BEGIN

        (* Set link data field *)
        Copy ( FormValue[ExtensionOffset].CharValue^,
                FormValue[ShowExtensionOffset].CharValue^ );
        ShowValue(Form, ShowExtensionOffset, FormValue);  (* 11/14/88 WKH *)

    END SetUserExt;



    (* When we enter the form, set up the protections correctly. *)

    PROCEDURE SetupForm();
    VAR
        ok          : BOOLEAN;
        DataRecord  : AColumnDataRecord;
        i, j,
        FmtField,
        ExtField    : CARDINAL;
        On,
        ExtOptional : BOOLEAN;
    BEGIN
        ok := GetBEndInfo ( FormValue[ FormatOffset ].CardValue,
                            ColumnExtOptional, 0, DataRecord);     (* 28-Jun-89 MWP *)

        ExtOptional := DataRecord.BooleanValue;

        SetFieldProtection( Form, ExtensionOffset, FormValue, NOT ExtOptional);

        (* Set link data fields *)
        FOR i  := 0 TO LinkDataRows - 1 DO
            j := ( i * ColsPerLinkGrp ) + NoYes;
            On := (FormValue[j].CardValue = 0);
            SetFieldProtection( Form, j + 1, FormValue, On);
            SetFieldHidden    ( Form, j + 1, FormValue, On);
        END;

        SetFieldProtection( Form, ShowExtensionOffset, FormValue, TRUE);
        SetFieldHidden    ( Form, ShowExtensionOffset, FormValue, FALSE);

    END SetupForm;


    (*
        Ajust Path - Ajust the user-entered path so that it is a real
                     DOS file path.  Expand it.  If it is bad, return
                     FALSE.
    *)
    PROCEDURE AjustPath( VAR in, out : ARRAY OF CHAR ) : BOOLEAN;
    VAR
        s               : ARRAY [0..255] OF CHAR;
        Nil             : ARRAY [0..1]   OF CHAR;
        ok              : BOOLEAN;
    BEGIN
        TrimFront(in);
        TrimRear(in);
        Nil[0] := 0C;
        ExpandPath( in, Nil, out );
        ok := DirectoryIsReachable( out );
        IF (NOT ok) THEN
            GetMessage( ModuleNumber + 50, s ); (* "Dir offline or bad" *)
            Error(s);
        END;
        RETURN ok;
    END AjustPath;


    PROCEDURE ExportFileNamesExist ( VAR FileName : ARRAY OF CHAR;
                                         FieldNo  : CARDINAL );
    VAR
        Path      :  ARRAY[0..80] OF CHAR;
        TempName  :  ARRAY[0..13] OF CHAR;
        Dir : CARDINAL;
    BEGIN

        Copy ( FormValue[ DirOffset ].CharValue^, Path );

        Copy( FileName, TempName );
        TrimRear ( TempName );
        ConcatS  ( TempName, "." );
        ConcatLS ( TempName, FormValue[ ExtensionOffset ].CharValue^ );
        ConcatLS ( Path, TempName );
        IF ( DoesFileExist ( Path ) ) THEN
            IF ( NOT OverWriteFiles ) THEN
                FileDuplicateFldNo := FieldNo;
            END;
            OverWriteFiles := TRUE;
        END;

    END ExportFileNamesExist;


    PROCEDURE DoesFileExist( VAR FileName : ARRAY OF CHAR ) : BOOLEAN;
    VAR
        f             : File;
        s             : ARRAY [0..199] OF CHAR;
    BEGIN
        LStringToTString(FileName,s);
        PrepareForIO(f);
        Lookup( f, s, FALSE );
        IF (CheckIO(f) <> done) THEN
            Close(f);
            RETURN FALSE;
        END;
        Close(f);
        RETURN TRUE;
    END DoesFileExist;


BEGIN
    Code := 0;  (* Init return code to "ok" *)

    (* If this is form entry, set default protections. *)

    IF (CheckReason = CheckFormEntry)  THEN
        IF (FieldNo = 0)               THEN
            SetupForm();
            ResetOverwriteMessage();
        END;
        RETURN TRUE;
    END;

    (* If check field entry/exit, ignore it. *)

    IF (CheckReason = CheckFieldEntry) OR
       (CheckReason = CheckFieldExit)  THEN
        RETURN TRUE;
    END;

    (* If F2 was pressed, make sure it is for the proper fields. *)

    IF (CheckReason = CheckFieldKey) THEN
        IF ( FieldNo <> DirOffset ) AND ( FieldNo <> FormatOffset  ) THEN
            Burp;
            RETURN FALSE;
        END;
    END;

    (* Now, based on the field we are on, process it. *)

    WITH FormValue[ FieldNo ] DO
        CASE FieldNumber( FieldNo ) OF
          NoYes        :
               On := (CardValue = 0); (* Not selected? turn off NAM field. *)
               SetFieldProtection( Form, FieldNo+1, FormValue, On);
               SetFieldHidden    ( Form, FieldNo+1, FormValue, On);
               IF (CheckReason = CheckFieldChange)          AND  (* Field has changed *)
                  (CardValue   > 0 )                        AND  (* It is set to Yes *)
                  (FormValue[FieldNo+1].CharValue^[0] = 0C) THEN (* We have no file to display *)

                   IF ( FieldNo <= MaxLinkDataField ) THEN
                      i :=  FieldNo DIV ColsPerLinkGrp;
                   ELSE
                      i :=  ( FieldNo - 1 ) DIV ColsPerLinkGrp;   (* 4-Sep-89 MWP *)
                   END;

                   GetRowInfo( i,
                               ok,
                               s,
                               FormValue[FieldNo+1].CharValue^,
                               s1,s );
                   ShowValue( Form, FieldNo+1, FormValue );
               END;
        | FileName     :
               Squish( CharValue^ );
               ShowValue( Form, FieldNo, FormValue );

               IF (CheckReason = CheckFormExit) THEN
                   IF (FormValue[(FieldNo - 1)].CardValue <> 0) AND (* ON *)
                      (CharValue^[0] = 0C)    THEN  (* But no name, *)
                       Code := CARDINAL(BITSET({15})) + FieldNo; (* GO TO <This field> *)
                       Burp;
                       RETURN FALSE;
                   END;

                   IF ( FormValue[(FieldNo - 1)].CardValue <> 0 ) THEN
                       ExportFileNamesExist ( CharValue^, FieldNo );
                       IF ( DirEntryProcessed ) THEN              (* 30-Nov-89 MWP *)
                           IF ( OverWriteFiles ) THEN
                              IF ( NOT DisplayOverwriteMessage () ) THEN
                                 OverWriteFiles := FALSE;
                                 Code := CARDINAL(BITSET({15})) + FileDuplicateFldNo;
                                 Burp;
                                 RETURN FALSE;
                              END;
                           END;
                       END;
                   END;

               ELSIF (CharValue^[0] <> 0C)    THEN  (* a name? *)
                   FOR i  := 0 TO LinkDataRows - 1 DO
                       j := ( i * ColsPerLinkGrp ) + FileName;
                       k := ( i * ColsPerLinkGrp ) + NoYes;
                       IF (j <> FieldNo) AND
                          (StringsEqual(CharValue^,FormValue[j].CharValue^)) THEN   (* RSC 1/2/88 *)
                           IF (FormValue[k].CardValue > 0) THEN (* FIELD IS ON *)
                               Burp;
                               RETURN FALSE;  (* Matching name. *)
                           ELSE
                               FormValue[j].CharValue^[0] := 0C;
                           END;
                       END;
                   END;

               END;
        | ShowExtensionOffset :
        | ReImportable :
               IF ( CardValue > 0 ) AND
                  ( FormValue[FormatOffset].CardValue = PlainCSV ) THEN  (* 24-Jul-91 TGS *)
                   Burp ();
                   RETURN FALSE;
               END;



        | FormatOffset:
               TrimRear( CharValue^ );
               IF (CheckReason = CheckFieldChange) THEN
                   IF (CharValue^[0] = 0C) THEN
                       Column := MAXCARDINAL;
                   ELSE
                       IF (NOT SearchForBEndColumn( CharValue^, Column )) THEN
                           Column := MAXCARDINAL;
                       END;
                   END;
                   IF (Column = MAXCARDINAL) THEN
                       Burp;
                       GetMessage( ModuleNumber + 53, s );           (* 1-Jul-89 MWP *)
                       Message ( s );
                       RETURN FALSE;
                   END;
                   SetOtherFields( Column );

                   CardValue := Column;
               ELSIF (CheckReason = CheckFieldKey) THEN
                   Column := CardValue;

                   IF PickBEndColumn( 50,8, 76,18,
                                      Column, CharValue^ ) THEN
                       CardValue := Column;
                       SetOtherFields( Column );
                   END;
               END;

               IF ( CardValue = PlainCSV ) THEN             (* 24-Jul-91 TGS *)
                  FormValue[ReImportable].CardValue := 0;
                  SetFieldProtection( Form, ReImportable, FormValue, TRUE);
                  ShowValue( Form, ReImportable, FormValue );
               ELSE
                  SetFieldProtection( Form, ReImportable, FormValue, FALSE);
               END;

               ShowValue( Form, FieldNo, FormValue );

        | ExtensionOffset :
               Squish( CharValue^ );
               Procustes( CharValue^, 3 );
               ShowValue( Form, FieldNo, FormValue );
               SetUserExt();

        | DirOffset:
               Squish( CharValue^ );
               IF (CheckReason = CheckFieldKey) THEN
                   IF (NOT AjustPath( CharValue^, s )) THEN
                       SetString(s, "DK:.\");  (* Default to this ... *)
                   END;
                   GetMessage( ModuleNumber + 7, s1 ); (* "Pick a directory" *)
                   ok := PickDirectory( GanttWStart,
                                        GanttWStart + 5 + ROWS,
                                        s1, s );
                   IF (NOT ok) THEN
                       RETURN FALSE;
                   END;
               ELSE
                   IF (NOT AjustPath( CharValue^, s )) THEN
                       Burp;
                       Code := CARDINAL(BITSET({15})) + FieldNo; (* GO TO <This field> *)
                       RETURN FALSE;
                   END;

                   IF (CheckReason = CheckFormExit) THEN
                       DirEntryProcessed := TRUE;
                       IF ( OverWriteFiles ) THEN
                          IF ( NOT DisplayOverwriteMessage () ) THEN
                             OverWriteFiles := FALSE;
                             Code := CARDINAL(BITSET({15})) + FileDuplicateFldNo;
                             Burp;
                             RETURN FALSE;
                          END;
                       END;
                   END;
               END;
               Copy(s, CharValue^);
               ShowValue( Form, FieldNo, FormValue );
        ELSE
            FatalError();
        END;
    END;

    RETURN TRUE;

END CheckTheForm;


  (* Do the form editing.
  *)
PROCEDURE EditForm( VAR DriverTable : ADriverTable ) : BOOLEAN;
VAR
    i, j         : CARDINAL;
    FormValue    : ARRAY [0..24]  OF AFieldValue;
    Strings      : ARRAY [1..20] OF AStringValue;
    s            : ARRAY [0..5] OF CHAR;
    ok           : BOOLEAN;
BEGIN

    GetMessageWord( ModuleNumber + 9, 1, s );  (* Number of front ends. *)
    j  := 1;
    ROWS := StoC( s, j );

 (* Build the form record *)

    ok := BuildFormValues ( DriverTable, FormValue, Strings );

 (* Build the tree of export formats. *)

    ok := (ok AND CreateBEndColumnsTree());

 (* Do the form.  If ESC is hit, don't do the report. *)

    ok := ok AND (DoForm ( 0, GanttWEnd,
                           maxcol,
                           maxrow-1,
                           EXPORTFORMID,
                           TRUE,
                           FormValue,  CheckTheForm ) = ExitKey);

    DisposeBEndColumnsTree();

    IF (ok) THEN
        BuildDriverTable( FormValue, DriverTable );
    END;

    RETURN ok;

END EditForm;





 (* Build Form Values - construct the form for this report. *)

PROCEDURE BuildFormValues ( VAR DriverTable : ADriverTable;
                            VAR FormValue   : ARRAY OF AFieldValue;
                            VAR Strings     : ARRAY OF AStringValue
                          ) : BOOLEAN;
VAR
    DataRecord  : AColumnDataRecord;
    StringIndex,
    i, j,  Loop,
    k,
    DriverEntry: CARDINAL;
    s          : ARRAY [0..79] OF CHAR;
    Result     : BOOLEAN;
    ok         : BOOLEAN;

    PROCEDURE SetUpFormWithDriver ();
    BEGIN
       (* Fill in the starting data for the field. *)

       FOR Loop := 0 TO HIGH(FormValue) DO
           FormValue[Loop].CardValue := 0;
           FormValue[Loop].CharValue := NIL;
       END;

       StringIndex := 0;  (* Next String value to use. *)

       i := 0;
       DriverEntry := 1;

       (* Fill in the 'link data' defaults. *)
       WHILE ( i < LinkDataRows ) DO
           j := ( i * ColsPerLinkGrp ) + FileName;
           k := ( i * ColsPerLinkGrp ) + NoYes;

           WITH DriverTable DO
               FormValue[ k ].CardValue := Drivers[ DriverEntry ].ReportFormat;

               IF (StringIndex > HIGH(Strings)) THEN
                   FatalError; (* Too many front ends! *)
               END;

               FormValue[ j ].CharValue := ADR( Strings[StringIndex] );

               INC(StringIndex);

               Copy( Drivers[ DriverEntry ].FileToUse, FormValue[j].CharValue^ );

               IF (Drivers[ DriverEntry ].FileToUse[0] = 0C) THEN
                   FormValue[k].CardValue := 0; (* No file?  Turn it off. *)
               END;
           END;
           INC(i);
           INC(DriverEntry);
       END;

       (* Fill in File Extension (shown next to export file names) *)
       WITH DriverTable DO
            FormValue[ ShowExtensionOffset ].CharValue := ADR( Strings[StringIndex] );

            INC(StringIndex);

            Copy( FileExt, FormValue[ ShowExtensionOffset ].CharValue^ );
       END;

       (* Fill in Re-importable *)
       WITH DriverTable DO
           IF ( ReImport ) AND ( BackEndNumber <> 8 ) THEN      (* 12-Sep-89 MWP *)
               FormValue[ ReImportable ].CardValue := 1;
           ELSE
               FormValue[ ReImportable ].CardValue := 0;
           END;
       END;


       WITH DriverTable DO
           IF ( ( StringIndex + 2 ) > HIGH(Strings)) THEN
               FatalError; (* Too many front ends! *)
           END;

           FormValue [ ExtensionOffset ].CharValue := ADR( Strings[StringIndex] );
           INC(StringIndex);

           FormValue[ DirOffset ].CharValue := ADR( Strings[StringIndex] );
           INC(StringIndex);

           FormValue[ FormatOffset ].CharValue := ADR( Strings[StringIndex] );

           INC ( StringIndex );

           Copy( FileExt, FormValue[ ExtensionOffset ].CharValue^ );
           Copy( FileDir, FormValue[ DirOffset ].CharValue^ );

           FormValue[ FormatOffset ].CardValue := BackEndNumber;

           ok := GetBEndInfo (BackEndNumber, ColumnBackEnd, HIGH(BackEnd), DataRecord);

           Copy (DataRecord.StringValue, BackEnd);

           ok := GetBEndInfo (BackEndNumber, ColumnBackEndContext, HIGH(BackEndContext),
                              DataRecord);
           Copy (DataRecord.StringValue, BackEndContext);

           ok := GetBEndInfo (BackEndNumber, ColumnBackEndName,
                              HIGH(FormValue[ FormatOffset ].CharValue^), DataRecord);

           Copy ( DataRecord.StringValue, FormValue[ FormatOffset ].CharValue^);
       END;

    END SetUpFormWithDriver;

BEGIN

    SetUpFormWithDriver ();


    RETURN TRUE;

END BuildFormValues;



  (* Get the information for one row.
  *)
PROCEDURE GetRowInfo( Row           : CARDINAL;
                  VAR Importable    : BOOLEAN;                  (* 2-May-89 MWP*)
                  VAR Description,
                      DefaultName,
                      OverlayName,
                      OverlayContext : ARRAY OF CHAR );
CONST
    ColumnMessageBase = 10;  (* SAME AS IN RPTCOMMON, ColumnHeadings!! *)
VAR
    i, j,
    Phrase : CARDINAL;
    s      : ARRAY [0..9] OF CHAR;
BEGIN
    GetMessageWord( ModuleNumber + 9, 0, s );  (* Number of back ends - 1. *)
    j      := 1;
    i      := StoC( s, j );

    Phrase := ModuleNumber + ColumnMessageBase + Row + i + 1;

    Importable := FALSE;

    GetMessageWord( Phrase, 0, Description    );
    GetMessageWord( Phrase, 1, DefaultName    );
    GetMessageWord( Phrase, 2, s );
    IF ( s[1] = "T" ) THEN
       Importable := TRUE;
    END;

    GetMessageWord( Phrase, 3, OverlayName    );
    GetMessageWord( Phrase, 4, OverlayContext );

END GetRowInfo;







  (* Initialize the driver table.
  *)
PROCEDURE InitDriverTable( VAR DriverTable : ADriverTable );
VAR
    ok          : BOOLEAN;
    DataRecord  : AColumnDataRecord;
    Loop        : CARDINAL;
    s, s1     : ARRAY [0..39] OF CHAR;
BEGIN
    WITH DriverTable DO
(***
        BackEndNumber     := 1;  (* Assume the first number *)    (* 3-Apr-89 LAA *)
***)
        BackEndNumber     := 2;  (* Assume 123 V 2 *)             (* 7-Sep-89 MWP *)

        ok := GetBEndInfo (BackEndNumber, ColumnExt, HIGH(FileExt), DataRecord);
        Copy (DataRecord.StringValue, FileExt);

        ok := GetBEndInfo (BackEndNumber, ColumnBackEnd, HIGH(BackEnd), DataRecord);
        Copy (DataRecord.StringValue, BackEnd);

        ok := GetBEndInfo (BackEndNumber, ColumnBackEndContext, HIGH(BackEndContext),
                           DataRecord);
        Copy (DataRecord.StringValue, BackEndContext);

        ok := GetBEndInfo (BackEndNumber, ColumnBackEndStartup, HIGH(BackEndInit), DataRecord);
        Copy (DataRecord.StringValue, BackEndInit);

        Copy( ProjectMedia, FileDir );
        GetMessageWord( ModuleNumber + 9, 1, s );  (* Number of front ends. *)
        Loop    := 1;
        Entries := StoC( s, Loop );

        FOR Loop := 1 TO Entries DO
            WITH Drivers[ Loop ] DO
                GetRowInfo( Loop-1, ReImportable, s, FileToUse, FrontEnd, FrontContext );
                ReportFormat := 1;
            END;
        END;

        FOR Loop := Entries - 2 TO Entries DO                     (* 11-Sep-89 MWP *)
            WITH Drivers[ Loop ] DO
               SetLengthOf ( FileToUse, 0 );
            END;
        END;

        FOR Loop := Entries+1 TO HIGH(Drivers) DO
            WITH Drivers[ Loop ] DO
                FileToUse[0]    := 0C;
                FrontEnd[0]     := 0C;
                FrontContext[0] := 0C;
                ReImportable := FALSE;
                ReportFormat := 1;
            END;
        END;
    END;
END InitDriverTable;


  (* Construct the driver table from the form data and the existing
     (from HOLDER) driver table.
  *)
PROCEDURE BuildDriverTable( VAR FormValue   : ARRAY OF AFieldValue;
                            VAR DriverTable : ADriverTable       );
VAR
    ok          : BOOLEAN;
    DataRecord  : AColumnDataRecord;
    Loop,
    i, j, k : CARDINAL;
    s, s1   : ARRAY [0..39] OF CHAR;
BEGIN
    DriverTable.Entries := 0;
    i := 0;
    WHILE ( i < LinkDataRows ) DO
        j := ( i * ColsPerLinkGrp ) + FileName;
        k := ( i * ColsPerLinkGrp ) + NoYes;

        WITH DriverTable DO
            INC(Entries);
            Drivers[ Entries ].ReportFormat := FormValue[k].CardValue;

            IF (FormValue[k].CardValue > 0 ) THEN (* FIELD IS ON *)
                Copy( FormValue[j].CharValue^, Drivers[ Entries ].FileToUse );
            ELSE
                Drivers[ Entries ].FileToUse[0] := 0C;
            END;

            GetRowInfo( i, Drivers[ Entries ].ReImportable, s,s1,
                        Drivers[ Entries ].FrontEnd,
                        Drivers[ Entries ].FrontContext );
        END;
        INC(i);
    END;

    i := 0;

    WITH DriverTable DO
        Copy( FormValue[ExtensionOffset].CharValue^, FileExt );
        Copy( FormValue[DirOffset].CharValue^, FileDir );
        BackEndNumber := FormValue[FormatOffset].CardValue;

        IF ( FormValue[ReImportable].CardValue = 1 ) AND          (* 12-Sep-89 MWP *)
           ( BackEndNumber <> PlainCSV ) THEN                     (* 25-Sep-89 MWP *)
           ReImport := TRUE;
        ELSE
           ReImport := FALSE;
        END;

        ok := GetBEndInfo (BackEndNumber, ColumnBackEnd, HIGH(BackEnd), DataRecord);
        Copy (DataRecord.StringValue, BackEnd);

        ok := GetBEndInfo (BackEndNumber, ColumnBackEndContext, HIGH(BackEndContext),
                           DataRecord);
        Copy (DataRecord.StringValue, BackEndContext);

        ok := GetBEndInfo (BackEndNumber, ColumnBackEndStartup, HIGH(BackEndInit), DataRecord);
        Copy (DataRecord.StringValue, BackEndInit);

        FOR Loop := Entries+1 TO HIGH(Drivers) DO
           WITH Drivers[ Loop ] DO
               FileToUse[0]    := 0C;
               FrontEnd[0]     := 0C;
               FrontContext[0] := 0C;
               ReImportable    := FALSE;
               ReportFormat    := 0;
            END;
        END;
    END;

END BuildDriverTable;





  (* Get the existing driver table from HOLDER, or initialize it.
  *)
PROCEDURE GetHeldContext( VAR DriverTable : ADriverTable );
VAR
    P                  : ADDRESS;
    Handle             : AnExtHandle;
    Size,
    Class              : CARDINAL;
    Category           : AHoldTypeSet;
    Name               : ARRAY [0..9] OF CHAR;
    Init               : BOOLEAN;
    Loop, NoOfEntries  : CARDINAL;
    s                  : ARRAY [0..39] OF CHAR;
BEGIN
    Init := TRUE;

    Class := 3;
    SetString( Name, "TLXFORM" );
    IF (LocateHeldItem( Name, Class, Category, P, Size )) THEN
        IF (Size = TSIZE(ADriverTable)) AND (HoldInFlexStor IN Category) THEN
            Handle := AnExtHandle(P);
            Size   := GetExtData( Handle, ADR(DriverTable) );
            GetMessageWord( ModuleNumber + 9, 1, s );  (* Number of front ends. *)
            Loop    := 1;
            NoOfEntries := StoC( s, Loop );
            IF ( DriverTable.Entries = NoOfEntries ) THEN
               Init := FALSE;
            END;
        END;
        DeleteHeldItem( Name, Class );
    END;

    IF ( Init ) THEN
       InitDriverTable( DriverTable );
    END;

END GetHeldContext;




   (* Save the driver table in holder for next time.  Delete any old copies.
   *)
PROCEDURE SaveInHolder( VAR DriverTable : ADriverTable );
VAR
    Size,
    Class              : CARDINAL;
    Handle             : AnExtHandle;
    DriverTableP       : POINTER TO ADriverTable;
    Category           : AHoldTypeSet;
    Name               : ARRAY [0..9] OF CHAR;
BEGIN
    SetString( Name, "TLXFORM" );
    Class := 3;
    IF (LocateHeldItem( Name, Class, Category, DriverTableP, Size)) THEN
        DeleteHeldItem( Name, Class );
    END;

    IF (CreateExtObjectWithSize( Handle, ExtSlow, TSIZE(ADriverTable) ) AND
        SetExtData( Handle, ADR(DriverTable), TSIZE(ADriverTable))) THEN
        Category      := AHoldTypeSet{HoldInDataFile,
                                      HeapNoOwner,
                                      HoldInFlexStor,  (* 23-Jan-91 RSC  *)
                                      HoldInConfig};  (* 9/14/89 EGK *)
        HoldThis( Name, Class, Category,
                  ADDRESS(Handle), TSIZE(ADriverTable));
    END;

END SaveInHolder;




  (* MAIN PROCEDURE *)

PROCEDURE DoTLXForm ();
VAR
    DriverTableP : POINTER TO ADriverTable;
    Copyright    : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    DriverTableP := OverlayContext();
    GetHeldContext( DriverTableP^ );
    
    IF (EditForm( DriverTableP^ )) THEN
        SaveInHolder( DriverTableP^ );
    ELSE
        DriverTableP^.Entries := 0;  (* Signal failure *)
    END;

END DoTLXForm;



BEGIN

    OverWriteFiles := FALSE;
    DirEntryProcessed := FALSE;
    DoTLXForm ();

END TLXForm.

