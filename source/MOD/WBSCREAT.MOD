IMPLEMENTATION MODULE WBSCreate;

  (*   Routines used in the creation and validation of WBS codes.

        MODIFICATION HISTORY:

         19-Apr-89  MWP  In the beginning...
         20-Jul-89  MWP  Upgrade the documentation of the code.
         29-Jul-89  MWP  Added VAR parameter 'WBSError' to CreateWBSCode.
                         This allows enumeration of an error, should it occur.
         03-Aug-89  LAA  Import AWBSError from WBSCommon.
         15-Aug-89  MWP  Use AWBSPtr as parameter.
         16-Aug-89  MWP  Fixed problem were validation of the last character
                         of a WBS code was not being checked for belonging
                         to character sequence set.
  *)


FROM Dialog         IMPORT
    (* PROC *)               Error;

FROM Foreign        IMPORT
    (* PROC *)              DoDash;

FROM LStrings       IMPORT
    (* PROC *)              SetLengthOf, LengthOf, TStringToLString, Copy,
                            ConcatLS, Search, SubStr, SetString;

FROM Strings        IMPORT
    (* PROC *)              Length;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS;

FROM WBSCommon      IMPORT
    (* TYPE *)              AnWBSFormsValue,
                            AWBSPtr,                                (* 15-Aug-89 MWP *)
                            AWBSError,
                            MaxWbsRows,
                            MaxWbsSize,
                            MaxWbsLen,
                            AShowMethod;


(*=============================================================================
 *  CalculateMinimumSize
 *  --------------------
 *  Based upon the WBS form values, calculate what the minimum size in
 *  characters a WBS code should be up to a certain level.
 *
 *  PRECONDITIONS : IndentLevel is <= MaxWbsRows.
 *                  WBSFormP points to a valid record structure of type
 *                  AnWBSFormsValue.
 *
 *  POSTCONDITIONS: None.
 *
 *  RETURNS       : The minimum size that a WBS code at segment level
 *                  'IndentLevel' would be.
 *============================================================================*)
PROCEDURE CalculateMinimumSize ( IndentLevel : CARDINAL;
                                 WBSFormP    : AWBSPtr ) : CARDINAL; (* 15-Aug-89 MWP *)
VAR
    Loop,
    Sum                     : CARDINAL;
BEGIN
    Sum := 0;

    WITH WBSFormP^ DO

       Sum := LengthOf ( Prefix );

       IF ( IndentLevel > MaxWbsRows ) THEN
          IndentLevel := MaxWbsRows;
       END;

       FOR Loop := 0 TO IndentLevel DO
          Sum := Sum + WBSColumns[ Loop ].SizeMin;
       END;
    END;
    RETURN Sum;

END CalculateMinimumSize;


(*=============================================================================
 *  CalculateMaximumSize
 *  --------------------
 *  Based upon the WBS form values, calculate what the maximum size in
 *  characters a WBS code could be up to and including a level depth.
 *
 *  PRECONDITIONS : IndentLevel is <= MaxWbsRows.
 *                  WBSFormP points to a valid record structure of type
 *                  AnWBSFormsValue.
 *
 *  POSTCONDITIONS: None.
 *
 *  RETURNS       : The maximum size that a WBS code at segment level
 *                  'IndentLevel' could possibly be. Note that depending
 *                  upon the WBS form, WBS codes can range in size from
 *                  a minimum up to this maximum.
 *============================================================================*)
PROCEDURE CalculateMaximumSize ( IndentLevel : CARDINAL;
                                 WBSFormP    : AWBSPtr ) : CARDINAL; (* 15-Aug-89 MWP *)
VAR
    Loop,
    Sum                     : CARDINAL;
BEGIN
    Sum := 0;

    WITH WBSFormP^ DO

       Sum := LengthOf ( Prefix );

       IF ( IndentLevel > MaxWbsRows ) THEN
          IndentLevel := MaxWbsRows;
       END;

       IF ( IndentLevel > 0 ) THEN
          FOR Loop := 0 TO IndentLevel - 1 DO
             Sum := Sum + WBSColumns[ Loop ].SizeMax;
             Sum := Sum + LengthOf ( WBSColumns[ Loop ].FollowBy );
          END;
       END;

       Sum := Sum + WBSColumns[ IndentLevel ].SizeMax;

       IF ( IndentLevel < MaxWbsRows ) AND
          ( WBSColumns[ IndentLevel + 1].AlwaysShow = AShowMethod(Yes) ) THEN

          Sum := Sum + LengthOf ( WBSColumns[ IndentLevel ].FollowBy );

          Loop := IndentLevel + 1;
          WHILE ( WBSColumns[ Loop ].AlwaysShow = AShowMethod(Yes) ) AND
                ( Loop < MaxWbsRows ) DO

             IF ( LengthOf ( WBSColumns[ Loop ].CharacterSequence ) > 0 ) THEN
                Sum := Sum + WBSColumns[ Loop ].SizeMax;
                Sum := Sum + LengthOf ( WBSColumns[ Loop ].FollowBy );
             END;
             INC(Loop);
          END;
       END;
    END;

    RETURN Sum;
END CalculateMaximumSize;



(*=============================================================================
 *  StripOffShowCharacters
 *  ----------------------
 *  Strips off any 'Always Show' characters which may exist in a WBS code.
 *
 *  PRECONDITIONS : SegmentLevel must be less than MaxWbsRows.
 *                  WBSFormP points to a valid record structure of type
 *                  AnWBSFormsValue.
 *                  WBSCode 'should' be a code based on the WBS form values.
 *
 *  POSTCONDITIONS: OutString will contain the stripped WBS code or be set to
 *                  zero length.
 *
 *  RETURNS       : TRUE  if WBS code could be analyzed.
 *                  FALSE if an error occured.
 *============================================================================*)
PROCEDURE StripOffShowCharacters (     SegmentLevel     : CARDINAL;
                                       WBSFormP         : AWBSPtr;  (* 15-Aug-89 MWP *)
                                   VAR WBSCode          : ARRAY OF CHAR;
                                   VAR OutString        : ARRAY OF CHAR ) : BOOLEAN;
VAR
    i                       : CARDINAL;
    Decompose               : ARRAY[0..255] OF CHAR;
    SegmentString           : ARRAY [0..MaxWbsLen] OF CHAR;
    ok                      : BOOLEAN;
BEGIN

    IF ( SegmentLevel > MaxWbsRows ) THEN
       RETURN FALSE;
    END;

    ok := DecomposeWBSCode (  WBSCode,
                              WBSFormP,
                              SegmentLevel,
                              Decompose );

    IF ( ok ) THEN
       SetLengthOf ( OutString, 0 );
       IF ( LengthOf ( WBSFormP^.Prefix ) > 0 ) THEN
          INC(SegmentLevel);
       END;

       FOR i := 0 TO SegmentLevel DO
           IF ( ok ) AND
              ( ExtractDecomposedSegment ( i,
                                           Decompose,
                                           SegmentString ) ) THEN
              ConcatLS ( OutString, SegmentString );
           ELSE
              ok := FALSE;
           END;
       END;
    END;

    RETURN ok;

END StripOffShowCharacters;



(*=============================================================================
 *  ExtractDecomposedSegment
 *  ------------------------
 *  Given a decomposed WBS code, extract the 'nth' WBS segment value.
 *
 *  PRECONDITIONS : SegmentNumber is the segment to extract. Must be
 *                  < MaxWbsRows.
 *                  DecomposedString is an LString containing the previously
 *                  decomposed WBS code.
 *
 *  POSTCONDITIONS: OutString will contain the extracted WBS segment, or
 *                  it will be of zero length if an error is encountered.
 *
 *  RETURNS       : TRUE  if segemnt was extracted.
 *                  FALSE if an error has occured.
 *============================================================================*)
PROCEDURE ExtractDecomposedSegment (     SegmentNumber    : CARDINAL;
                                     VAR DecomposedString : ARRAY OF CHAR;
                                     VAR OutString        : ARRAY OF CHAR ) : BOOLEAN;
VAR
    Index1,
    Index2,
    i                       : CARDINAL;
    Seperator               : ARRAY[0..1] OF CHAR;
BEGIN

    IF ( SegmentNumber > MaxWbsRows ) THEN
       RETURN FALSE;
    END;

    SetString ( Seperator, " " );
    Index1 := 1;
    Index2 := 1;

    FOR i := 0 TO SegmentNumber DO
       Index1 := Index2;
       Index2 := Search ( DecomposedString,
                         Seperator,
                         Index1 );

       IF ( Index2 = 0 ) THEN
          SetLengthOf ( OutString, 0 );
          RETURN FALSE;
       END;

       IF ( i < SegmentNumber ) THEN
          INC(Index2);
       END;
    END;

    (* Skip over Seperator character ONLY if we are not extracting first
       segment.*)

    SubStr   ( DecomposedString,
               OutString,
               Index1,
               Index2 - Index1 );

     IF ( LengthOf ( OutString ) <> Index2 - Index1 ) THEN
        SetLengthOf ( OutString, 0 );
        RETURN FALSE;
     END;

     RETURN TRUE;

END ExtractDecomposedSegment;


(*=============================================================================
 *  DecomposeWBSCode
 *  ----------------
 *  Input WBSCode will be broken down into it's component segment
 *  values, and placed into an output string. Each segment in the
 *  output string will be seperated by a space.
 *  The current WBS form values willl be used to break the CODE
 *  down. If any discrepancies are encountered during the decomposition
 *  then a FALSE value will be returned and the output string will
 *  be set to length 0, else a TRUE is returned.
 *
 *  Validation of the WBS Code is performed at this level.
 *  We will validate the Prefix, follow-by chars, and contents of the
 *  segment ensuring that each character is valid.
 *
 *
 *  PRECONDITIONS : WBSCode is a valid WBSCode created according to the
 *                  current WBS form values.
 *                  WBSFormP is a valid pointer to a 'AnWBSFormsValue' record.
 *                  Level is the segment level of the WBS code. It must be
 *                  < MaxWbsRows.
 *
 *  POSTCONDITIONS: Decomposed will contain the decomposed segments, or be
 *                  of zero length if an error was encountered.
 *
 *  RETURNS       : FALSE if any discrepancies are encountered during the
 *                  decomposition, else a TRUE is returned.
 *  NOTE:
 *        Validation of the WBS Code is performed at this level.
 *        We will validate the Prefix, follow-by chars, and contents of the
 *        segment ensuring that each character is valid.
 *============================================================================*)
PROCEDURE DecomposeWBSCode ( VAR WBSCode    : ARRAY OF CHAR;
                                 WBSFormP   : AWBSPtr;              (* 15-Aug-89 MWP *)
                                 Level      : CARDINAL;
                             VAR Decomposed : ARRAY OF CHAR ) : BOOLEAN;
VAR
    i,j,
    Min, Max,
    OutLen,
    InLen,
    Loop,
    OutMarker,
    InMarker                : CARDINAL;
BEGIN
    IF ( Level > MaxWbsRows ) THEN
       RETURN FALSE;
    END;
    SetLengthOf ( Decomposed, 0 );

    InLen := LengthOf ( WBSCode );

    IF ( InLen = 0 ) THEN
       RETURN FALSE;
    END;

    Min := CalculateMinimumSize ( Level, WBSFormP );
    Max := CalculateMaximumSize ( Level, WBSFormP );

    IF ( InLen < Min ) OR ( InLen > Max ) THEN
       RETURN FALSE;
    END;

    OutMarker := 1;
    InMarker  := 1;

    WITH WBSFormP^ DO
       (* First, the prefix *)
       OutLen := LengthOf ( Prefix );

       IF (  OutLen > 0 ) THEN
           FOR i := 1 TO OutLen DO

               (* If the prefix  characters do not match the WBSCode prefix
                  characters, and the prefix character is not ?, then we have a
                  verification error.
                *)
               IF ( Prefix[ i ] <> WBSCode[ InMarker ] ) AND
                  ( Prefix[ i ] <> '?' ) THEN
                   SetLengthOf ( Decomposed, 0 );
                   RETURN FALSE;
               END;

               Decomposed[ OutMarker ] := WBSCode[ InMarker ];
               INC(OutMarker);
               INC(InMarker);
           END;
           Decomposed[ OutMarker ] := ' ';
           INC(OutMarker);
       END;

       FOR Loop := 0 TO Level DO

           IF ( InMarker > InLen ) THEN
              SetLengthOf ( Decomposed, 0 );
              RETURN FALSE;
           END;

           IF ( LengthOf ( WBSColumns[ Loop ].FollowBy ) > 0 ) AND
              ( Loop < Level ) THEN

               OutLen := FindNextWBSCode ( WBSCode, Loop, WBSFormP, InMarker );

               IF ( OutLen > 0 ) THEN
                  IF ( OutLen >
                     ( WBSColumns[ Loop ].SizeMax +
                       LengthOf ( WBSColumns[ Loop ].FollowBy ) ) ) THEN
                         SetLengthOf ( Decomposed, 0 );
                         RETURN FALSE;
                  END;

                  IF ( NOT ValidateWBSCodeSegment ( WBSCode,  OutLen, Loop,
                                                    WBSFormP, FALSE, InMarker ) ) THEN
                     SetLengthOf ( Decomposed, 0 );
                     RETURN FALSE;
                  END;

                  FOR i := 1 TO OutLen DO
                      Decomposed[ OutMarker ] := WBSCode[ InMarker ];
                      INC(OutMarker);
                      INC(InMarker);
                  END;
               ELSE
                  SetLengthOf ( Decomposed, 0 );
                  RETURN FALSE;
               END;
           ELSE
              (* We are at last level. How do we get this last information?
                 It is not as easy as it seems. The pieces which must
                 be considered in the puzzle are:
                   1 - The SizeMin and Max.
                   2 - Always Show.
                   3 - Follow by character.
                 All these pieces can be put together in different flavours
                 do make it difficult to grab that last segment correctly.

                 The easiest scenario is SizeMin = SizeMax, in which case
                 we copy that many characters no matter what.

                 If they are unequal, then, we have to look at the the other
                 two pieces to decide how to extract the segment. ( In this
                 case, there MUST be a follow by sequence. )

                 If always show is NO, then just copy the rest of the segment.

                 If always show is YES, find where the segment ends by looking
                 for the follow by sequence, and copying up to BUT NOT
                 including the follow by.
              *)

              IF ( Loop = Level ) AND
                 ( WBSColumns[ Loop ].SizeMax <> WBSColumns[ Loop ].SizeMin ) THEN

                 IF ( WBSColumns[ Loop + 1 ].AlwaysShow = AShowMethod(Yes) ) THEN

                     OutLen := FindNextWBSCode ( WBSCode, Loop,
                                                 WBSFormP, InMarker );


                     IF ( OutLen = 0 ) THEN
                         SetLengthOf ( Decomposed, 0 );
                         RETURN FALSE;
                     END;
                     OutLen := OutLen - LengthOf ( WBSColumns[ Loop ].FollowBy );

                     IF ( NOT ValidateWBSCodeSegment ( WBSCode,     (* 16-Aug-89 MWP *)
                                                       OutLen,
                                                       Loop,
                                                       WBSFormP,
                                                       TRUE,
                                                       InMarker ) ) THEN
                         SetLengthOf ( Decomposed, 0 );
                         RETURN FALSE;
                     END;

                     FOR i := 1 TO OutLen DO
                        Decomposed[ OutMarker ] := WBSCode[ InMarker ];
                        INC(OutMarker);
                        INC(InMarker);
                     END;
                 ELSE

                    IF ( ( InLen - InMarker ) + 1 > WBSColumns[ Loop ].SizeMax ) OR
                       ( ( InLen - InMarker ) + 1 < WBSColumns[ Loop ].SizeMin ) THEN
                       SetLengthOf ( Decomposed, 0 );
                       RETURN FALSE;
                    END;

                    j := InLen - InMarker;

                    IF ( NOT ValidateWBSCodeSegment ( WBSCode,     (* 16-Aug-89 MWP *)
                                                      j + 1,
                                                      Loop,
                                                      WBSFormP,
                                                      TRUE,
                                                      InMarker ) ) THEN
                        SetLengthOf ( Decomposed, 0 );
                        RETURN FALSE;
                    END;

                    FOR i := 0 TO j DO
                       Decomposed[ OutMarker ] := WBSCode[ InMarker ];
                       INC(OutMarker);
                       INC(InMarker);
                    END;
                 END;
              ELSE
                 OutLen := WBSColumns[ Loop ].SizeMax;

                 IF ( NOT ValidateWBSCodeSegment ( WBSCode,  OutLen, Loop,
                                                   WBSFormP, TRUE, InMarker ) ) THEN
                    SetLengthOf ( Decomposed, 0 );
                    RETURN FALSE;
                 END;

                 FOR i := 1 TO OutLen DO
                    Decomposed[ OutMarker ] := WBSCode[ InMarker ];
                    INC(OutMarker);
                    INC(InMarker);
                 END;
              END;
           END;
           Decomposed[ OutMarker ] := ' ';
           INC(OutMarker);
       END;
    END;

    Decomposed[ 0 ] := CHR(OutMarker - 1);

    RETURN TRUE;

END DecomposeWBSCode;


(*=============================================================================
 *  ValidateWBSCodeSegment
 *  ----------------------
 *  Test each character of a given WBS code segment for validity against the
 *  character sequence values.
 *
 *  PRECONDITIONS : WBSCode is the WBS code of which a segment is to be
 *                  validated.
 *                  Level is the segment level which will be used to index
 *                  into the WBS form record to find the correct values.
 *                  OutLen is the length of the segment.
 *                  Inmarker is the starting index of the segment.
 *                  WBSFormP is a pointer to the WBS form record.
 *
 *  POSTCONDITIONS: None.
 *
 *  RETURNS       : TRUE is WBS code segment conforms to the form, else FALSE.
 *============================================================================*)
PROCEDURE  ValidateWBSCodeSegment ( VAR WBSCode  : ARRAY OF CHAR;
                                        OutLen   : CARDINAL;
                                        Level    : CARDINAL;
                                        WBSFormP : AWBSPtr;         (* 15-Aug-89 MWP *)
                                        LastLevel: BOOLEAN;         (* 16-Aug-89 MWP *)
                                        InMarker : CARDINAL ) : BOOLEAN;
VAR
    i,j,k,
    Index                   : CARDINAL;
    MatchSeq                : ARRAY [0..1] OF CHAR;
    ExpandedSeq             : ARRAY [0..255] OF CHAR;
BEGIN

    IF ( Level > MaxWbsRows ) THEN
       RETURN FALSE;
    END;

    SetLengthOf ( MatchSeq, 1 );

    j := 1;

    DoDash ( WBSFormP^.WBSColumns[Level].CharacterSequence,
             ExpandedSeq,
             j );

    ExpandedSeq[0] := CHR(j - 1);

    k :=  LengthOf ( WBSFormP^.WBSColumns[Level].FollowBy );

    IF ( k < OutLen ) AND ( NOT LastLevel ) THEN                    (* 16-Aug-89 MWP *)
       j :=  OutLen - k;
    ELSE
       j :=  OutLen;
    END;

    IF ( j > 0 ) THEN
       j := j - 1;
    END;

    FOR i := 0 TO j DO
       MatchSeq[1] := WBSCode[ InMarker + i];
       Index := Search ( ExpandedSeq, MatchSeq, 1 );

       IF ( Index = 0 ) THEN
          RETURN FALSE;
       END;
    END;

    RETURN TRUE;

END ValidateWBSCodeSegment;


(*=============================================================================
 *  FindNextWBSCode
 *  ---------------
 *  Given a WBS code string, find the the end of the current segment.
 *  We utilize the follow by character string from the WBS form to accomplish
 *  this. ( Note. It is a condition of this function that a follow by
 *  sequence exists. )
 *  We will examine the follow by sequence first to see if there are any
 *  wildcard values contained in it. If there are not, we simply scan
 *  the WBS code from the current character position, looking for the
 *  follow by sequence.
 *  If there are wildcards, things get a 'bit' more complicated.
 *  We start scanning the follow by sequence looking for a non
 *  wild card character. When we find one, we scan the WBS code for
 *  the next occurence of the character. When we find it, we will
 *  move our pointer forward for every remaining character position
 *  in the follow by sequence.
 *  Note. A slight modification the the original spec's requires
 *  that I explain briefly how the follow by sequence behaves.
 *  We demand that the character sequence be unique and seperate
 *  in composition from the form character sequence values. This
 *  allows us to accurately determine the end of an arbitrary length
 *  segment within a WBS code string. This means that given a follow
 *  by string, every non-wildcard character must be unique. That is
 *  why, in the code that follows, I only test the first non wildcard
 *  character in the follow by sequence for existence in the WBS code.
 *  If it does not exist, and I know that this character must be unique,
 *  then I have an error, and can exit.
 *
 *  PRECONDITIONS : WBSCode contains a valid code based on the WBS form.
 *                  Loop is the current segment that we are searching for.
 *                  WBSFormP is a pointer to the current WBS form record.
 *                  InMarker is where the WBS code starts.
 *
 *  POSTCONDITIONS: None.
 *
 *  RETURNS       : The character position within the WBS code string where
 *                  the next WBS code will start at. If an error occurs
 *                  0 is returned.
 *============================================================================*)
PROCEDURE FindNextWBSCode ( VAR WBSCode   : ARRAY OF CHAR;
                                Loop      : CARDINAL;
                            VAR WBSFormP  : AWBSPtr;                (* 15-Aug-89 MWP *)
                                InMarker  : CARDINAL ) : CARDINAL;
VAR
    MatchSeq                : ARRAY [0..1] OF CHAR;
    FollowByLen,
    i, j,
    OutLen                  : CARDINAL;
BEGIN

    SetLengthOf ( MatchSeq, 1 );
    MatchSeq[1] := '?';


    WITH WBSFormP^ DO
       OutLen := Search ( WBSColumns[ Loop ].FollowBy, MatchSeq, InMarker );

       IF ( OutLen = 0 ) THEN
          (* No damned question marks. Just search for the whole string. *)
          OutLen := Search ( WBSCode, WBSColumns[ Loop ].FollowBy, InMarker );

          IF ( OutLen > 0 ) THEN
              OutLen := ( OutLen - InMarker ) +
                        ( LengthOf (WBSColumns[ Loop ].FollowBy) );
          END;
       ELSE
          i := 1;
          FollowByLen := LengthOf (WBSColumns[ Loop ].FollowBy );

          LOOP
             IF ( i > FollowByLen ) THEN
                EXIT;
             END;

             IF ( WBSColumns[ Loop ].FollowBy[i] <> '?' ) THEN
                 MatchSeq[1] := WBSColumns[ Loop ].FollowBy[i];
                 OutLen := Search ( WBSCode, MatchSeq, InMarker );

                 IF ( OutLen = 0 ) THEN
                    EXIT;
                 END;

                 FOR j := 0 TO FollowByLen - i DO
                    IF ( WBSColumns[ Loop ].FollowBy[i] <> WBSCode [ OutLen + j ] ) AND
                       ( WBSColumns[ Loop ].FollowBy[i] <> '?' ) THEN
                          OutLen := 0;
                          EXIT;
                    END;
                 END;

                 OutLen := OutLen + ( FollowByLen - i );
                 EXIT;
             END;
             INC(i);
          END;
       END;
    END;

    RETURN OutLen;

END FindNextWBSCode;



(*=============================================================================
 *  CreateAWbsCode
 *  --------------
 *  Create the string representation of a WBS code value using the rules
 *  stated in the WBS form record.
 *
 *  PRECONDITIONS : Value is the cardinal to convert to a string using user
 *                  defined rules.
 *                  Level is the segment level of the code to be created.
 *                  ParentWBS is an LString which contains the parent's WBS
 *                  code ( or is of zero length if no parent exists ).
 *                  WBSFormP is a pointer to the WBS form record.
 *
 *  POSTCONDITIONS: WBSString will contain the WBS string code, along with
 *                  any follow by characters etc. which may have been defined
 *                  on the form.
 *
 *  RETURNS       : TRUE is the code could be created, else FALSE.
 *============================================================================*)
PROCEDURE CreateAWbsCode  (     Value         : CARDINAL;
                                Level         : CARDINAL;
                            VAR WBSString     : ARRAY OF CHAR;
                            VAR ParentWBS     : ARRAY OF CHAR;
                                WBSFormP      : AWBSPtr;            (* 15-Aug-89 MWP *)
                            VAR ErrChoice     : AWBSError ) : BOOLEAN; (* 29-Jul-89 MWP *)
VAR
    j,
    Base,
    StartOffset,
    SizeMin, SizeMax        : CARDINAL;
    ExpandedFormSeq         : ARRAY [0..255] OF CHAR;
    BaseString              : ARRAY [0..255] OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;
    WBSCode                 : ARRAY [0..MaxWbsLen] OF CHAR;
    PadChar                 : CHAR;
BEGIN


    IF ( Level > MaxWbsRows ) THEN
       ErrChoice := LevelTooDeep;
       RETURN FALSE;
    END;

    WITH WBSFormP^ DO
       IF ( LengthOf ( WBSColumns[Level].CharacterSequence ) = 0 ) THEN
          ErrChoice := LevelNotDefined;
          RETURN FALSE;
       END;

       SetLengthOf ( WBSString, 0 );
       j := 1;

       DoDash ( WBSColumns[Level].CharacterSequence,
                ExpandedFormSeq,
                j );

       Base := j - 1;

       ExpandedFormSeq[0] := CHR(Base);

       IF ( WBSColumns[ Level ].StartOffset = 0 ) THEN
          DEC(Value);
       END;

       CardToBaseString ( Value, Base, BaseString );

       TStringToLString ( BaseString, BaseString );

       IF ( LengthOf ( BaseString ) > WBSColumns[ Level ].SizeMax ) THEN
           ErrChoice := WBSTooLarge;
           RETURN FALSE;
       END;


       (* If at top level, see if a Prefix string exists, and if so, grab it *)

       IF ( Level = 0 ) THEN
          GrabPrefix ( Prefix, WBSString );
       END;

       StartOffset := WBSColumns[Level].StartOffset;

       MapToWBSCode ( ExpandedFormSeq, BaseString, WBSCode, StartOffset );

       IF ( Level > 0 ) AND ( LengthOf ( ParentWBS ) > 0 ) THEN
          ConcatLS ( WBSString, WBSColumns[ Level - 1 ].FollowBy );
       END;

       SizeMin := WBSColumns[ Level ].SizeMin;
       SizeMax := WBSColumns[ Level ].SizeMax;

       PadChar := WBSColumns[ Level ].CharacterSequence[1];

       PadOutWBS ( WBSString, WBSCode, SizeMin, SizeMax, PadChar );

    END;

    IF ( Level < MaxWbsRows ) THEN
       FillOutWithAlwaysShow ( WBSString, Level, WBSFormP );
    END;


    RETURN TRUE;

END CreateAWbsCode;


(*=============================================================================
 *  MapToWBSCode
 *  ------------
 *  Given a string in WBS internal ascii format, convert it to the appropriate
 *  ascii characters as defined by the user on the WBS form.
 *
 *  PRECONDITIONS : FormString is the complete unpacked 'alphabet' that the
 *                  user wishes to use. ( Defined within 'Character Sequence'
 *                  on the WBS form. )
 *                  BaseString is the string in our internal alphabetic format.
 *                  WBSString is the complete string according to the user's
 *                  character sequence format.
 *  POSTCONDITIONS: None.
 *
 *  RETURNS       : Nothing.
 *============================================================================*)
PROCEDURE MapToWBSCode ( VAR FormString : ARRAY OF CHAR;
                         VAR BaseString : ARRAY OF CHAR;
                         VAR WBSString  : ARRAY OF CHAR;
                             StartOffset : CARDINAL );
VAR
    i, j,
    OffSet                  : CARDINAL;
BEGIN
    j := LengthOf ( BaseString );

    IF ( j > MaxWbsSize ) THEN
       j := MaxWbsSize;
    END;

    FOR i := 1 TO j DO
       OffSet := ORD(BaseString[i]) - 47;
       WBSString[i] := FormString[ OffSet ];
    END;

    WBSString[0] := CHR(j);

END MapToWBSCode;


(*=============================================================================
 *  FillOutWithAlwaysShow
 *  ---------------------
 *  For all following WBS form segments, if Always Show is set to yes,
 *  concat the WBS code segment using the Null character from the form
 *  Size Min times, and also the follow by sequence ( if the next segments
 *  Always SHow is set to Yes. )
 *  PRECONDITIONS :
 *
 *  POSTCONDITIONS:
 *
 *  RETURNS       :
 *============================================================================*)
PROCEDURE FillOutWithAlwaysShow ( VAR WBSString : ARRAY OF CHAR ;
                                      Level     : CARDINAL;
                                      WBSFormP  : AWBSPtr );        (* 15-Aug-89 MWP *)
VAR
    i, j,
    SizeMin                 : CARDINAL;
    PadChar                 : CHAR;
    Buffer                  : ARRAY [0..16] OF CHAR;
BEGIN

    i := Level + 1;

    WITH WBSFormP^ DO

       WHILE ( WBSColumns[ i ].AlwaysShow = AShowMethod(Yes) ) DO
            ConcatLS ( WBSString, WBSColumns[ i - 1 ].FollowBy );
            SizeMin := WBSColumns[ i ].SizeMin;
            PadChar := WBSColumns[ i ].Null[1];

            FOR j := 1 TO SizeMin DO
               Buffer[ j ] := PadChar;
            END;
            Buffer[0] := CHR(SizeMin);
            ConcatLS ( WBSString, Buffer );
            INC(i);
       END;
    END;

END FillOutWithAlwaysShow;


(*=============================================================================
 *  PadOutWBS
 *  ---------
 *  If a WBSCode string is less than Size Max., it is to be padded on the
 *  left with the first character of the Character Sequence SizeMax -
 *  LengthOf(WBSCode) times.
 *
 *  PRECONDITIONS : WBSString is the previous segments values ( if they
 *                  exist ) that prepend the WBS code itself.
 *                  WBSCode is the calculated WBS code string.
 *                  Size Min and Max, are the size boundaries of the WBS code.
 *                  PadChar is the character to pad with.
 *
 *  POSTCONDITIONS: WBSString will have the PadChar(s) and the WBSCode
 *                  concatenated to it.
 *
 *  RETURNS       : Nothing.
 *============================================================================*)
PROCEDURE PadOutWBS ( VAR WBSString : ARRAY OF CHAR;
                      VAR WBSCode   : ARRAY OF CHAR;
                          SizeMin   : CARDINAL;
                          SizeMax   : CARDINAL;
                          PadChar   : CHAR );
VAR
    i, j                    : CARDINAL;
    Buffer                  : ARRAY[0..16] OF CHAR;
BEGIN
    j := LengthOf ( WBSCode );

    SetLengthOf ( Buffer, 0 );

    IF ( j < SizeMin ) THEN
       FOR i := 1 TO SizeMin - j DO
          Buffer[ i ] := PadChar;
       END;
       Buffer[0] := CHR(SizeMin - j );
    END;

    ConcatLS ( WBSString, Buffer );
    ConcatLS ( WBSString, WBSCode );
END PadOutWBS;



(*=============================================================================
 *  GrabPrefix
 *  ----------
 *
 *  PRECONDITIONS :
 *
 *  POSTCONDITIONS:
 *
 *  RETURNS       :
 *============================================================================*)
PROCEDURE GrabPrefix (     Prefix    : ARRAY OF CHAR;
                       VAR WBSString : ARRAY OF CHAR );
BEGIN
    Copy ( Prefix, WBSString );
END GrabPrefix;


(*=============================================================================
 *  CardToBaseString
 *  ----------------
 *  Convert the cardinal 'Value' into a string representation
 *  in using 'base'. The converted string is returned in 'Out'.
 *  Note that we use contiguous ascii character values to represent
 *  the digits used in constructing the string. For example,
 *  normally Base 16 ( hex ), used digits 0..9 A..F. Internally
 *  we always start digits at '0' and move up from there
 *  contiguously, so we do not skip groups of characters. Our
 *  Base 16 would use the ascii digits 0..9 and then :;<=>?.
 *  This makes our lives a lot easier when converting a user
 *  defined character sequence value back into a cardinal value.
 *
 *  PRECONDITIONS : Base must be a reasonable base value. We will
 *                  most likely run into problems if anyone tries to
 *                  convert to a base higher than Base 207 or
 *                  there-abouts.
 *
 *  POSTCONDITIONS: Out will contain string representation of Value Base Base.
 *
 *  RETURNS       : Nothing.
 *============================================================================*)
PROCEDURE CardToBaseString (     Value : CARDINAL;
                                 Base  : CARDINAL;
                             VAR Out   : ARRAY OF CHAR );
VAR
    Index                   : CARDINAL;
BEGIN
    Index := 0;

    REPEAT
       Out[ Index ] := CHR(  ( Value MOD Base ) + 48 );
       INC(Index);

       Value := Value DIV Base;
    UNTIL ( Value <= 0 );

    Out[ Index ] := 0C;
    Reverse ( Out );

END CardToBaseString;


(*=============================================================================
 *  Reverse
 *  -------
 *  Reverse contents of a string
 *
 *  PRECONDITIONS : None.
 *
 *  POSTCONDITIONS: String's contents will be reversed.
 *
 *  RETURNS       : Nothing.
 *============================================================================*)
PROCEDURE Reverse ( VAR String : ARRAY OF CHAR );
VAR
   Len,
   Index                    : CARDINAL;
   TempChar                 : CHAR;

BEGIN
   Index := 0;
   Len := Length ( String );
   IF ( Len > 0 ) THEN
       DEC(Len);

       WHILE Index < Len DO
          TempChar := String[Index];
          String [ Index ] := String [ Len ];
          String [ Len ] := TempChar;
          INC( Index );
          DEC( Len );
       END;
   END;

END Reverse;

END WBSCreate.
