MODULE TLRTable;  (* RESOURCE TABLE REPORT *)


  (* TL R TABLE - Resource Table Report

        MODIFICATION HISTORY:

                RSC  11/17/87  First version with new interpass file.
                RSC   2/12/88  Dont print things that dont apply to costs.
                RSC   2/25/88  Clean up form tabbing and code sets.
                RSC   2/26/88  Updated for added param on GetHeader
                AJL   3/3/88   Only return value for the Hourly Rate and
                               Baseline Hourly rate when the CostType
                               = CAmountRateTime (Resource or Var Cost).
                EGK   3/7/88   Use default decimal digits for each field.
                RSC  6/15/88   Added Thermometer support.
                AJL  6/27/88  -Added ResourceFiltersPassed;
                              -Added row highlighting.
        LAA  18-Nov-88         Removed the form from this overlay, and put it
                               into the forms file (TLRTFORM is the form
                               builder program).  Also tweaked the check proc
                               for some minor fixes.
        RSC 10-Jan-89          Changed Storage to Space.
        RSC  6-Feb-89          Change "ExportersOK" to "PackageOK"
        EGK 17-Mar-89     Put more checking into DoTLRTable to make sure
                          we don't leave the temp file open if the back
                          end (which would close it) isn't going to run.
        RSC 21-Mar-89     Use new captions and columns modules, rather than
                          using RptCommon and built in routines.
        EGK 04-Apr-89     Changed CheckTheForm so that it allows you to
                          blank out a column name field, but won't let you
                          leave with a name that isn't valid.
        RSC 18-Apr-89     Fixed bug causing Fatal Errors when low on memory.
                          Moved OverlayContext to an earlier part of the run.
        MWP 01-May-89     Allow writing of a SkipRecordType Int file record.
        EGK 26-May-89     Burp if the column name is no good.
        EGK 30-May-89     Changed ColumnData to use the font passed to it.
        KKC 22-Jun-89     Set ColumnWidth protect and Hidden if no ColumnName.
        MWP 05-Jul-89     Allow exporting ALL resource columns automatically
                          bypassing the Resource form. Both Resources and Costs
                          are exported.
        MWP 10-Jul-89     After resource choices are selected on resource
                          form, remove blank lines between resource choices.
    KKC/MWP 10-Jul-89     If the user enters in a field width of '0' on the
                          resource report form, Burp them.
        MWP 10-Jul-89     I have just discovered that Exporters are not the
                          only people who call this overlay. This means that
                          we were PMD'ing on other infidels abusing my
                          lovely module. I have corrected this.
    KKC/MWP 21-Jul-89     Do not pass an uninitialized string value to
                          GenerateFileHeaders as a Prefix value for headings.
    KKC/MWP 21-Jul-89     Allow width field to be blanked out, or set to '0'.
        EGK 26-Jul-89     Changed the types of "TBX" and "TBY" to conform
                          to the new ones that allow running totals.
        KKC 09-Aug-89     Add copyright message.
        MWP 20-Aug-89     Large amount of changes to accomodate new Export
                          form.
        KKC 22-Aug-89     Prompt error message when user leaves the form
                          without filling in anything.
        KKC 28-Aug-89     Pass two extra dummies to DigestReportHolderRecord
                          and BuildReportHolderRecord.
        MWP  2-Sep-89     Use ColumnExportWidth for exporting resource data.
        LAA 12-Sep-89     Removed import of Holder (no longer used).
        MWP 14-Sep-89     Included support for exporting only Baseline data.
        MWP 22-Sep-89     If user is exporting Resource baseline data, check
                          for existence of baseline data first, then, if baseline
                          data exists, only output data for those records.
        MWP 27-Sep-89     Removed some unnecessary imports.
        MWP  9-Oct-89     Removed text literals.
        30-Mar-90 RSC     Made Timeu to Timei/TimeForm conversions.
        05-Jun-90 AJL     Removed imports of ARateCalendar.
        1-Oct-90  PFG     In case user edited a task column name, check to see
                          if the same name is in any other field.  If it is,
                          redisplay those fields correctly.
       19-Oct-90  AJL     Renumbered the phrases which tell which columns are
                          exported for the "All" and "Baseline" choices.
        7-May-91  TGS     Some phrases were renumbered to make room for more
                          resource columns.
        8-May-91  TGS     We were using MagicNum.RsrcLastColumn to tell
                          us how many columns could be on the Resource Table 
                          form. That worked as long as the number of resource
                          columns was less than the maximum number of columns
                          that could be in the Holder record. I've changed
                          things so we copy the Columns array values to a
                          Holder-compatible Columns array and vice versa,
                          so it doesn't get out of bounds. Changed some 
                          FOR loop bounds to RsrcLastColumn rather than
                          MaxReportColumns.
                          Got rid of some unused CONSTs.
        10-Jun-91 PFG   Call GetRsrcColumnName() to fix a problem where 
                        pressing ESC from a pick list after changing a 
                        column name, the data columns whose contents had been 
                        changed didn't get refreshed properly.
   *)

FROM Allocs         IMPORT
    (* TYPE *)              ATaskFilter, ATaskFilterSet;

FROM Captions       IMPORT
    (* TYPE *)              AColumnDataRecord, AColumnInfoChoice;

FROM Dialog         IMPORT
        (* PROCS *)         Burp, FatalError, Error;

FROM ExportLinkage  IMPORT
    (* VAR *)               InterFile,    InterFileOpen;

FROM FileSystem     IMPORT
        (* TYPE *)          File,    Response,
        (* PROCS *)         SetOpen, Create;

FROM FileAux        IMPORT
        (* PROCS *)         CheckIO;

FROM Filter1        IMPORT
        (* PROC *)          ResourceFiltersPassed;

FROM FlexStor       IMPORT
        (* TYPE *)          AnExtHandle,
        (* PROC *)          DiscardExtObject,
                            CopyExtObject, LockObject,
                            ReleaseUnchangedObject, ReleaseObject;

FROM Forms          IMPORT
        (* TYPE *)          AFieldValue, AForm, ACheckReason, AStringValue,
        (* PROCS *)         DoForm, ShowValue, SetFieldHidden,
                            SetFieldProtection;

FROM FormCon        IMPORT
    (* TYPE *)              AFieldType, AFieldNo;

FROM IntFileIO      IMPORT
    (* CONST *)             PredicateSubfileNumber,
                            TextType, AFormat, AFormatType,
                            HeadingRecordType, SkipRecordType,
                            AHeadingRecord, AnIntDataRecord,
    (* PROC *)              WriteIntData,
                            ConvertCaptionsToIntermediate;

FROM Keys           IMPORT
        (* CONST *)         EditKey, ExitKey;

FROM Kbio           IMPORT
        (* CONST *)         maxrow, maxcol;

FROM Layout         IMPORT
        (* CONST *)         GanttWStart, GanttWEnd;

FROM LStrings       IMPORT
        (* PROCS *)         CtoS, SetString, LJust, Copy, TrimRear, Procustes,
                            LStringToTString, SetLengthOf, LengthOf, ConcatLS,
                            TrimFront, StoC, Upshift, StringsEqual, Compare,
                            Fill;

FROM MagicNum       IMPORT 
                            RsrcLastColumn;

FROM MsgFile        IMPORT
        (* PROCS *)         GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays       IMPORT
        (* VAR *)           PackageOK,
        (* PROCS *)         OverlayContext;

FROM Progress       IMPORT
        (* TYPE *)          AThermometer,
        (* PROCS *)         CreateThermometer, UpdateThermometer,
                            DiscardThermometer;

FROM RecordIO       IMPORT
        (* PROCS *)         WriteRecord;

FROM RptCommon      IMPORT
        (* TYPES *)         AColumn, AGetInfoProc, ASummChoice,
        (* PROCS *)         GenerateFileTrailers, ColumnHeadings, ReleaseDialog,
                            GenerateFileHeaders,  DoDialog,
                            CreateTheFile, GetMessageWord, RsrcHeaders,
                            SetResourcesOnly, CommonCleanup,
                            DigestReportHolderRecord, BuildReportHolderRecord;

FROM RsrcColumns    IMPORT
        (* PROCS *)         CreateRsrcColumnsTree, DisposeRsrcColumnsTree,
                            PickRsrcColumn, SearchForRsrcColumn,
                            GetRsrcColumnName;

FROM RsrcFormat     IMPORT
        (* PROCS *)         GetRsrcValue, GetRsrcInfo;

FROM RsrcMod        IMPORT
        (* CONST *)         ResourceNameLength,
        (* TYPE  *)         AResourcePointer,
                            AResourceType, ACostStyle,
        (* VAR   *)         ResourceTree,
        (* PROC *)          CheckResourceValid;

FROM Subfiles       IMPORT
                            StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM         IMPORT
        (* THINGS *)        SIZE, ADR, ADDRESS;

FROM TempFile       IMPORT
    (* PROC *)              DeleteTempFile;

FROM TreeObjects    IMPORT
        (* TYPE *)          ATree, ATreeNode, ATreeOrder,
        (* PROCS *)         ValidateTree, ValidateTreeNode;

FROM Timei          IMPORT
        (* CONST*)          MinDate,
        (* TYPE *)          ADate, ADurationUnit;

FROM Words          IMPORT
        (* PROC *)          ParseString;



CONST   ModuleNumber    = 13800;  (* For GetMessage *)


        MAXCARDINAL     = 65535;
        MAXDATE         = MAXCARDINAL;


        (* DoDialog() message constants:   *)

        NoBsLnResources = 4; (* "There are no Resources." *)
        NoResources     = 5; (* "There are no Resources." *)

        (* Subfile IO version number:   *)

        VersionNumber  = 1; (* For subfiles *)

        MaxReportColumns = 12; (* How many columns can the report have? *)
        LastColNameField = 23;          (* 1-Oct-90 PFG *)

        (* Font constants for printing *)

        NormalFont = 0C;
        BoldFont   = 1C;

        OutputBaseline = 2;

VAR
    Columns                  : ARRAY [1..RsrcLastColumn] OF AColumn;
    HolderColumns            : ARRAY [1..MaxReportColumns] OF AColumn; (* 8-May-91 TGS *)
    Thermometer              : AThermometer;
    ResourcesOnly            : BOOLEAN;
    OutputAllRsrcInformation : BOOLEAN;                       (* 5-Jul-89 MWP *)
    ReportFormat             : CARDINAL;



 (* Column Data - Given a node, return a single data item.

        Preconditions  - Node   is a valid tree node that contains a
                                   Resource.
                         Column is the column number, one of the constants
                                   defined above.
                         Width  is the maximum width of the resulting
                                   (string) field.
        Postconditions - DataType is the returned data type.
                         TheData  is a record containing the returned item.
 *)
PROCEDURE ColumnData ( Node     : ATreeNode;
                       Column   : CARDINAL;
                       Width    : CARDINAL; (* for strings only. *)
                   VAR DataType : CARDINAL;
                   VAR TheData  : AnIntDataRecord;
                       Font     : CHAR );
VAR
    Value   : AColumnDataRecord;
BEGIN

    DataType := MAXCARDINAL;                                 (* 1-May-89 MWP *)
    TheData.Font := Font;           (* 5/30/89 EGK *)

    IF (GetRsrcValue( Node, Column, Value)) THEN
        ConvertCaptionsToIntermediate( Value, Width, DataType, TheData );
    END;

END ColumnData;







 (* GenerateOneResource - create the data records for one resource.

        Preconditions  - A valid resource node
        Postconditions - one or more data records have been written to the file.
 *)
PROCEDURE GenerateOneResourcesData( VAR ResourceNode : ATreeNode;
                                        Context      : ADDRESS    );
VAR
    DataType,
    Loop              : CARDINAL;
    Counter           : POINTER TO CARDINAL;
    Resource          : AResourcePointer;
    DataRecord        : AnIntDataRecord;
    FilterSet         : ATaskFilterSet;
    Font              : CHAR;
BEGIN
    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );

    IF (ResourcesOnly) THEN
        IF (Resource^.Type <> Employable) THEN
            RETURN;
        END;
    END;

    FilterSet := ResourceFiltersPassed(ResourceNode);
    IF (NOT ( Selected IN FilterSet )) THEN
        RETURN;
    END;

    IF ( ReportFormat = OutputBaseline ) THEN
            (* If they have asked for baseline information, but there isn't
               any, return. *)
        IF (NOT HasBaseLine(ResourceNode)) THEN
            RETURN;
        END;
    END;


    Font     := NormalFont;
    IF ((FilterSet * ATaskFilterSet{Highlight1..Highlight5}) <> ATaskFilterSet{}) THEN
        Font     := BoldFont;
    END;


    Counter := Context;
    INC(Counter^);
    UpdateThermometer( Thermometer, Counter^ );

    FOR Loop := 1 TO RsrcLastColumn DO (* 8-May-91 TGS *)
        IF (Columns[ Loop ].Width > 0) THEN
            ColumnData( ResourceNode,
                        Columns[ Loop ].ColumnNumber,
                        Columns[ Loop ].Width,
                        DataType,
                        DataRecord,
                        Font );
            IF (DataType = MAXCARDINAL) THEN
                WriteIntData( SkipRecordType, DataRecord );
            ELSE
                WriteIntData( DataType, DataRecord );
            END;
        END;
    END;
END GenerateOneResourcesData;







 (* *************************** FORM Related stuff ****************** *)




 (* Check The Form - Standard Form Check procedure.  *)

PROCEDURE CheckTheForm(    Form         : AForm;
                           FieldNo      : AFieldNo;
                       VAR FormValue    : ARRAY OF AFieldValue;
                           CheckReason  : ACheckReason;
                       VAR Code         : CARDINAL
                                                      ) : BOOLEAN;
VAR
    Column        : CARDINAL;
    i             : CARDINAL;
    Result        : BOOLEAN;
    NoName        : BOOLEAN;
    TmpString     : AStringValue;
    s             : ARRAY[0..255] OF CHAR;

    PROCEDURE ColumnSize( Column : CARDINAL ) : CARDINAL;
    VAR
        c, DfltWidth : CARDINAL;
        Format       : AFormat;
        s1, s2       : ARRAY [0..69] OF CHAR;
        b            : BOOLEAN;
    BEGIN
        ColumnHeadings( AGetInfoProc(GetRsrcInfo),
                        Column,
                        s1, s2,
                        s1, s2,
                        b,  b,  c,
                        Format,  DfltWidth );
        RETURN DfltWidth;
    END ColumnSize;

BEGIN
    Code   := 0;
    Result := TRUE;

    IF (CheckReason = CheckFormEntry) THEN
        IF ( ( FieldNo > 0 ) AND ( (FieldNo MOD 2) = 1 ) ) THEN
            NoName := (LengthOf( FormValue[FieldNo].CharValue^ ) = 0);
            SetFieldHidden(Form, FieldNo + 1, FormValue, NoName);
            SetFieldProtection(Form, FieldNo + 1, FormValue, NoName);
        END;
    ELSIF (CheckReason = CheckFieldKey) THEN

      (* Only allow F2 on a 'real' column field.  These are the string
         fields, 1,3,5,7,9,...
      *)
        IF ((FieldNo MOD 2) = 1) THEN
            Column := FormValue[ FieldNo ].CardValue;
            IF (PickRsrcColumn( maxcol-29, 3, maxcol, maxrow-10,
                                Column, FormValue[ FieldNo ].CharValue^ )) THEN
                FormValue[ FieldNo ].CardValue := Column;
                FormValue[ FieldNo+1 ].CardValue := ColumnSize( Column );
                SetFieldHidden(Form, FieldNo + 1, FormValue, FALSE);
                SetFieldProtection(Form, FieldNo + 1, FormValue, FALSE);
                ShowValue( Form, FieldNo+1, FormValue );

            END;

            (* In case column names were edited, update all column
                names on form.  Need to do this even if PickRsrcColumn
                returns FALSE, since the user may have changed some 
                column other than the highlighted one.  *)

            FOR i := 1 TO LastColNameField BY 2 DO
                IF FormValue[i].CardValue <> MAXCARDINAL THEN
                    GetRsrcColumnName(  FormValue[i].CardValue,
                                        FormValue[i].CharValue^);
                ELSE
                    Fill(FormValue[i].CharValue^, " ", 24);
                    FormValue[i + 1].CardValue := 0;
                END;
                ShowValue( Form, i, FormValue );
            END;

        ELSE
            Burp;
            Result := FALSE;
        END;

    ELSIF (CheckReason = CheckFieldChange) THEN
        IF ((FieldNo MOD 2) = 1) THEN
            TrimRear( FormValue[ FieldNo ].CharValue^ );
            IF (      FormValue[ FieldNo ].CharValue^[0] > 0C) THEN
                IF (SearchForRsrcColumn( FormValue[ FieldNo ].CharValue^, Column )) THEN
                    FormValue[ FieldNo   ].CardValue := Column;
                    FormValue[ FieldNo+1 ].CardValue := ColumnSize( Column );
                    ShowValue( Form, FieldNo+1, FormValue );
                ELSE
                    Burp;               (* 5/26/89 EGK *)
                    Result := FALSE;
                END;
            ELSE
                FormValue[ FieldNo ].CardValue := MAXCARDINAL;  (* 4/5/89 EGK *)
                FormValue[ FieldNo+1 ].CardValue := 0; (* No width *)
                ShowValue( Form, FieldNo+1, FormValue );
            END;
        END;
    ELSIF (CheckReason = CheckFieldExit) THEN
        IF  ( FieldNo > 0 ) THEN
            IF ( (FieldNo MOD 2) = 1 )  THEN
               Copy(FormValue[FieldNo].CharValue^, TmpString);
               TrimFront(TmpString);
               NoName := (LengthOf( TmpString ) = 0);
               SetFieldHidden(Form, FieldNo + 1, FormValue, NoName);
               SetFieldProtection(Form, FieldNo + 1, FormValue, NoName);
(***                                                                (* 20-Jul-89 KKC/MWP *)
            ELSE
               IF (FormValue[FieldNo].CardValue = 0 ) THEN
                  Burp ();
                  RETURN FALSE;
               END;
****)
            END;
        END;
    ELSIF (CheckReason = CheckFormExit) THEN
        Result := FALSE;
        FOR Column := 0 TO 11 DO
            Copy(FormValue[Column * 2 + 1].CharValue^, TmpString);
            TrimFront(TmpString);
            IF ( LengthOf( TmpString ) <> 0 ) THEN
                Result := TRUE;
            END;
        END;
        IF ( NOT Result ) THEN
            GetMessage( ModuleNumber + 42, s ); (* Please enter data *)
            Error(s);
        END;
        RETURN Result;
    END;

    RETURN Result;

END CheckTheForm;




 (* Do The Form - Ask the user for the desired columns for the report.
 *)
PROCEDURE DoTheForm() : BOOLEAN;

CONST
    FormID                  = 42;

VAR
    Loop, j, i : CARDINAL;
    FormValue  : ARRAY [0..(MaxReportColumns
                          + MaxReportColumns)] OF AFieldValue;
    Strings    : ARRAY [1..MaxReportColumns]   OF AStringValue;
    C          : CARDINAL;
    F          : AFormat;
    s          : ARRAY [0..255] OF CHAR;
    B          : BOOLEAN;
    ok         : BOOLEAN;


    PROCEDURE ColumnDigits ( Column : CARDINAL ) : CARDINAL;
    VAR
        c, DfltWidth : CARDINAL;
        Format       : AFormat;
        s1, s2       : ARRAY [0..69] OF CHAR;
        b            : BOOLEAN;
    BEGIN
        ColumnHeadings( AGetInfoProc(GetRsrcInfo),
                        Column,
                        s1, s2,
                        s1, s2,
                        b,  b,  c,
                        Format,  DfltWidth );
        RETURN ORD(Format.DecimalDigits);
    END ColumnDigits;


BEGIN
 (* Build a tree of column names for the GoTo lists. *)

    IF (NOT CreateRsrcColumnsTree()) THEN
        RETURN FALSE;
    END;

 (* Fill in the starting data for the field. *)

    FormValue[0].CardValue := ORD(NOT ResourcesOnly);

    j := 0;
    FOR Loop := 1 TO (MaxReportColumns + MaxReportColumns) BY 2 DO
        INC(j);
        FormValue[Loop+1].CardValue   := Columns[ j ].Width;
        FormValue[Loop+1].CharValue := NIL;
        WITH FormValue[Loop] DO
            CharValue    := ADR(Strings[j]);
            IF ( Columns[j].ColumnNumber <> MAXCARDINAL ) THEN     (* 21-Jul-89 KKC/MWP *)
                ColumnHeadings( AGetInfoProc(GetRsrcInfo),
                                Columns[ j ].ColumnNumber,
                                s, CharValue^, s, s, B, B, C, F, C );
            ELSE
                CharValue^[0] := 0C;
            END;
            CardValue := Columns[ j ].ColumnNumber;
        END;
    END;

 (* Do the form.  If ESC is hit, don't do the report. *)

    ok := (DoForm(0, GanttWEnd, maxcol, maxrow-1, FormID, TRUE, FormValue, CheckTheForm) = ExitKey);

    DisposeRsrcColumnsTree();

    IF (ok) THEN
        ResourcesOnly := (FormValue[ 0 ].CardValue = 0);
        j := 0;

        FOR Loop := 1 TO (MaxReportColumns + MaxReportColumns) BY 2 DO
            TrimRear( FormValue[Loop].CharValue^);                 (* 21-Jul-89 KKC/MWP *)
            IF ( LengthOf ( FormValue[ Loop ].CharValue^) > 0 ) THEN
               INC(j);
               Columns[ j ].ColumnNumber := FormValue[Loop  ].CardValue;
               Columns[ j ].Width := FormValue[Loop+1].CardValue;
               Columns[ j ].Decimals := ColumnDigits (FormValue[Loop].CardValue);
            END;
        END;

        (* Fill out the rest of the Columns array... *)
        FOR i := j + 1 TO RsrcLastColumn DO (* 8-May-91 TGS *)
            Columns[ i ].Width := 0;
            Columns[ i ].ColumnNumber := MAXCARDINAL;
        END;
    END;

    RETURN ok;  (* TRUE means 'continue'.  FALSE means 'stop'. *)

END DoTheForm;


PROCEDURE HasBaseLine(  VAR ResourceNode : ATreeNode ) : BOOLEAN;
VAR
    Resource          : AResourcePointer;
BEGIN
    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );

    RETURN (Resource^.BaseLineRates <> AnExtHandle(NIL));
END HasBaseLine;


PROCEDURE CheckForBsLn ( VAR ResourceNode : ATreeNode;
                             Context      : ADDRESS    );
VAR
    BaseFound         : POINTER TO BOOLEAN;
BEGIN
    BaseFound := Context;

    IF (HasBaseLine(ResourceNode)) THEN
        BaseFound^ := TRUE;
    END;


END CheckForBsLn;



 (* Do the TLRTable report.
 *)
PROCEDURE DoTLRTable();
VAR
    Rows,
    Loop,
    ID                  : CARDINAL;
    P                   : POINTER TO ARRAY [0..255] OF CHAR; (* Overlay Context *)
    s,
    ProgramName         : ARRAY [0..19] OF CHAR;
    Copyright           : ARRAY[0..50] OF CHAR;
    dummy               : BOOLEAN;


    PROCEDURE Setup() : BOOLEAN;
    VAR
        SD, ED       : ADate;
        Period       : ADurationUnit;
        Norm         : BOOLEAN;
        DatesEntered : BOOLEAN;
        TBX, TBY     : ASummChoice;
    BEGIN
        SetString(ProgramName, "TLRTABLE" );

        DigestReportHolderRecord( ProgramName, HolderColumns,
                                  SD, ED, Period, Norm, TBX, TBY,
                                  DatesEntered, ResourcesOnly,
                                  dummy, dummy );

        FOR Loop := 1 TO MaxReportColumns DO
            Columns[Loop] := HolderColumns[Loop];
        END;

        (* Validate the resource tree.  Insure that there ARE some resources. *)

        ValidateTree(ResourceTree);
        IF (ResourceTree^.Methods^.GetFirst( ResourceTree ) = NIL) THEN
            DoDialog( ModuleNumber + NoResources, TRUE );
            RETURN FALSE;
        END;

        IF (NOT DoTheForm()) THEN
            RETURN FALSE;
        END;

        RETURN TRUE;

    END Setup;

    PROCEDURE AnyBaselineRsrcData () : BOOLEAN;
    VAR
        BaseFound           : BOOLEAN;
    BEGIN

        BaseFound := FALSE;

        ResourceTree^.Methods^.TraverseTree ( ResourceTree, ParentBeforeChild,
                                              9999, CheckForBsLn,
                                              ADR(BaseFound) );
        RETURN ( BaseFound );

    END AnyBaselineRsrcData;




    PROCEDURE SetupAll() : BOOLEAN;
    VAR
        i, j,
        CaptionLine, CountOfColumns,
        WhichCol       : CARDINAL;
        ok             : BOOLEAN;
        s, s1          : ARRAY [0..9] OF CHAR;
        DataRecord     : AColumnDataRecord;
    BEGIN

        (* Validate the resource tree.  Insure that there ARE some resources. *)

        ValidateTree(ResourceTree);
        IF (ResourceTree^.Methods^.GetFirst( ResourceTree ) = NIL) THEN
            DoDialog( ModuleNumber + NoResources, TRUE );
            RETURN FALSE;
        END;

        FOR i := 1 TO HIGH(Columns) DO
            Columns[ i ].Width := 0;  (* for RptCommon *)
        END;

        IF ( ReportFormat = 1 ) THEN   (* All fields. *)
            GetMessageWord( ModuleNumber + 95, 0, s );
            CaptionLine := ModuleNumber + 96;
        ELSE                           (* Baseline fields. *)
            IF ( NOT AnyBaselineRsrcData () ) THEN
               DoDialog ( ModuleNumber + NoBsLnResources, TRUE );
               RETURN FALSE;
            END;

            GetMessageWord( ModuleNumber + 95, 1, s );
            CaptionLine := ModuleNumber + 97;
        END;

        j := 1;

        CountOfColumns := StoC ( s, j );

        FOR i := 1 TO CountOfColumns DO
            WITH Columns[i] DO

               GetMessageWord( CaptionLine, i, s );

               j := 1;

               WhichCol := StoC ( s, j );

               ok := GetRsrcInfo( WhichCol,                         (* 2-Sep-89 MWP *)
                                  ColumnExportWidth,
                                  0,
                                  DataRecord );

                IF (NOT ok) THEN
                    FatalError();
                END;  (* too few? *)

                Width        := DataRecord.CardinalValue;
                ColumnNumber := WhichCol;

                ok := GetRsrcInfo( WhichCol, ColumnMaxDecimals, 0, DataRecord );
                Decimals     := DataRecord.CardinalValue;
            END;
        END;

        RETURN TRUE;

    END SetupAll;


    PROCEDURE GenerateData();
    VAR
        Count        : CARDINAL;
        ok           : BOOLEAN;
        s            : ARRAY [0..69] OF CHAR;
    BEGIN
        SetResourcesOnly( ResourcesOnly );

        IF ( ReportFormat = OutputBaseline ) THEN
            Rows := RsrcHeaders( ModuleNumber, 1, FALSE, TRUE);
        ELSE
            Rows := RsrcHeaders( ModuleNumber, 1, FALSE, FALSE);
        END;

        IF (CheckIO( InterFile ) <> done) THEN RETURN; END;
        GetMessage( ModuleNumber + 6, s ); (* "Resources' data generated" *)
        ok := CreateThermometer( Thermometer, 0, 0, s, Rows );

        (* Generate the data section of the file. *)

        StartSubfileOutput( InterFile, PredicateSubfileNumber + 2, VersionNumber );
        IF (CheckIO( InterFile ) = done) THEN
            Count := 0;  (* For Thermometer *)
            ResourceTree^.Methods^.TraverseTree(ResourceTree,ParentBeforeChild,
                                            9999, GenerateOneResourcesData, ADR(Count));
        END;
        DiscardThermometer ( Thermometer );
        IF (CheckIO( InterFile ) <> done) THEN RETURN; END;
        EndSubfileOutput( InterFile, PredicateSubfileNumber + 2 );
    END GenerateData;


    PROCEDURE  OutputAllInformation () : BOOLEAN;
    VAR
        s1,
        s2,
        s3         : ARRAY [0..9] OF CHAR;
        Loop, j    : CARDINAL;
        ret_rsvp   : BOOLEAN;
    BEGIN

        P := OverlayContext();                                        (* 1-May-89 MWP *)

        IF (P = NIL) THEN
            FatalError();
        END;

        Loop := 1;

        ParseString( P^, Loop, s1 );

        GetMessage ( ModuleNumber + 7, s2 );
        (* "EXPORT" *)

        IF ( Compare ( s1, s2 ) <> 0 ) THEN
           RETURN FALSE;
        END;

        ParseString( P^, Loop, s1 );

        j := 1;

        ReportFormat := StoC ( s1, j );

        IF ( ReportFormat = 1 ) OR ( ReportFormat = 2 ) THEN
            RETURN TRUE;
        END;

        RETURN FALSE;

    END OutputAllInformation;


BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    PackageOK := FALSE;  (* In case we terminate early. *)
    dummy := FALSE;

    SetLengthOf (s,0);

    (* Create the first part of the file (the non-data part) *)


    OutputAllRsrcInformation := OutputAllInformation ();


    IF ( NOT OutputAllRsrcInformation ) THEN
       IF (NOT Setup ()) THEN
           RETURN;
       END;
    ELSE
       IF (NOT SetupAll ()) THEN
           RETURN;
       END;
    END;

    IF ( NOT CreateTheFile ( s ) ) THEN
        RETURN;
    END;

    SetLengthOf (s,0);                                           (* 20-Jul-89 KKC/MWP *)

    IF (GenerateFileHeaders( AGetInfoProc(GetRsrcInfo),
                             ModuleNumber + 9,  (* OverallPhrase         *)
                             2,                 (* PredicateHeadingDepth *)
                             ModuleNumber + 40, (* DomainBase            *)
                             Columns,
                             s
                               )) THEN

        GenerateData();

        (* Clean up the file and exit.  Do not close the file! *)

        IF ((CheckIO( InterFile ) = done) AND GenerateFileTrailers()) THEN
            PackageOK := TRUE;  (* Tell mom that we're OK down here. *)
        END;
    END;

    CommonCleanup();

    IF ( NOT OutputAllRsrcInformation ) THEN
        FOR Loop := 1 TO MaxReportColumns DO
            HolderColumns[Loop] := Columns[Loop];
        END;
        BuildReportHolderRecord( ProgramName, HolderColumns,
                                 MinDate, MinDate, Days, FALSE, None, 
                                 None, FALSE,
                                 ResourcesOnly, dummy, dummy );
    END;

    IF (NOT PackageOK) AND (InterFileOpen) THEN     (* 3/17/89 EGK *)
        DeleteTempFile (InterFile);
        InterFileOpen := FALSE;
    END;

END DoTLRTable;




BEGIN
    OutputAllRsrcInformation := FALSE;                               (* 5-Jul-89 MWP *)
    ResourcesOnly            := FALSE;
    ReportFormat             := 0;

    DoTLRTable();

END TLRTable.
