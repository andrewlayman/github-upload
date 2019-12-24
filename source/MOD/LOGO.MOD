IMPLEMENTATION MODULE Logo;

(* Logo - Do Time Line's startup logo.

    This was a part of TLStart, but was moved here so that other stand-alone
    Time Line programs can use the logo code.

    Modification History:

    16-May-89 RSC First Version from TLSTART.
    13-Jun-89 WKH Added support for variable screen rows.
    26-Jun-89 RSC When the screen switches to color, redisplay the entire
                  screen, which may be more than 24 lines.
    27-Sep-89 RSC Put the logo data structures on the heap, so that we save
                  the 3.5K or so of data in TLSTART.
*)


FROM Dialog         IMPORT
    (* PROC *)          FatalError;

FROM Kbio           IMPORT
    (* CONST *)         maxcol, maxrow,
    (* TYPE *)          ascreeny, ascreenx, avidmode,
    (* VAR  *)          vidctrl,
    (* PROC *)          PutAttribute, PutString;

FROM LStrings       IMPORT
    (* PROC *)          Fill, SubStr, ConcatS;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage;

FROM Space          IMPORT
    (* PROC *)          Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM         IMPORT
    (* PROC *)          TSIZE;

FROM Video          IMPORT
    (* PROC *)          PutStringWithAttribute;





CONST
    ModuleNumber        = 5100;
    MaxCellsPerLine     = 43;
    MaxLogoLines        = 19;
    MaxLogoRefreshes    = 20;  (* How many refreshes there are. *)

TYPE
 (*$A+*)
    ALogoCell = RECORD
        EndingX  : ascreenx;   (* Where the point ends *)
        DeltaX   : INTEGER;    (* How much it changes by *)
    END;

    ALogoLine = RECORD
        CellCount : CARDINAL;  (* How many logo cells there are *)
        Cells     : ARRAY [1..MaxCellsPerLine] OF ALogoCell;
        FirstX,
        LastX     : ascreenx; (* Seen so far. *)
        EndChar,
        StartChar : CHAR; (* Use StartChar until very end. *)
    END;

    ALogoScreen = ARRAY [1..MaxLogoLines] OF ALogoLine;
 (*$A=*)


VAR
    LogoScreen       : POINTER TO ALogoScreen;  (* 27-Sep-89 RSC *)
    LogoRefreshCount : CARDINAL;
    RandomLines      : ARRAY [1..MaxLogoLines] OF CARDINAL;
    LogoDone         : BOOLEAN;




PROCEDURE Banner();
CONST
    StartingRow = 4;
    StartCol    = 37;
VAR
    y : ascreeny;
    Len : CARDINAL;
    Mode : avidmode;
BEGIN
    WHILE (NOT LogoDone) DO
        RefreshLogo();
    END;
    IF (LogoScreen <> NIL) THEN (* 27-Sep-89 RSC *)
        DISPOSE(LogoScreen);
    END;

        (* Display a video normal background so that when lights get
           displayed we don't get a seemingly random (really videonormal)
           line at the bottom of the screen against a black background.
         *)

    FOR y := 0 TO (maxrow - 1) DO  (* 26-Jun-89 RSC *)
        Mode := videonormal;
        IF ( y > StartingRow) AND (y <= StartingRow+MaxLogoLines) THEN
            Len := StartCol-1;
        ELSE
            IF (y >= 3) AND (y <= 4) THEN
                Mode := videodatebar;
            END;
            Len := maxcol+1;
        END;
        PutAttribute(0,y,Len,Mode);
    END;

END Banner;






  (* RefreshLogo - refresh the logo on the screen, as appropriate.
  *)
PROCEDURE RefreshLogo();

CONST StartingRow = 4;
      StartCol    = 37;
      ULC1        = 332C;
      URC1        = 277C;
      LLC1        = 300C;
      LRC1        = 331C;

VAR
    Line,
    i, j         : CARDINAL;
    Mode         : BITSET;
    Product,
    Change       : CARDINAL;
    X            : ascreenx;
    y            : ascreeny;
    s            : ARRAY [0..maxcol+1] OF CHAR;
    Char         : CHAR;
BEGIN

    IF (LogoScreen = NIL) OR (LogoRefreshCount = 0) THEN (* 27-Sep-89 RSC *)
        LogoDone := TRUE;
        RETURN;
    END;
    DEC( LogoRefreshCount );

    FOR i := 1 TO HIGH(LogoScreen^) DO
        Fill(s," ",maxcol-StartCol);
        Line := RandomLines[ i ];
        WITH LogoScreen^[Line] DO
            Char  := StartChar;
            FOR j := 1 TO CellCount DO
                WITH Cells[j] DO
                    Product := CARDINAL(ABS( DeltaX )) * LogoRefreshCount;
                    Change  := Product DIV MaxLogoRefreshes;
                    IF (((Product MOD MaxLogoRefreshes) * 2) >= MaxLogoRefreshes) THEN
                        INC(Change);
                    END;
                    IF (DeltaX >= 0) THEN
                        X := EndingX + Change;
                    ELSE
                        X := EndingX - Change;
                    END;
                    s[X] := Char;
                    IF (X < FirstX) THEN
                        FirstX := X;
                    END;
                    IF (X > LastX) THEN
                        LastX := X;
                    END;
                END;
            END;

        (* Middle line is red, top and bottom in white, rest bright white. *)

            Mode := BITSET( 0FH ); (* BRIGHT WHITE ON BLACK *)
            IF (Line = 10) THEN
                Mode := BITSET( 04H ); (* RED ON BLACK *)
            ELSIF (Line=1) OR (Line=HIGH(LogoScreen^)) THEN
                Mode := BITSET( 07H ); (* WHITE ON BLACK *)
            END;
            SubStr(s, s, FirstX, (LastX - FirstX) + 1 );
            PutStringWithAttribute(s, (StartCol + FirstX) - 1, Line + StartingRow, Mode );
        END;
    END;

 (* Are we done?  if so, finish up the boxes. *)

    IF ( LogoRefreshCount = 0 ) THEN
        s[0] := 1C;
        s[1] := ULC1;
        PutStringWithAttribute( s, StartCol-1, 5, BITSET( 07H ) ); (* White on gray *)
        s[1] := LLC1;
        PutStringWithAttribute( s, StartCol-1, 23, BITSET( 07H ) );
        s[1] := URC1;
        PutStringWithAttribute( s, maxcol, 5, BITSET( 07H ) );
        s[1] := LRC1;
        PutStringWithAttribute( s, maxcol, 23, BITSET( 07H ) );  (* 13-Jun-89 WKH *)
        s[1] := "³";
        FOR y := 6 TO 22 DO  (* 13-Jun-89 WKH *)
            PutStringWithAttribute( s, maxcol, y, BITSET( 07H ) );
        END;
    END;

END RefreshLogo;





 (* StartLogo - Setup the logo screens for displaying.

    Parse the phrases in TLPHRASE.TXT for the initial and final logo screens.
    Set up the global data structure used by the incremental logo display
    routine.  Our intention is to animate the screen in N steps.

    Remember that here, KbioInit() has NOT YET BEEN CALLED!, so be carefull
    which which features you invoke!
 *)

PROCEDURE StartLogo();
CONST
    StartCol            = 38;   (* First col of logo area (after vbar) *)
    InitialMessageStart = ModuleNumber + 14;
      FinalMessageStart = ModuleNumber + 40;

VAR
    i            : CARDINAL;
    TempLogoLine : ALogoLine;
    s            : ARRAY [0..maxcol+1] OF CHAR;


  (* Parse Logo Line - Parse the line of text into our structure.
  *)
  PROCEDURE ParseLogoLine( VAR TextLine : ARRAY OF CHAR;
                           VAR LogoLine : ALogoLine      );
  VAR
      Loop  : CARDINAL;
  BEGIN
      IF (TextLine[0]=0C) THEN
          Fill(TextLine," ",20);
          ConcatS(TextLine,"Ä"); (* Default to SOMETHING! *)
      END;
      WITH LogoLine DO
          FirstX    := maxcol;
          LastX     := 0;
          CellCount := 0;
          FOR Loop  := 1 TO ORD(TextLine[0]) DO
              IF (TextLine[ Loop ] <> " ") THEN
                  INC(CellCount);
                  IF (CellCount > MaxCellsPerLine) THEN FatalError; END;
                  Cells[ CellCount ].EndingX := Loop;
                  Cells[ CellCount ].DeltaX  := 0; (* for now *)
                  IF (Loop < FirstX) THEN
                      FirstX := Loop;
                  END;
                  IF (Loop > LastX) THEN
                      LastX := Loop;
                  END;
                  StartChar := TextLine[ Loop ];
              END;
          END;
      END;
  END ParseLogoLine;


  (* AnalizeLines - Synch up the initial and final drawings into the
      final data structure that will be used for the animation
  *)
  PROCEDURE AnalizeLines( VAR InitialLine, FinalLine : ALogoLine );
  VAR
      Loop,
      WhichInitial     : CARDINAL;
      FinalsPerInitial : INTEGER;

  BEGIN
   (* For each final char, assign one initial char. *)

      FinalsPerInitial := INTEGER(FinalLine.CellCount DIV InitialLine.CellCount);
      IF (FinalsPerInitial = 0) THEN
          FinalsPerInitial := 1;
      END;
      FinalLine.FirstX := InitialLine.FirstX;
      FinalLine.LastX  := InitialLine.LastX;

      FOR Loop := 1 TO FinalLine.CellCount DO

          (* Look for an initial char that is not used more than
             'FinalsPerInitial' times.  If not found, use the last one.
             This allows 3 to go into 2 once with the final cell used
             twice.  Use the 'DeltaX' field to track how many are assigned
             to this char.
          *)

          WhichInitial := 1;
          WHILE (WhichInitial < InitialLine.CellCount) AND
                (InitialLine.Cells[WhichInitial].DeltaX >= FinalsPerInitial) DO
              INC( WhichInitial );
          END;
          INC(InitialLine.Cells[WhichInitial].DeltaX);

          (* OK, we are going to assign initial[ WhichInitial ] to this
             final char.  Compute the deltaX.
          *)

          FinalLine.Cells[ Loop ].DeltaX :=
                        INTEGER( InitialLine.Cells[ WhichInitial ].EndingX )
                      - INTEGER(   FinalLine.Cells[ Loop         ].EndingX );
      END;

      FinalLine.EndChar   :=   FinalLine.StartChar;
      FinalLine.StartChar := InitialLine.StartChar;
  END AnalizeLines;

BEGIN                (* StartLogo begins here *)

    LogoDone  := FALSE;     (* Logo is not done yet (is just started) *)

    IF (Available(TSIZE(ALogoScreen))) THEN (* 27-Sep-89 RSC *)
        NEW( LogoScreen );
    ELSE
        LogoScreen := NIL;
        RETURN;
    END;

 (* Parse the final lines into the logo screen data structure. *)

    FOR i := 1 TO MaxLogoLines DO
        IF (i=1) OR (i=MaxLogoLines) THEN
            Fill(s, "Ä", maxcol - StartCol + 1 );
        ELSE
            GetMessage( FinalMessageStart + i - 2, s );
        END;
        ParseLogoLine( s, LogoScreen^[ i ] );
    END;

 (* Now, for each of the initial logo screen lines,
    Get the line
       Parse it
       Analize the line and its final line.
 *)

    FOR i := 1 TO MaxLogoLines DO
        GetMessage( InitialMessageStart + i - 1, s );
        SubStr( s, s, StartCol, ORD(s[0]) );
        ParseLogoLine( s, TempLogoLine );
        AnalizeLines( TempLogoLine, LogoScreen^[ i ] );
    END;

    RandomLines[1]   := 5;  (* Make redraw look pseudo-random *)
    RandomLines[2]   := 12;
    RandomLines[3]   := 8;
    RandomLines[4]   := 1;
    RandomLines[5]   := 17;
    RandomLines[6]   := 3;
    RandomLines[7]   := 11;
    RandomLines[8]   := 19;
    RandomLines[9]   := 2;
    RandomLines[10]  := 9;
    RandomLines[11]  := 10;
    RandomLines[12]  := 18;
    RandomLines[13]  := 4;
    RandomLines[14]  := 13;
    RandomLines[15]  := 15;
    RandomLines[16]  := 6;
    RandomLines[17]  := 14;
    RandomLines[18]  := 7;
    RandomLines[19]  := 16;

    LogoRefreshCount := MaxLogoRefreshes; (* Have not yet refreshed screen. *)
    RefreshLogo();                        (* But start to do so *)

END StartLogo;


END Logo.
