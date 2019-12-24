MODULE TLSizes;

(*  =========================================================================
    Last Edit : September 29, 1989 1:27PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Determine the size of the reserve layer by looking at several
        overlays that go into the reserved layer.

        run this by saying TIMELINE ADDIN IS TLSIZES.

    MODIFICATION HISTORY:

    20-Sep-89 RSC  First version.

    =========================================================================
*)


FROM ASCII      IMPORT
    (* CONST *)     EOL;

FROM Dialog     IMPORT
    (* PROC *)      Error;

FROM Directory  IMPORT
    (* TYPE *)      AFileAttribute,  AFileAttributeSet,
    (* PROC *)      FileLookupStart, FileLookupContinue;

FROM Direct411  IMPORT
    (* PROC *)      GetOutputFile;

FROM FileAux    IMPORT
    (* VAR *)       EXEPath,
    (* PROC *)      PrepareForIO, CheckIO;

FROM FileSystem IMPORT
    (* TYPE *)      File, Response,
    (* PROC *)      Lookup, Close, WriteNBytes, WriteChar;

FROM LStrings   IMPORT
    (* PROCS *)     Copy, ConcatS, SetString, ConcatLS, LStringToTString,
                    Procustes, LengthOf, SetLengthOf, Search, RJust;

FROM OvSize     IMPORT
    (* PROC *)      DetermineOverlaySize, OpenOverlay, DetermineSpaceNeeded;

FROM RealFormat IMPORT
    (* TYPE *)      ADecoration, AnAmountFormat,
    (* PROC *)      FormatAsAmount;

FROM SYSTEM     IMPORT
    (* PROC *)      ADR;

FROM Words      IMPORT
    (* PROC *)      ParseString;






TYPE
    AnOverlayEntry  = RECORD
        OverlayName     : ARRAY [0..15] OF CHAR;
        RSize,
        HSize           : CARDINAL;
    END;


VAR
    OverlayList  : ARRAY [1..250] OF AnOverlayEntry;
    ListSize     : CARDINAL;
    AmountFormat : AnAmountFormat;
    f            : File;
    OverlayPath  : ARRAY [0..129] OF CHAR;




PROCEDURE PrintString( VAR s : ARRAY OF CHAR ) : BOOLEAN;
VAR
    CountWritten    : CARDINAL;
BEGIN

    WriteNBytes( f, ADR(s[1]), LengthOf(s), CountWritten );
    WriteChar( f, EOL );

    RETURN (CheckIO(f) = done);

END PrintString;






(* TComboList is a TString!
*)
PROCEDURE PickCombos( TComboList  : ARRAY OF CHAR );
VAR
    TR,
    i, j        : CARDINAL;
    Overlay,
    s1,
    Line1,
    Line2,
    ComboList   : ARRAY [0..199] OF CHAR;
    ok          : BOOLEAN;
BEGIN
    SetString( ComboList, TComboList );
    SetLengthOf(Line1, 0);
    SetLengthOf(Line2, 0);

    TR := 0;
    j  := 1;

    ParseString( ComboList, j, Overlay );
    WHILE (LengthOf(Overlay) > 0) DO
        i := 1;
        WHILE (i <= ListSize) AND
              (Search( OverlayList[i].OverlayName, Overlay, 1) <> 1) DO
            INC(i);
        END;

        IF (i <= ListSize) THEN
            Procustes( Overlay, 8 );
            RJust( Overlay );
            ConcatLS( Line1, Overlay );

            WITH OverlayList[i] DO
                FormatAsAmount( FLOAT(RSize) * 16.0, AmountFormat, s1, 8,0,0,TRUE );
                ConcatLS( Line2, s1 );
                INC(TR,RSize);
            END;
            ConcatS( Line1, "  " );
            ConcatS( Line2, "  " );
        END;
        ParseString( ComboList, j, Overlay );
    END;

    ConcatS( Line2, "  TOTAL:" );
    FormatAsAmount( FLOAT(TR) * 16.0, AmountFormat, s1, 8,0,0,TRUE );
    ConcatLS( Line2, s1 );

    ok := PrintString( Line1 );
    ok := PrintString( Line2 );

    SetString(Line2, " ");
    ok := PrintString( Line2 );

END PickCombos;








PROCEDURE DoCombos();
VAR
    s   : ARRAY [0..99] OF CHAR;
    ok  : BOOLEAN;
BEGIN

    SetString(s, " ");
    ok := PrintString( s );

    SetString(s, "Common Combinations (assuming no heap fudge):");
    ok := PrintString( s );

    PickCombos( "TLSWAPF TLCAPTIO MACROS TLBTSMAC TLMAIN" );
    PickCombos( "TLPLAN TLRPLAN" );
    PickCombos( "TLGETIT TLITL2" );
    PickCombos( "TLGETIT TLITL3" );
    PickCombos( "TLGETIT TLITL4" );
    PickCombos( "TLXPREP TLXCNFG" );
    PickCombos( "TLXTL4" );
    PickCombos( "TLSTART" );

END DoCombos;








PROCEDURE OverlaySize(     Overlay  : ARRAY OF CHAR;
                       VAR ResSize,
                           HeapSize : CARDINAL );
VAR
    Handle  : CARDINAL;
    OvName  : ARRAY [0..255] OF CHAR;
BEGIN

    Copy( OverlayPath, OvName );
    ConcatLS( OvName, Overlay );

    IF (NOT OpenOverlay( OvName, Handle )) THEN
        Error(OvName);
        ResSize  := 0;
        HeapSize := 0;
        RETURN;
    END;

    ResSize  := DetermineOverlaySize();
    HeapSize := DetermineSpaceNeeded( ResSize );

END OverlaySize;








PROCEDURE OpenFile() : BOOLEAN;
VAR
    PathIn,
    PathOut : ARRAY [0..127] OF CHAR;
    NameIn,
    NameOut : ARRAY [0..99] OF CHAR;
    ok      : BOOLEAN;
BEGIN
    SetString( PathIn, "DK:.\" );
    SetString( NameIn, "SIZES.LOG" );

    ok := GetOutputFile(PathIn, NameIn, PathOut, NameOut, TRUE );

    IF (ok) THEN
        ConcatLS( PathOut, NameOut );
        LStringToTString( PathOut, PathOut );
        PrepareForIO(f);
        Lookup( f, PathOut, TRUE );
        ok := (CheckIO(f) = done);
    END;

    SetString( PathIn,  "Overlay Name     Size  Heap Size" );
    SetString( PathOut, "------------     ----  ---------" );
    RETURN ok AND 
           PrintString( PathIn ) AND
           PrintString( PathOut );

END OpenFile;








PROCEDURE TraverseDirectory( VAR Path   : ARRAY OF CHAR );
VAR
    i,
    CountWritten,
    ResSize,
    HeapSize    : CARDINAL;
    Attributes  : AFileAttributeSet;
    s1,
    TheName,
    OutputString,
    Mask        : ARRAY [0..127] OF CHAR;
    ok          : BOOLEAN;
BEGIN
    Copy( Path, Mask );
    ConcatS( Mask, "*.OVL" );
    Attributes := AFileAttributeSet{ReadOnlyAttribute};

    ListSize := 0;

    ok := FileLookupStart( Mask, TheName, Attributes );

    WHILE (ok) DO
        OverlaySize( TheName, ResSize, HeapSize );

        INC(ListSize);
        WITH OverlayList[ListSize] DO
            Copy(TheName, OverlayName );
            RSize := ResSize;
            HSize := HeapSize;
        END;

        Copy( TheName, OutputString );
        Procustes( OutputString, 15 );
        FormatAsAmount( FLOAT(ResSize) * 16.0, AmountFormat, s1, 7,0,0,TRUE );
        ConcatLS( OutputString, s1 );
        FormatAsAmount( FLOAT(HeapSize) * 16.0, AmountFormat, s1, 10,0,0,TRUE );
        ConcatLS( OutputString, s1 );

        ok := PrintString( OutputString ) AND
              FileLookupContinue( TheName, Attributes );
    END;


END TraverseDirectory;






BEGIN

    WITH AmountFormat DO
        RadixSymbol            := ".";
        SymbolForSignificance  := ",";
        DigitsForSignificance  := 3;
        IncludeAtLeastOneDigit := TRUE;
        OverflowSymbol         := "*";
        WITH Decorations DO
            LeadingNegativeSymbol[0]  := 0C;
            TrailingNegativeSymbol[0] := 0C;
            LeadingPositiveSymbol[0]  := 0C;
            TrailingPositiveSymbol[0] := 0C;
        END;
    END;

    Copy( EXEPath, OverlayPath );
    ConcatS( OverlayPath, "PROGRAMS\" );

    IF (OpenFile()) THEN
        TraverseDirectory( OverlayPath );
        DoCombos();
        Close(f);
    END;

END TLSizes.

