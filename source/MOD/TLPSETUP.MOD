MODULE TLPSetup;

(*  TLP Setup  - Set up a timeline printer.

    Modification History:

    1-Aug-89  MWP   In the beginning...
    10-Aug-89 KKC   Add copyright message.
    16-Aug-89 MWP   Included more consistent parsing format.
    18-Aug-89 KKC   Import PickADevice from DeviceColumns.
    24-Aug-89 MWP   Fix bug where we were loading compressed init and terminate
                    strings into normal printer data area.
    29-Aug-89 MWP   If setup cannot be done for disk file format, display
                    error message pertaining to Disk file not complete.
    13-Sep-89 MWP   If the user selected Disk Files, pass 'File Formats' to
                    pick processor.
    22-Sep-89 MWP   Disable reading of compressed and normal sequences
                    for Disk File format.
    27-Sep-89 MWP   Save Timeout into PrintStatic.GlobalTimeOut.
     7-Oct-89 MWP   When saving printer parameters for Disk File configurations,
                    we were neglecting to read the optional character translation
                    line, and the translate overlay line.
    23-Oct-89 RSC   Don't reset the ScheduleSaved flag.  Bug 1560.
     8-Nov-89 EGK   Don't check for an empty string before updating the
                    TranslateOverlay.  This fixes the bug which would
                    leave you in sideways mode (i.e., TLGLUE always runs)
                    permanently, even if you switched back to a non-rotated
                    disk file format.
    21-Nov-89 RSC   If ESC hit on list, do not proceed to do anything.
                    Bug # 1703.
    23-Oct-90 RSC   Changed %'s to 4's in filenames for Dos batch.
     1-May-91 RSC   The extension on the values file was being mangled.
                    Fixed it.
*)

FROM BalExpr        IMPORT
    (* PROC *)              ParseCardinal, ParseExpression, LStringToExpression;

FROM CommStatic     IMPORT
    (* TYPE *)              ACommFormContext, AMethod,   ABaudRate,  AStopBits,
                            ADataBits,        AProtocol, ADOSDevice, AParity,
    (* CONST *)             HighestMethod,   HighestBaudRate, HighestDataBits,
                            HighestStopBits, HighestParity,   HighestProtocol,
                            HighestDOSDevice;

FROM DeviceColumns IMPORT
    (* PROC *)              PickADevice;

FROM Dialog         IMPORT
    (* PROC *)              Error, FatalError, Message;

FROM FileAux        IMPORT
    (* VAR *)               TextPath,
    (* PROC *)              CheckIO, PrepareForIO;

FROM Foreign        IMPORT  ExpandStringToXLAT, DecodeString;

FROM Keys           IMPORT
    (* CONST *)             CancelKey;

FROM LStrings       IMPORT
    (* PROC *)              SetString, LengthOf, Copy, ConcatS, ConcatLS, SubStr,
                            TStringToLString, SetLengthOf, TrimRear, Search,
                            LStringToTString, Remove, Insert, Upshift, CtoS,
                            StringsEqual, StoC, LJust, Procustes, Fill, Compare;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage, DisplayMessage;

FROM Overlays       IMPORT
    (* PROC *)              OverlayContext,
                            CallOverlayWithContext;

FROM PrintCommon    IMPORT
    (* CONST *)             MaxSections,
    (* TYPE *)              AFileSectionRecord,
                            AFileSectionsArray,
    (* PROC *)              ErrorMessage,
                            ReadValuesFile,
                            ReadParametersFile,
                            PutCommFormContext,
                            WriteValuesFile,
                            GetTextLine,
                            FindSection,
                            FindOrCreateValuesSection,
                            InitializeCommFormContext;

IMPORT PrintStatic;

FROM Schedule       IMPORT
    (* VAR *)           ConfigSaved, CurrentFileExtension;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADR, TSIZE, ADDRESS;


FROM Text                   IMPORT
    (* PROC *)                  CopyLine, AssignLine, Compress, CreateText,
                                LineExists, TextExists, AText, SizeOfText,
                                DiscardText, AssignText;




CONST
    ModuleNumber            = 14000;   (* *)
    Unused                  = 65535;
    Normal                  = 0;
    Compressed              = 1;
    DoDiskFile              = 0;
    Printer                 = 1;
    NormalParams            = 1;
    CompressedParams        = 10;
    OptionalParams          = 19;




(*$S+*)



PROCEDURE SaveCommFormContext( VAR CommFormContext : ACommFormContext ) : BOOLEAN;
VAR
    s                       : ARRAY [0..41] OF CHAR;

BEGIN

    WITH CommFormContext DO

        CASE Method OF
            Serial     :
                 PrintStatic.PrintCB.PortType := PrintStatic.PortSerial;
                 PrintStatic.PrintCB.PrinterNumber := SerialPortNumber;
          | Parallel   :
                 PrintStatic.PrintCB.PortType := PrintStatic.PortParallel;
                 PrintStatic.PrintCB.PrinterNumber := ParallelPortNumber;
          | DOSDevice  :
                 PrintStatic.PrintCB.PortType := PrintStatic.PortDOS;
                 PrintStatic.PrintCB.PrinterNumber := ORD(DOSDev);
          | NullDevice :
                 PrintStatic.PrintCB.PortType := PrintStatic.PortNull;
          ELSE
          END;

        IF ( Method = Serial ) THEN
           CASE BaudRate OF
                  B300   :
                         PrintStatic.PrintCB.BaudRate :=  300;
               |  B600   :
                         PrintStatic.PrintCB.BaudRate :=  600;
               |  B1200  :
                         PrintStatic.PrintCB.BaudRate :=  1200;
               |  B2400  :
                         PrintStatic.PrintCB.BaudRate :=  2400;
               |  B4800  :
                         PrintStatic.PrintCB.BaudRate :=  4800;
               |  B9600  :
                         PrintStatic.PrintCB.BaudRate :=  9600;
               ELSE
                         PrintStatic.PrintCB.BaudRate :=  300;
               END;

           IF ( DataBits = D7 ) THEN
                PrintStatic.PrintCB.NumberOfBits := 7;
           ELSE
                PrintStatic.PrintCB.NumberOfBits := 8;
           END;

           IF (  StopBits = S1 ) THEN
                PrintStatic.PrintCB.StopBits := 1;
           ELSE
                PrintStatic.PrintCB.StopBits := 2;
           END;

           CASE Parity OF
               Even :
                    PrintStatic.PrintCB.ParityBit := TRUE;
                    PrintStatic.PrintCB.EvenParity := TRUE;
            |  Odd  :
                    PrintStatic.PrintCB.ParityBit := TRUE;
                    PrintStatic.PrintCB.EvenParity := FALSE;
            |  None :
                    PrintStatic.PrintCB.ParityBit := FALSE;
            ELSE
            END;

           CASE Protocol OF
               Auto        :
                    PrintStatic.PrintCB.Protocol :=  PrintStatic.NoProtocol;
            |  ClearToSend :
                    PrintStatic.PrintCB.Protocol :=  PrintStatic.CheckCTS;
            |  XONXOFF     :
                    PrintStatic.PrintCB.Protocol :=  PrintStatic.XonXoff;
            ELSE
            END;

            IF (TimeOut = 65535) THEN
               PrintStatic.GlobalTimeOut := 0;
            ELSE
               PrintStatic.GlobalTimeOut := TimeOut;                 (* 27-Sep-89 MWP *)
            END;
        END;
    END;

    RETURN TRUE;

END SaveCommFormContext;


PROCEDURE SavePrinterParams (     OutputFormat : CARDINAL;
                              VAR Parameters   : AFileSectionsArray
                            ) : BOOLEAN;
VAR
    Group                   : PrintStatic.AControlGroup;
    ok                      : BOOLEAN;
BEGIN

    IF ( OutputFormat = DoDiskFile ) THEN
       ok := ReadOneGroup( PrintStatic.PrintCB.ControlStrings[PrintStatic.WPNormal], Normal, Parameters );
       ReadOptionalLines ( Parameters, OutputFormat );
    ELSE
       ok := ReadOneGroup ( PrintStatic.PrintCB.ControlStrings[ PrintStatic.PrinterNormal ], Normal, Parameters );

       PrintStatic.PrintCB.ControlStrings[ PrintStatic.PrinterCompressed ] :=
           PrintStatic.PrintCB.ControlStrings[ PrintStatic.PrinterNormal ];   (* In case of error. *)

       ok := ReadOneGroup ( PrintStatic.PrintCB.ControlStrings[ PrintStatic.PrinterCompressed ], Compressed, Parameters );

       ReadOptionalLines ( Parameters, OutputFormat );

       ReadInitGroup ( PrintStatic.PrintCB.ControlStrings[ PrintStatic.PrinterNormal ], Normal, Parameters );
       ReadInitGroup ( PrintStatic.PrintCB.ControlStrings[ PrintStatic.PrinterCompressed ], Compressed, Parameters );
    END;

    RETURN ( ok );

END SavePrinterParams;

(*
   Read in initialization string stored in Paramters Array as AText data
   type.
*)
PROCEDURE ReadInitGroup ( VAR Group  :  PrintStatic.AControlGroup;
                              Mode   :  CARDINAL;
                          VAR Parameters : AFileSectionsArray );
VAR
    Index          : CARDINAL;
    i,j,
    LookForSection,
    ActualSection  : CARDINAL;
    ControlString  : ARRAY [0..255] OF CHAR;
    Line           : ARRAY [0..255] OF CHAR;
    s              : ARRAY [0..255] OF CHAR;
    C              : CHAR;
    Which          : CHAR;
BEGIN

    (* Determine which mode we are in, so we know which sections to look
       for. Normal uses section 4 for Init string and 5 for Terminate while
       compressed uses 6 for Init and 7 for Terminate.
    *)
    IF ( Mode = Normal ) THEN
        LookForSection := 4;
    ELSE
        LookForSection := 6;
    END;

    (* Init Section *)
    IF ( NOT FindSection ( Parameters, LookForSection, ActualSection ) ) THEN
       Group.Init := AText(NIL);
       RETURN;
    END;

    Group.Init := CreateText ();
    i := 0;

    WHILE ( LineExists ( Parameters[ActualSection].Contents, i ) ) DO
        CopyLine ( Parameters[ActualSection].Contents, i, ControlString );
        IF ( ParseExpression ( ControlString,
                               3,
                               s ) ) THEN
            DecodeString ( s, Line );
            IF NOT AssignLine ( Line, i, Group.Init ) THEN
                 ErrorMessage ( ModuleNumber + 56 );
            END;
        END;
        INC (i);
    END;

    Compress( Group.Init );


    INC(LookForSection);


    (* Terminate Section *)
    IF ( NOT FindSection ( Parameters, LookForSection, ActualSection ) ) THEN
       Group.Terminate := AText(NIL);
       RETURN;
    END;

    Group.Terminate := CreateText ();
    i := 0;

    WHILE ( LineExists ( Parameters[ActualSection].Contents, i ) ) DO
        CopyLine ( Parameters[ActualSection].Contents, i, ControlString );
        IF ( ParseExpression ( ControlString,
                               3,
                               s ) ) THEN
            DecodeString ( s, Line );
            IF NOT AssignLine ( Line, i, Group.Terminate ) THEN
                 ErrorMessage ( ModuleNumber + 56 );
            END;
        END;
        INC (i);
    END;

    Compress( Group.Terminate );

END ReadInitGroup;


    (* ReadOptionalLines -- Read and process lines of the general
                            form:
                            @x=string
                            Stop when a line does not start with "@".
                            *)

PROCEDURE ReadOptionalLines ( VAR Parameters : AFileSectionsArray;
                                  OutputFormat : CARDINAL );
VAR
    Index         : CARDINAL;
    i,j,Section   : CARDINAL;
    C             : CHAR;
    Which         : CHAR;
    ControlString : ARRAY [0..255] OF CHAR;
    s             : ARRAY [0..255] OF CHAR;
BEGIN

    IF ( NOT FindSection ( Parameters, 2, Section ) ) THEN
       ErrorMessage ( ModuleNumber + 9 );
       (* "The structure of the Printer Parameters file is not correct." *)
       RETURN;
    END;

    ControlString[0] := 0C;

    i := OptionalParams;

    IF ( GetTextLine ( Parameters[Section].Contents, i, j, ControlString ) ) THEN
        TrimRear(ControlString);
        IF ( ParseExpression ( ControlString,
                               3,
                               s ) ) THEN

            IF ( LengthOf ( s ) > 0 ) THEN
               IF ( OutputFormat = DoDiskFile ) THEN
                   ExpandStringToXLAT ( s,
                                        PrintStatic.PrintXLAT[ PrintStatic.OutToDisk] );
               ELSE
                   ExpandStringToXLAT ( s,
                                        PrintStatic.PrintXLAT[ PrintStatic.OutToPrinter]);
               END;
           END;
        END;
    ELSE
        RETURN;
    END;

    INC(i);

    IF ( GetTextLine ( Parameters[Section].Contents, i, j, ControlString ) ) THEN
        TrimRear(ControlString);
        IF ( ParseExpression ( ControlString,
                               3,
                               s ) ) THEN
                (* This used to depend on whether s was empty.  Thus, once
                   the overlay name was set to something, you could never
                   change it back to an empty string. -- 11/8/89 EGK
                *)
            Copy (s, PrintStatic.TranslateOverlay);
        END;
    END;


END ReadOptionalLines;




PROCEDURE ReadOneGroup ( VAR Group  :  PrintStatic.AControlGroup;
                             Mode   :  CARDINAL;
                         VAR Parameters : AFileSectionsArray ) : BOOLEAN;
TYPE
    AState = (SNewPage, SNewLine, SNormal, SBold,
              STop, SBottom, SLeft, SRight, SPause, SDone);
VAR
    Index         : CARDINAL;
    i,j,Section   : CARDINAL;
    State         : AState;
    ControlString : ARRAY [0..100] OF CHAR;
    s             : ARRAY [0..255] OF CHAR;
    C             : CHAR;
BEGIN
    MakeDefaults ( Group );

    (* Now read the printer control chars into the appropriate arrays *)
    State := SNewPage;

    IF ( Mode = Normal ) THEN
        i     := NormalParams;
    ELSE
        i     := CompressedParams;
    END;

    (* Grab Section 2 from the Parameters Array. *)
    IF ( NOT FindSection ( Parameters, 2, Section ) ) THEN
       ErrorMessage(ModuleNumber + 9);      (* Bad structure *)
       RETURN FALSE;
    END;

    ControlString[0] := 0C;

    WHILE (State < SDone) DO
        (*
           Grab the individual text lines and parse each into the
           appropriate group parameter.
        *)
        IF ( GetTextLine ( Parameters[Section].Contents, i, j, ControlString ) ) THEN
            TrimRear(ControlString);
            (*
               All the strings will be in the Bal format of
               (x)()(String)
               We are interested in the third entry.
            *)
            IF ( ParseExpression ( ControlString,
                                   3,
                                   s ) ) THEN
                CASE State OF
                    SNewPage:
                               DecodeString ( s, Group.NewPage );
                |   SNewLine:
                               DecodeString ( s,Group.NewLine );
                |   SNormal:
                               DecodeString ( s, Group.Normal );
                |   SBold:
                               DecodeString ( s,Group.Bold );
                |   STop:
                               Group.TopMargin := Number ( s );
                |   SBottom:
                               Group.BottomMargin := Number ( s );
                |   SLeft:
                               Group.LeftMargin := Number ( s );
                |   SRight:
                               Group.RightMargin := Number ( s );
                |   SPause:
                               Group.Pause := TrueOrFalse ( s );
                    ELSE
                       FatalError ();
                END;
            END;

            INC(State);
            ControlString[0] := 0C;
            INC(i);
        ELSE
            RETURN TRUE;
        END;
    END;

    RETURN TRUE;

END ReadOneGroup;


PROCEDURE MakeDefaults ( VAR Group : PrintStatic.AControlGroup );
BEGIN

    MakeDefaultControls ( Group );

    WITH Group DO
        Fill ( Bold, " ", 0 );
        TopMargin    := 3;
        BottomMargin := 63;
        LeftMargin   := 6;
        RightMargin  := 78;
        Pause        := FALSE;
    END;

END MakeDefaults;





PROCEDURE MakeDefaultControls ( VAR Group : PrintStatic.AControlGroup );
BEGIN

    WITH Group DO
        IF ( TextExists ( Init ) ) THEN
            DiscardText ( Init );
        END;

        Init := AText(NIL);

        Fill ( NewPage, 14C, 0 ); (* Form feed *)
        SetString ( NewLine, "12" );
        NewLine[1] := 15C;  (* Carriage return *)
        NewLine[2] := 12C;  (* Line feed       *)
        Fill ( Normal, " ", 0 );
        Fill ( Bold, " ", 0 );

        IF ( TextExists ( Terminate ) ) THEN
            DiscardText ( Terminate );
        END;

        Terminate := AText(NIL);
    END;

END MakeDefaultControls;



PROCEDURE Number(VAR NS:ARRAY OF CHAR):CARDINAL;
VAR
    i,n : CARDINAL;
    s : ARRAY [0..255] OF CHAR;
BEGIN
    i := 1;
    n := StoC(NS,i);
    IF (NS[0] < 1C) OR (i <= ORD(NS[0])) THEN
        GetMessage ( ModuleNumber + 16, s );
        (*  Bad Format )Expecting a number instead of ~  *)
        ConcatLS(s,NS);
        Error(s);
    END;
    RETURN n;
END Number;


PROCEDURE TrueOrFalse(VAR TS:ARRAY OF CHAR):BOOLEAN;
VAR
    i  : CARDINAL;
    Copyright               : ARRAY[0..50] OF CHAR;
    S : ARRAY [0..99] OF CHAR;
    S1 : ARRAY [0..9] OF CHAR;
    S2 : ARRAY [0..5] OF CHAR;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Copy ( TS, S1 );
    Upshift ( S1 );
    LJust ( S1 );
    Procustes ( S1, 1 );
    GetMessage ( ModuleNumber + 17, S2 );
    (* TF *)
    i := Search ( S2, S1, 1 );
    CASE i OF
        1 : RETURN TRUE;
      | 2 : RETURN FALSE;
      ELSE
            GetMessage ( ModuleNumber + 18, S );
            (*  Bad Format )Expecting to find a "T" or "F" instead of ~ *)
            ConcatLS ( S, TS );
            Error ( S );
    END;
    RETURN FALSE;
END TrueOrFalse;




PROCEDURE DoTLPSetup();
VAR
    OutputFormat            : CARDINAL;
    CommFormContext         : ACommFormContext;
    Parameters              : AFileSectionsArray;
    Values                  : AFileSectionsArray;
    LSetupPathName          : ARRAY [0..69] OF CHAR;
    LSetupFileName          : ARRAY [0..9] OF CHAR;
    OverlayName             : ARRAY [0..29] OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;
    Ext                     : ARRAY [0..5]   OF CHAR;
    ok                      : BOOLEAN;

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


    PROCEDURE GetOutputOption ();
    VAR
        Context     : POINTER TO ARRAY [0..255] OF CHAR;
    BEGIN

        Context := OverlayContext();
        IF (Context <> NIL) AND (Context^[0] <> 0C) THEN
            CASE Context^[1] OF
                "P"  :
                       OutputFormat := Printer;
              | "D"  :
                       OutputFormat := DoDiskFile;
            ELSE
                FatalError();
            END;
        ELSE
            FatalError();
        END;

    END GetOutputOption;


    PROCEDURE MakeNewValues();

    VAR
        i                       : CARDINAL;



        PROCEDURE CopyToValues( ParamIndex : CARDINAL );

        VAR
            j                   : CARDINAL;
        BEGIN                   (* CopyToValues *)

            FindOrCreateValuesSection ( Parameters[ParamIndex].Section,
                                        j,
                                        ADR(Values) );

            ok := AssignText(Parameters[ParamIndex].Contents,
                             Values[j].Contents);


        END CopyToValues;

    BEGIN                       (* MakeNewValues *)

        FOR i := 1 TO MaxSections DO
            IF ( NOT ok ) THEN
                RETURN;
            END;

            CASE Parameters[i].Section OF
                1   :
                        (* Printer name etc. *)
                        CopyToValues(i);
            |   2   :
                        (* Printer params *)
                        CopyToValues(i);
            |   3   :   (* Comm Params. Don't do anything *)

            |   4   :   (* Init string normal  *)
                        CopyToValues(i);
            |   5   :   (* Terminate Strings normal *)
                        CopyToValues(i);
            |   6   :   (* Init string compressed  *)
                        CopyToValues(i);
            |   7   :   (* Terminate Strings compressed *)
                        CopyToValues(i);
            ELSE
            END;
        END;

    END MakeNewValues;

BEGIN
    OutputFormat := Printer;
    InitParametersArray();
    InitValuesArray();

    GetOutputOption ();

    MakeDefaultControls ( PrintStatic.PrintCB.ControlStrings[ PrintStatic.NoControls ] );

    Copy(TextPath, LSetupPathName);
    ok := TRUE;

    IF ( OutputFormat = Printer ) THEN
       SetString( Ext, "%PP" );
       Ext[1] := CurrentFileExtension[2];   (* 23-Oct-90 RSC ".4T0" *)
       Copy ( PrintStatic.OutputDeviceName, LSetupFileName);
    ELSE
       SetString( Ext, "%DP" );
       Ext[1] := CurrentFileExtension[2];   (* 23-Oct-90 RSC ".4T0" *)
       Copy ( PrintStatic.OutputDiskName, LSetupFileName);
    END;

    IF ( OutputFormat = Printer ) THEN
        GetMessage ( ModuleNumber + 3, s );
        (* "Printer Devices" *)
    ELSE
        GetMessage ( ModuleNumber + 4, s );                   (* 13-Sep-89 MWP *)
        (* "File Formats" *)
    END;

    ok := (ok AND PickADevice(LSetupPathName, LSetupFileName, Ext, s ));

    IF ( ok ) THEN
        IF ( OutputFormat = Printer ) THEN
            Copy ( LSetupFileName, PrintStatic.OutputDeviceName );
        ELSE
            Copy ( LSetupFileName, PrintStatic.OutputDiskName );
        END;

        DisplayMessage(ModuleNumber + 12);
        (* "One moment ... reading the Parameters file." *)

        ok := (ok AND ReadParametersFile( LSetupPathName,
                                          LSetupFileName,
                                          Ext,
                                          ADR(Parameters) ) );

            (*  Get the Values file from the current directory.  *)

        SetString( s, ".\" );

        IF ( OutputFormat = Printer ) THEN
           SetString( Ext, "%PV" );
           Ext[1] := CurrentFileExtension[2];   (* 23-Oct-90 RSC ".4T0" *)
        ELSE
           SetString( Ext, "%DV" );
           Ext[1] := CurrentFileExtension[2];   (* 23-Oct-90 RSC ".4T0" *)
        END;

        ok := (ok AND ReadValuesFile( s,
                                      LSetupFileName,
                                      Ext,
                                      ADR(Values) ) );

        SetLengthOf(s, 0);       (* erase the One moment ... message *)
        Message(s);

        ok := ( ok AND InitializeCommFormContext( ADR(Parameters),
                                                  ADR(Values),
                                                  ADR(CommFormContext) ) );

        IF ( ok ) AND ( OutputFormat <> DoDiskFile ) THEN
            SetString( s, "\TLFBASE(TLCOMM)" );
            ok := (ok AND CallOverlayWithContext( s, ADR(CommFormContext) )
                   AND (CommFormContext.FormCode <> CancelKey));
        END;

        (*
           Place user specified comm form values into a values array format.
        *)
        IF ( ok ) AND ( OutputFormat <> DoDiskFile ) THEN
           ok := (ok AND PutCommFormContext ( ADR(CommFormContext),
                                              ADR(Values) ) );

           (*
               Save the comm parameters into Timeline internal data structures for
               use by Timeline printer routines.
           *)
           ok := (ok AND SaveCommFormContext (CommFormContext) );
        END;

        GetMessage ( ModuleNumber + 1, s );   (* Translation string. *)

        IF ( OutputFormat = DoDiskFile ) THEN
            ExpandStringToXLAT ( s, PrintStatic.PrintXLAT[ PrintStatic.OutToDisk ] );
        ELSE
            ExpandStringToXLAT ( s, PrintStatic.PrintXLAT[ PrintStatic.OutToPrinter ] );
        END;

        (*
           Save the printer specific parameters into Timeline interanl data
           structures for use by Timeline print routines.
        *)
        ok := (ok AND SavePrinterParams ( OutputFormat, Parameters ) );

            (*  Values file will be saved into the current directory.  *)

        SetString( s, ".\" );

        IF ( ok ) AND ( OutputFormat <> DoDiskFile ) THEN
            MakeNewValues ();

            IF ( OutputFormat = Printer ) THEN
                SetString ( Ext, ".%PV" );
            ELSE
                SetString ( Ext, ".%DV" );
            END;

                (* 1-May-91 RSC Made Ext[1] be Ext[2]. *)
            Ext[2] := CurrentFileExtension[2];   (* 23-Oct-90 RSC ".4T0" *)

            ok := WriteValuesFile( s,
                                   LSetupFileName,
                                   Ext,
                                   ADR(Values) );
            IF (NOT ok) THEN
                ErrorMessage(ModuleNumber + 10);
                (* "Unable to write a new Printer Values file." *)
            END;
        END;
    END;

    DiscardValuesArray();

    DiscardParametersArray();

    IF (NOT ok) THEN
        IF ( OutputFormat = Printer ) THEN
            ErrorMessage(ModuleNumber + 11);
            (* "Printer device setup not completed." *)
        ELSE
            ErrorMessage(ModuleNumber + 13);
            (* "Disk file setup not completed." *)
        END;
    ELSE
        ConfigSaved := FALSE;   (* To say that we modified the options *)
    END;

END DoTLPSetup;

BEGIN

    DoTLPSetup ();

END TLPSetup.
