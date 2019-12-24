MODULE TLGSetup;

(*  TLG Setup  - Set up a graphics device.

    Modification History:

    5-Apr-89  RSC   First version.
    09-May-89 LAA   Reorganized to include the device setup form, etc.
    01-Jun-89 LAA   Added the ConfigRecord to IlsaStatic, and changed the
                    location of some fields from the setuprecord to there.
    03-Jun-89 LAA   Fixed a bug caused by not making a copy of the text
                    field in the Config Record when I copied the record.
                    Added code to grab the new Section 2 of parameters file.
    08-Jun-89 WKH   Changed TLGSetupRecord field references so that X now
                    means Wide and Y means High.
    09-Jun-89 LAA   Fixed a bug which cause an error message if there was no
                    pre-existing values file.
    13-Jun-89 LAA   Changed DOSDevice to DOSDev in the CommFormContext to
                    adjust for a change made by Matt.
    14-Jun-89 LAA   Section 1 of the parameters file no longer has 4 lines.
                    Removed the MassageLine procedure.
    22-Jun-89  LAA  Put two new fields in the SetupRecord to keep around
                    the plottable area of a page, because we have to swap
                    the existing fields for Sedona if Rotate is TRUE.
    23-Jun-89 LAA   Expanded the PaperName field of the SetupFormContext so
                    it can hold "extra" information which will be defined on
                    a per-page-size basis, and used solely by Sedona.
    29-Jun-89 LAA   Always look in the TEXT subdirectory for parameters files.
    18-Jul-89 LAA   Some Texts were not being discarded under some conditions.
                    Put in calls to procedures at the end of this process to
                    get rid of anything left over.
    24-Jul-89 LAA   Put in a temporary kludge to write line 11 of Section 3
                    so the Sedona drivers would work.  This line will always
                    (until I fix it) specify no file name.
     2-Aug-89 MWP   Most procedures have been moved to another module named
                    PrintCommon to create a common set of routines for
                    device setup parameter and values files.
    10-Aug-89 KKC   Add copyright message.
    14-Aug-89 MWP   Add extension delimiter, '.', to extension name.
    18-Aug-89 KKC   Import PickADevice from DeviceColumns.
    31-Aug-89 LAA   Removed unused imports.  Fixed a bug caused by the flag
                    which controls AskContinuous being controlled by the
                    values file.  Only the parameters file should control
                    this.  Fix to InitSetupFormContext.
     1-Sep-89 MWP   Support output to disk file and fix problem with
                    retrieving the device description instead of the
                    device name for form displays.
    11-Sep-89 LAA   A PMD was resulting from escaping from the device 
                    selection list, because of the strange structure of the
                    TLGSetup procedure.  I've never been happy with this
                    structure, so I inserted explicit tests of ok all over
                    the place, and fixed the condition that was causing the
                    PMD.
    15-Sep-89 KKC   Leave the "one moment" message on screen until 
                    InitSetupFormContext is completed.
    22-Sep-89 KKC   Change device name to have 255 characters.
    28-Sep-89 LAA   Initialize the SetupFormContext.FormChoices to NIL, in
                    case there are no device-specific choices.
    29-Nov-89 EGK   Somehow, ValuesFileFound wasn't initialized to anything.
                    Now, we set it based on the return value from
                    ReadValuesFile.  Also, in DoTLGSetup, put up a help box
                    reminding user to change the palette after changing the
                    graphics device.
     7-Dec-89 RSC   Fixed bug # 1893, default device name lost when getting
                    output file name.
    01-Jan-90 WKH   Happy New Year!  Now back to reality.  Only show device
                    help if a user has changed devices.
    02-Jan-90 WKH   OK, so I slipped.  Don't show help if user pressed ESC
                    or some other problem ocurred.
    12-Jul-90 PHR   Any parameters section which is not recognized by this
                    module is copied to the values file.  This allows
                    addition of new sections for drivers without code changes
                    to Time Line.
    23-Oct-90 RSC   Changed %'s to 4's in filenames for Dos batch.
    12-Nov-90 TGS   Merge changes made to 4.03.
     1-May-91 RSC   Remove globals so that there are no overlay swapping
                    problems.
    12-May-91 AJL   Allow specific help for certain devices.
                    To create help for a particular device, create a help
                    text subject beginning with "CG." and the first five
                    characters of the device parameters file name.  For
                    example, if the file name is "HPLASER.5GP" you would
                    make the subject "CG.HPLAS".
*)

FROM BalExpr    IMPORT
    (* PROC *)      ParseExpression, ParseCardinal;

FROM CommStatic IMPORT
    (* TYPE *)      ACommFormContext, AMethod,   ABaudRate,  AStopBits,
                    ADataBits,        AProtocol, ADOSDevice, AParity,
    (* CONST *)     HighestMethod,   HighestBaudRate, HighestDataBits,
                    HighestStopBits, HighestParity,   HighestProtocol,
                    HighestDOSDevice;

FROM DeviceColumns          IMPORT
    (* PROC *)                  PickADevice;

FROM Dialog     IMPORT
    (* PROC *)      Error, FatalError, Message;

FROM Direct411  IMPORT
                    GetOutputFile;

FROM Directory  IMPORT
    (* CONST *)     MaximumDeviceNameLength,
                    MaximumPathNameLength,
                    MaximumFileNameLength,
                    MaximumExtensionLength,
                    ParseFileName;

FROM FileAux    IMPORT
    (* VAR *)       TextPath,
    (* PROC *)      CheckIO, PrepareForIO;

FROM FileSystem IMPORT
    (* TYPE *)      File, Response,
    (* PROC *)      Lookup, Close, Delete, Rename;

FROM GrafFile   IMPORT
    (* PROC *)      StartGrafFileInput,  StartGrafFileOutput,
                    ReadGrafFileSection, WriteGrafFileSection,
                    EndGrafFileInput,    EndGrafFileOutput,
                    ForAllGrafFileSections;

FROM Helper     IMPORT
    (* TYPE *)      AScreenAction,
    (* PROC *)      HelpExists, GiveHelp;

FROM IlsaStatic IMPORT
    (* TYPE *)      ATLGSSetupRecordPtr, ATLGSSetupRecord,
                    ATLGSConfigRecord, ATLGSConfigRecordPtr,
                    AGraphicsOrientation,
    (* PROC *)      TLGSSetupRecord, TLGSSetupRecordExists, TLGSConfigRecord;

FROM Keys       IMPORT
    (* CONST *)     CancelKey;

FROM Layout     IMPORT
    (* CONST *)     GanttWStart, GanttWEnd;

FROM LStrings   IMPORT
    (* PROC *)      SetString, LengthOf, Copy, ConcatS, ConcatLS, SubStr,
                    TStringToLString, SetLengthOf, TrimRear, Search,
                    LStringToTString, Remove, Insert, Upshift, CtoS,
                    StringsEqual, StoC;

FROM MsgFile    IMPORT
    (* PROC *)      GetMessage, DisplayMessage;

FROM Overlays   IMPORT
    (* PROC *)      CallOverlayWithContext;

FROM PrintCommon    IMPORT
    (* CONST *)         MaxSections, Unused,
    (* TYPE *)          AFileSectionRecord, AFileSectionsArray,
    (* PROC *)          ErrorMessage, ReadValuesFile, ReadParametersFile,
                        PutCommFormContext, WriteValuesFile,
                        FindOrCreateValuesSection, RealExpression,
                        BoolExpression, EnumExpression, StringExpression,
                        FindSection, FindNewSection, GetTextLine,
                        InitializeCommFormContext;

FROM Schedule   IMPORT
    (* VAR *)       ConfigSaved, CurrentFileExtension;

FROM Space      IMPORT
    (* PROC *)      HeapAvailable, ALLOCATE, DEALLOCATE;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADR;

FROM Text       IMPORT
    (* TYPE *)      AText,
    (* PROC *)      CreateText, DiscardText, AppendLine, AssignLine,
                    LineExists, TextExists, CopyLine, AssignText;




CONST
    ModuleNumber            = 29600;
    DeviceOut               = 0;

TYPE
    ASetupFormContext       = RECORD
                                DeviceName  : ARRAY [0..255] OF CHAR;
                                PaperName   : ARRAY [0..255] OF CHAR;    (* 23-Jun-89 LAA *)
                                FormChoices : AText;
                                PaperChoices: AText;
                                FormValues  : AText;
                                SetupRecord : ATLGSSetupRecordPtr;
                                ConfigRecord: ATLGSConfigRecordPtr;
                                OutputChoice: CARDINAL;
                                ReturnCode  : CARDINAL;
                              END;



(*$S+*)          (* 1-May-91 RSC out of stack? *)



(* Do TLG Setup - Main logic driver for this overlay.

    1) Get the current device's context from IlsaStatic.
    2) Ask the customer to pick a device.  The default is the same
       device they were using.
    3) If they pick a different device, get the defaults for the form
       from the parameters file, else from the existing values file.
    4) Get the actual values from the customer via the TLDevSet and TLComm
       overlays.
    5) Save the context back into IlsaStatic.

*)
PROCEDURE DoTLGSetup();
VAR
    CommFormContext         : POINTER TO ACommFormContext;
    SetupFormContext        : POINTER TO ASetupFormContext;
    Parameters              : AFileSectionsArray;
    Values                  : AFileSectionsArray;
    SetupRecord             : ATLGSSetupRecordPtr;
    ConfigRecord            : ATLGSConfigRecordPtr;
    BaudRateTable           : ARRAY ABaudRate OF CARDINAL;
    LSetup                  : ATLGSSetupRecord;
    LConfig                 : ATLGSConfigRecord;
    LSetupPathName          : ARRAY [0..69] OF CHAR;
    LSetupFileName          : ARRAY [0..9] OF CHAR;
    Section3NotSeen         : BOOLEAN;
    UseParmFileCommSection  : BOOLEAN;
    ValuesFileFound         : BOOLEAN;
    ok                      : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;
    Ext                     : ARRAY [0..5]   OF CHAR;
    OldDeviceName           : ARRAY [0..9] OF CHAR;
    OverlayName             : ARRAY [0..29] OF CHAR;

    PROCEDURE MakeNewValues();

    VAR
        i                       : CARDINAL;
        Copyright               : ARRAY[0..50] OF CHAR;



        PROCEDURE CopyToValues(    ParamIndex : CARDINAL);

        VAR
            j                   : CARDINAL;

        BEGIN                   (* CopyToValues *)

            IF (NOT ok) THEN RETURN END;

            FindOrCreateValuesSection ( Parameters[ParamIndex].Section,
                                        j,
                                        ADR(Values) );

            ok := AssignText(Parameters[ParamIndex].Contents,
                             Values[j].Contents);

        END CopyToValues;


        PROCEDURE MakeSection2();

        VAR
            i, j                : CARDINAL;
            s                   : ARRAY [0..255] OF CHAR;
            s2                  : ARRAY [0..255] OF CHAR;

        BEGIN                   (* MakeSection2 *)

            IF (NOT ok) THEN RETURN END;

            FindOrCreateValuesSection( 2, j, ADR(Values) );
            Values[j].Contents := CreateText();
            ok := Values[j].Contents <> AText(NIL);

            FOR i := 1 TO 8 DO
                IF (NOT ok) THEN RETURN END;
                CASE i OF
                    1 : RealExpression(LSetup.PhysPageWide, i, s);
                |   2 : RealExpression(LSetup.PhysPageHigh, i, s);
                |   3 : RealExpression(LSetup.OrigPlotAreaWide, i, s);  (* 22-Jun-89 LAA *)
                |   4 : RealExpression(LSetup.OrigPlotAreaHigh, i, s);
                |   5 : BoolExpression(LSetup.AskContinuous, i, s);
                |   6 : BoolExpression(LSetup.ContinuousPrint, i, s);
                |   7 : EnumExpression(ORD(LSetup.Orientation), i, s);
                |   8 : CopyLine(LSetup.DeviceDescription, 1, s2);
                        StringExpression(s2, i, s);
                END;
                ok := (ok AND AppendLine(s, Values[j].Contents));
            END;

        END MakeSection2;


    BEGIN                       (* MakeNewValues *)

        Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

        FOR i := 1 TO MaxSections DO
            IF (NOT ok) THEN RETURN END;

            CASE Parameters[i].Section OF
                2   :   MakeSection2();
            |   3   :   (* Not in parameters file.  Set up below. *);
            |   4   :   (* Has been done by Device Setup Form.  *);
            |   5   :   (* Does not exist in Values file, only Parameters. *);
            |  12   :   (* Does not exist in Values file, only Parameters. *);
			| Unused:   (* Did not exist in parameters, so not in values. *);
            ELSE
                CopyToValues(i);
            END;
        END;

    END MakeNewValues;


    PROCEDURE InitParametersArray();

    VAR
        i                   : CARDINAL;

    BEGIN                   (* InitParametersArray *)

        FOR i := 1 TO MaxSections DO
            Parameters[i].Section := Unused;
            Parameters[i].Contents := AText(NIL);
        END;

    END InitParametersArray;


    PROCEDURE InitValuesArray();

    VAR
        i                   : CARDINAL;

    BEGIN                   (* InitValuesArray *)

        FOR i := 1 TO MaxSections DO
            Values[i].Section := Unused;
            Values[i].Contents := AText(NIL);
        END;

    END InitValuesArray;


    PROCEDURE DiscardParametersArray();

    VAR
        i                   : CARDINAL;

    BEGIN                   (* DiscardParametersArray *)

        FOR i := 1 TO MaxSections DO
            IF ((Parameters[i].Section <> Unused) AND (Parameters[i].Contents <> AText(NIL))) THEN
                DiscardText(Parameters[i].Contents);
            END;
        END;

    END DiscardParametersArray;


    PROCEDURE DiscardValuesArray();

    VAR
        i                   : CARDINAL;

    BEGIN                   (* DiscardValuesArray *)

        FOR i := 1 TO MaxSections DO
            IF ((Values[i].Section <> Unused) AND (Values[i].Contents <> AText(NIL))) THEN
                DiscardText(Values[i].Contents);
            END;
        END;

    END DiscardValuesArray;


    PROCEDURE DiscardLSetup();                                    (* 18-Jul-89 LAA *)

    BEGIN                   (* DiscardLSetup *)

        WITH LSetup DO
            IF (TextExists(PrimColorDesc)) THEN
                DiscardText(PrimColorDesc);
            END;
            IF (TextExists(DeviceDescription)) THEN
                DiscardText(DeviceDescription);
            END;
        END;

    END DiscardLSetup;



    PROCEDURE DiscardLConfig();

    BEGIN                   (* DiscardLConfig *)

        WITH LConfig DO
            IF (TextExists(ConfigDescription)) THEN
                DiscardText(ConfigDescription);
            END;
        END;

    END DiscardLConfig;





    PROCEDURE InitSetupFormContext();

    VAR
        i, j                : CARDINAL;
        Where               : CARDINAL;
        ParametersAsk       : BOOLEAN;


        PROCEDURE ExtractSection2(    Contents : AText);

        VAR
            s               : ARRAY [0..255] OF CHAR;
            s2              : ARRAY [0..255] OF CHAR;
            Where           : CARDINAL;

        BEGIN               (* ExtractSection2 *)

            IF (GetTextLine(Contents, 8, Where, s)) THEN
                IF (ParseExpression(s, 3, SetupFormContext^.PaperName)) THEN  (* 23-Jun-89 LAA *)
                END;
            END;
            IF (GetTextLine(Contents, 7, Where, s)) THEN
                IF (ParseExpression(s, 3, s2)) THEN
                    Where := 1;
                    Where := StoC(s2, Where);
                    LSetup.Orientation := VAL(AGraphicsOrientation, Where);
                END;
            END;
            IF (GetTextLine(Contents, 6, Where, s)) THEN
                IF (ParseExpression(s, 3, s2)) THEN
                    Where := 1;
                    Where := StoC(s2, Where);
                    LSetup.ContinuousPrint := VAL(BOOLEAN, Where);
                END;
            END;
            IF (GetTextLine(Contents, 5, Where, s)) THEN
                IF (ParseExpression(s, 3, s2)) THEN
                    Where := 1;
                    Where := StoC(s2, Where);
                    LSetup.AskContinuous := VAL(BOOLEAN, Where);
                END;
            END;

        END ExtractSection2;

        PROCEDURE ExtractSection15(    Contents : AText);

        VAR
            i, j            : CARDINAL;
            s               : ARRAY [0..255] OF CHAR;

        BEGIN               (* ExtractSection15 *)

            i := 1;
            WHILE (GetTextLine(Contents, i, j, s)) DO
                IF (NOT TextExists(LSetup.PrimColorDesc)) THEN
                    LSetup.PrimColorDesc := CreateText();
                END;
                    (* Put code to translate into readable form here. *)
                IF (NOT AssignLine(s, i, LSetup.PrimColorDesc)) THEN
                    RETURN;
                END;
                INC(i);
            END;

        END ExtractSection15;


    BEGIN                   (* InitSetupFormContext *)

        IF (NOT ok) THEN RETURN; END;

        IF (NOT FindSection(Parameters, 12, i)) THEN
            ErrorMessage(ModuleNumber + 9);      (* Bad structure *)
            ok := FALSE;
            RETURN;
        END;

        SetupFormContext^.PaperChoices := Parameters[i].Contents;

        SetupFormContext^.SetupRecord := ADR(LSetup);
        SetupFormContext^.ConfigRecord := ADR(LConfig);            (* 01-Jun-89 LAA *)

        IF ((FindSection(Parameters, 1, i))
(*
           AND (GetTextLine( Parameters[i].Contents, 3, Where, s ))
*)
           AND (GetTextLine( Parameters[i].Contents, 2, Where, s ))
           AND (ParseExpression( s, 1, SetupFormContext^.DeviceName ))) THEN ;
        ELSE
            ErrorMessage(ModuleNumber + 9);      (* Bad structure *)
            ok := FALSE;
            RETURN;
        END;

        CopyLine(LSetup.DeviceDescription, 1, SetupFormContext^.PaperName);

        IF (FindSection(Parameters, 2, i)) THEN                   (* 31-Aug-89 LAA *)
            ExtractSection2(Parameters[i].Contents);
            IF ((ValuesFileFound) AND (FindSection(Values, 2, i))) THEN
                ParametersAsk := LSetup.AskContinuous;
                ExtractSection2(Values[i].Contents);
                LSetup.AskContinuous := ParametersAsk;
            END;
        ELSE
            ErrorMessage(ModuleNumber + 9);      (* Bad structure *)
            ok := FALSE;
            RETURN;
        END;

        IF (FindSection(Parameters, 15, i)) THEN
            ExtractSection15(Parameters[i].Contents);
        ELSE
            FatalError();
        END;

        SetupFormContext^.FormChoices := AText(NIL);               (* 28-Sep-89 LAA *)

        IF (FindSection(Parameters, 4, i)) THEN
            SetupFormContext^.FormChoices := Parameters[i].Contents;

            IF (NOT FindSection(Values, 4, i)) THEN
                IF (FindNewSection(Values, i)) THEN
                    Values[i].Section := 4;
                    IF (NOT AssignText(SetupFormContext^.FormChoices,
                                       Values[i].Contents)) THEN
                        ErrorMessage(ModuleNumber + 8);   (* Out of EMS memory *)
                        ok := FALSE;
                        RETURN;
                    END;
                ELSE
                    FatalError();
                END;
            END;
            SetupFormContext^.FormValues := Values[i].Contents;
        END;

        SetupFormContext^.OutputChoice := 0;

        IF ( FindSection ( Values, 3, i ) ) THEN
            IF ( GetTextLine ( Values[i].Contents, 1, Where, s ) ) THEN
               IF ( ParseCardinal( s, 1, j ) ) AND ( j = 1 ) THEN
                  IF ( ParseCardinal ( s, 3, j ) ) AND ( j = ORD(DiskFile) ) THEN
                     SetupFormContext^.OutputChoice := 1;
                  END;
               END;
            END;
        END;

    END InitSetupFormContext;




    PROCEDURE SaveSetupFormContext();

    VAR
        i                   : CARDINAL;

    BEGIN                   (* SaveSetupFormContext *)

        IF (NOT ok) THEN RETURN; END;

        IF (NOT FindSection(Values, 4, i)) THEN
            IF (NOT FindNewSection(Values, i)) THEN
                FatalError();
            END;
            Values[i].Section := 4;
        END;

        IF (Values[i].Contents <> SetupFormContext^.FormValues) THEN
            IF (Values[i].Contents <> AText(NIL)) THEN
                DiscardText(Values[i].Contents);
            END;
            Values[i].Contents := SetupFormContext^.FormValues;
            SetupFormContext^.FormValues := AText(NIL);            (* 18-Jul-89 LAA *)
        END;

        IF (NOT TextExists(LSetup.DeviceDescription)) THEN
            LSetup.DeviceDescription := CreateText();
        END;

        IF (LSetup.DeviceDescription <> AText(NIL)) THEN
            ok := AssignLine(SetupFormContext^.PaperName, 1,
                             LSetup.DeviceDescription);
        ELSE
            ok := FALSE;
        END;

    END SaveSetupFormContext;


    PROCEDURE UnpackSetupRecord();

    BEGIN                   (* UnpackSetupRecord *)

        SetupRecord := TLGSSetupRecord();
        IF (SetupRecord = NIL) THEN
            FatalError();
        END;

        ConfigRecord := TLGSConfigRecord();
        IF (ConfigRecord = NIL) THEN
            FatalError();
        END;

        LConfig := ConfigRecord^;
        ok := AssignText(ConfigRecord^.ConfigDescription,         (* 03-Jun-89 LAA *)
                         LConfig.ConfigDescription);
        WITH ConfigRecord^ DO
            CopyLine(ConfigDescription, 1, LSetupFileName);
        END;

        LSetup := SetupRecord^;
        WITH SetupRecord^ DO
            ok := (ok AND AssignText(DeviceDescription, LSetup.DeviceDescription));
            ok := (ok AND AssignText(PrimColorDesc, LSetup.PrimColorDesc));
        END;

    END UnpackSetupRecord;



    PROCEDURE RepackSetupRecord();

    BEGIN                   (* RepackSetupRecord *)

        IF (NOT ok) THEN RETURN END;

        WITH LSetup DO
            IF (NOT TextExists(DeviceDescription)) THEN
                DeviceDescription := CreateText();
                ok := (DeviceDescription <> AText(NIL));
            END;
            ok := (ok AND AssignLine(SetupFormContext^.DeviceName, 0,
                                     DeviceDescription));
            ok := (ok AND AssignLine(SetupFormContext^.PaperName, 1,
                                     DeviceDescription));
        END;

        WITH LConfig DO
            IF (NOT TextExists(ConfigDescription)) THEN
                ConfigDescription := CreateText();
                ok := (ConfigDescription <> AText(NIL));
            END;
            ok := (ok AND AssignLine(LSetupPathName, 0, ConfigDescription));
            ok := (ok AND AssignLine(LSetupFileName, 1, ConfigDescription));
        END;

        IF (ok) THEN
            DiscardText(SetupRecord^.PrimColorDesc);
            DiscardText(SetupRecord^.DeviceDescription);
            SetupRecord^ := LSetup;
            LSetup.PrimColorDesc := AText(NIL);                   (* 18-Jul-89 LAA *)
            LSetup.DeviceDescription := AText(NIL);
            DiscardText(ConfigRecord^.ConfigDescription);
            ConfigRecord^ := LConfig;
            LConfig.ConfigDescription := AText(NIL);
            ConfigSaved := FALSE;  (* So we try to save the config file later. *)
        END;

    END RepackSetupRecord;

    PROCEDURE GetOutputFileName ( VAR DefaultName : ARRAY OF CHAR ) : BOOLEAN;
    VAR
        DeviceName   : ARRAY [0..MaximumDeviceNameLength] OF CHAR;
        PathName     : ARRAY [0..MaximumPathNameLength] OF CHAR;
        PathNameOut  : ARRAY [0..MaximumPathNameLength] OF CHAR;
        FileNameIn   : ARRAY [0..MaximumPathNameLength] OF CHAR;
        FileNameOut  : ARRAY [0..MaximumPathNameLength] OF CHAR;
        FileName     : ARRAY [0..13] OF CHAR;
        Extension    : ARRAY [0..MaximumExtensionLength] OF CHAR;
        ok           : BOOLEAN;
    BEGIN
        ParseFileName ( DefaultName, DeviceName, PathName, FileName, Extension );

        Insert( PathName, DeviceName, 1 );  (* RSC 7-Dec-89 *)

        Copy ( FileName, FileNameIn );
        ConcatS ( FileNameIn, "." );
        ConcatLS ( FileNameIn, Extension );

        ok := GetOutputFile ( PathName, FileNameIn, PathNameOut,
                              FileNameOut, TRUE );

        IF ( ok ) THEN
           Copy ( PathNameOut, DefaultName );
           ConcatLS ( DefaultName, FileNameOut );
        ELSE
           SetLengthOf ( DefaultName, 0 );
        END;

        RETURN ( ok );
    END GetOutputFileName;


BEGIN
    IF (NOT HeapAvailable()) THEN
        RETURN;
    END;
    NEW(CommFormContext);
    NEW(SetupFormContext);

        (*
            I've restructured this proc to test the ok variable explicitly
            to determine if there's been an error so far.  You'll see a
            number of procedure calls which seem to be unconditional: they
            aren't.  In each one (if you look) you'll see that the first 
            thing they do is make sure the everything's ok.  So if anything
            goes wrong in here, the effect is to fall to the end, where a
            message is printed.
        *)

    ValuesFileFound := FALSE;           (* 11/29/89 LAA/EGK *)

    InitParametersArray();
    InitValuesArray();

    Copy(TextPath, LSetupPathName);

    ok := TRUE;

    UnpackSetupRecord();

    (* Pick a device file from Direct411. *)

    SetString( Ext, "%GP" );
    Ext[1] := CurrentFileExtension[2]; (* "5" *) (* 23-Oct-90 RSC *)

    GetMessage( ModuleNumber + 0, s );
    (* "Graphics Devices" *)

    IF (ok) THEN
        ok := PickADevice ( LSetupPathName, LSetupFileName, Ext, s );
    END;

    IF (ok) THEN
        DisplayMessage ( ModuleNumber + 12);        (*  One moment ... reading the parameters file.  *)

        ok := ReadParametersFile ( LSetupPathName, LSetupFileName, Ext,
                                   ADR(Parameters) );
    END;

    IF (ok) THEN
        (*  Get the Values file from the current directory.  *)

        SetString( s, ".\" );
        SetString( Ext, "%GV" );
        Ext[1] := CurrentFileExtension[2]; (* "5" *) (* 23-Oct-90 RSC *)

        ok := ReadValuesFile ( s, LSetupFileName, Ext, ADR(Values) );
        ValuesFileFound := ok;          (* 11/29/89 LAA/EGK *)
    END;

    InitSetupFormContext();

    SetLengthOf(s, 0);       (* erase the One moment ... message *)
    Message(s);

    IF (ok) THEN
        SetString(s, "\TLFBASE(TLDEVSET)");
        ok := CallOverlayWithContext(s, SetupFormContext)
              AND (SetupFormContext^.ReturnCode <> CancelKey);
    END;

    SaveSetupFormContext();

    (*  LAA - here is where we should bring up the Setup Form.  Upon F10, we
        have to check and see if the Communications form is appropriate,
        or whether we should bring up a file name form.
    *)
    IF (ok) THEN
        ok := InitializeCommFormContext( ADR(Parameters), ADR(Values),
                                         CommFormContext );
    END;

    IF (ok) THEN
        IF ( SetupFormContext^.OutputChoice = DeviceOut ) THEN
           IF ( CommFormContext^.Method = DiskFile ) THEN
                CommFormContext^.Method := Parallel;
           END;

           SetString( s, "\TLFBASE(TLCOMM)" );

           ok := CallOverlayWithContext( s, CommFormContext )
                 AND (CommFormContext^.FormCode <> CancelKey);

           IF ( ok ) THEN
              SetLengthOf ( CommFormContext^.FileName, 0 );
           END;
        ELSE
           (* Call file form. *)
           CommFormContext^.Method := DiskFile;

           ok := GetOutputFileName ( CommFormContext^.FileName );  
        END;
    END;

    IF (ok) THEN
        ok := PutCommFormContext ( CommFormContext, ADR(Values) );
    END;

    MakeNewValues();

    IF (ok) THEN
        (*  Values file will be saved into the current directory.  *)

        SetString( s, ".\" );
        SetString( Ext, ".%GV" );                                   (* 14-Aug-89 MWP *)
        Ext[2] := CurrentFileExtension[2];     (* "5" *)     (* 23-Oct-90 RSC *)
        ok := WriteValuesFile( s, LSetupFileName, Ext, ADR(Values) );
        IF (NOT ok) THEN
            ErrorMessage(ModuleNumber + 10);      (* Unable to write a new values file.  Setup not done *)
        END;
    END;

    CopyLine(ConfigRecord^.ConfigDescription, 1, OldDeviceName);

        (* If the output device has changed, give a help message. *)

    IF (ok AND (NOT StringsEqual(OldDeviceName, LSetupFileName))) THEN (* 2-Jan-90 WKH Check before new values wipe out old ones*)
            (* Give help about setting up this device.  First, see if there
               is specific help about this device.  If not, give generic
               help about device setup. *)
        SetString(s,"CG.");
        ConcatLS(s,LSetupFileName);
        IF (NOT HelpExists(s)) THEN
            SetString (s, ".DEVSET");        (* 11/29/89 LAA/EGK *)
        END;
        GiveHelp (s, 0, GanttWEnd, RestoreTheScreen);
    END;

    RepackSetupRecord();

    DiscardValuesArray();
    DiscardParametersArray();
    DiscardLSetup();                                              (* 18-Jul-89 LAA *)
    DiscardLConfig();

    IF (NOT ok) THEN            (* 1-Jan-90 WKH  *)
        ErrorMessage(ModuleNumber + 11);   (* "Graphics device setup has not been done." *)
    END;

    DISPOSE(CommFormContext);
    DISPOSE(SetupFormContext);

END DoTLGSetup;


BEGIN
    DoTLGSetup();
END TLGSetup.

