MODULE TLXPorts;

  (* Universal exporting driver.

        RSC 6/16/88
        EGK 6/27/88  Added first-time flag stuff.
        RSC 10/31/88 Changed meaning of "ExportersOK" flag:
                     It is now used as a signal from the front end as to
                     wether to call the back end or not.  This way, if
                     one front/back pair fails, we still go on.
                     Bug # 8396
        EGK 2/2/89   Added capability to run a back-end initializer overlay.
                     This is defined in phrases, and is run once before the
                     main export loop.  Removed "first time flag" stuff.
        RSC 6-Feb-89 Change "ExportersOK" to "PackageOK".
        EGK 12-Apr-89 Change XTabBaseOffset to 9 (from 10).  Back ends are
                      now indexed from 1, not 0.
        MWP  5-Jul-89 Import "IsImportable" from ExportLinkage. Used to
                      tell back ends if the user may want to re-import
                      the data.
        MWP 11-Jul-89 If calling WBS verification routines, tell them NOT
                      to highlight!
        KKC 09-Aug-89 Add copyright message.
        MWP 20-Aug-89 Large amount of changes to accomodate new Export
                      form.
        MWP 11-Aug-89 Change front end message to show file we are exporting to.
        LAA 12-Sep-89 Removed import of Holder (no longer used).
        WKH 19-Jan-90 Put form in rsrvd layer.
        RSC  9-Apr-91 Made the driver table and WBS Context be on the heap
                      (well, STACK for WBS context).
                      When they were global memory, the global memory was
                      being used in overlays that overlayed this one.
                      Also, allow parens in context so that we can call
                      front ends THROUGH an overlay.
        TGS 24-Apr-91 Call the form mentioned in TLWHAT instead of hard-coded
                      "TLXFORM", since this will do the new Export Cross Tabs
                      setup as well.
  *)

FROM Allocs         IMPORT
    (* CONST *)             WBSLine, WBSLen,
    (* PROC *)              GetCodingField, SetCodingField,
    (* TYPE *)              ATaskPtr,
    (* VAR  *)              TaskTree;


FROM Boxes          IMPORT
    (* TYPE *)              ABoxAttribute, ABoxType,
    (* PROCS *)             DrawBox;

FROM Dialog         IMPORT
    (* TYPE *)              ADialogOption,
    (* PROC *)              MultipleChoiceBox, FatalError, Error;

FROM ExportLinkage  IMPORT
    (* VAR *)               InterFile, InterFileOpen, ExportMedia, ExportName,
                            IsImportable;
FROM FileSystem     IMPORT
    (* PROCS *)             Delete;

FROM Kbio           IMPORT
    (* TYPE *)              ascreenx, ascreeny, avidmode,
    (* PROCS *)             PutString, BreakRequested, ClearBreak;

FROM LStrings       IMPORT
    (* PROCS *)             Procustes, TrimRear, SetString, ConcatS, ConcatLS,
                            StoC, Copy, LengthOf, SetLengthOf, CtoS;

FROM Menus          IMPORT
    (* PROCS *)             WordNumber;

FROM MsgFile        IMPORT
    (* PROCS *)             ConcatMessage, GetMessage;

FROM Overlays       IMPORT
    (* VARS *)              PackageOK,
    (* PROC *)              CallOverlayWithContext, OverlayContext,
                            OverlayCallChain;

FROM Rugs           IMPORT
    (* TYPE *)              ARug,
    (* PROCS *)             GetRug, PutRug;

FROM Space          IMPORT
    (* PROC *)              Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM         IMPORT
    (* THING *)             ADR, ADDRESS, TSIZE;

FROM TempFile       IMPORT
    (* PROCS *)             DeleteTempFile;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder, ATree;

FROM XPorTable      IMPORT
    (* TYPE *)              ADriverTable;

FROM WBSCommon      IMPORT
    (* TYPE *)
                            AWBSError,
                            AWBSErrorSet,
                            MaxWbsLen,
    (* VAR *)               AContextRecord;

CONST
    ModuleNumber      = 24600;
    XFormModuleNumber = 24200;  (* Module # of TLXForm.Mod *)

    (* Box co-ordinates: *)
    Uly =  5;
    Lry = 11; (* top, bottom, shadow, 2 white-space lines, 2 text lines. *)
    Ulx = 10;
    Lrx = 70;

VAR
    Rug                  : ARug;
    DriverTable          : POINTER TO ADriverTable; (* 9-Apr-91 RSC  *)
    BackEndMessageX,
    FrontEndMessageX     : ascreenx;
    BackEndMessageY,
    FrontEndMessageY     : ascreeny;
    BackEndMessageL,
    FrontEndMessageL,
    FrontEndMessageStart : CARDINAL;
    RugTaken             : BOOLEAN;

    BackEndPhrase,
    CollectingPhrase  : ARRAY [0..79] OF CHAR;

    BlanksFound             : BOOLEAN;


  (* Call the overlay to fill in the structure that drives the calling
     of overlays.
  *)
PROCEDURE FillInTable( VAR DriverTable : ADriverTable );
VAR
    ok      : BOOLEAN;
    Overlay : POINTER TO ARRAY [0..39] OF CHAR;

BEGIN

    Overlay := OverlayContext();
    DriverTable.Entries := 0;

    ok := CallOverlayWithContext( Overlay^, ADR(DriverTable) );

    PackageOK := PackageOK AND ok AND (DriverTable.Entries > 0);

END FillInTable;



  (* Start the dialog box:
  *)
PROCEDURE StartBox( VAR DriverTable : ADriverTable );
CONST
    XTabBaseOffset      = 9;        (* From phrases *)
VAR
    AllIsCool : BOOLEAN;
    i         : CARDINAL;
    s         : ARRAY [0..255] OF CHAR;
    Title     : ARRAY [0..79]  OF CHAR;
BEGIN
    RugTaken := GetRug(Ulx, Uly, Lrx, Lry, Rug);
    IF (RugTaken) THEN

    (* Build the phrases needed for the running of the overlays.  There are
       two lines of text in a box.  The look something like this:
            -----------------------------------------------------
            |                                                   |
            |  Exporting: Task Table Report                     |
            |  Generating DBASE III Output                      |
            |                                                   |
            -----------------------------------------------------

         Line 1 cycles between all the front ends.
         Line 2 cycles between "Collecting data" and "Generating xxx Output".
      *)
        GetMessage( ModuleNumber + 1, Title ); (* "Export progress" *)
        DrawBox( Ulx, Uly, Lrx, Lry, ABoxType{SingleBox,ShadowBox},Title,videonormal);

        GetMessage( ModuleNumber + 2, s ); (* "Exporting:" *)
        PutString( s, Ulx + 2, Uly + 2, videonormal );
        FrontEndMessageX := Ulx + 2 + ORD(s[0]);
        FrontEndMessageY := Uly + 2;
        FrontEndMessageL := Lrx - 3 - FrontEndMessageX;
        BackEndMessageX  := Ulx + 2;
        BackEndMessageY  := Uly + 3;
        BackEndMessageL  := Lrx - 3 - BackEndMessageX;
        GetMessage( ModuleNumber + 3, CollectingPhrase ); (* "Collecting Data" *)
        Procustes( CollectingPhrase, BackEndMessageL );
        GetMessage( ModuleNumber + 4, BackEndPhrase    ); (* "Generating ~" *)
        GetMessage( XFormModuleNumber + XTabBaseOffset + DriverTable.BackEndNumber, s );    (* 4/12/89 EGK *)
        (* "Lotus 1-2-3/Symphony/Quattro/DBase III/CSV/..." *)
        WordNumber( s, 1, Title );
        ConcatLS( BackEndPhrase, Title );
        ConcatMessage( BackEndPhrase, ModuleNumber + 5 ); (* "~ Output" *)
        Procustes( BackEndPhrase, BackEndMessageL );

        (* Get the number of "Back ends" so we can get the starting
           "Front End" phrase.
        *)
        GetMessage( XFormModuleNumber + 9, s ); (* "4,7" *)
        WordNumber( s, 1, Title );
        i := 1;
        FrontEndMessageStart := XFormModuleNumber + 10 + StoC( Title, i );
    END;
END StartBox;





  (* Export loop.  Call the front ends, one at a time, calling the
                   (one) backend for each of the front ends.
  *)
PROCEDURE ExportData( VAR DriverTable : ADriverTable );
VAR
    i       : CARDINAL;
    AllIsCool,
    ok      : BOOLEAN;
    CancelExport : BOOLEAN;
    s            : ARRAY [0..3] OF CHAR;

    (* Update the message box with the latest info. *)

    PROCEDURE UpdateStatus( i : CARDINAL );
    VAR
        s, s1 : ARRAY [0..79] OF CHAR;
    BEGIN
        GetMessage( FrontEndMessageStart + i, s );
        WordNumber( s, 1, s1 );

        GetMessage( ModuleNumber + 9, s );
        ConcatLS ( s1, s );                                   (* 11-Sep-89 MWP *)
        ConcatLS ( s1, ExportName );

        Procustes( s1, FrontEndMessageL );
        PutString( s1, FrontEndMessageX, FrontEndMessageY, videobright );
    END UpdateStatus;

    (* Close the interpass file.  To do this, we need to reconstruct the
       file name.   Ugh.
    *)
    PROCEDURE CloseTempFile();
    BEGIN
        IF (InterFileOpen) THEN (* Terminate with file open? *)
            DeleteTempFile( InterFile );
            InterFileOpen := FALSE;
        END;
    END CloseTempFile;

BEGIN
    WITH DriverTable DO                             (* 2/2/89 EGK *)
        IF (LengthOf (BackEndInit) > 0) THEN
            PackageOK := TRUE;
            IF (NOT CallOverlayWithContext (BackEndInit, NIL)) OR (NOT PackageOK) THEN
                RETURN;
            END;
        END;
    END;

    IsImportable := FALSE;

    WITH DriverTable DO
       IF ( ReImport ) THEN
           i := 1;
           WITH DriverTable DO
               WHILE (i <= Entries) DO
                  IF ( Drivers[ i ].ReImportable ) THEN
                     IsImportable := TRUE;
                  END;
                  INC(i);
               END;
           END;
       END;
    END;

    CancelExport := TRUE;

    IF ( IsImportable ) THEN
       CancelExport := VerifyTasks();
    END;

    IF ( CancelExport ) THEN
       StartBox( DriverTable );
       i := 1;
       WITH DriverTable DO
           Copy( FileDir, ExportMedia );
           AllIsCool := TRUE;
           WHILE ( i <= Entries ) AND
                 ( AllIsCool ) DO

               PackageOK := TRUE;      (* RSC 10/31/88 added this line           *)

               IF ( BreakRequested () ) THEN
                  ClearBreak ();
                  AllIsCool := StopExport ();
               END;

               IF ( Drivers[ i ].FileToUse[0] <> 0C ) AND
                  ( AllIsCool ) THEN
                   Copy( Drivers[ i ].FileToUse, ExportName );
                   TrimRear( ExportName );
                   ConcatS(  ExportName, "." );
                   ConcatLS( ExportName, FileExt );
                   PutString( CollectingPhrase, BackEndMessageX, BackEndMessageY, videonormal );
                   UpdateStatus( i );

                        (* 9-Apr-91 RSC Allow parens in context
                        *)
                   WITH Drivers[i] DO
                       IF (ReImportable) THEN
                          CtoS(ReportFormat, s );
                          IF (FrontContext[LengthOf(FrontContext)] = ")") THEN
                              FrontContext[LengthOf(FrontContext)] := " ";
                              ConcatLS(FrontContext, s );
                              ConcatS( FrontContext, ")" );
                          ELSE
                              ConcatS( FrontContext, " " );
                              ConcatLS(FrontContext, s );
                          END;
                       END;
                   END;


                   ok := CallOverlayWithContext( Drivers[ i ].FrontEnd,
                                             ADR(Drivers[ i ].FrontContext) );

                   PackageOK := PackageOK AND ok;

                   IF ( BreakRequested () ) THEN
                      ClearBreak ();
                      AllIsCool := StopExport ();
                   END;

                   IF ( PackageOK ) AND
                      ( AllIsCool ) THEN
                       PutString( BackEndPhrase, BackEndMessageX, BackEndMessageY, videonormal );
                       ok := CallOverlayWithContext( BackEnd, ADR(BackEndContext) );
                       PackageOK := PackageOK AND ok;
                   END;
                   CloseTempFile();
               END;
               INC(i);
           END;
       END;

       IF (RugTaken) THEN
           PutRug( Ulx, Uly, Lrx, Lry, Rug );
       END;
    END;
END ExportData;


PROCEDURE StopExport () : BOOLEAN;
VAR
    Choice     : CARDINAL;
    Prefix     : ARRAY [0..41] OF CHAR;
    Choices    : ARRAY [0..255] OF CHAR;
    S          : ARRAY [0..255] OF CHAR;
    NillString : ARRAY [0..1] OF CHAR;
BEGIN

    SetLengthOf(NillString,0);

    GetMessage ( ModuleNumber + 10, Prefix );
    GetMessage ( ModuleNumber + 11, Choices );
    GetMessage ( ModuleNumber + 12, S );

    Choice := 1;

       (* Find out what they want.  Do not allow the CancelKey
          since its meaning is unclear in this context. *)
    REPEAT
    UNTIL (MultipleChoiceBox( S, NillString, NoHelp, Prefix, Choices, Choice ));

    IF ( Choice = 2 ) THEN
        RETURN  FALSE;
    ELSE
        RETURN TRUE;
    END;

END StopExport;


PROCEDURE VerifyTasks () : BOOLEAN;
VAR
    ContextRecord           : AContextRecord;
    Overlay                 : ARRAY [0..39] OF CHAR;
    ok                      : BOOLEAN;
BEGIN
    BlanksFound := FALSE;
    CheckAllWBSCodes ();

    IF ( BlanksFound ) THEN
       ok := DisplayWBSMessage ();
       RETURN ok;
    END;

    ContextRecord.RangeChoice := 1;

    SetString( Overlay, "\TLWBSGEN(TLVERIFY)" );

    ContextRecord.ShowThese   := AWBSErrorSet{};
    ContextRecord.ErrorsFound := AWBSErrorSet{};

    ok := CallOverlayWithContext( Overlay, ADR(ContextRecord) );

    IF ( ok ) THEN
       IF ( BlankError IN ContextRecord.ErrorsFound ) OR
          ( DuplicateError IN ContextRecord.ErrorsFound ) THEN
           ok := DisplayWBSMessage ();
       END;
    END;

    RETURN ok;

END VerifyTasks;


PROCEDURE CheckAllWBSCodes ();
VAR
    TaskNode                : ATreeNode;
BEGIN
    TaskNode := ATreeNode(NIL);

    TaskTree^.Methods^.TraverseTree( TaskTree,
                                     ParentBeforeChild,
                                     999,
                                     CheckWBSForBlank,
                                     ADR(TaskNode) );
END CheckAllWBSCodes;


PROCEDURE CheckWBSForBlank ( VAR TaskNode : ATreeNode;
                                 Context  : ADDRESS );
VAR
    TaskPtr                 : ATaskPtr;
    ok                      : BOOLEAN;
    s                       : ARRAY [ 0..MaxWbsLen ] OF CHAR;
BEGIN
    IF ( BlanksFound ) THEN
       RETURN;
    END;

    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    GetCodingField ( TaskPtr^, WBSLine, s );

    TaskNode^.Methods^.UnlockUnchangedDataObject( TaskNode );

    TrimRear ( s );

    BlanksFound := LengthOf( s ) = 0;

END CheckWBSForBlank;


PROCEDURE  DisplayWBSMessage () : BOOLEAN;
VAR
    Prefix                  : ARRAY [0..255] OF CHAR;
    MenuPrefix              : ARRAY [0..29] OF CHAR;
    Choices                 : ARRAY [0..255] OF CHAR;
    Choice                  : CARDINAL;
    Title                   : ARRAY [0..29] OF CHAR;
    ok                      : BOOLEAN;
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    SetLengthOf ( Title, 0 );

    GetMessage( ModuleNumber + 6, Prefix );
    (*
    "Some of your tasks have blank or duplicate WBSü"
    "numbers. This would prevent proper import ofü"
    "this data. This can be fixed by using theü"
    "/UTILITIES WBS menu choice."
    *)


    GetMessage( ModuleNumber + 7, MenuPrefix );
    (* "EXPORT ANYWAY" *)

    GetMessage( ModuleNumber + 8, Choices );
    (* "No,Yes" *)

    Choice := 1; (* Default is No *)

    ok := MultipleChoiceBox ( Prefix, Title, OfferHelp, MenuPrefix, Choices, Choice);

    IF ( ok ) THEN
        ok := Choice = 2;
    END;

    RETURN ok;

END DisplayWBSMessage;


BEGIN
    DriverTable := NIL;         (* 9-Apr-91 RSC  *)

    IF (Available( TSIZE( ADriverTable ))) THEN  (* 9-Apr-91 RSC  *)
        NEW(DriverTable);
        FillInTable( DriverTable^ );
    ELSE
        PackageOK := FALSE;
    END;

    IF (PackageOK) THEN
        ExportData( DriverTable^ );
    END;

    IF (DriverTable <> NIL) THEN    (* 9-Apr-91 RSC  *)
        DISPOSE(DriverTable);
    END;

END TLXPorts.

