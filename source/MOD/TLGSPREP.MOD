MODULE TLGSPrep;

(*  =========================================================================
    Last Edit : November 9, 1990 3:14PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        01-Jun-89 WKH   FirstVersion
        14-Jun-89 WKH   Make this really work
        16-Jun-89 WKH   Fix -v={V} to be just v={V}
        19-Jun-89 WKH   Move all batch commands into phrases file.
        26-Jun-89 WKH   Get paths from phrases
        29-Jun-89 WKH   Oops!  wrong phrases file number being used.
        10-Aug-89 KKC   Add copyright message.
        29-Nov-89 EGK   Check for at least DOS 3.0 before doing anything.
        30-Nov-89 WKH   Do what Ed wanted to do.
        06-Dec-89 WKH   OOPS.  Was using a global string as an error msg
                        string.  Most of the time it was correct, put once
                        in a while...  Now do what I really wanted to do.
        03-Oct-90 DSL   CHanged $ to % in filenames for Unix compatability
        23-Oct-90 RSC   Changed %'s to 4's in filenames for Dos batch.
        26-Oct-90 PFG   Fixed Roger's fix.  
         9-Nov-90 PFG   Added fixes from 4.0.3:
                        24-Jul-90 WKH   
                            Damn, on Novell nets, you can open a file as Read/Write 
                            even if you don't have write rights to it as long 
                            as you don't actually write to it!!!  This is how 
                            the use of Lookup slipped by me and testing!!! Arrgh. 
                            Use RequestFileOpenReadOnly from FileOpen instead.
                            Also, delete TLNEXT before writing to it. 
                            Removed an incorrect call to FatalError, and changed
                            uses of FileComplaint to DisplayFileError to give 
                            more accurate error messages. 
                        End of 4.0.3 changes.
    =========================================================================
*)


FROM ASCII         IMPORT
        (* CONST *)     EOL;

FROM Dialog       IMPORT
        (* PROCS *)     Error;

FROM Directory    IMPORT
        (* PROC *)      DOSVersion;

FROM FileAux      IMPORT
        (* PROCS *)     DisplayFileError,
                        FlushBuffer, PrepareForIO, CheckIO,
                        OverlayPath, EXEPath;

FROM FileOpen     IMPORT
        (* PROCS *)     RequestFileOpenReadOnly;  (* 24-Jul-90 WKH *) 

FROM FileSystem   IMPORT
        (* PROCS *)     File, Lookup, Response, Close, WriteChar, Delete;

FROM GaGa         IMPORT
        (* PROCS *)     GetGaGaMessage;

FROM GrafFile     IMPORT
        (* PROCS *)     StartGrafFileInput, ReadGrafFileSection, EndGrafFileInput;

FROM IlsaStatic   IMPORT
        (* TYPES *)     ATLGSConfigRecordPtr,
        (* PROCS *)     TLGSConfigRecord;

FROM LStrings     IMPORT
        (* PROCS *)     SetString, ConcatLS, CtoS, StoC,
                        SubStr, LStringToTString, TStringToLString,
                        Insert, Fill, StringsEqual, Upshift, TrimRear, Copy,
                        LengthOf, Search, Remove, SetLengthOf;

FROM MsgFile      IMPORT
        (* PROCS *)     GetMessage, ConcatMessage, DisplayMessage;

FROM Overlays     IMPORT
        (* VARS  *)     PackageOK;

FROM ParmLine     IMPORT
        (* PROCS *)     GetOption;

FROM Schedule     IMPORT
    (* VAR *)           CurrentFileExtension;

FROM Text         IMPORT
        (* PROC *)      AText, TextExists, LineExists, CopyLine, DiscardText;

FROM Words        IMPORT
        (* PROC *)      ParseString;

CONST
    ModuleNumber            = 6400;
    NoConfigMsg             = 0;
    BadParmFileMsg          = 1;
    TLGSExePathMsg          = 2;
    GDriversPathMsg         = 3;
    TextPathMsg             = 4;
    DOSVersionMsg           = 10;           (* 11/29/89 EGK *)
    StartOfBatchFile        = 20;
    InterfaceFileName       = "DK:TLNEXT.BAT";


VAR
    ParmFileName            : ARRAY [0..9] OF CHAR;
    Section1Text            : AText;



PROCEDURE MassageLine( VAR Line : ARRAY OF CHAR ) : BOOLEAN;

CONST
    TLSTARTModuleNumber = 12300;

VAR
    FoundAt                 : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..255] OF CHAR;
    Found                   : BOOLEAN;
    f                       : File;
    i                       : CARDINAL;
    s3                      : ARRAY [0..11]  OF CHAR;
    ValuesFileExt,
    ParmFileExt             : ARRAY [0..4]   OF CHAR;

BEGIN
    SetString(ParmFileExt, ".4GP" );
    ParmFileExt[2] := CurrentFileExtension[2]; (* ".4T0" *) (* 23-Oct-90 RSC *)

    Copy( ParmFileExt, ValuesFileExt );
    ValuesFileExt[4] := "V";  (* ".4GV" *)


    (* Translate {V} to VALUES FILE *)

    SetString( s, "{V}" );
    FoundAt := Search( Line, s, 1 );
    IF (FoundAt > 0) THEN
        Remove( Line, FoundAt, LengthOf(s) );
        Copy(ParmFileName, s );
        ConcatLS(s, ValuesFileExt );
        Insert( Line, s, FoundAt );
    END;

    (* Translate {T} to TLG/S executable name, full path specification *)

    SetString( s, "{T}" );
    FoundAt := Search( Line, s, 1 );
    IF (FoundAt > 0) THEN
        Remove( Line, FoundAt, LengthOf(s) );
        Copy(EXEPath, s);
        ConcatMessage(s, ModuleNumber + TLGSExePathMsg);
        Insert( Line, s, FoundAt );
    END;

    (* Translate {P} to OverlayPath from command line *)

    SetString( s, "{P}" );
    FoundAt := Search( Line, s, 1 );
    IF (FoundAt > 0) THEN
        Remove( Line, FoundAt, LengthOf(s) );
        GetGaGaMessage( TLSTARTModuleNumber + 1, s ); (* "PATH" *)
        GetOption( s, Found, s2 );
        IF (Found) THEN
            Insert( Line, s2, FoundAt );
        END;
    END;

    (* Translate {E} to GetOutOfHere!!! *)

    SetString( s, "{E}" );
    FoundAt := Search( Line, s, 1 );
    IF (FoundAt > 0) THEN
        RETURN FALSE;
    END;

    (* Translate {D} to Device Driver name *)

    SetString( s, "{D}" );
    FoundAt := Search( Line, s, 1 );
    IF (FoundAt > 0) THEN
        Remove( Line, FoundAt, LengthOf(s) );

        Copy(EXEPath, s);
        ConcatMessage(s, ModuleNumber + TextPathMsg);
        Copy(ParmFileName, s2); 
        ConcatLS(s2, ParmFileExt ); 

        PrepareForIO(f);

        IF (RequestFileOpenReadOnly(s, s2, s2, f)) THEN  (* 24-Jul-90 WKH *)
            IF (NOT StartGrafFileInput(f)) THEN 
                DisplayFileError(f, s2);
                PackageOK := FALSE;
                Close(f);
                RETURN PackageOK;
            ELSE
                IF (NOT ReadGrafFileSection(f, 1, Section1Text)) THEN 
                    DisplayFileError( f, s2 );

                    PackageOK := FALSE;
                    Close(f); 
                    RETURN PackageOK;
                ELSE
                    EndGrafFileInput(f);
                    Close(f);

                    IF (NOT GetTextLine(Section1Text, 1, i, s2)) THEN
                        GetMessage(ModuleNumber + BadParmFileMsg, s);
                        ConcatLS(s, ParmFileName);
                        ConcatLS(s, ParmFileExt);
                        Error(s);
                        IF (Section1Text <> AText(NIL)) THEN
                            DiscardText(Section1Text);
                        END;
                        PackageOK := FALSE;
                        RETURN PackageOK;
                    END;

                    IF (Section1Text <> AText(NIL)) THEN
                        DiscardText(Section1Text);
                    END;
                END;
            END;
        ELSE
            PackageOK := FALSE;
            RETURN PackageOK;
        END;

        Copy(EXEPath, s);
        ConcatMessage(s, ModuleNumber + GDriversPathMsg);

        Remove(s2, 1, 1);   (* Get rid of "(" *)

        SetString(s3, ".");

        i := Search(s2, s3, 1);

        IF (i > 0) THEN
            Remove(s2, i, 5);  (* Get rid of .EXE), .COM), or .BAT) *)
        END;

        ConcatLS(s, s2);

        Insert( Line, s, FoundAt );

    END;

    RETURN TRUE;

END MassageLine;


(* Scans a text looking for the Nth non-comment line.

    Preconditions
                    TheText     A text with lines in it.
                    LogicalLine desired line, starting with 1.
    Postconditions
                    PhysLine    physical line found on, starting at 0.
                    s           text found.
*)
PROCEDURE GetTextLine( VAR TheText      : AText;
                           LogicalLine  : CARDINAL;
                       VAR PhysLine     : CARDINAL;
                       VAR s            : ARRAY OF CHAR ) : BOOLEAN;
VAR
    ErrorText   : ARRAY [0..255] OF CHAR;

BEGIN
    PhysLine := 0;
    WHILE (LogicalLine > 0) DO
        IF (LineExists( TheText, PhysLine )) THEN
            CopyLine( TheText, PhysLine, s );
            IF (NOT ((LengthOf(s) > 1)    AND     (* IF not a comment, *)
                     (s[1] = "-")         AND
                     (s[2] = "-")))       THEN
                DEC(LogicalLine);                (* THEN dec count of lines *)
            END;
        ELSE
            RETURN FALSE;
        END;
        INC(PhysLine);                           (* and go on to the next.  *)
    END;

    DEC(PhysLine);  (* Oops.  We are one higher than we want. *)

    RETURN TRUE;

END GetTextLine;


PROCEDURE MakeTLGSBatchFile();

VAR
    i                       : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;
    f                       : File;
    ConfigRecord            : ATLGSConfigRecordPtr;
    Copyright               : ARRAY[0..50] OF CHAR;


    PROCEDURE Print( VAR s : ARRAY OF CHAR );

    VAR
        i                   : CARDINAL;
        s2                  : ARRAY [0..255] OF CHAR; 

    BEGIN
        i := 1;
        WHILE (i <= ORD(s[0]) ) AND (CheckIO(f) = done) DO
            WriteChar(f,s[i]);
            IF (CheckIO(f) <> done) THEN
                SetString( s2, InterfaceFileName ); 
                DisplayFileError(f, s2);
                PackageOK := FALSE; 
                f.res := notdone; (* So we don't try again. *)
                RETURN;
            END;
            INC(i);
        END;
    END Print;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    IF (DOSVersion() < 0300H) THEN          (* 11/29/89 EGK *)
        GetMessage (ModuleNumber+DOSVersionMsg, s);
        Error (s);
        PackageOK := FALSE;
        RETURN;
    END;

    ConfigRecord := TLGSConfigRecord();
    PackageOK    := TRUE;
    Section1Text := AText(NIL);

    GetMessage(ModuleNumber + NoConfigMsg, s);
    WITH ConfigRecord^ DO
        IF (NOT TextExists(ConfigDescription)) THEN
            Error(s);
            PackageOK := FALSE;
        ELSIF (NOT LineExists(ConfigDescription, 1)) THEN
            Error(s);
            PackageOK := FALSE;
        ELSE
            CopyLine(ConfigDescription, 1, ParmFileName);
            IF (LengthOf(ParmFileName) = 0) THEN
                Error(s);
                PackageOK := FALSE;
            END;
        END;
    END;

    IF (PackageOK) THEN
            (* Create a new file with a set name. *)

        PrepareForIO(f);
        Delete(InterfaceFileName, f);  (* 24-Jul-90 WKH *)
        PrepareForIO(f);
        Lookup(f,InterfaceFileName,TRUE);
        IF (CheckIO(f) <> done) THEN
            SetString(s, InterfaceFileName);
            DisplayFileError(f, s); 
            PackageOK := FALSE;
            RETURN;
        END;

        i := ModuleNumber + StartOfBatchFile;

        GetMessage(i, s);

        WHILE (MassageLine(s)) DO
            Print(s);
            IF (CheckIO(f)=done) THEN
                WriteChar(f,EOL);
            END;
            INC(i);

            GetMessage(i, s);
        END;

            (* Always close our files. *)

        Close(f);
    END;

END MakeTLGSBatchFile;



BEGIN
    MakeTLGSBatchFile();
END TLGSPrep.
