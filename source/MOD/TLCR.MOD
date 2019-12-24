MODULE TLCr;  (* COST REPORTS *)


  (* Cost report: Task vs Time

        MODIFICATION HISTORY:

                RSC  11/25/87  First version with new interpass file.
                RSC   2/24/88  Detect break key.
                RSC   2/26/88  Remove "Units" Column.
                RSC   6/16/88  Remove "One moment" box so thermometers work.
                LAA 21-Dec-88  Changed imports for Lazlo reorganization.
                RSC  2-Jan-89  Changed references to Compare() to StringsEqual().
                RSC 10-Jan-89  Changed references to Storage to Space.
                RSC  2-Feb-89  Changed ParseCallChain to ParseString.
                RSC  6-Feb-89  Change "ExportersOK" to "PackageOK"
        EGK 17-Mar-89     Put more checking into DoTLCR to make sure
                          we don't leave the temp file open if the back
                          end (which would close it) isn't going to run.
       22-Mar-89 RSC  Improve for "Better Reports" project.  Use XTabFormat
                      rather than RptCommon routines.
       24-May-89 LAA  Removed some of the constants imported from MagicNumbers
                      because they were renamed there from "Man" to "Work",
                      but are not used here.
       19-Jul-89 KKC  Pass new parameter ClientUse to TLCRForm.
       09-Aug-89 KKC  Add copyright message.
       28-Aug-89 KKC  Set different form id for each cross tab form.
       12-Sep-89 LAA  Removed import of Holder (no longer needed).
       09-Oct-89 MWP  Removed text literals.
       21-Feb-90 KKC  Remove import of Timeu.
       22-Aug-90 TGS  Changed references to some phrases to make room for 
                      more XTab column phrase nums ( "ModNum + 7?" & "+ 8?").
       29-Oct-90 AJL  Import numbers from XTabColNumbers instead of MagicNumbers.
       26-Mar-91 RSC  Remove unused imports.
       10-May-91 RSC  Make global items local for overlay calling.
  *)

FROM Allocs        IMPORT
    (* VAR   *)         TaskTree;

FROM Dialog        IMPORT
        (* PROCS *)     FatalError;

FROM ExportLinkage IMPORT
    (* VAR *)           InterFile,    InterFileOpen;

FROM FileSystem    IMPORT
        (* TYPE *)      Response;

FROM FileAux       IMPORT
        (* PROCS *)     FileResultMeans, FlushBuffer, PrepareForIO, CheckIO;

FROM IntFileIO     IMPORT
    (* CONST *)         OverallSubfileNumber, PredicateSubfileNumber,
                        TextType, RealNumberType, IntegerType,
                        CardinalType, BooleanType, BigStartTimeType,
                        PredicateRecordType, EnumeratedType, BigEndTimeType,
                        HeadingRecordType, SkipRecordType,
                        RepeatRecordType, AggregatorRecordType,
    (* TYPE *)          AFont, ADataType, AnOverallRecord,
                        APredicateHeadingRecord, ADomainRecord,
                        APredicateRecord, AFormatType, AFormat,
                        AnAggType, AnAggregatorRecord,
                        AHeadingRecord, AnIntDataRecord,
    (* PROC *)          WriteIntData, ReadIntData;

FROM Kbio          IMPORT
    (* PROC *)          BreakRequested;

FROM LStrings      IMPORT
        (* PROCS *)     CtoS, SetString, LJust, Copy, TrimRear, Procustes,
                        Upshift, StringsEqual,
                        LStringToTString, SetLengthOf, LengthOf, ConcatLS;

FROM XTabColNumbers IMPORT
    (* CONST *)         XTabBaseLineOffset,
                        XTabLastColumn;

FROM MsgFile       IMPORT
    (* PROC *)          GetMessage;

FROM Overlays      IMPORT
        (* VARS  *)     PackageOK,
        (* PROCS *)     OverlayContext, CallOverlayWithContext;

FROM RptCommon     IMPORT
        (* TYPES *)     AColumn, AnOverlayInterface, AReportType,
                        AGetInfoProc, AClientUse,
        (* VARS  *)     TotalByX, TotalByY,
        (* PROCS *)     GenerateFileTrailers, ColumnHeadings, ReleaseDialog,
                        GenerateFileHeaders,  DoDialog,
                        CreateTheFile, GetMessageWord, TaskHeaders,
                        TimeHeaders, CommonCleanup, RsrcHeaders,
                        BuildReportHolderRecord, DigestReportHolderRecord;

FROM RsrcMod       IMPORT
        (* VAR   *)     ResourceTree;

FROM Space         IMPORT
        (* PROCS *)     ALLOCATE, DEALLOCATE;

FROM Subfiles      IMPORT
        (* PROCS *)     StartFileOutput,    EndFileOutput,
                        StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM        IMPORT
        (* THINGS *)    SIZE, TSIZE, ADDRESS, ADR;

FROM TempFile      IMPORT
    (* PROC *)          DeleteTempFile;

FROM TreeObjects   IMPORT
        (* TYPE *)      ATree, ATreeNode, ATreeOrder,
        (* PROCS *)     ValidateTree, ValidateTreeNode;

FROM Words         IMPORT
        (* PROC *)      ParseString;

FROM XTabFormat    IMPORT
        (* PROC *)      GetXTabInfo;



CONST   ModuleNumber    = 21400;  (* For GetMessage *)


        MAXCARDINAL     = 65535;
        MAXDATE         = MAXCARDINAL;
        Zero            = 0.0;
        TaskVsTimeForm      =   44;
        TaskVsResourceForm  =   69;
        ResourceVsTimeForm  =   70;


        (* DoDialog() message constants:   *)

        NoResources    = 5; (* "There are no Resources." *)
        Computing      = 7; (* "We are computing ..." *)

        MaxReportColumns = 1; (* How many we allow across the page. *)





 (* Do The Form - Ask the user for the desired columns for the report.
 *)
PROCEDURE DoTheForm( VAR Interface : AnOverlayInterface ) : BOOLEAN;
VAR
    s : ARRAY [0..9] OF CHAR;
BEGIN

    SetString( s, "TLCRFORM" );

    RETURN (CallOverlayWithContext( s, ADR( Interface ) ) AND
            Interface.OverlayOK );

END DoTheForm;







 (* Do The Work - Generate the data to the file via a helper overlay.
 *)
PROCEDURE DoTheWork( VAR Interface : AnOverlayInterface );
VAR
    s         : ARRAY [0..9] OF CHAR;
    ok        : BOOLEAN;
BEGIN

    SetString( s, "TLCRWORK" );

    ok := CallOverlayWithContext( s, ADR( Interface ) );

END DoTheWork;







 (* Do a TLCr report.
 *)
PROCEDURE DoTLCr();
VAR
    Interface           : AnOverlayInterface;
    PColumns            : ARRAY [1..MaxReportColumns] OF AColumn;

    OverallPhrase,
    DomainBase          : CARDINAL;
    ProgramName         : ARRAY [0..9] OF CHAR; (* TvsT, RvsT, TvsR *)
    s                   : ARRAY [0..40] OF CHAR;
    Copyright           : ARRAY[0..50] OF CHAR;


    PROCEDURE Setup( VAR OverallPhrase, DomainBase : CARDINAL ) : BOOLEAN;
    VAR
        Size,
        Class,
        Loop       : CARDINAL;
        P          : POINTER TO ARRAY [0..255] OF CHAR; (* Overlay Context *)
        s1,
        s2,
        s3         : ARRAY [0..9] OF CHAR;
        NewColumns : BOOLEAN;
        Client     : ARRAY [0..1] OF CHAR; (* 'H', 'C' *)
    BEGIN
        WITH Interface DO
            P := OverlayContext(); (* Get device to put file on, and report type *)
            IF (P = NIL) THEN
                FatalError();
            END;
            Loop := 1;
            ParseString( P^, Loop, ProgramName ); (* TvsR, TvsT, RvsT, Rsrc *)
            Upshift( ProgramName );

            (*
            SetString(s1, "TVSR" );  (* Task vs Rsrc report? *)
            SetString(s2, "TVST" );  (* Task vs Time report? *)
            SetString(s3, "RVST" );  (* Rsrc vs Time report? *)
            *)

            GetMessage (ModuleNumber+91, s1);                     (* 9-Oct-89 MWP *)
            GetMessage (ModuleNumber+92, s2);
            GetMessage (ModuleNumber+93, s3);

            IF (StringsEqual(s1,ProgramName)) THEN
                PReportType   := TvsR;                   (* Task vs. Resource *)
                OverallPhrase := ModuleNumber +  9;
                DomainBase    := ModuleNumber + 70;
                WhichForm     := TaskVsResourceForm;
            ELSIF (StringsEqual(s2,ProgramName)) THEN
                PReportType   := TvsT;                   (* Task vs. Time     *)
                OverallPhrase := ModuleNumber + 72;
                DomainBase    := ModuleNumber + 73;
                WhichForm     := TaskVsTimeForm;
            ELSIF (StringsEqual(s3,ProgramName)) THEN
                PReportType   := RvsT;                   (* Resource vs. Time *)
                OverallPhrase := ModuleNumber + 75;
                DomainBase    := ModuleNumber + 76;
                WhichForm     := ResourceVsTimeForm;
            ELSE
                FatalError(); (* Bad tlwhat.cfg *)
            END;

            Class := 0;

            (* Validate the two trees.  Insure that there ARE some things. *)

            ValidateTree(ResourceTree);
            ValidateTree(TaskTree);
            IF (ResourceTree^.Methods^.GetFirst( ResourceTree ) = NIL) OR
               (    TaskTree^.Methods^.GetFirst(     TaskTree ) = NIL) THEN
                DoDialog( ModuleNumber + NoResources, TRUE );
                RETURN FALSE;
            END;

            DigestReportHolderRecord( ProgramName, PColumns,
                                      TheStartDate, TheEndDate,
                                      Period, Normalize,
                                      TotalByX, TotalByY, DatesEntered,
                                      ResourcesOnly, CostTracking,
                                      FillValuesOnScreen );

            (* Set up the interface context. *)

            Columns                 := ADR(PColumns);
            PModuleNumber           := ModuleNumber;
            PBaseLineOffset         := XTabBaseLineOffset;
            PLastColumn             := XTabLastColumn;
            PMaxReportColumns       := MaxReportColumns;
(*                                          (* KKC Aug 27, 89 *)
            ShortForm               := (PReportType = TvsR); (* No date fields *)
*)
            OverlayOK               := FALSE;
            PNeedActualAssignment   := FALSE;
            PNeedBaseAssignment     := FALSE;

            ParseString( P^, Loop, s1 ); (* Default disk to use. *)

            ParseString( P^, Loop, Client ); (* ClientUse. *)

            IF (Client[1] = 'H' ) THEN
                ClientUse := Histogram;
            ELSE
                ClientUse := CrossTab;
            END;

            IF (NOT DoTheForm(Interface)) THEN
                RETURN FALSE;
            END;

            IF (NOT CreateTheFile( s1 )) THEN
                RETURN FALSE;
            END;

        END;
        RETURN TRUE;
    END Setup;


BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    PackageOK := FALSE;  (* In case we terminate early. *)

    IF (NOT Setup( OverallPhrase, DomainBase )) THEN (* Trouble getting going? *)
        RETURN;
    END;

    (* Create the first part of the file (the non-data part) *)

    IF (Interface.Normalize) THEN
        GetMessage (ModuleNumber+90, s);        (* "hourly rate of " *)
    ELSE
        SetLengthOf (s,0);
    END;
    IF (GenerateFileHeaders( AGetInfoProc(GetXTabInfo),
                             OverallPhrase,
                             2,  (* PredicateHeadingDepth *)
                             DomainBase,
                             PColumns,
                             s
                            )) THEN

        DoTheWork(Interface);

            (* If all is ok, clean up the file and exit.
               Do not close the file!
            *)

        IF (CheckIO( InterFile ) = done) AND
           (NOT BreakRequested())        AND
           (GenerateFileTrailers())      THEN
            PackageOK := TRUE;  (* Tell mom that we're OK down here. *)
        END;
    END;

    CommonCleanup();
    WITH Interface DO
        BuildReportHolderRecord( ProgramName, PColumns,
                                 TheStartDate, TheEndDate,
                                 Period, Normalize,
                                 TotalByX, TotalByY, DatesEntered,
                                 ResourcesOnly, CostTracking,
                                 FillValuesOnScreen );
    END;

    IF (NOT PackageOK) AND (InterFileOpen) THEN     (* 3/17/89 EGK *)
        DeleteTempFile (InterFile);
        InterFileOpen := FALSE;
    END;

END DoTLCr;




BEGIN

    DoTLCr();

END TLCr.

