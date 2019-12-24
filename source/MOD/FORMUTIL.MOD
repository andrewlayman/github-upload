IMPLEMENTATION MODULE FormUtil;

    (* MODIFICATION HISTORY:

        6-Oct-90 AJL -Add a help button to forms.
        7-Jan-91 AJL -Changed the parameter S on StringToReal from VAR
                      to call-by-value, so that a side-effect of the routine
                      is no longer to modify the input parameters.
    *)


FROM Boxes   IMPORT ABoxAttribute, ABoxType,
                    DrawBox;

FROM Codes      IMPORT ACode, ASetOfCodes;

FROM Dialog     IMPORT Burp;

FROM EvalReal   IMPORT
    (* PROC *)      EvaluateRealExpression;

FROM Events     IMPORT 
    (* TYPE *)      AnEvent, AnEventType;
IMPORT Events;

FROM FatalErr   IMPORT FatalError;

FROM Foreign  IMPORT UpshiftTable, ConvertedCharacter;

FROM FormCon    IMPORT MaxChoice, AFieldNo,
                       AChoiceNo, AFieldType;

FROM FormRec    IMPORT Anxoff, Ayoff, MaxFLines,
                       AFormField, AFormRecord, FLineLen, MaxCapLen,
                       AFormRecordPointer, APromptType,
                       AnAttribute, ASetOfAttributes,
                       ACaption, MaxCaptionsPerField;

FROM Forms      IMPORT 
    (* TYPE *)         AForm, (* Same as a FormControlBlockPointer *)
                       AFieldValue, ACheckProc, AQueryPromptProc,
                       AStringValuePointer, ACursorAttribute,
    (* PROC *)         MinIndex,MaxIndex,FindFieldXY;

FROM Helper  IMPORT AScreenAction, AHelpBox, OpenHelpBox,
                    CloseHelpBox;

FROM Kbio       IMPORT 
    (* TYPE *)         ascreenx, ascreeny, avidmode,ACursorType,
    (* VAR  *)         maxcol, 
    (* PROC *)         GetCode,PutString,SetCursorType,GotoXY,
                       PourText;

FROM LStrings   IMPORT SubStr, Procustes, CtoS, StoC, LengthOf,
                       Copy, ConcatLS, Insert, Remove, Fill,
                       LJust, RJust, Overlay, LStringToTString,
                       TStringToLString, Compare, TrimRear, Upshift,
                       SetString, ConcatS, TrimFront, Search,
                       InsertWithOverflow, SetLengthOf;

FROM Menus   IMPORT NoYes;

FROM Mouse          IMPORT
    (* PROC *)          MousePresent, CancelDoubleClick;

FROM MsgFile IMPORT
    (* CONST *)     Forms,
    (* PROC *)      GetMessage, ConcatMessage,
                    GetMessageForClass;

FROM RealFormat IMPORT
    (* VARS  *)        DefaultAmountFormat, DefaultCurrencyFormat,
    (* PROCS *)        FormatAsAmount, FormatAsCurrency;


CONST
    MAXINT        = 32767;
    MAXCARDINAL   = 65535;
    Zero          = 0.0;
    ModuleNumber  = 2200;   (* For MsgFile module reference. *)





PROCEDURE ClearAnyHelpText( Form : AFormControlBlockPointer );
BEGIN
    WITH Form^ DO
        IF (HelpLRY >= HelpULY) THEN
            CloseHelpBox(HelpBox);
            HelpULY := 1;               (* Impossible range. *)
            HelpLRY := 0;
        END;
    END;
END ClearAnyHelpText;




    (*  SHOWBASE -- Show the base portion of a screen form.
                    Y gives the starting line number. *)

PROCEDURE ShowBase(Form : AFormControlBlockPointer);
VAR
    FormRecord : AFormRecordPointer;
    Line       : Ayoff;
    BoxType    : ABoxType;
BEGIN
    FormRecord := Form^.FormRecordPointer;
    IF (FormRecord^.MaxLine > MaxFLines) THEN FatalError; END;

    BoxType := FormRecord^.Box;
    IF (MousePresent()) THEN
        BoxType := BoxType + ABoxType{HasOk,HasCancel,HasHelp};
    END;

    WITH Form^ DO
        DrawBox(ULX,ULY,LRX,LRY,BoxType,FormRecord^.Title,videoformback);
    END;

    FOR Line := 0 TO FormRecord^.MaxLine DO
        PutString(FormRecord^.FLine[Line], Form^.ULX, Form^.ULY + Line + 1, videoformback );
    END;
END ShowBase;





    (* TemplateFieldNo -- Return the number of the field whose attributes
                          define the passed field.  This dereferences
                          repeating fields. *)

PROCEDURE TemplateFieldNo(VAR Form:AFormRecord; FieldNo:AFieldNo):AFieldNo;
VAR
    StartField    : AFieldNo;
    Size          : CARDINAL;
BEGIN
    StartField := Form.Table.StartField;
    IF (FieldNo < StartField) THEN
        RETURN FieldNo;
    ELSE
        Size       := Form.Table.MinorSize;
        RETURN ((FieldNo - StartField) MOD Size) + StartField;
    END;
END TemplateFieldNo;







    (* GetFieldCaptions -- Find the x,y position of the captions for
                          a field.  This does the computations necessary
                          to shield the user from concerns about whether
                          this is a unique field or part of a table.
                          *)

    (*<CAPTIONS

PROCEDURE GetFieldCaptions(VAR Form:AFormRecord;
                               FieldNo:AFieldNo;
                           VAR Captions : ARRAY OF ACaption );
VAR
    Group            : CARDINAL;
    StartField       : AFieldNo;
    MajorSize        : CARDINAL;
    TableIndex,
    TableMajorIndex,
    TableMinorIndex  : CARDINAL;
    i                : CARDINAL;
    XAdjustment      : CARDINAL;
    YAdjustment      : CARDINAL;
    BaseField, Field : AFormField;
BEGIN
    GetFieldAttributes(Form,FieldNo,Index,BaseField,XOff,YOff,Len,Group);


        (* Copy the highlight array. *)

    FOR i := 1 TO HIGH(Captions) DO
        Captions[i] := BaseField.Captions[i];
    END;

        (*  If this field is part of a repeating group, make
            adjustments. *)

    StartField := Form.Table.StartField;
        (* Which row of the table are we on?   Which column? *)

    IF (FieldNo >= StartField) THEN
        MajorSize  := Form.Table.MajorSize;
        TableIndex := (FieldNo - StartField);
        TableMajorIndex := TableIndex DIV MajorSize;
        TableMinorIndex := (TableIndex MOD MajorSize) DIV Form.Table.MinorSize;

        XAdjustment :=
                 (Form.Table.MajorDeltaX * TableMajorIndex ) +
                 (Form.Table.MinorDeltaX * TableMinorIndex );
        YAdjustment :=
                 (Form.Table.MajorDeltaY * TableMajorIndex ) +
                 (Form.Table.MinorDeltaY * TableMinorIndex );
            (* Move the X or Y, but not both, offsets of the
               captions.  The first caption has the X offset moved
               an Y left the same.  Second moves Y and leaves X. *)
        FOR i := 1 TO HIGH(Captions) DO
            IF (ODD(i)) THEN
                INC(Captions[i].X, XAdjustment);
            ELSE
                INC(Captions[i].Y, YAdjustment);
            END;
        END;
    END;
END GetFieldCaptions;
        CAPTIONS>*)








    (* GetFieldAttributes -- Find the x,y position of
                          a field.  This does the computations necessary
                          to shield the user from concerns about whether
                          this is a unique field or part of a table.   If
                          the field is a string or numeric field, the
                          Index is not used. *)

PROCEDURE GetFieldAttributes(VAR Form:AFormRecord;
                                 FieldNo:AFieldNo;
                                 Index:CARDINAL;
                             VAR BaseField : AFormField;
                             VAR XOff : Anxoff;
                             VAR YOff : Ayoff;
                             VAR Len  : CARDINAL;
                             VAR Group : CARDINAL );
VAR
    BaseFieldNo      : AFieldNo;
    StartField       : AFieldNo;
    MajorSize        : CARDINAL;
    TableIndex,
    TableMajorIndex,
    TableMinorIndex  : CARDINAL;
    i                : CARDINAL;
    XAdjustment      : CARDINAL;
    YAdjustment      : CARDINAL;
    Field            : AFormField;
BEGIN
    IF (FieldNo > Form.MaxField) THEN FatalError; END;
    StartField := Form.Table.StartField;
        (* Which row of the table are we on?   Which column? *)
    IF (FieldNo >= StartField) THEN
        MajorSize  := Form.Table.MajorSize;
        TableIndex := (FieldNo - StartField);
        TableMajorIndex := TableIndex DIV MajorSize;
        TableMinorIndex := (TableIndex MOD MajorSize) DIV Form.Table.MinorSize;
    END;

    BaseFieldNo := TemplateFieldNo(Form,FieldNo);
    BaseField   := Form.Fields[BaseFieldNo];
    Group       := BaseField.Group;

        (* Get the position of the field. *)

    IF (BaseField.FFType IN AFieldTypeSet{FormChoice,FormPickSet}) THEN
        IF (Index > BaseField.Count) THEN FatalError; END;
        XOff := BaseField.Choicexoff[Index];
        YOff := BaseField.Choiceyoff[Index];
        Len  := BaseField.ChoiceLen[Index];   (* Length of this choice. *)
    ELSE
        XOff := BaseField.xoff;
        YOff := BaseField.yoff;
        Len  := BaseField.StLen;              (* Length of entire field. *)
    END;

        (*  If this field is part of a repeating group, make
            adjustments. *)

    IF (FieldNo >= StartField) THEN
        INC ( Group, (Form.Table.MajorGroupDelta * TableMajorIndex)
                    +(Form.Table.MinorGroupDelta * TableMinorIndex) );
        XAdjustment :=
                 (Form.Table.MajorDeltaX * TableMajorIndex ) +
                 (Form.Table.MinorDeltaX * TableMinorIndex );
        INC(XOff, XAdjustment);
        YAdjustment :=
                 (Form.Table.MajorDeltaY * TableMajorIndex ) +
                 (Form.Table.MinorDeltaY * TableMinorIndex );
        INC(YOff, YAdjustment);
    END;
END GetFieldAttributes;













    (* SHOWCHOICE -- Show a selected element of a choice or set
                    in the indicated videomode. *)

PROCEDURE ShowChoice(    x          : ascreenx;
                         y          : ascreeny;
                     VAR FormRecord : AFormRecord;
                         FieldNo    : AFieldNo;
                         i          : AChoiceNo;
                         Mode       : avidmode );
VAR
    XOff      : Anxoff;
    YOff      : Ayoff;
    Len       : CARDINAL;
    BaseField : AFormField;
    Group     : CARDINAL;
    s         : ARRAY [ 0.. MaxCapLen ] OF CHAR;
BEGIN
    GetFieldAttributes(FormRecord,FieldNo,i,BaseField,XOff,YOff,Len,Group);
    IF (Mode = videovanish) THEN              (*  Display blanks  *)
        Fill(s," ",Len);
        Mode := videoformback;
    ELSE
        SubStr(FormRecord.FLine[YOff],
               s,
               XOff+1,
               Len);
    END;
    PutString(s, x + XOff, y + YOff, Mode);
END ShowChoice;







PROCEDURE MakeNumericString(VAR FieldValue:AFieldValue;
                                Len:CARDINAL;
                            VAR s : ARRAY OF CHAR);
VAR
    LocalFieldValue : AFieldValue;
BEGIN
    LocalFieldValue := FieldValue;
    LocalFieldValue.RealValue := FLOAT(FieldValue.CardValue);
    MakeRealString(LocalFieldValue,0,MAXCARDINAL,Len,s);
END MakeNumericString;





PROCEDURE MakeRealString(VAR FieldValue: AFieldValue;
                             MinDigits, MaxDigits : CARDINAL;
                             Len       : CARDINAL;
                         VAR s         : ARRAY OF CHAR);
CONST
    MAXTRAILING = 8; (* After that, the numbers round funny. *)
VAR
    i         : CARDINAL;
    Attributes: ASetOfAttributes;
    Dot       : ARRAY [0..1]  OF CHAR;
    s2        : ARRAY [0..39] OF CHAR;
BEGIN
        (* Convert the number to a string representation.  If
           not all will fit, keep as many of the important
           digits as we can. *)
    (* RSC 2/16/88 - Make the field overflow if it doesn't fit! *)

    Attributes := ASetOfAttributes(FieldValue.Private);

    IF (Len = 0) OR
      ((FieldValue.RealValue = Zero) AND
       (BlankIfZero IN Attributes)) THEN
        Fill(s," ",Len);
    ELSIF (MinDigits >= MAXINT) THEN
        FormatAsCurrency( FieldValue.RealValue,
                          DefaultCurrencyFormat,
                          s, Len,
                          FALSE,
                          TRUE,
                          FALSE );
        SetStringAttributes(s,Attributes);
    ELSE
        IF (MaxDigits >= Len) THEN
            MaxDigits := Len - 1; (* Allow for point *)
        END;
        IF (MaxDigits > 0) AND
           (DefaultAmountFormat.IncludeAtLeastOneDigit) THEN
            DEC( MaxDigits ); (* Leading digits. *)
        END;
        IF (MaxDigits >  MAXTRAILING) THEN
            MaxDigits := MAXTRAILING;
        END;
        IF (MaxDigits <  MinDigits) THEN
            MaxDigits := MinDigits;
        END;
        FormatAsAmount( FieldValue.RealValue, DefaultAmountFormat, s2,
                        HIGH(s2), MinDigits, MaxDigits,
                        FALSE );
        TrimRear(  s2 );
        TrimFront( s2 );

        IF (LengthOf(s2) > Len) THEN        (* If too long, but there is a dot, *)
                (* Crush out commas. *)
            i := 1;
            WHILE (i <= LengthOf(s2)) DO
                IF (s2[i] = DefaultAmountFormat.SymbolForSignificance) THEN  (*","*)
                    Remove(s2,i,1);
                ELSE
                    INC(i);
                END;
            END;
            IF (LengthOf(s2) > Len) THEN
                SetString( Dot, DefaultAmountFormat.RadixSymbol );
                i := Search( s2, Dot, 1 );
                IF (i = 0) OR (i > (Len+1)) THEN
                    Fill( s2, DefaultAmountFormat.OverflowSymbol, Len );
                END;
            END;
        END;

        Copy(s2,s);
        Procustes(s,Len);

        SetStringAttributes(s,Attributes);
    END;
END MakeRealString;




PROCEDURE SetStringAttributes( VAR S : ARRAY OF CHAR;
                                   Attributes : ASetOfAttributes );
BEGIN
    IF (JustifyRight IN Attributes) THEN
        RJust(S);
    ELSIF (JustifyLeft IN Attributes) THEN
        LJust(S);
    END;
    IF (ShiftUp IN Attributes) THEN
        Upshift(S);
    END;
END SetStringAttributes;




    (* Convert a string containing a number or numeric expression
       to a real number, or else set ok to FALSE. *)

PROCEDURE StringToReal(     S : ARRAY OF CHAR;
                        VAR R : REAL;
                        VAR ok : BOOLEAN );
VAR
    i : CARDINAL;
BEGIN
    TrimFront(S);
    TrimRear(S);
    IF (LengthOf(S) > 0) THEN
        i := 1;
        EvaluateRealExpression( S,i,R,DefaultAmountFormat,ok);
        ok := NOT ok;     (* EvaluateReal uses ErrorFlag. *)
    ELSE
        R := Zero;
        ok := TRUE;
    END;
END StringToReal;








PROCEDURE MakeStringValue(     Form : AFormControlBlockPointer;
                               FieldValue : AFieldValue;
                               BaseField : AFormField;
                               Len    : CARDINAL;
                           VAR S : ARRAY OF CHAR );
BEGIN
    CASE BaseField.FFType OF
        FormString:
            Copy(FieldValue.CharValue^,S);
            Procustes(S,Len);
            SetStringAttributes(S,BaseField.Attributes);
      | FormCard:
            MakeNumericString(FieldValue,Len,S);
      | FormReal:
            MakeRealString(FieldValue,ORD(BaseField.Digits),MAXCARDINAL,Len,S);
      ELSE FatalError;
    END;

END MakeStringValue;








        (* SetTemporaryValue -- Copy the value of the field into a
                                temporary work area.  This is in,
                                (or pointed to) by Form^. *)


PROCEDURE SetTemporaryValue(     Form     : AFormControlBlockPointer;
                                 Field    : AFieldNo     );
VAR
    FormValue : AFormValuePointer;
    XOff    : Anxoff;
    YOff    : Ayoff;
    Len     : CARDINAL;
    Group   : CARDINAL;
    BaseField : AFormField;
BEGIN
        (* Get a local address space reference to the temporary
           string currently in use.  Any updates to this will be
           updates that everybody uses. *)

    FormValue            := Form^.FormValuePointer;

    GetFieldAttributes(Form^.FormRecordPointer^,Field,0,BaseField,XOff,YOff,Len,Group);


    CASE BaseField.FFType OF
        FormString,FormCard,FormReal:
            MakeStringValue(Form,FormValue^[Field],BaseField,Len,Form^.TemporaryStringValue^);
      | FormChoice:
            Form^.Index := FormValue^[Field].CardValue;
      ELSE FatalError;
    END;
END SetTemporaryValue;







    (* SHOWVALUE -- Show a single field's value.  *)

PROCEDURE ShowThisValue(    Form       : AFormControlBlockPointer;
                            FieldNo:AFieldNo;
                        VAR FieldValue: AFieldValue);
VAR
    i : AChoiceNo;
    Mode : avidmode;
    y : ascreeny;
    x : ascreenx;
    In, Out : avidmode;
    XOff    : Anxoff;
    YOff    : Ayoff;
    Len     : CARDINAL;
    Group   : CARDINAL;
    BaseField : AFormField;
    FormRecord : AFormRecordPointer;
    TemporaryString : ARRAY [0..maxcol] OF CHAR;
BEGIN
        (* If the display is temporarily inhibited, do nothing. *)
    IF (NOT Form^.DisplayEnable) THEN
        RETURN;
    END;

    FormRecord := Form^.FormRecordPointer;

    GetFieldAttributes(FormRecord^,FieldNo,0,BaseField,XOff,YOff,Len,Group);
    y := Form^.ULY + 1;   (* Add one to compensate for box. *)
    x := Form^.ULX;

        (* If the field is hidden, show nothing. *)

    IF (Hidden IN ASetOfAttributes(FieldValue.Private)) THEN
        IF (BaseField.FFType = FormChoice) THEN
            FOR i := 0 TO BaseField.Count DO
                ShowChoice(x,y,FormRecord^,FieldNo,i,videovanish);
            END;
        ELSE
            Fill(TemporaryString," ",Len);
            PutString(TemporaryString, x+XOff, y+YOff, videoformback);
        END;
        RETURN;
    END;


        (* Remove any conflicting help text. *)

    WITH Form^ DO
        IF (y+YOff >= HelpULY) AND (y+YOff <= HelpLRY) THEN
            ClearAnyHelpText(Form);
        END;
    END;



    IF (DisplayOnly IN ASetOfAttributes(FieldValue.Private)) THEN
        In := videoformback;
        Out := videovanish;
    ELSE
        In := videoformdata;
        Out := videoformback;
    END;

    CASE BaseField.FFType OF
        FormString,FormCard,FormReal :
            MakeStringValue(Form,FieldValue,BaseField,Len,TemporaryString);
            PutString(TemporaryString,
                  x+XOff,
                  y+YOff,
                  In);

         |
        FormChoice:
            FOR i := 0 TO BaseField.Count DO
                IF (i = FieldValue.CardValue) THEN
                    Mode := In;
                ELSE
                    Mode := Out;
                END;
                ShowChoice(x,y,FormRecord^,FieldNo,i,Mode)
            END;
            RETURN;
       ELSE FatalError;
    END;


END ShowThisValue;









PROCEDURE DisplayCursor(    Form            : AFormControlBlockPointer;
                        VAR FormValue       : ARRAY OF AFieldValue;
                            FieldNo         : AFieldNo;
                            Index           : CARDINAL;
                            CursorAttribute : ACursorAttribute);
VAR
    FormRecord      : AFormRecordPointer;
    XOff            : Anxoff;
    YOff            : Ayoff;
    Len             : CARDINAL;
    Group           : CARDINAL;
    BaseField       : AFormField;
    Mode,OnMode,
    OffMode,
    RestingMode     : avidmode;
    Cursorx, Endx   : ascreenx;
    Cursory         : ascreeny;
    CursorType      : ACursorType;
    OnString        : ARRAY [0..MaxCapLen] OF CHAR;
BEGIN
    OffMode := videoformdata;
    OnMode := cvideoformdata;
    RestingMode := videorestingcursor;

    FormRecord := Form^.FormRecordPointer;
    GetFieldAttributes(FormRecord^,FieldNo,Index,
                       BaseField,XOff,YOff,Len,Group);
    CASE BaseField.FFType OF
        FormString,
        FormCard,
        FormReal:
                        IF (Hidden IN ASetOfAttributes(FormValue[FieldNo].Private)) THEN
                            Fill(OnString," ",1);
                        ELSE
                            SubStr(Form^.TemporaryStringValue^,
                                   OnString,
                                   Index,1);
                        END;
          |
        FormChoice:
                        IF (Hidden IN ASetOfAttributes(FormValue[FieldNo].Private)) THEN
                            Fill(OnString," ",Len);
                        ELSE
                            SubStr(FormRecord^.FLine[YOff],
                                   OnString,
                                   XOff+1,
                                   Len );
                        END;
                        IF (Index <> FormValue[FieldNo].CardValue) THEN
                            OffMode := videoformback;
                            OnMode := cvideoformback;
                        ELSE
                            RestingMode := cvideoformdata;
                        END;
        ELSE FatalError;
    END;

    CASE CursorAttribute OF
        CursorOn      : Mode := OnMode;
      | CursorOff     : Mode := OffMode;
      | CursorResting : Mode := RestingMode;
        ELSE HALT;
    END;

        (*  Display a cursor.  However, if on a text field, avoid
               displaying one if there is also a mouse cursor, since
               the two can be confusing.
        *) 

    FindFieldXY(AForm(Form),FieldNo,Index,Cursorx,Cursory,Endx);

    IF (BaseField.FFType = FormChoice) 
        OR (NOT MousePresent()) 
        OR (CursorAttribute <> CursorOn) THEN
            PutString(OnString,Cursorx,Cursory,Mode);
    END;

    IF (CursorAttribute = CursorOn) THEN
        IF (Form^.InsertMode) THEN
            CursorType := BlockCursor;
        ELSE
            CursorType := UnderlineCursor;
        END;
    ELSE
        CursorType := NoCursor;
    END;


    GotoXY(Cursorx,Cursory);
    SetCursorType(CursorType);

END DisplayCursor;









PROCEDURE GetPromptCoordinates(     Form  : AFormControlBlockPointer;
                                VAR PULX  : ascreenx;
                                VAR PULY  : ascreeny;
                                VAR PLRX  : ascreenx;
                                VAR PLRY  : ascreeny   );
BEGIN

    WITH Form^.FormRecordPointer^ DO
        PULX := PromptULX;
        PULY := PromptULY;
        PLRX := PromptLRX;
        PLRY := PromptLRY;
    END;
END GetPromptCoordinates;







    (* DisplayFieldPrompt -- Display the prompt text in the
                             prompt area of the form. *)

PROCEDURE DisplayFieldPrompt(     Form      : AFormControlBlockPointer;
                                  Type      : AFieldType;
                                  FieldNo   : AFieldNo;
                                  Highlight : BOOLEAN    );
VAR
    ULX : ascreenx;
    ULY : ascreeny;
    LRX : ascreenx;
    LRY, LastY : ascreeny;
    Width            : CARDINAL;
    EffectiveFieldNo : AFieldNo;
    S                : ARRAY [0..255] OF CHAR;
    Mode             : avidmode; 
BEGIN

    IF (Form^.FormRecordPointer^.PromptType <> NoPrompts) THEN
        IF (Highlight) THEN
             Mode := videobright;
        ELSE
             Mode := videomessage;
        END;      

        GetPromptCoordinates(Form,ULX,ULY,LRX,LRY);

            (* General text for all forms. *)
        GetMessage(ModuleNumber+1, S);
        PourText(S,videocaption,ULX,ULY+2,LRX,LRY,LastY);

            (* Get some help text based on the type of field. *)
        GetMessage(ModuleNumber+2+ORD(Type), S);
        PourText(S,videocaption,ULX,ULY+1,LRX,LRY,LastY);

            (* Get specific text for this field. *)

        EffectiveFieldNo := TemplateFieldNo(Form^.FormRecordPointer^,FieldNo);

        Form^.QueryPrompt( Form^.FormRecordPointer^.PhrasesStart + EffectiveFieldNo,
                           S );
        PourText(S,Mode,ULX,ULY,LRX,LRY,LastY);
    END;

END DisplayFieldPrompt;








PROCEDURE OkToEscapeForm( Form : AFormControlBlockPointer ) : BOOLEAN;
VAR
    s : ARRAY [0..255] OF CHAR;
BEGIN

    IF (Form^.ChangesMadeToForm) THEN
        GetMessage( ModuleNumber + 12, s );
        RETURN (NoYes(s));
    END;

    RETURN TRUE;

END OkToEscapeForm;








    (*------------------ Start of Module KeyboardInterface ---------- *)
MODULE KeyboardInterface;

    (* This module allows us to get codes from the keyboard, intermediated
       by a stack of codes that we may generate internally. *)

IMPORT Events,
       AnEvent, AnEventType,
       ACode, ASetOfCodes, AFormControlBlockPointer,
       UpshiftTable, ConvertedCharacter, Burp;

EXPORT GetNextEvent, PushCode, PopEvent;


PROCEDURE GetNextEvent(     Form : AFormControlBlockPointer;
                        VAR CodeSet:ASetOfCodes;
                        VAR Event  :AnEvent );
CONST
    BitsPerBitSet = 16;
VAR
    TheCode, NewCode : CARDINAL;
    Good : BOOLEAN;
BEGIN
        (* Pushing things is under the control of the forms module,
           so we do not transform any code that has been pushed.  This
           allows, perhaps, a CheckProc to turn an illegal Code into
           one that happens anyway. *)

    IF (PopEvent(Form,Event)) THEN
        RETURN;
    END; 
    
        (* Get a real event, but only allow keyboard events whose codes
           are in the code set. *)

    LOOP
        Events.GetNextEvent(Event);

            (* Events not from the keyboard are returned without
               translation. *)
    
        IF (Event.EventType <> KeyboardEvent) THEN
            EXIT;
        END;

            (*  Check if the code is in the set of ok codes.
                If not, convert lower case alphabetics to upper
                case and try again.
            *)
    
        LOOP
            TheCode := Event.EventCode;
            Good := (TheCode MOD BitsPerBitSet) IN CodeSet[TheCode DIV BitsPerBitSet];
            IF (Good) OR (TheCode > 255) THEN
                EXIT;   (* Exit if good, or outside the character range. *)
            END;
            NewCode := ORD(ConvertedCharacter( CHR(TheCode), UpshiftTable ));
            IF (NewCode <> TheCode) THEN
                Event.EventCode := NewCode;
            ELSE
                EXIT;
            END;
        END;
    
        IF (Good) THEN  (* The code is now in the CodeSet. *)
            EXIT;
        END;
    
        Burp;
    END;
    
END GetNextEvent;




PROCEDURE PushCode(    Form : AFormControlBlockPointer;
                       Code : ACode );
BEGIN
        (* Code 0 is a NOP. *)
    IF (Code <> 0) THEN
        (*+2<
        IF (Form^.KeyStackIndex >= StackSize) THEN HALT; END;
        +2>*)

        WITH Form^ DO
            KeyStack[KeyStackIndex] := Code;
            INC(KeyStackIndex);
        END;
    END;
END PushCode;


PROCEDURE PopEvent(     Form : AFormControlBlockPointer;
                    VAR Event  :AnEvent ) : BOOLEAN;
BEGIN
    WITH Form^ DO
        IF (KeyStackIndex = 0) THEN
            RETURN FALSE;
        ELSE
            DEC(KeyStackIndex);
            Event.EventCode := KeyStack[KeyStackIndex];
            Event.EventType := KeyboardEvent;
            RETURN TRUE;
        END;
    END;
END PopEvent;


BEGIN
END KeyboardInterface;
    (*------------------ End of Module KeyboardInterface ---------- *)




BEGIN
END FormUtil.
