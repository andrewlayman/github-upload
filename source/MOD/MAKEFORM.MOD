IMPLEMENTATION MODULE MakeForm;

    (* MakeForm -- Construct a basic dialog form independent of its
                   internal representation based on (primarily) coded
                   ascii text.


    RULES OF USE:

           IF YOU CREATE THE FORM HERE:

              - You cannot create a second form before filling the
                first one in.  The first form must have at least one field
                filled in before creating the second form!!

           IF THE FORM IS FROM THE FORMS FILE:

              - It must ALREADY have at least one field!!

              - Before adding any fields, you must FIRST either:

                    1) Call "StartNewGroup", or
                    
                    2) Set Fields[MaxField+1].Group := Fields[MaxField].Group;
     *)

     (* MODIFICATION HISTORY

        30-Mar-89  RSC  Initial version.
        10-May-89  LAA  Fixed a problem with AddSeparator, because the FLine
                        after the previously MaxLine was not initialized.
                        Also fixed problems in AddField.
        15-May-89  LAA  Fixed bug in StartNewGroup.  The group number for the
                        "next" field will be set to 1 more than the group
                        number of the last field.
        04-Jun-89  LAA  Added support for string-type fields.
        20-Nov-89  KKC  Added support for numeric-type fields.
     *) 


FROM BalExpr        IMPORT
    (* PROC *)          ParseExpression, ParseCardinal;

FROM Boxes          IMPORT
    (* TYPE *)          ABoxType;

FROM Codes          IMPORT
    (* CONST *)         MaxCode,
    (* TYPE *)          ASetOfCodes, ACode,
    (* VAR  *)          EmptyCodeSet,
    (* PROC *)          SetCodeBits;

FROM Dialog         IMPORT
    (* PROC *)          FatalError;

FROM Foreign        IMPORT
    (* PROC *)          ExpandStringToXLAT;

FROM FormCon        IMPORT
    (* TYPE *)          AFieldNo, AChoiceNo, AFieldType;

FROM FormHand       IMPORT
    (* TYPE *)          AFormHandle,
    (* PROC *)          AttachHandleToRecord, DiscardFormHandle,
                        GetAddressFromFormHandle;

FROM FormRec        IMPORT
    (* TYPE *)          AFormRecord, AFormField, APromptType, AnAttribute,
                        ASetOfAttributes;

FROM Kbio           IMPORT
    (* CONST *)         maxcol;

FROM Layout         IMPORT
    (* CONST *)         GanttWStart;

FROM LStrings       IMPORT
    (* PROC *)          Copy, SetLengthOf, Fill, LengthOf, Overlay, SetString,
                        SubStr, StoC;

FROM Menus          IMPORT
    (* PROC *)          WordNumber;

FROM RealFormat     IMPORT
    (* VAR  *)          DefaultAmountFormat;

FROM Words          IMPORT
    (* PROC *)          MaxWordstringThatFits;




VAR
    LastFormCreated  : AFormHandle;


    CardinalCodes,
    NumericCodes,
    StringCodes      : ASetOfCodes;








    (* ------------------------------------------------------------------

       CreateForm

       Preconditions: None

       PostConditions: FormHandle will refer to a form with no fields but
                       with the given BoxType, Title and of the set Width.
                       The highest Group associated with the form is 0. 
    
    -------------------------------------------------------------------*)


PROCEDURE CreateForm( VAR FormHandle : AFormHandle;
                          BoxType    : ABoxType;
                          TheTitle   : ARRAY OF CHAR; 
                          Width      : CARDINAL     ): BOOLEAN;
VAR
    FormRecord : AFormRecord;
    i          : CARDINAL;
    ok         : BOOLEAN;

BEGIN
    IF (LastFormCreated <> AFormHandle(NIL)) THEN
        FatalError();  (* Another form initialized, but has no fields? *)
    END;

    WITH FormRecord DO
        SetLengthOf( HelpKey, 0 );
        Copy( TheTitle, Title );
        ID           := 0;
        PhrasesStart := 30000 + (ID * 100);
        MaxLine      := 0;
        PromptType   := SeparatePrompts;
        PromptULX    := 0;
        PromptULY    := 0;
        PromptLRX    := maxcol;
        PromptLRY    := GanttWStart - 1;
        Box          := BoxType;
        SetCodeBits(CheckCodeSet,0,MaxCode,FALSE);
        MaxField     := 0;
        Fields[ 0 ].Group := 0;     (* Next field initted to group 0 *)

        FOR i := 0 TO HIGH( FLine ) DO
            Fill( FLine[i], " ", Width );
            FLine[i,1]       := "º";
            FLine[i,Width]   := "º";
        END;
    END;
    
    ok              := AttachHandleToRecord( FormHandle, FormRecord );
    LastFormCreated := FormHandle;

    RETURN ok;

END CreateForm;








    (* ------------------------------------------------------------------

       DiscardForm

       Preconditions: FormHandle refers to a form.

       PostConditions: FormHandle will no longer refer to a form.
                       Its previous storage is deallocated.
    
    -------------------------------------------------------------------*)



PROCEDURE DiscardForm( VAR FormHandle : AFormHandle );
BEGIN
    DiscardFormHandle( FormHandle );
END DiscardForm;







    (* ------------------------------------------------------------------

       SetHelpKey

       Preconditions: FormHandle refers to a form.
                      HelpKey is an LString.

       PostConditions: The help key of the form is set to the first 
                       seven characters of the passed HelpKey.
    
    -------------------------------------------------------------------*)


PROCEDURE SetHelpKey(     FormHandle : AFormHandle;
                      VAR HelpKey    : ARRAY OF CHAR );  
VAR
    FormRecordPtr : POINTER TO AFormRecord;
BEGIN
    GetAddressFromFormHandle( FormHandle, FormRecordPtr );
    Copy( HelpKey, FormRecordPtr^.HelpKey );
END SetHelpKey;







PROCEDURE ParseField( VAR Field      : AFormField;
                          Row        : CARDINAL;
                      VAR Spec       : ARRAY OF CHAR;
                      VAR Background : ARRAY OF CHAR ) : BOOLEAN;
CONST
    EnumerationType = 6;
    StringType      = 1;                                          (* 04-Jun-89 LAA *)
    NumericType     = 2;            (* 20-Nov-89 KKC  *)

VAR
    OverlayPos,
    Word,
    Ask,
    Type        : CARDINAL;
    j           : CARDINAL;
    NIntegerDigits, 
    NDecimalDigits  : CARDINAL;
    s, s1       : ARRAY [0..maxcol] OF CHAR;
    s2, s3      : ARRAY [0..maxcol] OF CHAR;


    PROCEDURE AddToBackground( VAR StrToAdd : ARRAY OF CHAR ) : BOOLEAN;
    VAR
        Length : CARDINAL;
    BEGIN

        Length := LengthOf(StrToAdd);
        IF ((OverlayPos + Length) >= LengthOf( Background )) THEN
            RETURN FALSE;
        END;

        Overlay( Background, StrToAdd, OverlayPos, Length );
        INC( OverlayPos, Length );   (* Where to start next time. *)

        RETURN TRUE;

    END AddToBackground;


BEGIN

    (* EXPECTED FORMAT OF "Spec":

            1:  Parameter Number        (ignored here)
            2:  Type (1=string, 2=number, 5=Boolean, 6=enumeration, others ??)
            3:  Default value           (ignored here)
            4:  Title, used in the form background.
            5:  Details.
            6:  Ask (1=Ask, 0=Skip)
            7:  Prompt                  (ignored here)
            8:  HelpKey                 (ignored here)

            As of this release of the document (\LAZLO\GRAFFILE.DOC, Feb 89)
            only type 6, enumerations, are fully supported.
    *)


    (* Get Type *)

    IF (NOT (ParseCardinal( Spec, 2, Type ))) THEN
        RETURN FALSE;
    END;


    (* Get the Title, or backgound, for the field. *)

    OverlayPos := 3;
    IF (NOT ParseExpression( Spec, 4, s )) OR
       (NOT AddToBackground( s ))          THEN
        RETURN FALSE;
    END;


    (* Get field details.  For now, only handle type 6, enumerations. *)

    WITH Field DO
        Attributes := ASetOfAttributes{};
        CASE Type OF
            EnumerationType :
                FFType     := FormChoice;
                CodeSet    := EmptyCodeSet;

                SetString( s2, ": (" );
                IF (NOT AddToBackground( s2 )) THEN
                    RETURN FALSE;
                END;

                (* Details. *)

                IF (NOT (ParseExpression( Spec, 5, s ))) THEN
                    RETURN FALSE;
                END;

                Word := 1;
                WordNumber( s, Word, s1 );
                WHILE (LengthOf(s1) > 0) DO
                    IF (Word > 1) THEN
                        SetString( s2, ", " );
                        IF (NOT AddToBackground( s2 )) THEN
                            RETURN FALSE;
                        END;
                    END;
                    Count := Word - 1;
                    Choicexoff[ Count ] := OverlayPos - 1;
                    Choiceyoff[ Count ] := Row;
                    ChoiceLen[  Count ] := LengthOf(s1);
                    IF (NOT AddToBackground( s1 )) THEN
                        RETURN FALSE;
                    END;
                    INC(Word);
                    WordNumber( s, Word, s1 );
                END;

                SetString( s2, ")" );
                IF (NOT AddToBackground( s2 )) THEN
                    RETURN FALSE;
                END;

            |   StringType :
                FFType     := FormString;
                CodeSet    := EmptyCodeSet;

                SetString( s2, ": [" );
                IF (NOT AddToBackground( s2 )) THEN
                    RETURN FALSE;
                END;

                (* Details. *)

                IF (NOT (ParseExpression( Spec, 5, s ))) THEN
                    RETURN FALSE;
                END;
                IF (NOT ParseExpression(s, 1, s2)) THEN
                    RETURN FALSE;
                END;
                j := 1;
                StLen := StoC(s2, j);
                xoff := OverlayPos - 1;
                yoff := Row;

                Fill(s2, " ", StLen);
                IF (NOT AddToBackground( s2 )) THEN
                    RETURN FALSE;
                END;

                IF (NOT ParseExpression(s, 2, s2)) THEN
                    RETURN FALSE;
                END;
                ExpandStringToXLAT(s2, s3);
                FOR j := 1 TO LengthOf(s3) DO
                    SetCodeBits(CodeSet, ORD(s3[j]), ORD(s3[j]), TRUE);
                END;
                
                IF (NOT ParseExpression(s, 3, s2)) THEN
                    RETURN FALSE;
                END;
                j := 1;
                j := StoC(s2, j);
                IF (j > 0) THEN
                    INCL(Attributes, ShiftUp);
                END;

                IF (NOT ParseExpression(s, 4, s2)) THEN
                    RETURN FALSE;
                END;
                j := 1;
                j := StoC(s2, j);
                CASE j OF
                    1 : INCL(Attributes, JustifyLeft);
                |   2 : INCL(Attributes, JustifyRight);
                ELSE
                END;
                
                SetString( s2, "]" );
                IF (NOT AddToBackground( s2 )) THEN
                    RETURN FALSE;
                END;

            | NumericType: 
     (* !!! I have not implemented the routine to handle Min value,     *) 
     (* !!  Max value and scale.  Min value and Max value are ignored   *)
     (* !!  and scale is always assumed to be equal to one              *)
                FFType := FormReal;
                CodeSet    := EmptyCodeSet;

                SetString( s2, ": [" );
                IF (NOT AddToBackground( s2 )) THEN
                    RETURN FALSE;
                END;

                (* Details. *)

                IF (NOT (ParseExpression( Spec, 5, s ))) THEN
                    RETURN FALSE;
                END;

   (* 
        s  = (Max digits)(Min Value)(Max Value)(Max decimal digits )(scale) 
        UserUnites * scale = InternalUnits;
   *)

                IF (NOT ParseExpression(s, 1, s2)) THEN (* Digits to the left of decimal *)
                    RETURN FALSE;
                END;
                j := 1;
                NIntegerDigits :=  StoC(s2, j);

                IF (NOT ParseExpression(s, 4, s2)) THEN (* Digits to the right of decimal *)
                    RETURN FALSE;
                END;
                j := 1;
                NDecimalDigits :=  StoC(s2, j);

                IF ( NDecimalDigits <> 0 ) THEN
                    StLen := NIntegerDigits + NDecimalDigits + 1;
                ELSE
                    StLen := NIntegerDigits;
                END;
                Digits := NDecimalDigits;

                Fill(s2, " ", StLen);

                xoff := OverlayPos - 1;
                yoff := Row;
                SetCodeBits(CodeSet,0,MaxCode,FALSE);
                SetCodeBits(CodeSet,ORD(" "),ORD(" "),TRUE);
                SetCodeBits(CodeSet,ORD("0"),ORD("9"),TRUE);
                SetCodeBits(CodeSet,ORD("."),ORD("."),TRUE);
                Attributes := ASetOfAttributes{Numeric,BlankIfZero,
                                                         ResetCursorOnError};

                IF (NOT AddToBackground( s2 )) THEN
                    RETURN FALSE;
                END;
                SetString( s2, "]" );
                IF (NOT AddToBackground( s2 )) THEN
                    RETURN FALSE;
                END;
        ELSE
            RETURN FALSE;
        END;
    END;

    RETURN TRUE;

END ParseField;










    (* ------------------------------------------------------------------

       AddField

       Preconditions: FormHandle refers to a form.
                      Spec is a field spec as defined in the document
                      "TLGS Parameter File Format."

       PostConditions: Either FALSE is returned or 
                       the form contains one more field which matches
                       the Spec.  This field is assigned to the highest
                       Group associated with the form.
                       The FieldNumber of the field is the number of times
                       this procedure has been called previously (that
                       is, fields are numbered sequentially from zero.)  
    
    -------------------------------------------------------------------*)

PROCEDURE AddField(     FormHandle : AFormHandle;
                    VAR Spec       : ARRAY OF CHAR ): BOOLEAN;
VAR
    FormRecordPtr : POINTER TO AFormRecord;
    Ask           : CARDINAL;
    ok            : BOOLEAN;
BEGIN
    (* Should we be here? *)

    IF (NOT (ParseCardinal( Spec, 6, Ask ))) THEN
        RETURN FALSE;
    END;

    IF (Ask <> 1) THEN
        RETURN TRUE;        (* Field ok, just not one of ours. *)
    END;


    GetAddressFromFormHandle( FormHandle, FormRecordPtr );

    WITH FormRecordPtr^ DO
        IF (MaxField = 0) THEN
            IF (LastFormCreated = FormHandle) THEN
                LastFormCreated := AFormHandle(NIL);
            ELSE
                INC(MaxField);
            END;
        ELSE
            IF (MaxField = HIGH(Fields)) THEN
                FatalError();  (* Too many fields!! *)
            END;
            INC(MaxField);
        END;

        IF (MaxField < HIGH(Fields)) THEN
            Fields[ MaxField ].Group := Fields[ MaxField - 1].Group;  (* 10-May-89 LAA *)
        END;

        INC(MaxLine);   (* Next screen line.  Line 0 never used. *)
        IF (MaxLine > HIGH(FLine)) THEN
            FatalError();
        END;

        Fill(FLine[MaxLine], " ", LengthOf(FLine[MaxLine - 1]));  (* 10-May-89 LAA *)
        FLine[MaxLine][1] := "º";
        FLine[MaxLine][LengthOf(FLine[MaxLine])] := "º";

        ok := ParseField( Fields[MaxField], MaxLine, Spec, FLine[MaxLine] );

    END;

    RETURN ok;

END AddField;








    (* ------------------------------------------------------------------

       StartNewGroup

       Preconditions: FormHandle refers to a form.  At least 2 fields are
                      defined.

       PostConditions: The last field of the form (probably the one just
                       added) is given a group number one higher than the
                       group number of the preceeding field.

    -------------------------------------------------------------------*)

PROCEDURE StartNewGroup(     FormHandle : AFormHandle );
VAR
    FormRecordPtr : POINTER TO AFormRecord;
BEGIN
    GetAddressFromFormHandle( FormHandle, FormRecordPtr );
    WITH FormRecordPtr^ DO
        IF ((MaxField < 1) OR (MaxField > HIGH(Fields))) THEN
            FatalError();  (* Not enough, or too many fields!! *)
        END;
        Fields[MaxField].Group := Fields[MaxField - 1].Group + 1; (* 15-May-89 LAA *)
    END;
END StartNewGroup;







    (* ------------------------------------------------------------------

       AddSeparator

       Preconditions: FormHandle refers to a form.

       PostConditions: An additional line is at the end of the form,
                       extending the full width, consisting of the 
                       SeparatorChar repeated. 
    
    -------------------------------------------------------------------*)

PROCEDURE AddSeparator(     FormHandle    : AFormHandle;
                            SeparatorChar : CHAR         ): BOOLEAN;
VAR
    FormRecordPtr : POINTER TO AFormRecord;
    Length        : CARDINAL;
    s             : ARRAY [0..255] OF CHAR;
BEGIN
    GetAddressFromFormHandle( FormHandle, FormRecordPtr );
    WITH FormRecordPtr^ DO
        INC(MaxLine);   (* Next screen line.  Line 0 never used. *)
        IF (MaxLine > HIGH(FLine)) THEN
            FatalError();
        END;
        Copy(FLine[MaxLine - 1], FLine[MaxLine]);                 (* 10-May-89 LAA *)
        Length := LengthOf( FLine[ MaxLine ] );                
        Fill( s, SeparatorChar, (Length - 2));
        Overlay( FLine[ MaxLine ], s, 2, LengthOf( s ));
        IF (SeparatorChar = "Ä") THEN
            FLine[ MaxLine, 1      ] := "Ç";  (* Handle the most common case. *)
            FLine[ MaxLine, Length ] := "¶";
        END;
    END;
    RETURN TRUE;
END AddSeparator;






    (* ------------------------------------------------------------------

       AddText

       Preconditions: FormHandle refers to a form.

       PostConditions: Additional lines are added at the end of the form.
                       These contain the text, which may have been word
                       wrapped to fit.
    
    -------------------------------------------------------------------*)

PROCEDURE AddText(      FormHandle : AFormHandle;
                    VAR Text       : ARRAY OF CHAR ): BOOLEAN;
CONST
    BreakWordChar  = " ";
    BreakLineChar  = "ü";
VAR
    FormRecordPtr : POINTER TO AFormRecord;
    FirstCharOnLine,
    Length,
    i             : CARDINAL;
    s             : ARRAY [0..maxcol] OF CHAR;
BEGIN
    GetAddressFromFormHandle( FormHandle, FormRecordPtr );
    WITH FormRecordPtr^ DO

        Length := LengthOf( FLine[ MaxLine ] ) - 4;  (* All lines are the same. *)

        (* Use something like PourText, but, alas, PourText works only out to
           the screen.  Fortunately, Words has a nice routine for us.
        *)
        FirstCharOnLine := 1;
        LOOP
            i := MaxWordstringThatFits( Text,
                                        FirstCharOnLine,
                                        Length,
                                        BreakWordChar,
                                        BreakLineChar );
            IF (i = 0) THEN
                EXIT;
            END;

            INC(MaxLine);   (* Next screen line.  Line 0 never used. *)
            SubStr( Text, s, FirstCharOnLine, i );
            Overlay( FLine[ MaxLine ], s, 3, LengthOf(s) );

            INC(FirstCharOnLine, i);
            WHILE (      FirstCharOnLine  <= LengthOf( Text ))   AND
                 ((Text[ FirstCharOnLine ] = BreakWordChar)      OR
                  (Text[ FirstCharOnLine ] = BreakLineChar))     DO
                INC(FirstCharOnLine);
            END;
        END;
    END;
    RETURN TRUE;
END AddText;











PROCEDURE InitMakeForm();


    PROCEDURE SetChar( VAR Set : ASetOfCodes;
                           C   : CHAR );
    VAR
        Code    : ACode;
    BEGIN
        Code := ORD(C);
        SetCodeBits( Set, Code, Code, TRUE );
    END SetChar;


    PROCEDURE SetStringOfChars( VAR Set : ASetOfCodes;
                                VAR s   : ARRAY OF CHAR );
    VAR
        Loop    : CARDINAL;
    BEGIN
        FOR Loop := 1 TO LengthOf(s) DO
            SetChar( Set, s[Loop] );
        END;
    END SetStringOfChars;


BEGIN
    LastFormCreated := AFormHandle(NIL);

    CardinalCodes   := EmptyCodeSet;
    SetCodeBits( CardinalCodes, ORD("0"), ORD("9"), TRUE );
    SetChar(     CardinalCodes, " " );

    NumericCodes := CardinalCodes;

    WITH DefaultAmountFormat DO

        SetChar( NumericCodes, RadixSymbol           );
        SetChar( NumericCodes, SymbolForSignificance );

        WITH Decorations DO

            SetStringOfChars( NumericCodes, LeadingNegativeSymbol );
            SetStringOfChars( NumericCodes, TrailingNegativeSymbol );
            SetStringOfChars( NumericCodes, LeadingPositiveSymbol );
            SetStringOfChars( NumericCodes, TrailingPositiveSymbol );

        END;
    END;

    StringCodes  := EmptyCodeSet;
    SetCodeBits( StringCodes,ORD(" "),175,TRUE);

END InitMakeForm;



BEGIN
    InitMakeForm();
END MakeForm.
