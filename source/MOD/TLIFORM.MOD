MODULE TLIForm;

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
           5-Jul-89 MWP   Assigned an help key identifier instead of setting
                          it to null.
          09-Aug-89 KKC   Add copyright message.
          20-Aug-89 MWP   Large amount of changes to accomodate new Import
                          form.
          23-Aug-89 MWP   Center the form on screen.
          28-Aug-89 MWP   Place form at bottom of screen. ( All that's left is
                          to try the top! ).
          30-Aug-89 MWP   Save the file format in Driver record.
           7-Sep-89 MWP   Default file format is 123 V 2.
          14-Sep-89 EGK   Added HoldInConfig to the HoldTypeSet.
          23-Jan-91 RSC   Put Holder item in FlexStor.
    *)


FROM IEndColumns    IMPORT
    (* PROC *)              CreateBEndColumnsTree, DisposeBEndColumnsTree,
                            PickBEndColumn,        SearchForBEndColumn;

FROM IEndFormat     IMPORT
    (* PROC *)              GetBEndInfo;

FROM Captions       IMPORT
    (* TYPE *)              AColumnInfoChoice, AColumnDataRecord;

FROM Dialog         IMPORT
    (* PROCS *)             Burp, Error, FatalError;

FROM Directory      IMPORT
    (* PROCS *)             DirectoryIsReachable,
                            ExpandPath;

FROM FlexStor       IMPORT
    (* TYPE *)              AnExtHandle, AnExtStoragePreference,
    (* PROC *)              CreateExtObjectWithSize, GetExtData,
                            SetExtData;

FROM Forms          IMPORT
        (* TYPE *)          AFieldValue, AForm, ACheckReason, AStringValue,
        (* PROCS *)         DoForm, ShowValue, SetFieldProtection,
                            SetFieldHidden;

FROM FormCon        IMPORT
    (* TYPE *)              AFieldNo;

FROM Holder         IMPORT
    (* TYPE *)              AHoldType, AHoldTypeSet,
    (* PROC *)              LocateHeldItem, HoldThis, DeleteHeldItem;

FROM Kbio           IMPORT
    (* TYPE *)              maxcol,
                            maxrow;

FROM Keys           IMPORT
    (* CONST *)             ExitKey;

FROM Layout         IMPORT
    (* CONST *)             GanttWStart, GanttWEnd;

FROM LStrings       IMPORT
    (* PROCS *)             TrimFront, SetString,
                            StringsEqual, TrimRear, Procustes, LJust,
                            Search,  StoC, Remove, Copy;

FROM MsgFile        IMPORT
    (* PROCS *)             GetMessage;

FROM Overlays       IMPORT
    (* PROC *)              OverlayContext;

FROM PickDirs       IMPORT
    (* PROCS *)             PickDirectory;

FROM RptCommon      IMPORT
    (* PROCS *)             GetMessageWord;

FROM Schedule       IMPORT
    (* VAR *)               ProjectMedia;

FROM Space          IMPORT
    (* PROCS *)             Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM         IMPORT
    (* THING *)             TSIZE, ADR, ADDRESS;

FROM XPorTable      IMPORT
    (* TYPES *)             ADriverTable;



CONST
    ModuleNumber            = 29200;
    MAXCARDINAL             = 65535;
    IMPORTFORMID            = 80;

    LinkDataRows            = 4;
    NoYes                   = 0;
    FileName                = 1;
    FileExt                 = 2;
    ColsPerLinkGrp          = 3;
    FormatOffset            = 12;
    ExtensionOffset         = 13;
    DirOffset               = 14;
    MaxLinkDataField        = 11;

    ColumnExt               = ColumnFormalName;
    ColumnExtOptional       = ColumnUniqueId;
    ColumnBackEnd           = ColumnHeading1;
    ColumnBackEndContext    = ColumnHeading2;
    ColumnBackEndName       = ColumnName;
    ColumnBackEndStartup    = ColumnNarrowHeading1;

VAR
    ROWS                    : CARDINAL;   (* Number of repeating rows on the form *)


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


    (* When the back-end format changes, we need to refresh the EXT fields *)

    PROCEDURE SetOtherFields( Column : CARDINAL );
    VAR
        ok          : BOOLEAN;
        DataRecord  : AColumnDataRecord;
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

        (* Set link data fields *)
        FOR i  := 0 TO LinkDataRows - 1 DO
            j := ( i * ColsPerLinkGrp ) + FileExt;
            Copy ( FormValue[ExtensionOffset].CharValue^,
                   FormValue[j].CharValue^ );
            ShowValue(Form, j, FormValue);  (* 11/14/88 WKH *)
        END;

        SetFieldProtection( Form, ExtensionOffset, FormValue, NOT ExtOptional);

    END SetOtherFields;


    PROCEDURE SetUserExt();
    VAR
        i,j         : CARDINAL;
    BEGIN

        (* Set link data fields *)
        FOR i  := 0 TO LinkDataRows - 1 DO
            j := ( i * ColsPerLinkGrp ) + FileExt;
            Copy ( FormValue[ExtensionOffset].CharValue^,
                   FormValue[j].CharValue^ );
            ShowValue(Form, j, FormValue);
        END;

    END SetUserExt;



    (* When we enter the form, set up the protections correctly. *)

    PROCEDURE SetupForm();
    VAR
        ok          : BOOLEAN;
        DataRecord  : AColumnDataRecord;
        i, j        : CARDINAL;
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

            SetFieldProtection( Form, j + 2, FormValue, TRUE);
            SetFieldHidden    ( Form, j + 2, FormValue, FALSE);
        END;

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


BEGIN
    Code := 0;  (* Init return code to "ok" *)

    (* If this is form entry, set default protections. *)

    IF (CheckReason = CheckFormEntry)  THEN
        IF (FieldNo = 0)               THEN
            SetupForm();
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
        k := FieldNumber ( FieldNo );
        CASE FieldNumber( FieldNo ) OF
          NoYes        :
               On := (CardValue = 0); (* Not selected? turn off NAM field. *)
               SetFieldProtection( Form, FieldNo+1, FormValue, On);
               SetFieldHidden    ( Form, FieldNo+1, FormValue, On);
               IF (CheckReason = CheckFieldChange)          AND
                  (CardValue   > 0 )                        AND
                  (FormValue[FieldNo+1].CharValue^[0] = 0C) THEN

                   i :=  FieldNo DIV ColsPerLinkGrp;

                   GetRowInfo( i,
                               s,
                               FormValue[FieldNo+1].CharValue^,
                               s1,s );
                   ShowValue( Form, FieldNo+1, FormValue );
               END;
        | FileName:
               Squish( CharValue^ );
               ShowValue( Form, FieldNo, FormValue );
               IF (CheckReason = CheckFormExit) THEN
                   IF (FormValue[(FieldNo - 1)].CardValue <> 0 ) AND (* ON *)
                      (CharValue^[0] = 0C)    THEN  (* But no name, *)
                       Code := CARDINAL(BITSET({15})) + FieldNo; (* GO TO <This field> *)
                       Burp;
                       RETURN FALSE;
                   END;
               ELSIF (CharValue^[0] <> 0C)    THEN  (* a name? *)
                   FOR i  := 0 TO LinkDataRows - 1 DO
                       j := ( i * ColsPerLinkGrp ) + FileName;
                       k := ( i * ColsPerLinkGrp ) + NoYes;
                       IF (j <> FieldNo) AND
                          (StringsEqual(CharValue^,FormValue[j].CharValue^)) THEN   (* RSC 1/2/88 *)
                           IF (FormValue[k].CardValue > 0 ) THEN (* FIELD IS ON *)
                               Burp;
                               RETURN FALSE;  (* Matching name. *)
                           ELSE
                               FormValue[j].CharValue^[0] := 0C;
                           END;
                       END;
                   END;
               END;

          (* Do nothing *)
        | FileExt      :

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
(* NOTE - Export displays a message here. Should Import? *)
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
               ShowValue( Form, FieldNo, FormValue );

        | ExtensionOffset:
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
    i, j,
    FormLeftCol,
    FormRightCol,
    FormUpperRow,
    FormLowerRow : CARDINAL;
    FormValue    : ARRAY [ 0..14 ] OF AFieldValue;
    Strings      : ARRAY [ 1..20 ] OF AStringValue;
    s            : ARRAY [ 0..5 ]  OF CHAR;
    ok           : BOOLEAN;
BEGIN

    GetMessageWord( ModuleNumber + 9, 1, s );  (* Number of front ends. *)
    j  := 1;
    ROWS := StoC( s, j );

    (* Build the form record *)

    ok := BuildFormValues ( DriverTable, FormValue, Strings );

    (* Build the tree of export formats. *)

    ok := (ok AND CreateBEndColumnsTree());

    FormLeftCol     :=  0;
    FormRightCol    :=  maxcol;
    FormUpperRow    :=  GanttWEnd;
    FormLowerRow    :=  maxrow - 1;

    (* Do the form.  If ESC is hit, don't do the report. *)

    ok := ok AND (DoForm ( FormLeftCol,
                           FormUpperRow,
                           FormRightCol,
                           FormLowerRow,
                           IMPORTFORMID,
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
    k,l,
    DriverEntry: CARDINAL;
    ok         : BOOLEAN;

    PROCEDURE SetUpFormWithDriver ();
    VAR
        Upper : CARDINAL;
    BEGIN

       (* Fill in the starting data for the field. *)
       Upper :=  HIGH(FormValue);

       FOR Loop := 0 TO Upper DO
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
           l := ( i * ColsPerLinkGrp ) + FileExt;


           WITH DriverTable DO
               FormValue[ k ].CardValue := 1;

               IF (StringIndex > HIGH(Strings)) THEN
                   FatalError; (* Too many front ends! *)
               END;

               FormValue[ j ].CharValue := ADR( Strings[StringIndex] );

               INC(StringIndex);

               Copy( Drivers[ DriverEntry ].FileToUse, FormValue[j].CharValue^ );

               FormValue[ l ].CharValue := ADR( Strings[StringIndex] );

               INC(StringIndex);

               Copy( FileExt, FormValue[ l ].CharValue^ );

               IF (Drivers[ DriverEntry ].FileToUse[0] = 0C) THEN
                   FormValue[k].CardValue := 0; (* No file?  Turn it off. *)
               END;
           END;
           INC(i);
           INC(DriverEntry);
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
PROCEDURE GetRowInfo(     Row            : CARDINAL;
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

    GetMessageWord( Phrase, 0, Description    );
    GetMessageWord( Phrase, 1, DefaultName    );
    GetMessageWord( Phrase, 2, OverlayName    );
    GetMessageWord( Phrase, 3, OverlayContext );

END GetRowInfo;



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
    i                   := 0;
    DriverTable.FileFormat := FormValue[FormatOffset].CardValue;  (* 30-Aug-89 MWP *)

    WHILE ( i < LinkDataRows ) DO
        j := ( i * ColsPerLinkGrp ) + FileName;
        k := ( i * ColsPerLinkGrp ) + NoYes;

        WITH DriverTable DO
            INC(Entries);
(***
            Drivers[ Entries ].ReportFormat := FormValue[k].CardValue;
***)
            IF (FormValue[k].CardValue > 0 ) THEN (* FIELD IS ON *)
                Copy( FormValue[j].CharValue^, Drivers[ Entries ].FileToUse );
            ELSE
                Drivers[ Entries ].FileToUse[0] := 0C;
            END;

            GetRowInfo( i, s, s1,
                        Drivers[ Entries ].FrontEnd,
                        Drivers[ Entries ].FrontContext );
        END;
        INC(i);
    END;


    WITH DriverTable DO
        Copy( FormValue[ExtensionOffset].CharValue^, FileExt );
        Copy( FormValue[DirOffset].CharValue^, FileDir );

        BackEndNumber := FormValue[FormatOffset].CardValue;



        ok := GetBEndInfo (BackEndNumber, ColumnBackEnd, HIGH(BackEnd), DataRecord);
        Copy (DataRecord.StringValue, BackEnd);

        ok := GetBEndInfo (BackEndNumber, ColumnBackEndContext, HIGH(BackEndContext),
                           DataRecord);
        Copy (DataRecord.StringValue, BackEndContext);

        ok := GetBEndInfo (BackEndNumber, ColumnBackEndStartup, HIGH(BackEndInit), DataRecord);
        Copy (DataRecord.StringValue, BackEndInit);
        LJust (BackEndInit);
        TrimRear (BackEndInit);

        FOR Loop := Entries+1 TO HIGH(Drivers) DO
           WITH Drivers[ Loop ] DO
               FileToUse[0]    := 0C;
               FrontEnd[0]     := 0C;
               FrontContext[0] := 0C;
(**
               ReportFormat    := 0;
**)
            END;
        END;
    END;

END BuildDriverTable;




  (* Initialize the driver table.
  *)
PROCEDURE InitDriverTable( VAR DriverTable : ADriverTable );
VAR
    ok          : BOOLEAN;
    DataRecord  : AColumnDataRecord;
    Loop        : CARDINAL;
    s           : ARRAY [0..39] OF CHAR;
BEGIN
    WITH DriverTable DO
(**
        BackEndNumber     := 1;  (* Assume the first number *)    (* 3-Apr-89 LAA *)
***)
        BackEndNumber     := 2;  (* Assume 123 V2 *)              (* 7-Sep-89 MWP *)

        ok := GetBEndInfo (BackEndNumber, ColumnExt, HIGH(FileExt), DataRecord);
        Copy (DataRecord.StringValue, FileExt);

        ok := GetBEndInfo (BackEndNumber, ColumnBackEnd, HIGH(BackEnd), DataRecord);
        Copy (DataRecord.StringValue, BackEnd);

        ok := GetBEndInfo (BackEndNumber, ColumnBackEndContext, HIGH(BackEndContext),
                           DataRecord);
        Copy (DataRecord.StringValue, BackEndContext);

        ok := GetBEndInfo (BackEndNumber, ColumnBackEndStartup, HIGH(BackEndInit), DataRecord);
        Copy (DataRecord.StringValue, BackEndInit);
        LJust (BackEndInit);
        TrimRear (BackEndInit);

        Copy( ProjectMedia, FileDir );

        GetMessageWord( ModuleNumber + 9, 1, s );  (* Number of front ends. *)
        Loop    := 1;
        Entries := StoC( s, Loop );
        FOR Loop := 1 TO Entries DO
            WITH Drivers[ Loop ] DO
                GetRowInfo( Loop-1, s, FileToUse, FrontEnd, FrontContext );
(**
                ReportFormat := 1;
***)
            END;
        END;

        FOR Loop := Entries+1 TO HIGH(Drivers) DO
            WITH Drivers[ Loop ] DO
                FileToUse[0]    := 0C;
                FrontEnd[0]     := 0C;
                FrontContext[0] := 0C;
(***
                ReportFormat := 1;
***)
            END;
        END;
    END;
END InitDriverTable;



  (* Get the existing driver table from HOLDER, or initialize it.
  *)
PROCEDURE GetHeldContext( VAR DriverTable : ADriverTable );
VAR
    P                  : ADDRESS;
    Handle             : AnExtHandle;
    Size,
    Loop, NoOfEntries  : CARDINAL;
    Class              : CARDINAL;
    Category           : AHoldTypeSet;
    Name               : ARRAY [0..9] OF CHAR;
    Init               : BOOLEAN;
    s                  : ARRAY [0..39] OF CHAR;
BEGIN
    Init := TRUE;

    Class := 3;
    SetString( Name, "TLIFORM" );

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
    SetString( Name, "TLIFORM" );
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

PROCEDURE DoImportForm ();
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

END DoImportForm;





BEGIN
    DoImportForm ();
END TLIForm.
