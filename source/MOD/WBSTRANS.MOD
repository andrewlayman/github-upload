IMPLEMENTATION MODULE WBSTranslate;

  (*   Routines used in the creation and translation and verification of
       WBS codes.

        MODIFICATION HISTORY:

         14-Jun-89  MWP  In the beginning...
         20-Jul-89  MWP  CompareSegments moved in this module.
         29-Jul-89  MWP  Modified CheckParentWBSCode to use new error
                         notification scheme.
         15-Aug-89  MWP  Use AWBSPtr as parameter.
         29-May-91  EGK  Fixed bug in ConvertSegToCard, in which leading
                         "zeros" were ignored by looking for the user's
                         "start character", instead of the first character
                         of the character sequence.  For Tech Support
                         Problem #666 (no kidding).
  *)

FROM Foreign        IMPORT
    (* PROC *)              DoDash;

FROM LStrings       IMPORT
    (* PROC *)              SetLengthOf, LengthOf,
                            Search;

FROM SYSTEM         IMPORT
   (* TYPE *)               ADDRESS;

FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATree;

FROM WBSCommon      IMPORT
    (* TYPE *)              AnWBSFormsValue,
                            AWBSPtr,                                (* 15-Aug-89 MWP *)
                            AContextPtr,
                            MaxWbsLen,
    (* TYPE *)              AWBSError,
                            MaxWbsRows,
                            AContextRecord,
    (* PROC *)              GetWBSCode,
                            ErrorsInTask;

FROM WBSCreate      IMPORT
    (* PROC *)              ExtractDecomposedSegment,
                            StripOffShowCharacters,
                            DecomposeWBSCode;

FROM WBSDialog      IMPORT
    (* PROC *)              WBSError;


PROCEDURE ConvertWBSCodeToCard (     SegmentLevel     : CARDINAL;
                                     WBSFormP         : AWBSPtr;    (* 15-Aug-89 MWP *)
                                 VAR WBSCode          : ARRAY OF CHAR;
                                 VAR Value            : CARDINAL ) : BOOLEAN;
VAR
    Decomposed              : ARRAY[0..255] OF CHAR;
    SegmentString           : ARRAY [0..MaxWbsLen] OF CHAR;
    ok                      : BOOLEAN;
    i                       : CARDINAL;
BEGIN
    IF ( SegmentLevel > MaxWbsRows ) THEN
       RETURN FALSE;
    END;

    ok := DecomposeWBSCode (  WBSCode,
                              WBSFormP,
                              SegmentLevel,
                              Decomposed );


    IF ( ok ) THEN
        IF ( LengthOf ( WBSFormP^.Prefix ) > 0 ) THEN
           i := SegmentLevel + 1;
        ELSE
           i := SegmentLevel;
        END;

        IF ( ExtractDecomposedSegment ( i, Decomposed, SegmentString ) ) THEN
           ConvertSegToCard ( SegmentString, Value, WBSFormP, SegmentLevel );
        END;
    END;

    RETURN ( ok );

END ConvertWBSCodeToCard;


PROCEDURE  ConvertSegToCard ( VAR SegmentString : ARRAY OF CHAR;
                              VAR Value         : CARDINAL;
                                  WBSFormP      : AWBSPtr;          (* 15-Aug-89 MWP *)
                                  Level         : CARDINAL );
VAR
    StartWith, i, Len, j    : CARDINAL;
    Base                    : CARDINAL;
    CurrentValue            : CARDINAL;
    StartCalcPos, Min       : CARDINAL;
    BaseString              : ARRAY [0..255] OF CHAR;
    StartChar               : CHAR;
BEGIN

    StartWith := WBSFormP^.WBSColumns[ Level ].StartOffset;


    (* Convert form character sequence into expanded form. *)
    j := 1;

    DoDash ( WBSFormP^.WBSColumns[Level].CharacterSequence,
             BaseString,
             j );

    Base := j - 1;

    BaseString[0] := CHR(Base);


    Len := LengthOf ( SegmentString );

    Value := 0;

    StartCalcPos := 1;

    Min := WBSFormP^.WBSColumns[ Level ].SizeMin;

    (* If minimum size on form is more than one, we pad with the Start With
        character.

    *)
    IF ( Min > 1 ) THEN
       StartChar := BaseString[1];      (* 29-May-91 EGK *)
       WHILE ( StartCalcPos < Min ) AND
             ( SegmentString[ StartCalcPos ] = StartChar ) DO
           INC(StartCalcPos);
       END;
    END;

    (* For all valid characters in the WBS code string,
       Find their index position in the BaseString, and
       add to a running Value total.
     *)
    FOR i := StartCalcPos TO Len DO
       CurrentValue := FindCharPosition ( SegmentString[ i ], BaseString );

       IF ( CurrentValue > 0 ) THEN
           CurrentValue := CurrentValue - 1;
       ELSE
          Value := 0;
          RETURN;
       END;
(***
       IF ( CurrentValue > 0 ) THEN
           CurrentValue := CurrentValue - StartWith;
       ELSE
          Value := 0;
          RETURN;
       END;
***)
       Value :=  ( Base * Value ) + CurrentValue;
    END;

    IF ( StartWith = 0 ) THEN
       INC(Value);
    END;

END ConvertSegToCard;


PROCEDURE FindCharPosition (     FindChar   : CHAR;
                             VAR BaseString : ARRAY OF CHAR ) : CARDINAL;
VAR
    Index                   : CARDINAL;
    SearchString            : ARRAY[0..1] OF CHAR;
BEGIN
    SetLengthOf ( SearchString, 1 );
    SearchString[ 1 ] := FindChar;

    Index := Search ( BaseString,
                      SearchString,
                      1 );

    RETURN Index;

END FindCharPosition;


PROCEDURE CalculateWBSCardinalValue ( VAR CursorNode : ATreeNode;
                                          Direction  : CARDINAL;
                                          WBSFormP   : AWBSPtr ) : CARDINAL; (* 15-Aug-89 MWP *)
CONST
    Previous = 1;
    Next     = 2;
VAR
    CountNode               : ATreeNode;
    HighValue, TempValue    : CARDINAL;
    ProcessLevel            : CARDINAL;
    s                       : ARRAY [0..MaxWbsLen] OF CHAR;
BEGIN

    HighValue := 0;

    ProcessLevel := CursorNode^.Methods^.IndentationLevel ( CursorNode );

    IF ( ProcessLevel > MaxWbsRows ) THEN
       RETURN ( 0 );
    END;

    IF ( Direction = Previous ) THEN
       CountNode := CursorNode^.Methods^.GetPrev ( CursorNode );
    ELSE
       CountNode := CursorNode^.Methods^.GetNext ( CursorNode );
    END;

    WHILE ( CountNode <> ATreeNode(NIL) ) DO

        GetWBSCode ( CountNode, s );

        IF ( LengthOf ( s ) > 0 ) THEN
            IF ( ConvertWBSCodeToCard ( ProcessLevel,
                                        WBSFormP,
                                        s,
                                        TempValue ) ) THEN
               IF ( TempValue > HighValue ) THEN
                   HighValue := TempValue;
               END;
           END;
        END;
        IF ( Direction = Previous ) THEN
           CountNode := CountNode^.Methods^.GetPrev ( CountNode );
        ELSE
           CountNode := CountNode^.Methods^.GetNext ( CountNode );
        END;
    END;

    RETURN ( HighValue );

END CalculateWBSCardinalValue;


PROCEDURE CheckParentWBS ( VAR CursorNode     : ATreeNode;
                               WBSFormP       : AWBSPtr;             (* 15-Aug-89 MWP *)
                               ContextRecordP : AContextPtr;
                           VAR ParentWBS      : ARRAY OF CHAR ) : BOOLEAN;
VAR
    ParentLevel             : CARDINAL;
    ParentNode              : ATreeNode;
    ok                      : BOOLEAN;
BEGIN
    ok := TRUE;

    SetLengthOf ( ParentWBS, 0 );

    ParentNode   := CursorNode^.Methods^.Parent ( CursorNode );

    IF ( ParentNode <> ATreeNode(NIL) ) THEN
           ParentLevel := ParentNode^.Methods^.IndentationLevel ( ParentNode );

           IF ( ParentLevel > MaxWbsRows ) THEN
              RETURN FALSE;
           END;

           GetWBSCode ( ParentNode, ParentWBS );

           IF ( LengthOf ( ParentWBS ) > 0 )  THEN
              IF ( NOT StripOffShowCharacters ( ParentLevel,
                                                WBSFormP,
                                                ParentWBS,
                                                ParentWBS ) ) THEN
                 ok := FALSE;
              END;
           ELSE
              ok := FALSE;
           END;
    END;

    IF ( NOT ok ) THEN
        WBSError ( CursorNode,
                   ParentError,
                   ContextRecordP^.ShowThese,
                   ContextRecordP^.ErrorsFound );
    END;

    RETURN ok;

END CheckParentWBS;

(*=============================================================================
 *  CompareSegemnts
 *  ---------------
 *  Given two task WBS values in decomposed format, compare them segment
 *  for segment up to the level indicated by ParentLevel.
 *
 *  PRECONDITIONS:
 *            TaskBuffer   - The current task's WBS code in decomposed format.
 *            ParentBuffer - The current task's parent's WBS code, in
 *                           decomposed format.
 *            ParentLevel  - The outline level of the parent.
 *
 *  POSTCONDITIONS:
 *            None.
 *
 *  RETURNS   TRUE  - if the segments of both task's compared correctly.
 *            FALSE - segments do not match.
 *============================================================================*)
PROCEDURE CompareSegments ( VAR TaskBuffer   : ARRAY OF CHAR;
                            VAR ParentBuffer : ARRAY OF CHAR;
                                ParentLevel  : CARDINAL ) : BOOLEAN;
VAR
    i, j,
    ParentLen               : CARDINAL;
    ParentSeg               : ARRAY[0..MaxWbsLen] OF CHAR;
    TaskSeg                 : ARRAY[0..MaxWbsLen] OF CHAR;
BEGIN
    ParentLen := LengthOf ( ParentBuffer );

    (* Task Buffer MUST be as large or larger than the Parent,
       or we have a definite problem.
    *)
    IF ( LengthOf ( TaskBuffer ) < ParentLen ) THEN
        RETURN FALSE;
    END;

    (* For all valid parent segments, i.e. ignore Show characters,
       test them against the Task segments. If they differ, we have a problem.
    *)

    FOR i := 0 TO ParentLevel DO
        IF ( NOT ExtractDecomposedSegment ( i, TaskBuffer, TaskSeg ) ) OR
           ( NOT ExtractDecomposedSegment ( i, ParentBuffer, ParentSeg ) ) THEN
            RETURN FALSE;
        END;

        ParentLen := LengthOf ( ParentSeg );

        (* I would like to use Compare here instead, however the TaskSeg
           value could have 'follow by' characters appended to it which
           the parent does not have, and this would cause Compare to fail.
        *)

        IF ( ParentLen > 0 ) THEN
           FOR j := 1 TO ParentLen DO
              IF ( TaskSeg[ j ] <> ParentSeg[ j ] ) THEN
                 RETURN FALSE;
              END;
           END;
        ELSE
           RETURN FALSE;
        END;
    END;

    RETURN TRUE;

END CompareSegments;


END WBSTranslate.
