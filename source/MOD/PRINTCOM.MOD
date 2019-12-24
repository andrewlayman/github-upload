IMPLEMENTATION MODULE PrintCommon;
    (* PrintCommon contains routines common to both the Timeline printer
       interface routines and the TLGS printer routines.
    *)

    (* MODIFICATION HISTORY:

         1-Aug-89  MWP  In the beginning...
        18-Aug-89  KKC  Rewrite PickADevice and move it to DeviceColumns
        18-Aug-89  MWP  Use Line 2 of section 1 for Device name, instead of
                        Line 3, the device description.
        31-Aug-89  LAA  Hard-coded into this module the standard U.S. real
                        number format.  This ensures that all numbers written
                        to the graphics parameters files will be in the
                        format expected by TLG/S drivers, even when used
                        internationally.
         1-Sep-89  MWP  Include support for output to disk file.
        22-Sep-89  KKC  Make s to 255 characters long in 
                        InitializeCommFormContext
        21-Nov-89  RSC  Make a default file name.
        29-Nov-89  RSC  Don't use "Lookup" for the parameters file.
        30-Apr-90  RSC  Remove the comma from the numbers, as the sweeds were
                        interpreting the comma as a decimal point char.

                        The full fix is to ignore any fancy formatting of
                        these numbers, and to not interpret the number format
                        in TLSTART.
        15-Feb-91  RSC  Remove the import of Direct411.
        21-Feb-91  RSC  Remove the NotYetImplementeds.
        26-Mar-91  AJL  More error checking.
        23-Apr-91  RSC  Too much error checking!!
                        I think the fix of 26-Mar-91 introduced a bug where
                        the missing VALUES file caused an abort of the setup
                        of a NEW values file.
    *)

FROM BalExpr    IMPORT
    (* PROC *)      ParseCardinal, ParseExpression, LStringToExpression;

FROM CommStatic IMPORT
    (* TYPE *)      ACommFormContext, AMethod,   ABaudRate,  AStopBits,
                    ADataBits,        AProtocol, ADOSDevice, AParity,
    (* CONST *)     HighestMethod,   HighestBaudRate, HighestDataBits,
                    HighestStopBits, HighestParity,   HighestProtocol,
                    HighestDOSDevice;

FROM Dialog     IMPORT
    (* PROC *)      Error, FatalError, Message, NotYetImplemented;

FROM Directory  IMPORT
    (* TYPE *)      AFileAttributeSet, AFileAttribute,
    (* PROC *)      FileLookupStart;

FROM FileAux    IMPORT
    (* PROC *)      CheckIO, PrepareForIO;

FROM FileOpen   IMPORT
    (* PROC *)      RequestFileOpenReadOnly;

FROM FileSystem IMPORT
    (* TYPE *)      File, Response,
    (* PROC *)      Lookup, Close, Delete, Rename;


FROM GrafFile   IMPORT
    (* PROC *)      StartGrafFileInput,  StartGrafFileOutput,
                    ReadGrafFileSection, WriteGrafFileSection,
                    EndGrafFileInput,    EndGrafFileOutput,
                    ForAllGrafFileSections;

FROM LStrings   IMPORT
    (* PROC *)      SetString, LengthOf, Copy, ConcatS, ConcatLS, SubStr,
                    TStringToLString, SetLengthOf, TrimRear, Search,
                    LStringToTString, Remove, Insert, Upshift, CtoS,
                    StringsEqual, StoC;

FROM Menus      IMPORT
    (* PROC *)      WordNumber;

FROM MsgFile    IMPORT
    (* PROC *)      GetMessage;

FROM RealFormat IMPORT
    (* TYPE *)      AnAmountFormat,
    (* PROC *)      FormatAsAmount;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS;

FROM Text       IMPORT
    (* TYPE *)      AText,
    (* PROC *)      CreateText, DiscardText, AppendLine, AssignLine,
                    LineExists, TextExists, CopyLine, AssignText;


CONST
    ModuleNumber            = 14050;

VAR
    BaudRateTable           : ARRAY ABaudRate OF CARDINAL;
    USAmountFormat          : AnAmountFormat;


PROCEDURE ErrorMessage(    PhraseNo         : CARDINAL);

VAR
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* ErrorMessage *)

    GetMessage(PhraseNo, s);
    Error(s);

END ErrorMessage;



(* Given a path and file name, try to open a file.
*)
PROCEDURE GetFile( VAR Path,
                       FileName,
                       Ext              : ARRAY OF CHAR;
                   VAR TheFile          : File;
                       CreateFile       : BOOLEAN;
                   VAR FileExists       : BOOLEAN
                                      ) : BOOLEAN;
VAR
    Attributes   : AFileAttributeSet;
    FullFileName : ARRAY [0..159] OF CHAR;
    FoundFile    : ARRAY [0..59]  OF CHAR;

BEGIN
    Copy( Path, FullFileName );
    ConcatLS(   FullFileName, FileName );
    ConcatS(    FullFileName, "." );
    ConcatLS(   FullFileName, Ext );

    Copy( FileName, FoundFile );
    Attributes := AFileAttributeSet{ReadOnlyAttribute};

    PrepareForIO( TheFile );

    (* Does the file already exist? *)
    FileExists := FileLookupStart( FullFileName, FoundFile, Attributes );

    LStringToTString( FullFileName, FullFileName );

    PrepareForIO( TheFile );
    Lookup( TheFile, FullFileName, CreateFile );

    (* If there was a file error, return FALSE. *)

    RETURN (CheckIO( TheFile ) = done);

END GetFile;

(*
    ReadSections --

    Read a section of the Parameters or Values file into an element of
    the SectionsArray passed as the context.  This allows the procedure
    to be used for reading both Parameters and Values files.

    Preconditions:
        The SourceFile must be open, and StartGrafFileInput must have been
        called on it.  The SectionsArray must have been initialized so that
        all unused sections have a section number of zero.

    Postconditions:
        The indicated section will be read from the SourceFile, and put into
        the SectionsArray, if possible.  Otherwise, the SectionsArray will be
        unchanged.  File errors must be detected by the caller, due to
        restrictions on the parameters that may be passed.
*)

PROCEDURE ReadSections(VAR SourceFile       : File;
                           TheSection       : CARDINAL;
                           SectionsArray    : ADDRESS    );

VAR
    TheText                 : AText;
    SectionsPtr             : POINTER TO AFileSectionsArray;
    i                       : CARDINAL;

BEGIN                       (* ReadSections *)

    SectionsPtr := SectionsArray;

    IF (ReadGrafFileSection( SourceFile, TheSection, TheText )) THEN
        IF (FindNewSection(SectionsPtr^, i)) THEN
            SectionsPtr^[i].Section := TheSection;
            SectionsPtr^[i].Contents := TheText;
        ELSE
            FatalError();
        END;
    END;

END ReadSections;


(*  FindSection --

    Locate a section in the given SectionsArray by number, and return its
    index.
*)

PROCEDURE FindSection(VAR SectionsArray     : AFileSectionsArray;
                          TheSection        : CARDINAL;
                      VAR I                 : CARDINAL          )
                                                                 : BOOLEAN;

BEGIN                       (* FindSection *)

    I := 1;
    WHILE ((I <= MaxSections) AND (SectionsArray[I].Section <> TheSection)) DO
        INC(I);
    END;

    RETURN (I <= MaxSections);

END FindSection;





(*  FindNewSection --

    Locate a new section in the given SectionsArray by number, and return its
    index.
*)

PROCEDURE FindNewSection(VAR SectionsArray  : AFileSectionsArray;
                         VAR I              : CARDINAL          )
                                                                 : BOOLEAN;

BEGIN                       (* FindNewSection *)

    RETURN (FindSection(SectionsArray, Unused, I));

END FindNewSection;







PROCEDURE FileOk( VAR f : File ) : BOOLEAN;
VAR
    Res : Response;
BEGIN
    Res := CheckIO(f);
    RETURN (Res = done) OR ((* (Res = notdone) AND *) f.eof);   (* 23-Apr-91 RSC  *)
END FileOk;







(*
    ReadParametersFile --

    Read the parameters file indicated by the PathName and FileName into
    the parameters array.

    Preconditions:
        The PathName and FileName should indicate an existing directory and
        file.
        Parameters is a valid address of AFileSectionsArray.

    Postconditions:
        All the sections of the indicated parameters file will be read into
        the global Parameters array, if possible, and TRUE returned.  If the
        file could not be correctly read, FALSE will be returned.
*)

PROCEDURE ReadParametersFile(VAR PathName    : ARRAY OF CHAR;
                             VAR FileName    : ARRAY OF CHAR;
                             VAR Extension   : ARRAY OF CHAR;
                                 Parameters  : ADDRESS ) : BOOLEAN;

VAR
    ParmFile                : File;
    i                       : CARDINAL;
    ok                      : BOOLEAN;
    FileExists              : BOOLEAN;
    Ext                     : ARRAY [0..5] OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;
    s1                      : ARRAY [0..1] OF CHAR;

BEGIN                       (* ReadParametersFile *)

    ok := FALSE;

    Copy( FileName, s );
    ConcatS( s, "." );
    ConcatLS( s, Extension );
    SetLengthOf( s1, 0 );

    IF (RequestFileOpenReadOnly(PathName, s, s1, ParmFile)) THEN
        IF (StartGrafFileInput(ParmFile)) THEN
            ForAllGrafFileSections(ParmFile, ReadSections, Parameters);
            ok := FileOk(ParmFile);
            EndGrafFileInput(ParmFile);
        ELSE
            ErrorMessage( ModuleNumber );  (* "Graphics Parameters file is inaccessible.  Please pick another one." *)
        END;
        Close(ParmFile);
    ELSE
        ErrorMessage( ModuleNumber );  (* "Graphics Parameters file is inaccessible.  Please pick another one." *)
        (* "Parameters file is inaccessible.  Please pick another one." *)
    END;

    RETURN ok;

END ReadParametersFile;


PROCEDURE ReadValuesFile(VAR PathName       : ARRAY OF CHAR;
                         VAR FileName       : ARRAY OF CHAR;
                         VAR Extension      : ARRAY OF CHAR;
                             Values         : ADDRESS ) : BOOLEAN;

VAR
    ValuFile                : File;
    i                       : CARDINAL;
    ok                      : BOOLEAN;
    FileExists              : BOOLEAN;
    Ext                     : ARRAY [0..5] OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* ReadValuesFile *)

    ok := TRUE;
    ValuesFileFound := FALSE;

    IF (GetFile(PathName, FileName, Extension, ValuFile, FALSE, FileExists)) THEN
        IF (StartGrafFileInput(ValuFile)) THEN
            ForAllGrafFileSections(ValuFile, ReadSections, Values);
            ok := FileOk(ValuFile);
            EndGrafFileInput(ValuFile);
        ELSE
            ok := FALSE;
        END;
        ValuesFileFound := TRUE;
        Close(ValuFile);
    ELSE
        ok := (CheckIO( ValuFile ) = done) OR
              (CheckIO( ValuFile ) = unknownfile);   (* 23-Apr-91 RSC  *)
    END;

    IF (NOT ok) THEN
        ErrorMessage( ModuleNumber+1 );
    END;

    RETURN ok;

END ReadValuesFile;



PROCEDURE WriteValuesFile( VAR PathName      : ARRAY OF CHAR;
                           VAR FileName      : ARRAY OF CHAR;
                           VAR Extension     : ARRAY OF CHAR;
                               ValuesArray   : ADDRESS ) : BOOLEAN;

VAR
    TheValuesFile           : File;
    i                       : CARDINAL;
    Temp                    : AFileSectionRecord;
    s                       : ARRAY [0..69] OF CHAR;
    Sorted                  : BOOLEAN;
    ValuesPtr               : POINTER TO AFileSectionsArray;

BEGIN                       (* WriteValuesFile *)

    ValuesPtr := ValuesArray;

    (* Create a new values file *)

    Copy(PathName, s);
    ConcatLS(  s, FileName );
    ConcatLS(   s, Extension );
    LStringToTString( s, s );

    PrepareForIO( TheValuesFile );
    Delete( s, TheValuesFile );    (* Delete old file *)
    PrepareForIO( TheValuesFile );
    Lookup( TheValuesFile, s, TRUE );
    IF (CheckIO( TheValuesFile ) <> done) THEN
        ErrorMessage(ModuleNumber + 1); (* "Values Inaccessible." *)
        (* "Values file is inaccessible.  Please pick another one. " *)
        RETURN FALSE;
    END;

    REPEAT
        Sorted := TRUE;
        FOR i := 1 TO MaxSections - 1 DO
            IF (ValuesPtr^[i].Section > ValuesPtr^[i+1].Section) THEN
                Temp := ValuesPtr^[i];
                ValuesPtr^[i] := ValuesPtr^[i+1];
                ValuesPtr^[i+1] := Temp;
                Sorted := FALSE;
            END;
        END;
    UNTIL (Sorted);

    IF (StartGrafFileOutput(TheValuesFile)) THEN
        FOR i := 1 TO MaxSections DO
            IF (ValuesPtr^[i].Section <> Unused) THEN
                WITH ValuesPtr^[i] DO
                    IF (NOT WriteGrafFileSection(Contents, Section, TheValuesFile)) THEN
                    END;
                END;
            END;
        END;
        EndGrafFileOutput(TheValuesFile);
    END;

    IF (CheckIO( TheValuesFile ) <> done) THEN
        ErrorMessage(ModuleNumber + 2);
        (* "Error writing new Values file" *)
        Close(TheValuesFile);
        RETURN FALSE;
    END;

    Close( TheValuesFile );

    RETURN TRUE;

    IF (CheckIO( TheValuesFile ) <> done) THEN
        ErrorMessage(ModuleNumber + 2);
        (* "Error writing new Values file" *)
        RETURN FALSE;
    END;

END WriteValuesFile;




(* Initialize a Comm Form Context record.
*)
PROCEDURE InitializeCommFormContext(     ParamsArray     : ADDRESS;
                                         ValuesArray     : ADDRESS;
                                         CommFormContext : ADDRESS
                                    ) : BOOLEAN;
VAR
    TheText                     : AText;
    i                           : CARDINAL;
    Where                       : CARDINAL;
    s                           : ARRAY [0..255] OF CHAR;
    ok                          : BOOLEAN;
    ParamsPtr                   : POINTER TO AFileSectionsArray;
    ValuesPtr                   : POINTER TO AFileSectionsArray;
    CommPtr                     : POINTER TO ACommFormContext;

BEGIN

    ParamsPtr := ParamsArray;
    ValuesPtr := ValuesArray;
    CommPtr   := CommFormContext;

    WITH CommPtr^ DO
        FormCode            := 0;
        Method              := Parallel;
        ParallelPortNumber  := 1;
        SerialPortNumber    := 0;
        BaudRate            := B2400;
        DataBits            := D8;
        StopBits            := S1;
        Parity              := None;
        TimeOut             := 65535;  (* No time out *)
        Protocol            := ClearToSend;
        DOSDev              := LPT1;                          (* 13-Jun-89 LAA *)

        SetLengthOf(DeviceName, 0);

        (* 21-Nov-89 RSC Changed this to a default name as per bug 1774.
        SetLengthOf(FileName, 0);                             (* 1-Sep-89 MWP *)
        *)
        GetMessage( ModuleNumber + 36, FileName ); (* DK:.\GRAPHICS.TXT *)
    END;

    (* Parameters section 1 has the device description in it. *)

    ok := FALSE;

    IF (FindSection(ParamsPtr^, 1, i)) THEN
        IF (GetTextLine( ParamsPtr^[i].Contents, 2, Where, s )) THEN    (* 19-Aug-89 MWP *)
            IF (ParseExpression( s, 1, CommPtr^.DeviceName )) THEN
                ok := TRUE;
            END;
        END;
    END;

    IF (ok) THEN
        IF (FindSection(ValuesPtr^, 3, i)) THEN
            IF (NOT DigestCommunicationSection ( ValuesPtr^[i].Contents,
                                                 CommFormContext ) ) THEN
                ok := FALSE;
            END;
        ELSIF (MakeTextForCommunications(TheText)) THEN
            IF (NOT DigestCommunicationSection ( TheText,
                                                 CommFormContext ) ) THEN
                ok := FALSE;
            END;
        ELSE
            ok := FALSE;
        END;
    END;

    RETURN ( ok );

END InitializeCommFormContext;



(* Create text for the comm section from the phrases file.  *)

PROCEDURE MakeTextForCommunications(VAR CommSection : AText): BOOLEAN;

VAR
    i           : CARDINAL;
    TheText     : AText;
    s           : ARRAY [0..255] OF CHAR;
    Word        : ARRAY [0..79]  OF CHAR;
    ok          : BOOLEAN;
BEGIN

    TheText := CreateText();
    IF (TheText = AText(NIL)) THEN
        ErrorMessage ( ModuleNumber + 4 );
        (* "There is not sufficient memory to perform the requested function." *)
        RETURN FALSE;
    ELSE
        GetMessage( ModuleNumber + 5, s ); (* Default Communications settings. *)
        (* "(1)(6)(0),(2)(2)(0),(3)(2)(0),(4)(2)(9600),(5)(6)(1),(6)(6)(0),(7)(6)(0),(8)(2)(20),(9)(6)(1)," *)

        i := 1;

        WordNumber( s, i, Word );
        WHILE (LengthOf(Word) > 0) DO
            IF (NOT AppendLine(Word, TheText)) THEN
                ErrorMessage(ModuleNumber + 6);
                (* "There is not sufficient virtual memory to
                    perform the requested function." *)
                DiscardText(TheText);
                RETURN FALSE;
            END;
            INC(i);
            WordNumber( s, i, Word );
        END;

    END;

    CommSection := TheText;

    RETURN TRUE;

END MakeTextForCommunications;


(* Digest the section of the file that contains the comm parameters.
   Place these params into the CommFormContext.

   Header is section 1 of the file, Params is section 3.

   See "Graffile.Doc" Page 12.

*)
PROCEDURE DigestCommunicationSection(     CommSection     : AText;
                                          CommFormContext : ADDRESS
                                     ) : BOOLEAN;
VAR
    i,
    Section,
    Type,
    Value,
    Where   : CARDINAL;
    TheFileName,        (* 21-Nov-89 RSC *)
    s       : ARRAY [0..99] OF CHAR;
    ok      : BOOLEAN;
    CommPtr : POINTER TO ACommFormContext;

BEGIN

    CommPtr   := CommFormContext;

    (* We expect 10 lines of data. *)

    FOR i := 1 TO 10 DO
        ok := (GetTextLine( CommSection, i, Where, s )  AND
               ParseCardinal( s, 1, Section )      AND
               ParseCardinal( s, 2, Type    )      AND
               ParseCardinal( s, 3, Value   ));

        ok := (ok AND (Section = i));

        IF (ok) THEN
            WITH CommPtr^ DO
                CASE Section OF
                    1 : IF (Value > ORD(HighestMethod)) THEN
                            ok := FALSE;
                        ELSE
                            Method := AMethod(CHR(Value));
                        END;

                  | 2 : IF (Value > 3) THEN
                            ok := FALSE;
                        ELSE
                            ParallelPortNumber := Value;
                        END;

                  | 3 : IF (Value > 4) THEN
                            ok := FALSE;
                        ELSE
                            SerialPortNumber := Value;
                        END;

                  | 4 : BaudRate := B300;
                        WHILE (BaudRate < HighestBaudRate) AND
                              (Value <> BaudRateTable[BaudRate]) DO
                            INC(BaudRate);
                        END;

                        ok := (Value = BaudRateTable[BaudRate]);

                  | 5 : IF (Value > ORD(HighestDataBits)) THEN
                            ok := FALSE;
                        ELSE
                            DataBits := ADataBits(CHR(Value));
                        END;

                  | 6 : IF (Value > ORD(HighestStopBits)) THEN
                            ok := FALSE;
                        ELSE
                            StopBits := AStopBits(CHR(Value));
                        END;

                  | 7 : IF (Value > ORD(HighestParity)) THEN
                            ok := FALSE;
                        ELSE
                            Parity := AParity(CHR(Value));
                        END;

                  | 8 : TimeOut := Value;

                  | 9 : IF (Value > ORD(HighestProtocol)) THEN
                            ok := FALSE;
                        ELSE
                            Protocol := AProtocol(CHR(Value));
                        END;

                  | 10: IF (Value > ORD(HighestDOSDevice)) THEN
                            ok := FALSE;
                        ELSE
                            DOSDev := ADOSDevice(CHR(Value));     (* 13-Jun-89 LAA *)
                        END;
                ELSE
                    ok := FALSE;
                END;
            END;
        END;

        IF (NOT ok) THEN
            ErrorMessage( ModuleNumber + 7 );
            (* "The structure of the Values file is not correct." *)
        END;
    END;

    (* Get filename entry, if one exists. *)
    ok := ( ok AND GetTextLine ( CommSection, 11, Where, s ) );    (* 1-Sep-89 MWP *)
    ok := ( ok AND ParseExpression ( s, 3, TheFileName ) );
    IF (LengthOf(TheFileName) > 0) THEN     (* 21-Nov-89 RSC *)
        Copy( TheFileName, CommPtr^.FileName );
    END;

    RETURN ok;

END DigestCommunicationSection;



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



(*  PutCommFormContext --

    Put the Communications Form Context to the Values array in section
    number 3.  If that section already exists, its contents will be
    replaced by the Context.

    Preconditions:
        The CommFormContext should have been initialized, and the Values
        array must have been initialized.

    Postconditions:
        The CommFormContext will be converted into the appropriate structure
        and stored in the Values array as section 3, and TRUE will be
        returned.  If this can't be done, FALSE will be returned.
*)

PROCEDURE PutCommFormContext ( CommFormContext : ADDRESS;
                               ValuesArray     : ADDRESS ) : BOOLEAN;

VAR
    i           : CARDINAL;
    TheText     : AText;
    s           : ARRAY [0..255] OF CHAR;
    s2          : ARRAY [0..1] OF CHAR;
    ValuesPtr   : POINTER TO AFileSectionsArray;
    CommPtr     : POINTER TO ACommFormContext;


    PROCEDURE ConcatExpr( VAR PreviousStuff  : ARRAY OF CHAR;
                              CardToAdd      : CARDINAL );
    VAR
        CardAsAString,
        CardAsAnExpression  : ARRAY [0..9] OF CHAR;
    BEGIN
        CtoS( CardToAdd, CardAsAString );
        LStringToExpression( CardAsAString, CardAsAnExpression );
        ConcatLS( PreviousStuff, CardAsAnExpression );
    END ConcatExpr;


BEGIN                       (* PutCommFormContext *)

    ValuesPtr := ValuesArray;
    CommPtr   := CommFormContext;

    TheText := CreateText();
    IF (TheText = AText(NIL)) THEN
        ErrorMessage(ModuleNumber + 4);
        (* "There is not sufficient memory to perform the requested function." *)
        RETURN FALSE;
    END;

    FOR i := 1 TO 11 DO                                           (* 24-Jul-89 LAA *)

        SetLengthOf( s, 0 );

        ConcatExpr( s, i );

        WITH CommPtr^ DO
            CASE i OF
                1:  ConcatExpr( s, 6 );
                    ConcatExpr( s, ORD(Method) );

              | 2:  ConcatExpr( s, 6 );
                    ConcatExpr( s, ParallelPortNumber );

              | 3:  ConcatExpr( s, 6 );
                    ConcatExpr( s, SerialPortNumber );

              | 4:  ConcatExpr( s, 2 );
                    ConcatExpr( s, BaudRateTable[BaudRate] );

              | 5:  ConcatExpr( s, 6 );
                    ConcatExpr( s, ORD(DataBits) );

              | 6:  ConcatExpr( s, 6 );
                    ConcatExpr( s, ORD(StopBits) );

              | 7:  ConcatExpr( s, 6 );
                    ConcatExpr( s, ORD(Parity) );

              | 8:  ConcatExpr( s, 2 );
                    ConcatExpr( s, TimeOut );

              | 9:  ConcatExpr( s, 6 );
                    ConcatExpr( s, ORD(Protocol) );

              | 10: ConcatExpr( s, 6 );
                    ConcatExpr( s, ORD(DOSDev) );                 (* 13-Jun-89 LAA *)

(*
              | 11: SetLengthOf(s2, 0);                           (* 24-Jul-89 LAA *)
                    StringExpression(s2, 11, s);
*)
              | 11:
                    StringExpression ( FileName, 11, s);

            END;

        END;

        IF (NOT AppendLine(s, TheText)) THEN
            ErrorMessage(ModuleNumber + 6);     (*  Out of EMS memory *)
            (* "There is not sufficient virtual memory to
                perform the requested function." *)
            DiscardText( TheText );
            RETURN FALSE;
        END;

    END;

    FindOrCreateValuesSection(3, i, ValuesArray);

    ValuesPtr^[i].Contents := TheText;

    RETURN TRUE;

END PutCommFormContext;




PROCEDURE EmbedInExpression(    String      : ARRAY OF CHAR;
                                Id          : CARDINAL;
                                Type        : CARDINAL;
                            VAR Expression  : ARRAY OF CHAR);

VAR
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..9] OF CHAR;

BEGIN                       (* EmbedInExpression *)

    CtoS(Id, s);
    LStringToExpression(s, Expression);
    CtoS(Type, s);
    LStringToExpression(s, s2);
    ConcatLS(Expression, s2);
    TrimRear(String);
    LStringToExpression(String, s);
    ConcatLS(Expression, s);

END EmbedInExpression;



PROCEDURE RealExpression(    Value          : REAL;
                             Id             : CARDINAL;
                         VAR Expression     : ARRAY OF CHAR);

VAR
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* RealExpression *)

    FormatAsAmount(Value, USAmountFormat, s, 20, 0, 5, FALSE);    (* 31-Aug-89 LAA *)
    EmbedInExpression(s, Id, 2, Expression);

END RealExpression;





PROCEDURE BoolExpression(    Value          : BOOLEAN;
                             Id             : CARDINAL;
                         VAR Expression     : ARRAY OF CHAR);

VAR
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* BoolExpression *)

    CtoS(ORD(Value), s);
    EmbedInExpression(s, Id, 5, Expression);

END BoolExpression;


PROCEDURE EnumExpression(    Value          : CARDINAL;
                             Id             : CARDINAL;
                         VAR Expression     : ARRAY OF CHAR);

VAR
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* EnumExpression *)

    CtoS(Value, s);
    EmbedInExpression(s, Id, 2, Expression);

END EnumExpression;


PROCEDURE StringExpression(VAR Value        : ARRAY OF CHAR;
                               Id           : CARDINAL;
                           VAR Expression   : ARRAY OF CHAR);

BEGIN                       (* StringExpression *)

    EmbedInExpression(Value, Id, 1, Expression);

END StringExpression;




PROCEDURE FindOrCreateValuesSection(    Section     : CARDINAL;
                                    VAR Index       : CARDINAL;
                                        ValuesArray : ADDRESS );
VAR
    ValuesPtr   : POINTER TO AFileSectionsArray;

BEGIN                       (* FindOrCreateValuesSection *)

    ValuesPtr := ValuesArray;

    IF (FindSection(ValuesPtr^, Section, Index)) THEN
        DiscardText(ValuesPtr^[Index].Contents);
    ELSIF (FindNewSection(ValuesPtr^, Index)) THEN
        ValuesPtr^[Index].Section := Section;
    ELSE
        FatalError();
    END;

END FindOrCreateValuesSection;



PROCEDURE InitRateTable();

BEGIN                   (* InitRateTable *)

    BaudRateTable[ B300] :=  300;
    BaudRateTable[ B600] :=  600;
    BaudRateTable[B1200] := 1200;
    BaudRateTable[B2400] := 2400;
    BaudRateTable[B4800] := 4800;
    BaudRateTable[B9600] := 9600;

END InitRateTable;


PROCEDURE InitUSAmountFormat();                                   (* 31-Aug-89 LAA *)

VAR
    S                       : ARRAY [0..255] OF CHAR;


    PROCEDURE ExtractCharacter( VAR S : ARRAY OF CHAR;
                                    N : CARDINAL ) : CHAR;
    VAR
        S2 : ARRAY [0..31] OF CHAR;
        S3 : ARRAY [0..99] OF CHAR;
    BEGIN
        WordNumber(S,N,S2);
        RETURN S2[1];
    END ExtractCharacter;



    PROCEDURE ExtractBoolean( VAR S : ARRAY OF CHAR;
                                  N : CARDINAL ) : BOOLEAN;
    BEGIN
        RETURN (CAP(ExtractCharacter(S,N)) = "T");
    END ExtractBoolean;



    PROCEDURE ExtractCardinal( VAR S : ARRAY OF CHAR;
                                   N : CARDINAL ) : CARDINAL;
    VAR
        i,j  : CARDINAL;
        S2 : ARRAY [0..31] OF CHAR;
        S3 : ARRAY [0..99] OF CHAR;
    BEGIN
        WordNumber(S,N,S2);
        i := 1;
        j := StoC(S2,i);
        RETURN j;
    END ExtractCardinal;


BEGIN                       (* InitUSAmountFormat *)

    SetString(S, ",|.|,|99|T|*|||-|");  (*  This is the standard U.S. format *)

    WITH USAmountFormat DO
        RadixSymbol            := ExtractCharacter(S,1);
        SymbolForSignificance  := ExtractCharacter(S,2);
        DigitsForSignificance  := ExtractCardinal(S,3);
        IncludeAtLeastOneDigit := ExtractBoolean(S,4);
        OverflowSymbol         := ExtractCharacter(S,5);
        WordNumber(S,6,Decorations.LeadingPositiveSymbol);
        WordNumber(S,7,Decorations.TrailingPositiveSymbol);
        WordNumber(S,8,Decorations.LeadingNegativeSymbol);
        WordNumber(S,9,Decorations.TrailingNegativeSymbol);
    END;

END InitUSAmountFormat;


BEGIN

    InitRateTable ();
    InitUSAmountFormat();

END PrintCommon.
