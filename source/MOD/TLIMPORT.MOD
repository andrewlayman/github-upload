MODULE TLImport;

  (* Universal importing driver.

        Modification History:

        RSC  6/16/88
        EGK  6/27/88  Added first-time flag stuff.
        RSC 10/31/88  Changed meaning of "ExportersOK" flag:
                      It is now used as a signal from the front end as to
                      wether to call the back end or not.  This way, if
                      one front/back pair fails, we still go on.
                      Bug # 8396
        EGK  2/2/89   Added capability to run a back-end initializer overlay.
                      This is defined in phrases, and is run once before the
                      main export loop.  Removed "first time flag" stuff.
        RSC  6-Feb-89 Change "ExportersOK" to "PackageOK".
        MWP 26-Jul-89 Call overlay 'TLENDIMP' to sanitize the imported data.
        MWP 28-Jul-89 If user is importing task data, build formal column
                      name tree before calling front and back end overlays.
        KKC 10-Aug-89 Add copyright message.
        MWP 25-Aug-89 Take out calls to building and destroying formal name
                      structures.
        MWP 30-Aug-89 Save the file format for back and front ends.
        MWP 11-Aug-89 Change front end message to show file we are
                      exporting from.
        MWP 22-Sep-89 Check break key processing.
        MWP  2-Oct-89 Change the DefaultDateOption to ShowDateAndTime for
                      all import.
        MWP  6-Oct-89 When checking if the schedule has been altered before
                      being saved, also check that either tasks or resources
                      are present to be overwritten.
        30-Mar-90 RSC Made Timeu to Timei/TimeForm conversions.
        14-Feb-91 RSC Imported "AllFormalName" to balance out the relative
                      sizes of this (parent) overlay and its kids.
        10-May-91 PFG Temp versions of DriverTable and ImportTable added since
                      global versions can't be passed to overlays without 
                      being clobbered.
  *)
IMPORT AllFormalName;           (* 14-Feb-91 RSC  *)

FROM Allocs        IMPORT
    (* VAR *)               TaskTree;

FROM Boxes          IMPORT
    (* TYPE *)              ABoxAttribute, ABoxType,
    (* PROCS *)             DrawBox;

FROM Dialog         IMPORT
    (* TYPE *)              ADialogOption,
    (* PROC *)              MultipleChoiceBox;

FROM ExportLinkage  IMPORT
    (* VAR *)               InterFile, InterFileOpen, ExportMedia, ExportName;

FROM ImportCommon   IMPORT
    (* VAR *)               HaltImport,
    (* PROC *)              StopImport;

FROM Kbio           IMPORT
    (* TYPE *)              ascreenx, ascreeny, avidmode,
    (* PROCS *)             PutString, BreakRequested, ClearBreak;

FROM LStrings       IMPORT
    (* PROCS *)             Procustes, TrimRear, SetString, ConcatS, ConcatLS,
                            StoC, Copy, LengthOf, SetLengthOf;

FROM Menus          IMPORT
    (* PROCS *)             WordNumber;

FROM MsgFile        IMPORT
    (* PROCS *)             ConcatMessage, GetMessage;

FROM Overlays       IMPORT
    (* VARS *)              PackageOK,
    (* PROC *)              CallOverlayWithContext;

FROM RsrcMod        IMPORT
    (* VAR   *)             ResourceTree;

FROM Rugs           IMPORT
    (* TYPE *)              ARug,
    (* PROCS *)             GetRug, PutRug;

FROM Schedule       IMPORT
    (* VAR *)               ScheduleSaved;

FROM SYSTEM         IMPORT
    (* THING *)             ADR;

FROM TempFile       IMPORT
    (* PROCS *)             DeleteTempFile;

FROM TimeFormat     IMPORT
     (* TYPE *)             ADateDisplayOption,
     (* VAR *)              DefaultDateOption;


FROM XPorTable      IMPORT
    (* TYPE *)              ADriverTable;

FROM ImPorTable     IMPORT
    (* TYPE *)              AImportTable,
    (* VAR  *)              FileType, FormatType,
    (* PROC *)              CreateJournal, EndJournal;



CONST
    ModuleNumber            = 29300;
    XFormModuleNumber       = 29200;  (* Module # of TLXForm.Mod *)

    (* Box co-ordinates: *)
    Uly                     =  5;
    Lry                     = 11; (* top, bottom, shadow, 2 white-space lines, 2 text lines. *)
    Ulx                     = 10;
    Lrx                     = 70;

VAR
    Rug                     : ARug;
    BackEndMessageX,
    FrontEndMessageX        : ascreenx;
    BackEndMessageY,
    FrontEndMessageY        : ascreeny;
    BackEndMessageL,
    FrontEndMessageL,
    FrontEndMessageStart    : CARDINAL;
    DriverTable             : ADriverTable;
    ImportTable             : AImportTable;
    TaskTreeBuilt,
    RugTaken                : BOOLEAN;
    SavedDefaultDateOption  : ADateDisplayOption;

    BackEndPhrase,
    CollectingPhrase        : ARRAY [0..79] OF CHAR;



  (* Call the overlay to fill in the structure that drives the calling
     of overlays.
  *)
PROCEDURE FillInTable( VAR DriverTable : ADriverTable;
                       VAR ImportTable : AImportTable );
VAR
    Overlay : ARRAY [0..39] OF CHAR;
    TempDriverTable : ADriverTable;
    ok      : BOOLEAN;

BEGIN
    DriverTable.Entries := 0;
    ImportTable.ErrorOccured := FALSE;
    ImportTable.ImportBaseLineInfo := FALSE;
    ImportTable.BaseLineEncountered := FALSE;

    SetString( Overlay, "\TLFBASE(TLIFORM)" );

        (* 10-May-91 PFG    Temp var added because global version could get
                            clobbered when this overlay is swapped out.  *)
    TempDriverTable := DriverTable;         (* 10-May-91 PFG  *)
    ok := CallOverlayWithContext( Overlay, ADR(TempDriverTable) );
    DriverTable := TempDriverTable;         (* 10-May-91 PFG  *)

    PackageOK := PackageOK AND ok AND (DriverTable.Entries > 0);

END FillInTable;



  (* Start the dialog box:
  *)
PROCEDURE StartBox( VAR DriverTable : ADriverTable );
VAR
    i      : CARDINAL;
    s      : ARRAY [0..255] OF CHAR;
    Title  : ARRAY [0..79]  OF CHAR;
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
        GetMessage( XFormModuleNumber + 10 + ( DriverTable.BackEndNumber - 1 ), s );
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
PROCEDURE ImportData( VAR DriverTable : ADriverTable );
VAR
    i               : CARDINAL;
    TempImportTable : AImportTable;
    StopTheImport,
    ok,
    ErrorFlag       : BOOLEAN;
    s               : ARRAY [0..20] OF CHAR;
    (* Update the message box with the latest info. *)

    PROCEDURE UpdateStatus( i : CARDINAL );
    VAR
        s, s1 : ARRAY [0..79] OF CHAR;
    BEGIN
        GetMessage( FrontEndMessageStart + i, s );
        WordNumber( s, 1, s1 );

        GetMessage( ModuleNumber, s );
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
    ErrorFlag := FALSE;

    WITH DriverTable DO                             (* 2/2/89 EGK *)
        IF (LengthOf (BackEndInit) > 0) THEN
            PackageOK := TRUE;
            IF ( NOT CallOverlayWithContext ( BackEndInit, NIL ) ) OR
               ( NOT PackageOK ) THEN
                RETURN;
            END;
        END;
    END;

    StartBox( DriverTable );

    i := 1;

    SavedDefaultDateOption := DefaultDateOption;

    DefaultDateOption := ShowDateAndTime;

    WITH DriverTable DO
        FormatType := FileFormat;                               (* 30-Aug-89 MWP *)

        Copy( FileDir, ExportMedia );

        IF ( i <= Entries ) THEN
           CreateJournal ();
        END;

        StopTheImport := FALSE;

        (* 10-May-91 PFG    Temp var added because global version could get
                            clobbered when this overlay is swapped out.  *)
        TempImportTable := ImportTable;     (* 10-May-91 PFG *)

        WHILE ( i <= Entries ) AND
              ( NOT StopTheImport )    AND
              ( NOT HaltImport ) DO
            PackageOK := TRUE;

            StopTheImport := StopImport ();

            IF ( Drivers[ i ].FileToUse[0] <> 0C ) AND
               ( NOT StopTheImport ) THEN
                Copy( Drivers[ i ].FileToUse, ExportName );
                TrimRear( ExportName );
                ConcatS(  ExportName, "." );
                ConcatLS( ExportName, FileExt );
                PutString( CollectingPhrase, BackEndMessageX, BackEndMessageY, videonormal );
                UpdateStatus( i );

                FileType := i;

                (*
                  Importing task data so build formal column name tree for front
                  and back ends.
                *)

                ok := CallOverlayWithContext( BackEnd, ADR(TempImportTable) );

                IF ( TempImportTable.ErrorOccured ) THEN
                   ErrorFlag := TRUE;
                   TempImportTable.ErrorOccured := FALSE;
                END;


                PackageOK := PackageOK AND ok;

                StopTheImport := StopImport ();

                IF ( PackageOK ) AND
                   ( NOT StopTheImport ) THEN
                    PutString( BackEndPhrase, BackEndMessageX, BackEndMessageY, videonormal );

                    ok := CallOverlayWithContext( Drivers[ i ].FrontEnd,
                                                  ADR(TempImportTable) );

                    IF ( TempImportTable.ErrorOccured ) THEN
                       ErrorFlag := TRUE;
                       TempImportTable.ErrorOccured := FALSE;
                    END;

                    PackageOK := PackageOK AND ok;
                END;
                CloseTempFile();
            END;
            INC(i);
        END;

        (* Finished importing. Sanitize the task tree. *)
         SetString ( s, "TLENDIMP" );                              (* 26-Jul-89 MWP *)
         ok := CallOverlayWithContext( s, ADR(TempImportTable) );

         IF ( TempImportTable.ErrorOccured ) THEN
              ErrorFlag := TRUE;
              TempImportTable.ErrorOccured := FALSE;
         END;

         ImportTable := TempImportTable;        (* 10-May-91 PFG *)
    END;

    DefaultDateOption := SavedDefaultDateOption;

    IF (RugTaken) THEN
        PutRug( Ulx, Uly, Lrx, Lry, Rug );
    END;

    EndJournal ( ErrorFlag );

END ImportData;


PROCEDURE DisplaySaveScheduleBox () : BOOLEAN;
VAR
    Choice                  : CARDINAL;
    Prefix                  : ARRAY [0..255] OF CHAR;
    MenuPrefix              : ARRAY [0..29] OF CHAR;
    Choices                 : ARRAY [0..255] OF CHAR;
    Title                   : ARRAY [0..29] OF CHAR;
    ok                      : BOOLEAN;
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    SetLengthOf ( Title, 0 );
    GetMessage ( ModuleNumber + 6, Prefix );
    (* "Your schedule has been changed without beingü"
        saved. Importing may alter existing scheduleü
        information. Please save schedule before import" *)
    GetMessage( ModuleNumber + 50, MenuPrefix );
    (* "IMPORT ANYWAY?" *)

    GetMessage( ModuleNumber + 51, Choices );
    (* "No,Yes" *)

    Choice := 1; (* Default is No *)

    ok := MultipleChoiceBox ( Prefix, Title, OfferHelp, MenuPrefix, Choices, Choice);

    IF ( ok ) THEN
        ok := Choice = 2;
    END;

    RETURN ok;

END DisplaySaveScheduleBox;

VAR
    ok  :  BOOLEAN;

BEGIN
    ok := TRUE;
    TaskTreeBuilt := FALSE;

    IF ( NOT ScheduleSaved ) AND
       ( ( TaskTree^.Methods^.GetFirst( TaskTree ) <> NIL ) OR
         ( ResourceTree^.Methods^.GetFirst( ResourceTree ) <> NIL ) ) THEN
       ok := DisplaySaveScheduleBox ();
    END;

    IF ( ok ) THEN
       FillInTable( DriverTable, ImportTable );
       IF (PackageOK) THEN
           ImportData( DriverTable );
       END;
    END;

END TLImport.
