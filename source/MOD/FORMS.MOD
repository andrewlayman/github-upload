IMPLEMENTATION MODULE Forms;

    (* MODIFICATION HISTORY:
       10-Jan-90 AJL -Clicking on a field positions the cursor exactly.
                     -Up is only honored if at the same region as the down.
        6-Oct-90 AJL -Allow the AlternateEraseKey (Ctrl-End) to erase to eol. 
                     -Add a help button to forms.
       26-Dec-90 AJL -Modified DoThePaste to take a parameter controlling the
                      maximum index value to return so that pasting a string
                      that would extend past the end of the field doesn't
                      crash the program.
        8-Jan-90 AJL -Don't attempt to locate the screen position of protected
                      fields when a mouse key is pressed.  It may not really
                      be a valid field (for example, the cross-tab report
                      form deactivates some fields; sets their internals to
                      a way that doesn't give them any screen position; and
                      protects them.
       24-Jul-91 EGK -In MoveOver, the variable "LastCodeTyped" was never
                      reset by mouse events.  This was causing old codes to
                      be passed to checkprocs.  Here I set LastCodeTyped to
                      0 before calling ProcessMouseEvent.  (See Eve bug
                      no. 4808 for one manifestation of this.)
                     -LocateFieldAndIndex had an "off by one" error which
                      was incorrectly matching the first character past the
                      end of a string field.
        5-Aug-91 PFG -SetFieldProtection was turning DisplayOnly off even
                      if a field was marked as hidden.  Now we disallow that.
       14-Aug-91 PFG -Well...my last change turned out not to be a good idea,
                      so I backed it out and just handled it in the forms 
                      where it was a problem.
       24-Sep-91 AJL -Replaced a Not YetImplemented with ErrorPhrase.
                     -Replace local WarnOf procedure with ErrorPhrase.
    *)


    FROM Boxes   IMPORT ABoxAttribute, ABoxType, AMouseClickPoint,
                        CorrelateMousePoint;

    FROM Codes      IMPORT SetCodeBits, ACode, ASetOfCodes, MaxCode,
                           EmptyCodeSet;

    FROM CutPaste   IMPORT
        (* PROC *)      CopyToPasteBuffer, PasteBuffer;

    FROM Events     IMPORT 
        (* TYPE *)      AnEvent, AnEventType;

    FROM Kbio       IMPORT ascreenx, ascreeny, maxrow, maxcol, avidmode,
                           PutString, GetCode, ACursorType, SetCursorType,
                           GotoXY, PourText, KeyPress;

    FROM Dialog     IMPORT Error, FatalError, Burp, ErrorPhrase;

    FROM LStrings   IMPORT SubStr, Procustes, CtoS, StoC, LengthOf,
                           Copy, ConcatLS, Insert, Remove, Fill,
                           LJust, RJust, Overlay, LStringToTString,
                           TStringToLString, Compare, TrimRear, Upshift,
                           SetString, ConcatS, TrimFront, Search,
                           InsertWithOverflow, SetLengthOf;

    FROM Keys       IMPORT Fwrd, Reverse, DoIt, Tab, RTab,
                           Up, Down, RollLeft, RollRight,
                           ExitKey, InsertKey, DeleteKey, EditKey,
                           HomeKey, EndKey, HelpKey,
                           BackSpace, UndoKey, EraseToEOLKey, EraseKey,
                           CancelKey, GotoKey, ReportsKey,
                           CopyToPasteKey, PasteKey,
                           MouseDown, MouseStillDown, MouseUp, MouseDouble,
                           AlternateEraseKey;

    FROM FormCon    IMPORT MaxChoice, AFieldNo,
                           AChoiceNo, AFieldType;

    FROM FormRec    IMPORT Anxoff, Ayoff, MaxFLines,
                           AFormField, AFormRecord, FLineLen, MaxCapLen,
                           AFormRecordPointer, APromptType,
                           AnAttribute, ASetOfAttributes,
                           ACaption, MaxCaptionsPerField;

    FROM FormRead   IMPORT GetFormRecordByNumber;

    FROM FormHand   IMPORT AFormHandle, GetAddressFromFormHandle,
                           AttachHandleToRecord, DiscardFormHandle;


    FROM Mouse          IMPORT
        (* PROC *)          MousePresent, CancelDoubleClick;

    FROM Rugs              IMPORT ARug, GetRug, PutRug;

    FROM SYSTEM            IMPORT ADR, TSIZE, ADDRESS;

    FROM Notices IMPORT
        (* TYPE *)            AnOccasion, AStep,
        (* PROC *)            Permission, SendNotices, RegisterForNotices;

    FROM Space   IMPORT ALLOCATE, DEALLOCATE, StackSpaceLeft;

    FROM MsgFile IMPORT
        (* CONST *)     Forms,
        (* PROC *)      GetMessage, DisplayMessage, ConcatMessage,
                        GetMessageForClass;

    FROM Helper  IMPORT AScreenAction, AHelpBox, OpenHelpBox;
                        

    FROM Layout  IMPORT GanttWStart, GanttWEnd, MaxColumn, MaxRow;

    FROM Fits    IMPORT Without;

    FROM RealFormat IMPORT
        (* VARS  *)        DefaultAmountFormat;

    FROM Space   IMPORT
        (* PROC *)      Available;

    FROM Words   IMPORT
        (* PROC *)      FindNextWord, FindPriorWord, StartOfWord, EndOfWord;


    FROM FormUtil IMPORT
        (* TYPE *)      AFormControlBlock, AFormControlBlockPointer,
                        AnOpenMode, AFormValuePointer, AFieldTypeSet,
        (* PROC *)      GetNextEvent, PushCode, PopEvent,
                        ClearAnyHelpText,ShowBase,TemplateFieldNo,
                        GetFieldAttributes,ShowChoice,MakeNumericString,
                        MakeRealString,
                        StringToReal,MakeStringValue,SetTemporaryValue,
                        ShowThisValue,DisplayCursor,OkToEscapeForm,
                        GetPromptCoordinates,DisplayFieldPrompt;


CONST
    MAXINT        = 32767;
    MAXCARDINAL   = 65535;
    Zero          = 0.0;
    ModuleNumber  = 2200;   (* For MsgFile module reference. *)
    StackSize     = 10;     (* Maximum codes that can be pushed. *)
    WordSeparator = " ";

    FormHelpPrefix        = 342C;
    FormExtremeHelpPrefix = 345C;   (* Alt-229 *)

    MemoryWarningMsg        = ModuleNumber+13;
    StackWarningMsg         = ModuleNumber+20;

       (* Region ID's *)

    OnHelpText  = OnVScrollDown;      (* Re-use the id number to simplify typing. *)

TYPE
    AForm                    = AFormControlBlockPointer;

VAR
    GuidanceMode             : BOOLEAN;

        (* This contextual information should work even when forms are
           reentered, because this variable is used on a double click,
           and double clicks are preceeded by single clicks.  A single
           click is what sets up this variable.
           RSC 15-Nov-89.
        *)
    SuggestedMouseDoubleKey    : ACode;
    OldHighlight,
    HighlightPrompt            : BOOLEAN;








    (* SHOWVALUE -- Show a single field's value.  This also adjusts the
                    fields internal representation in some cases. *)

PROCEDURE ShowValue(     Form      : AForm;
                         FieldNo   : AFieldNo;
                     VAR FormValue : ARRAY OF AFieldValue);
BEGIN
    ShowThisValue(Form,FieldNo,FormValue[FieldNo]);

        (* If the field that we have just displayed is the current
           cursor field, then update the temporary string value.
           This can happen if a user's CheckProc updates the string
           value and then calls us to display the new value. *)

    IF (FieldNo = Form^.Field) THEN
        SetTemporaryValue(Form,FieldNo);
    END;
END ShowValue;





PROCEDURE HighlightField(    Form      : AForm;
                         VAR FormValue : ARRAY OF AFieldValue;
                             FieldNo   : AFieldNo;
                             Attribute  : ACursorAttribute );
VAR
    i,j             : CARDINAL;
BEGIN
    i := MinIndex(Form,FieldNo);
    j := MaxIndex(Form,FieldNo);
    WHILE (i <= j) DO
        DisplayCursor(Form,FormValue,FieldNo,i,Attribute);
        INC(i);
    END;
END HighlightField;






PROCEDURE MaxIndex(    Form : AFormControlBlockPointer; FieldNo:AFieldNo):CARDINAL;
BEGIN
    FieldNo := TemplateFieldNo(Form^.FormRecordPointer^,FieldNo);
    WITH Form^.FormRecordPointer^.Fields[FieldNo] DO
        IF (FFType IN AFieldTypeSet{FormChoice,FormPickSet}) THEN
            RETURN Count
        ELSE
            RETURN StLen;
        END;
    END;
END MaxIndex;



PROCEDURE MinIndex(Form : AFormControlBlockPointer; FieldNo:AFieldNo):CARDINAL;
BEGIN
    FieldNo := TemplateFieldNo(Form^.FormRecordPointer^,FieldNo);
    IF (Form^.FormRecordPointer^.Fields[FieldNo].FFType IN
           AFieldTypeSet{FormChoice,FormPickSet}) THEN
        RETURN 0;
    ELSE
        RETURN 1;
    END;
END MinIndex;




    (* FindFieldXY -- Given a Field number and an index in that Field,
               this returns the starting x,y coordinates and
               the ending x coordinate for that position on the
               Form. *)

PROCEDURE FindFieldXY(    Form    : AFormControlBlockPointer;
                          Field   : AFieldNo;
                          Index   : CARDINAL;
                      VAR Cursorx:ascreenx;
                      VAR Cursory: ascreeny;
                      VAR Endx:ascreenx );
VAR
    XOff    : Anxoff;
    YOff    : Ayoff;
    Len     : CARDINAL;
    Group   : CARDINAL;
    BaseField : AFormField;
BEGIN
    GetFieldAttributes(Form^.FormRecordPointer^,Field,Index,BaseField,XOff,YOff,Len,Group);
    Cursorx := Form^.ULX + XOff;
    Cursory := Form^.ULY + YOff + 1;   (* Add one to compensate for box. *)
        (*  If this is a string or numeric field, then pick out the
            single character at position Index within the string.  If
            a set or choice field, pick out the entire choice[Index]
            item. *)
    IF (BaseField.FFType IN AFieldTypeSet{FormChoice,FormPickSet}) THEN
        Endx := Cursorx + Len - 1;
    ELSE
            (* Force within range answers for out-of-range input *)
        IF (Index = 0) THEN
            Index := 1;
        ELSIF (Index > Len) THEN
            Index := Len;
        END;
            (* Compute location. *)
        INC(Cursorx,Index-1);
        Endx := Cursorx;
    END;
END FindFieldXY;












PROCEDURE DoThePaste( VAR T        : ARRAY OF CHAR;
                          MaxIndex : CARDINAL;
                      VAR Index    : CARDINAL );
VAR
    MaxSize : CARDINAL;
    S, S2   : ARRAY [0..255] OF CHAR;
BEGIN
    PasteBuffer( S );     (* Pull the source string from the paste buffer. *)

    LJust(S);             (* Trim the blanks from it. *)
    TrimRear(S);

    MaxSize := LengthOf(T);


    SetLengthOf(S2,0);

        (* If we are at the start of the end of a word, insert an extra
           space so that the cursor remains at a word boundary.
        *)

    IF (StartOfWord(T,Index," ")) THEN
        Fill(S2," ",1);
    ELSIF (Index > 1) AND (EndOfWord(T,Index-1," ")) THEN
        Copy(S,S2);
        Fill(S," ",1);
    END;


    InsertWithOverflow(T,S,Index,MaxSize);
    InsertWithOverflow(T,S2,Index,MaxSize);

    IF (Index > MaxIndex) THEN
        Index := MaxIndex;
    END;

END DoThePaste;



    (*$R-*) (*$T-*)  (* The compiler cannot compile this long procedure
                        unless these range checks are disabled. (1.1).  *)


    (* MoveOver: Procedures for moving the cursor over a form and
                 maybe changing its values. *)

PROCEDURE MoveOver( Form : AForm ) : ACode;

CONST
    Space = 32;
VAR
    i, C, C2,
    CurIndex           : CARDINAL;
    Len                : CARDINAL;
    Group              : CARDINAL;
    LastCodeTyped      : CARDINAL;
    Event              : AnEvent;


       (* These fields are copies of fields in Form^, and
          are here so that they can be referred to without an extra
          indirection. *)

    FormRecord               : AFormRecordPointer;
    TemporaryStringValue     : AStringValuePointer;
    FormValue                : AFormValuePointer;
    CheckProc                : ACheckProc;
    CheckCodeSet             : ASetOfCodes;

    XOff               : Anxoff;
    YOff               : Ayoff;
    Y                  : ascreeny;
    CurField, OldField : AFieldNo;
    CCodeSet, RCodeSet : ASetOfCodes;
    OldMode, Mode      : avidmode;
    BaseField          : AFormField;
    CurrentAttributes  : ASetOfAttributes;

        (* We keep the original value of each field here when we
           are on the field.  It is not actually necessary to keep
           the OriginalFieldValue since we do not change the
           FormValue array until the field changes are approved,
           but it seems simpler and safer to keep this copy.  We
           do need the original string, though, definitely. *)

    OriginalFieldValue       : AFieldValue;
    OriginalFieldValueString : ARRAY [0..maxcol] OF CHAR;

    s1                 : ARRAY [0..1] OF CHAR;
    s10                : ARRAY [0..11] OF CHAR;

    Captions           : ARRAY [0..0] OF ACaption;

    OK                 : BOOLEAN;
    Finished           : BOOLEAN;
    FieldType          : AFieldType;
    DownRegion                 : AMouseClickPoint;  
    DownField, DownIndex       : CARDINAL;



        (* Next -- Find the next unprotected field. *)


    PROCEDURE Next(VAR Field:AFieldNo; VAR Index:CARDINAL);
    VAR
        f2 : AFieldNo;
    BEGIN
        f2 := Field;
        REPEAT
            Field := (Field + 1) MOD (FormRecord^.MaxField+1);
            IF (NOT FieldIsProtected(Form,Field,FormValue^)) THEN
                f2 := Field
            END
        UNTIL (Field = f2);
        Index := MinIndex(Form,Field);
    END Next;


        (* Prior -- Find the preceding unprotected field. *)


    PROCEDURE Prior(VAR Field:AFieldNo; VAR Index:CARDINAL);
    VAR
        f2 : AFieldNo;
    BEGIN
        f2 := Field;
        REPEAT
            IF (Field = 0) THEN
                Field := FormRecord^.MaxField
            ELSE
                DEC(Field)
            END;
            IF (NOT FieldIsProtected(Form,Field,FormValue^)) THEN
                f2 := Field
            END;
        UNTIL (Field = f2);
        Index := MinIndex(Form,Field);
    END Prior;



        (* BLANKREST -- Set all the characters in the field after the
                        one just typed to be blank. *)

    PROCEDURE BlankRest(FieldNo:AFieldNo;Index:CARDINAL);
    VAR
        XOff    : Anxoff;
        YOff    : Ayoff;
        Len     : CARDINAL;
        Group   : CARDINAL;
        BaseField : AFormField;
    BEGIN
        GetFieldAttributes(FormRecord^,FieldNo,0,BaseField,XOff,YOff,Len,Group);
        INC(Index);
        WHILE (Index <= Len) DO
            TemporaryStringValue^[Index] := " ";
            INC(Index);
        END;
        PutString(TemporaryStringValue^,
                  Form^.ULX+XOff,
                  Form^.ULY+YOff+1,   (* Add one to compensate for box. *)
                  videoformdata);
    END BlankRest;



    PROCEDURE FieldChecksOut(     FieldNo : AFieldNo;
                                  Reason  : ACheckReason;
                              VAR Code    : CARDINAL;
                                  Highlight: BOOLEAN ): BOOLEAN;
    VAR
        OK : BOOLEAN;
    BEGIN
        Code := LastCodeTyped;   (* Pass to the checkproc the last code processed. *)

        IF (Highlight) THEN
            HighlightField(Form,FormValue^,FieldNo,CursorResting);
        END;

            (* Save any local data that must be preserved while we
               call CheckProc. *)
        SaveCurrentData;
        OK := CheckProc(Form,FieldNo,FormValue^,Reason,Code);


        IF (Highlight) THEN
            HighlightField(Form,FormValue^,FieldNo,CursorOff);
        END;

        RETURN OK;
    END FieldChecksOut;

        (* AnnounceCaptions -- Fields may have one or more caption
                               areas on the background text of the
                               form.  We can turn these captions on
                               or off. *)

        (*<CAPTIONS
    PROCEDURE AnnounceCaptions(     Attributes : ASetOfAttributes;
                                VAR Captions   : ARRAY OF ACaption;
                                    Mode       : avidmode   );
    VAR
        XOFF : ascreenx;
        YOFF : ascreeny;
        Length : CARDINAL;
        i      : CARDINAL;
        S      : ARRAY [0..maxcol+1] OF CHAR;
    BEGIN
        IF (ShowCaptions IN Attributes) THEN
            FOR i := 1 TO HIGH(Captions) DO
                XOFF := ORD(Captions[i].X);
                YOFF := ORD(Captions[i].Y);
                Length := ORD(Captions[i].Len);
                IF (Length > 0) THEN
                    SubStr(FormRecord^.FLine[YOFF], S, XOFF+1, Length);
                    PutString(S, Form^.ULX + XOFF, Form^.ULY + YOFF+1, Mode);
                END;
            END;
        END;
    END AnnounceCaptions;
        CAPTIONS>*)




    PROCEDURE Entering(Field:AFieldNo; VAR Index :CARDINAL );
    VAR
        XOff      : Anxoff;
        YOff      : Ayoff;
        Len       : CARDINAL;
        Group     : CARDINAL;
        BaseField : AFormField;
        Code      : CARDINAL;
        Highlight : BOOLEAN;
        OK        : BOOLEAN;
        Type      : AFieldType;

         (*<CAPTIONS
        Captions  : ARRAY [0..MaxCaptionsPerField] OF ACaption;
         CAPTIONS>*)
    BEGIN
        HighlightPrompt := FALSE;     (* Turn off any prompt highlighting. *)

        Form^.FieldIsFull := FALSE;   (* No text overrun yet. *)

        GetFieldAttributes(FormRecord^,Field,0,BaseField,XOff,YOff,Len,Group);


        Type := BaseField.FFType;


            (* Get, for convenience, the current fields attribute set. *)

        CurrentAttributes := ASetOfAttributes(FormValue^[Field].Private);

            (* If we have somehow entered a protected field, say via Goto,
               then disallow changes.  Otherwise, allow them. *)

            (*  Set the internal copy of the field's string value
                to be a reflection of the outside view of it.
                We need to do this before the field can be
                properly displayed.  This particular setting of it
                is necessary because we may highlight the field on
                entry.
                *)

        SetTemporaryValue(Form,Field);

            (* Enhance the caption text of the background. *)

         (*<CAPTIONS
        GetFieldCaptions(FormRecord^,Field,Captions);
        AnnounceCaptions(CurrentAttributes,Captions,cvideoformback);
         CAPTIONS>*)

            (* Display any prompt text.   Actually, set a flag that will
               cause the prompt to be displayed when there is free time. *)

        Form^.PromptPending := TRUE;

            (* If highlighting is wanted, do so.   We will highlight
               the field during the CheckProc call. *)

        Highlight := (HighlightOnEntry IN CurrentAttributes);

            (*  Check the field, and give the CheckProc a chance to
                do any fancy things it wants to.  As a particularly
                tricky aside, if the check proc return is FALSE, the
                code returned will be pushed onto a keyboard input
                list.
                *)

        OK := FieldChecksOut(Field,CheckFieldEntry,Code,Highlight);

        PushCode(Form,Code);  (* Push any code returned.  This will be interpreted unless 0. *)

            (*  Set the internal copy of the field's string value
                to be a reflection of the outside view of it.
                Since the CheckProc may have changed the field value,
                set our internal stuff. *)

        SetTemporaryValue(Form,Field);
        CurIndex := Form^.Index;


            (* Make a record of the original value of the field.
               We always record the exact FieldValue record.  For
               fields that are displayed as strings, we also record
               the original display value. *)

        OriginalFieldValue := FormValue^[Field];

        IF (Type IN AFieldTypeSet{FormCard,FormReal,FormString}) THEN
            SubStr(TemporaryStringValue^,OriginalFieldValueString,1,HIGH(OriginalFieldValueString));
        END;

        Form^.InsertMode := FALSE;

            (* Display any requisite help. *)

        IF (GuidanceMode) AND (NOT FieldIsProtected(Form,Field,FormValue^)) THEN
            ShowHelp(YOff,FALSE);
        END;

    END Entering;


        (* ResetCursor -- Set the cursor to its starting place
                          after an error.   Not applicable to
                          Choice fields. *)


    PROCEDURE ResetCursor(     Field : AFieldNo;
                           VAR Index : CARDINAL;
                               Type  : AFieldType;
                               Dammit : BOOLEAN );
    BEGIN
             (* Special hook: certain fields require the cursor
                to be repositioned on error. *)
         IF ( Dammit OR  (ResetCursorOnError IN CurrentAttributes)  )
            AND
            (Type <> FormChoice) THEN
             Index := MinIndex(Form,Field);
         END;
    END ResetCursor;



        (* UpdateOriginalDataToFormValue -- Restore the field to
                                            its original condition in
                                            the FormValue array. *)


    PROCEDURE UpdateOriginalDataToFormValue( Field : AFieldNo;
                                             BaseField : AFormField );
    BEGIN
        IF (BaseField.FFType = FormString) THEN
            SubStr(OriginalFieldValueString,FormValue^[Field].CharValue^,1,Len);
        ELSE
            FormValue^[Field] := OriginalFieldValue;
        END;
    END UpdateOriginalDataToFormValue;


        (* UpdateTemporaryDataToFormValue -- Move the field's contents
                                             from the temporary working
                                             copy to the FormValue array. *)


    PROCEDURE UpdateTemporaryDataToFormValue(     Field     : AFieldNo;
                                              VAR FieldValue : AFieldValue;
                                                  BaseField : AFormField ) : BOOLEAN;
    VAR
        R       : REAL;
        j       : CARDINAL;
        ok      : BOOLEAN;
    BEGIN
        ok := TRUE;
            (* Update the FormValue. *)

        CASE BaseField.FFType OF
             FormString:
                    SubStr(TemporaryStringValue^,FieldValue.CharValue^,1,Len);
            | FormCard:
                    j := 1;
                    StringToReal(TemporaryStringValue^,R,ok);
                    IF (ok) THEN
                        FieldValue.CardValue := TRUNC(R);
                        MakeNumericString(FieldValue,Len,TemporaryStringValue^);
                    END;
                      ShowThisValue(Form,Field,FieldValue);
            | FormReal:
                    j := 1;
                    StringToReal(TemporaryStringValue^,R,ok);
                    IF (ok) THEN
                        FieldValue.RealValue := R;
                        MakeRealString(FieldValue,ORD(BaseField.Digits),MAXCARDINAL,Len,TemporaryStringValue^);
                        ShowThisValue(Form,Field,FieldValue);
                    END;
            | FormChoice:
                    FieldValue.CardValue := Form^.Index; (* 5/26/89 WKH *)
           ELSE FatalError;
        END;

        IF (NOT ok) THEN
            DisplayMessage(ModuleNumber+17);
            Burp();
        END;

        RETURN ok;
    END UpdateTemporaryDataToFormValue;







            (* ShowTemporaryValue -- Show the value stored in the
                                     temporary copies. *)


    PROCEDURE ShowTemporaryValue(     FieldNo : AFieldNo;
                                      BaseField : AFormField );
    VAR
        LocalFieldValue : AFieldValue;
        LocalString     : AStringValue;
    BEGIN
        IF (BaseField.FFType = FormString) THEN
            LocalFieldValue.CharValue := ADR(LocalString);          (* 11/11/88 EGK *)
        END;
        LocalFieldValue.Private := FormValue^[FieldNo].Private;    (* Display attributes. *)
        IF UpdateTemporaryDataToFormValue( FieldNo,LocalFieldValue,BaseField) THEN
            ShowThisValue(Form,FieldNo,LocalFieldValue);
        END;
    END ShowTemporaryValue;




    PROCEDURE ConditionalCheckout(    Field : AFieldNo;
                                      Index : CARDINAL;
                                      Type  : AFieldType;
                                      Reason : ACheckReason;
                                  VAR Code   : CARDINAL;
                                      Highlight : BOOLEAN
                                 ) : BOOLEAN;
    BEGIN
        IF (NOT UpdateTemporaryDataToFormValue( Field, FormValue^[Field], BaseField )) THEN
            RETURN FALSE;
        END;

            (* Notify the client that the field value has changed. *)

        IF (FieldChecksOut(Field,Reason,Code,Highlight)) THEN
            RETURN TRUE;
        ELSE
                (* Ooops . . . put back any changes to the FormValue array. *)
                (* We do not restore the value for Choice fields since
                   every change to the choice field is immediately reported
                   to the CheckProc w/ CheckFieldChange, and the FormValue
                   is kept continuously updated to equal CurIndex. *)
            IF (Type <> FormChoice) THEN
                UpdateOriginalDataToFormValue(Field,BaseField);
            END;
            ShowTemporaryValue(Field,BaseField);
            ResetCursor( Field, Index, Type, FALSE );   (* No effect on choice fields. *)
            RETURN FALSE;
       END;

    END ConditionalCheckout;




        (*  Leaving -- Clean up in preparation to leave a field.  Since
                       it is possible that a call to CheckProc will
                       prevent the exit from the field, we cannot
                       do anything that is irreversable.
                       Returns TRUE iff leaving is OK.
                       *)


    PROCEDURE Leaving(Field:AFieldNo; VAR Index:CARDINAL):BOOLEAN;
    VAR
        Code      : CARDINAL;
        Len       : CARDINAL;
        Group     : CARDINAL;
        BaseField : AFormField;
        Type      : AFieldType;
        XOff      : Anxoff;
        YOff      : Ayoff;
        Changed,
        Changed2  : BOOLEAN;
        OK        : BOOLEAN;
         (*<CAPTIONS
        Captions  : ARRAY [0..MaxCaptionsPerField] OF ACaption;
         CAPTIONS>*)

        (* RSC 10/25/88 *)

        PROCEDURE DidItChange() : BOOLEAN;
        VAR
            LocalString : ARRAY [0..81] OF CHAR;
        BEGIN
            MakeStringValue(Form,FormValue^[Field],BaseField,Len,LocalString);
            RETURN ( Compare(TemporaryStringValue^,LocalString) <> 0 );
        END DidItChange;


    BEGIN
        GetFieldAttributes(FormRecord^,Field,0,BaseField,XOff,YOff,Len,Group);
        Type := BaseField.FFType;


            (* Detect if the field has changed value. *)


        IF (Type IN AFieldTypeSet{FormString,FormCard,FormReal}) THEN
                (* Compare the string representations to see if the
                   user changed anything. *)
            Changed := ( Compare(TemporaryStringValue^,OriginalFieldValueString) <> 0 );
                (* Did a CheckProc change anything?  Does our internal copy
                   differ from the FormValue array? *)
            Changed := Changed OR (DidItChange()); (* RSC 10/25/88 *)
        ELSE  (* FormChoice *)
                (* Compare the index value. *)
            Changed := (Index <> OriginalFieldValue.CardValue) OR
                       (Index <> FormValue^[Field].CardValue);
        END;


            (* If the field has changed value, update the FormValue and
               also notify the client. *)


        IF (Changed) THEN

                (* Notify the client that the field value has changed. *)

            IF (NOT ConditionalCheckout(Field,Index,Type,
                                        CheckFieldChange,Code,FALSE)) THEN
                IF (Code >= 2000H) THEN
                    (* PushCode(Form,Code); *)
                END;
                RETURN FALSE;
            END;
        END;


            (* Notify client that we intend to leave the field. *)


            (* Notify the client that we are leaving the field. *)

        OK := FieldChecksOut(Field,CheckFieldExit,Code,FALSE);

            (* Allow the client to force a key to be processed. *)

        PushCode(Form,Code);

        IF (NOT OK) THEN
                (* Ooops . . . put back any changes to the FormValue array.
                   Since the user does not approve these changes, we cannot
                   leave them in his data array.   The most canny problem
                   this could cause would be if the user editted the field
                   back to the original value.  Then, we would, by comparing
                   the temporary to the original value, detect no change.
                   That would allow us to exit the field without moving
                   the temporary value into the (changed) FormValue array. *)
                (* We do not restore the value for Choice fields since
                   every change to the choice field is immediately reported
                   to the CheckProc w/ CheckFieldChange, and the FormValue
                   is kept continuously updated to equal CurIndex. *)
            IF (Type <> FormChoice) THEN
                UpdateOriginalDataToFormValue(Field,BaseField);
            END;
            ResetCursor( Field, Index, Type, FALSE );   (* No effect on choice fields. *)
            ShowTemporaryValue(Field,BaseField);
        END;

            (* Clear any help text still showing. *)
            (* Restore the caption text of the background. *)

        IF (OK) THEN
            ClearAnyHelpText(Form);
            (*<CAPTIONS
            GetFieldCaptions(FormRecord^,Field,Captions);
            AnnounceCaptions(CurrentAttributes,Captions,videoformback);
            CAPTIONS>*)
            IF (Changed) THEN
                SetFormChange( Form ); (* Form changed and was allowed.  RSC 10/16/87 *)
            END;
        END;

        RETURN OK;

    END Leaving;







        (* FieldFwd -- Move to the next (forward direction) field
                       and index from the current ones. *)


    PROCEDURE FieldFwd( VAR Field : AFieldNo;   VAR Index : CARDINAL);
    BEGIN
        IF (Leaving(Field,Index)) THEN
            Next(Field,Index);
            AndMaybeGoto(Field,Index);
            Entering(Field,Index);
        END;
    END FieldFwd;



        (* FieldBack -- Move to the prior (backward direction) field
                        and index from the current ones. *)

    PROCEDURE FieldBack( VAR Field : AFieldNo; VAR Index : CARDINAL);
    BEGIN
        IF (Leaving(Field,Index)) THEN
            Prior(Field,Index);
            AndMaybeGoto(Field,Index);
            Entering(Field,Index);
        END;
    END FieldBack;


        (* GroupFwd -- Move to the next (forward direction) group
                       and index from the current ones. *)


    PROCEDURE GroupFwd( VAR Field : AFieldNo;   VAR Index : CARDINAL);
    VAR
        Group, OldGroup : CARDINAL;
        XOff            : Anxoff;
        YOff            : Ayoff;
        Len             : CARDINAL;
        OldField        : AFieldNo;
        BaseField       : AFormField;
    BEGIN
        IF (Leaving(Field,Index)) THEN
            OldField := Field;
            GetFieldAttributes(FormRecord^,Field,0,BaseField,XOff,YOff,Len,OldGroup);
            REPEAT
                Next(Field,Index);
                GetFieldAttributes(FormRecord^,Field,0,BaseField,XOff,YOff,Len,Group);
            UNTIL (Group <> OldGroup)
               OR (Field = OldField);
            AndMaybeGoto(Field,Index);
            Entering(Field,Index);
        END;
    END GroupFwd;



        (* GroupBack -- Move to the prior (backward direction) group
                        and index from the current ones. *)

    PROCEDURE GroupBack( VAR Field : AFieldNo; VAR Index : CARDINAL);
    VAR
        Group, OldGroup : CARDINAL;
        XOff            : Anxoff;
        YOff            : Ayoff;
        Len             : CARDINAL;
        BaseField       : AFormField;
        OldField        : AFieldNo;
    BEGIN
        IF (Leaving(Field,Index)) THEN
            OldField := Field;
            GetFieldAttributes(FormRecord^,Field,0,BaseField,XOff,YOff,Len,OldGroup);
            REPEAT
                Prior(Field,Index);
                GetFieldAttributes(FormRecord^,Field,0,BaseField,XOff,YOff,Len,Group);
            UNTIL (Group <> OldGroup)
               OR (Field = OldField);
            AndMaybeGoto(Field,Index);
            Entering(Field,Index);
        END;
    END GroupBack;


        (* IndexFwd -- Move forward in the current field, or
                       out of it in the forward direction. *)


    PROCEDURE IndexFwd(VAR Field:AFieldNo; VAR Index:CARDINAL);
    BEGIN
        IF (Index >= MaxIndex(Form,Field)) THEN
            FieldFwd(Field,Index);
        ELSE
            INC(Index);
        END;
    END IndexFwd;



        (* IndexBack -- Move backward in the current field, or
                        out of it in the backward direction. *)


    PROCEDURE IndexBack(VAR Field:AFieldNo; VAR Index:CARDINAL);
    BEGIN
        IF (Index <= MinIndex(Form,Field)) THEN
            IF (Leaving(Field,Index)) THEN
                Prior(Field,Index);
                AndMaybeGoto(Field,Index);
                Entering(Field,Index);
            END;
        ELSE
            DEC(Index)
        END;
    END IndexBack;


        (*  Move forward, but do not leave field. *)

    PROCEDURE RotateForward(Field:AFieldNo; VAR Index:CARDINAL);
    BEGIN
        IF (Index >= MaxIndex(Form,Field)) THEN
            Index := MinIndex(Form,Field);
        ELSE
            INC(Index);
        END;
    END RotateForward;



        (*  Move backward, but do not leave field. *)

    PROCEDURE RotateBackward(Field:AFieldNo; VAR Index:CARDINAL);
    BEGIN
        IF (Index <= MinIndex(Form,Field)) THEN
            Index := MaxIndex(Form,Field);
        ELSE
            DEC(Index)
        END;
    END RotateBackward;






        (* MoveForward -- Move to the right, either within the field
                          or flowing out of it. *)

    PROCEDURE MoveForward(VAR Field:AFieldNo; VAR Index:CARDINAL);
    VAR
        BaseFieldNo : AFieldNo;
    BEGIN
        BaseFieldNo := TemplateFieldNo(FormRecord^,Field);
        IF (FlowRight IN FormRecord^.Fields[BaseFieldNo].Attributes) THEN
            IndexFwd(Field,Index);
        ELSE
            RotateForward(Field,Index);
        END;
    END MoveForward;






    PROCEDURE MoveBackward(VAR Field:AFieldNo; VAR Index:CARDINAL);
    VAR
        BaseFieldNo : AFieldNo;
        OriginalFieldNo : AFieldNo;
    BEGIN
        OriginalFieldNo := Field;
        BaseFieldNo := TemplateFieldNo(FormRecord^,Field);
        IF (FlowLeft IN FormRecord^.Fields[BaseFieldNo].Attributes) THEN
            IndexBack(Field,Index);
                (* If we have changed fields, put us at the right hand
                   edge. *)
            IF (Field <> OriginalFieldNo) THEN
                Index := MaxIndex(Form,Field);
            END;
        ELSE
            RotateBackward(Field,Index);
        END;
    END MoveBackward;



    PROCEDURE CodeToField( Code : CARDINAL ) : AFieldNo;
    BEGIN
        RETURN (Code MOD 100H) MOD (FormRecord^.MaxField + 1);
    END CodeToField;


        (* GotoField -- Move the cursor to the indicated field. *)


    PROCEDURE GotoField(     NewField : CARDINAL;
                         VAR Field    : AFieldNo;
                         VAR Index    : CARDINAL   ):BOOLEAN;
    VAR
        New : CARDINAL;
    BEGIN
        New := CodeToField(NewField);
        IF (New <> Field) THEN
            IF (Leaving(Field,Index)) THEN
                Field := New;
                    (*  We must move a little in case the field is
                        protected.  *)
                Prior(Field,Index);
                Next(Field,Index);
                AndMaybeGoto(Field,Index);    (* In case another goto key waits. *)
                Entering(Field,Index);
                RETURN TRUE;
            ELSE
                RETURN FALSE;
            END;
        END;
        RETURN TRUE;
    END GotoField;

        (* GotoFieldDamnit -- Goto the field, even if protected. *)


    (* Disabled Dec. 15, 1989 AJL
    PROCEDURE GotoFieldDamnit(     NewField : CARDINAL;
                               VAR Field    : AFieldNo;
                               VAR Index    : CARDINAL   );
    VAR
        New : CARDINAL;
    BEGIN
        New := CodeToField(NewField);
        IF (New <> Field) THEN
            IF (Leaving(Field,Index)) THEN
                Field := New;
                Entering(Field,Index);
            END;
        END;
    END GotoFieldDamnit;
    *)



        (* Obtain, from the user, the number of a field. *)

    (* Disabled Dec. 15, 1989 AJL
    PROCEDURE SelectFieldNumber() : CARDINAL;
    VAR
        Event   : AnEvent;
        CodeSet : ASetOfCodes;
    
    BEGIN
            (* The next code that is entered that is in the range of
               field numbers, starting with "A", is returned as the
               number of the field. *)
        LOOP
            SetCodeBits(CodeSet,0,MaxCode,FALSE);
            SetCodeBits(CodeSet,ORD("A"), ORD("A")+FormRecord^.MaxField, TRUE);
            GetNextEvent(Form,CodeSet,Event);
            IF (Event.EventType = KeyboardEvent) THEN  
                RETURN Event.EventCode - ORD("A");
            END;
        END;
    END SelectFieldNumber;
    *)




        (* AndMaybeGoto -- If a code command key is waiting, use it
                          to modify the current field. *)



    PROCEDURE AndMaybeGoto( VAR Field : AFieldNo;  VAR Index : CARDINAL );
    VAR
        Code : CARDINAL;
        Event : AnEvent;
    BEGIN
        IF (PopEvent(Form,Event)) THEN  (* it must be a keyboard event. *)
            Code := Event.EventCode; 
            IF (Code > MaxCode) THEN
                Field := CodeToField(Code);
                Prior(Field,Index);  (* Back up one field, in case this one protected. *)
                Next(Field,Index);
            ELSE
                PushCode(Form,Code);   (* Sorry, Wrong number *)
            END;
        END;
    END AndMaybeGoto;



        (*  Get the first letter of the choice. *)

    PROCEDURE FirstLetterOfItem(FieldNo:AFieldNo;Index:CARDINAL):ACode;
    VAR
        XOff    : Anxoff;
        YOff    : Ayoff;
        Len     : CARDINAL;
        Group   : CARDINAL;
        BaseField : AFormField;
    BEGIN
        GetFieldAttributes(FormRecord^,FieldNo,Index,BaseField,XOff,YOff,Len,Group);
        RETURN ORD(FormRecord^.FLine[YOff][XOff+1]);
    END FirstLetterOfItem;



        (* FINDCHOICENO -- If a letter was typed while on a set or
                           choice field, look at all the choices
                           and pick the next one that starts with
                           the same letter. *)

    PROCEDURE FindChoiceNo(Field:AFieldNo; i:CARDINAL; C:ACode):AChoiceNo;
    VAR
        OldIndex : CARDINAL;
    BEGIN
        OldIndex := i;

        REPEAT
            INC(i);
            IF (i > MaxIndex(Form,Field)) THEN
                i := MinIndex(Form,Field);
            END;
            IF (C = FirstLetterOfItem(Field,i)) THEN
                RETURN i;
            END;
        UNTIL (i = OldIndex);

        FatalError();
               (* This is an error condition.  Somehow we were asked
                  about a code that isn't the start of any word. *)
    END FindChoiceNo;



    PROCEDURE ShowCurrentString();
    BEGIN
        IF NOT (Hidden IN ASetOfAttributes(FormValue^[CurField].Private)) THEN
            PutString(TemporaryStringValue^,
                      Form^.ULX+XOff,
                      Form^.ULY+YOff+1,  (* Add one to compensate for box. *)
                      videoformdata);
        END;
    END ShowCurrentString;

        (* Remove character i from the current field's string value. *)


    PROCEDURE DeleteCharacter(i:CARDINAL);
    VAR
        j         : CARDINAL;
        XOff      : Anxoff;
        YOff      : Ayoff;
        Len       : CARDINAL;
        Group     : CARDINAL;
        BaseField : AFormField;
        s1        : ARRAY [0..1] OF CHAR;
    BEGIN
        GetFieldAttributes(FormRecord^,CurField,0,BaseField,XOff,YOff,Len,Group);
        Fill(s1," ",1);
        Remove(TemporaryStringValue^,i,1);
        ConcatLS(TemporaryStringValue^,s1);

            (*  Show the field as a string.  Avoid any call (such as ShowValue)
                that might cause interpretation of the string, or resetting of
                the string to its numeric value. *)

        ShowCurrentString();

        Form^.FieldIsFull := FALSE;

    END DeleteCharacter;






        (*  SetChoiceValue -- If this field is a CHOICE, set the CARDVALUE
                              to the current index and display the field. *)

    PROCEDURE SetChoiceValue;
    VAR
        DummyCode   : CARDINAL;
        BaseFieldNo : AFieldNo;
    BEGIN
        BaseFieldNo := TemplateFieldNo(FormRecord^,CurField);
        IF (FormRecord^.Fields[BaseFieldNo].FFType = FormChoice) THEN
            FormValue^[CurField].CardValue := CurIndex;
            ShowThisValue(Form,CurField,FormValue^[CurField]);
            IF (NOT FieldChecksOut(CurField,CheckFieldChange,DummyCode,FALSE)) THEN
                Burp;
            END;
            PushCode(Form,DummyCode);
        END;
    END SetChoiceValue;




        (* SaveCurrentData -- Store some of our needed stuff into the
                              FormControlBlock. *)

    PROCEDURE SaveCurrentData;
    BEGIN
        WITH Form^ DO
            Field := CurField;
            Index := CurIndex;
        END;
    END SaveCurrentData;


        (* GetCurrentFormPointers -- Make our local pointers point to
                                     our correct data and work areas. *)

    PROCEDURE GetCurrentFormPointers;
    BEGIN
        WITH Form^ DO
            FormValue := FormValuePointer;
            FormRecord := FormRecordPointer;
            CheckProc := UserCheckProc;
            CurField := Field;
            CurIndex := Index;
        END;
        TemporaryStringValue := Form^.TemporaryStringValue;
        CheckCodeSet := FormRecord^.CheckCodeSet;
    END GetCurrentFormPointers;

        (* Put up a form that allows a user to enter a long number or
           expression.  Return the number as a string. *)

    PROCEDURE GetLargerNumber(YOff : ascreeny; VAR S : ARRAY OF CHAR):BOOLEAN;
    CONST
        Size = 4;
    VAR
        Top, Bottom, FieldY  : ascreeny;
        MinDigits,MaxDigits            : CARDINAL;
    BEGIN
        FieldY := Form^.ULY+YOff+1;   (* Add 1 to compensate for box. *)
        Without(Size,Size,FieldY,FieldY,1,GanttWEnd,Top,Bottom);
        IF (BaseField.FFType = FormReal) THEN
            MinDigits := BaseField.Digits;
            MaxDigits := MAXCARDINAL;
        ELSE
            MinDigits := 0;
            MaxDigits := 0;
        END;
        RETURN DoLargerNumberForm(Top,Bottom,MinDigits,MaxDigits,S);
    END GetLargerNumber;




    PROCEDURE ShowHelp(YOff : Ayoff; Modal:BOOLEAN);
    CONST
        Start = 1;
    VAR
        HelpSize,MinSize,MaxSize  : CARDINAL;
        Top, Bottom       : ascreeny;
        FieldY, LastY     : ascreeny;
        s80               : ARRAY [0..MaxFormStringLen] OF CHAR;
        ScreenAction      : AScreenAction;
    BEGIN
        ClearAnyHelpText(Form);

            (* Always display the field prompt so that, since it might also
               be on the screen, it will be correct.  This also ensures that
               PrompPending is set to FALSE, and therefore we will not try
               to write prompts over top of the help message in the main
               loop of MoveOver.
            *)

        HighlightPrompt := FALSE;
        OldHighlight := HighlightPrompt; 
        DisplayFieldPrompt(Form,FieldType,CurField,FALSE);
        Form^.PromptPending := FALSE;

        Form^.ModalHelp := Modal;

        IF (Modal) THEN
            ScreenAction := LeaveTheText;
            HighlightField(Form,FormValue^,CurField,CursorResting);
            MinSize      := ((MaxRow-Start) DIV 2);
            MaxSize      := MAXCARDINAL;       (* Take up maximum amount of room. *)
            SetString( s80, FormHelpPrefix);
        ELSE
            ScreenAction := JustDisplayTheText;
            MinSize      := 10;                (* Always 10 lines, 8 for content. *)
            MaxSize      := 10;
            SetString( s80, FormExtremeHelpPrefix);
        END;

            (* Before displaying any help text, save the
               previous screen image. *)
        Top := Start;
        Bottom := Form^.ULY - 1;
        HelpSize := Bottom - Top + 1;
            (* Pick a location for the help.  Hopefully above the form,
               but if not, then avoiding the current field. *)
        IF (HelpSize < MinSize) THEN
            FieldY := Form^.ULY+YOff+1;   (* Add 1 to compensate for box. *)
            Without(MinSize,MaxSize,FieldY,FieldY,1,GanttWEnd,Top,Bottom);
            HelpSize := Bottom - Top + 1;
        ELSIF (NOT Modal) THEN
                (* If the non-modal help box will obscure the three-line prompts,
                   Put the most important key prompt at the top. *)
            DisplayMessage(ModuleNumber+1);
        END;

        (* Build help string.  RSC 2/3/88 *)
        ConcatLS(  s80, FormRecord^.HelpKey );
        CtoS(CurField,s10);
        Procustes( s80, 8 - ORD(s10[0]) );
        TrimRear(  s80 );
        ConcatLS(  s80, s10);

        IF (OpenHelpBox(s80,ABoxType{DoubleBox},0,Top,MaxColumn,Bottom,
                        ScreenAction,Form^.HelpBox)) THEN
            Form^.HelpULY := Top;
            Form^.HelpLRY := Bottom;
            IF (Modal) THEN
                GetMessage(ModuleNumber+8,s80);
                Procustes(s80,MaxColumn-3);
                PourText(s80,videoenhance,2,Bottom-1,MaxColumn-2,Bottom-1,LastY);
            END;
         END;

         IF (Modal) THEN
             HighlightField(Form,FormValue^,CurField,CursorOff);
         END;
    END ShowHelp;



    PROCEDURE GoodCode( C : ACode ):BOOLEAN;
    BEGIN
        IF ( C > MaxCode ) THEN
            (* Outside the normal checking range. It must be
               a goto command.  Let it pass. *)
        ELSIF NOT ((C MOD 16) IN (RCodeSet[C DIV 16])) THEN
            RETURN FALSE;
        END;
        RETURN TRUE;
    END GoodCode;


        (* All field changing codes must be set or not in ComputeRCodeSet. *)


    PROCEDURE ComputeRCodeSet( VAR CCodeSet, RCodeSet : ASetOfCodes;
                                   IncludeCheckCodes : BOOLEAN );
    VAR
        i,j : CARDINAL;
        C : ACode;
        S : ARRAY [0..20] OF CHAR;
    BEGIN
        RCodeSet := CCodeSet;

            (* If the field is protected, disable the keys that
               would allow changes. *)

        IF (FieldIsProtected(Form,CurField,FormValue^)) THEN
            RETURN;
        END;

        SetCodeBits(CCodeSet,RollLeft,RollLeft,TRUE);
        SetCodeBits(CCodeSet,RollRight,RollRight,TRUE);

        RCodeSet := CCodeSet;

            (* Allow the check codes. *)

        IF (IncludeCheckCodes) THEN
            FOR i := 0 TO HIGH(RCodeSet) DO
                RCodeSet[i] :=  RCodeSet[i] + CheckCodeSet[i];
            END;
        END;

        WITH BaseField DO
            IF (FFType <> FormChoice) THEN                 (* Some sort of string. *)
                FOR i := 0 TO HIGH(RCodeSet) DO
                    RCodeSet[i] :=  RCodeSet[i] + CodeSet[i];
                END;
                SetCodeBits(RCodeSet,InsertKey,InsertKey,TRUE);
                SetCodeBits(RCodeSet,DeleteKey,DeleteKey,TRUE);
                SetCodeBits(RCodeSet,BackSpace,BackSpace,TRUE);
                SetCodeBits(RCodeSet,EraseKey,EraseKey,TRUE);
                SetCodeBits(RCodeSet,EraseToEOLKey,EraseToEOLKey,TRUE);
                SetCodeBits(RCodeSet,AlternateEraseKey,AlternateEraseKey,TRUE);
                SetCodeBits(RCodeSet,CopyToPasteKey,CopyToPasteKey,TRUE);
                SetCodeBits(RCodeSet,PasteKey,PasteKey,TRUE);

                IF (FFType IN AFieldTypeSet{FormCard,FormReal}) THEN
                        (* Numeric operators for expressions. *)
                    SetString(S," 0123456789+-*/()");
                    FOR i := 1 TO ORD(S[0]) DO
                        j := ORD(S[i]);
                        SetCodeBits(RCodeSet,j,j,TRUE);
                    END;
                        (* Adapt a real number format to international needs. *)
                    IF (FFType = FormReal) THEN          (* AJL 11/28/88 *)
                        j := ORD(DefaultAmountFormat.RadixSymbol);
                        SetCodeBits(RCodeSet,j,j,TRUE);
                    END;
                END;

                IF (Numeric IN Attributes) THEN
                       (* Edit key. *)
                    SetCodeBits(RCodeSet,EditKey,EditKey,TRUE);
                END;

            ELSE
                    (* Allow the first letter of each
                       choice.*)
                FOR i := 0 TO Count DO
                    C := FirstLetterOfItem(CurField,i);
                    SetCodeBits(RCodeSet,C,C,TRUE);
                END;
                SetCodeBits(RCodeSet,Space,Space,TRUE);
                SetCodeBits(RCodeSet,BackSpace,BackSpace,TRUE);
            END;
        END;
    END ComputeRCodeSet;

        (* 15-Nov-89 RSC process mouse select.
    
            > Move cursor to clicked-on suggestion, if found.
            > else, leave selection where it was.
        *)



    PROCEDURE MouseToRegion( MouseX, MouseY : CARDINAL ) : AMouseClickPoint;
    VAR
        BoxType    : ABoxType;
        MouseWent  : AMouseClickPoint;
    BEGIN
        BoxType := FormRecord^.Box + ABoxType{HasOk,HasCancel,HasHelp};
        WITH Form^ DO
            IF (HelpLRY >= HelpULY)         (* Help is showing. *)
               AND (HelpULY <= MouseY) AND (MouseY <= HelpLRY) THEN
                MouseWent := OnHelpText;
            ELSE
                MouseWent := CorrelateMousePoint(ULX,ULY,LRX,LRY,BoxType,MouseX,MouseY);
            END;
        END;
        RETURN MouseWent;
    END MouseToRegion;


    PROCEDURE ProcessMouseUp( MouseX, MouseY : CARDINAL;
                              VAR SuggestedMouseDoubleKey : ACode);
    VAR
        MouseWent  : AMouseClickPoint;   (* Where on the box. *)
    BEGIN
        SuggestedMouseDoubleKey := 0;
            (* Figure out where they clicked. *)
        MouseWent := MouseToRegion(MouseX,MouseY);

            (* If the up is not in the same general region as the down was,
               it doesn't count. *)

        IF (MouseWent <> DownRegion) THEN
            RETURN;
        END;      

            (* Branch based on where the mouse click happened. *)

        CASE MouseWent OF
            OnOk     :
                        PushCode(Form,ExitKey);
                        CancelDoubleClick();
          | OnCancel :
                        PushCode(Form,CancelKey);
                        CancelDoubleClick();

          | OnHelp   :  
                        PushCode(Form,HelpKey);
                        CancelDoubleClick();
          | OnInside :

          | OnOutside :  
                            (* A click in the help prompts at the top
                               of the screen brings up the field help. *)
                        IF (FormRecord^.PromptULY <= MouseY) AND (MouseY <= FormRecord^.PromptLRY)
                           AND     
                           (Form^.HelpLRY < Form^.HelpULY) THEN    (* no help already showing. *)
                            SuggestedMouseDoubleKey := HelpKey;
                        ELSE
                            Burp();
                        END; 
         | OnHelpText : 
                           (* A click while help is showing, if it is in the help box,
                              closes the box. *) 
                        ClearAnyHelpText(Form);
                        CancelDoubleClick();


            ELSE        
                        Burp();
        END;
    END ProcessMouseUp;
    
        (* Processes MouseDown and MouseStillDown. *)

    PROCEDURE ProcessMouseDown(     MouseX, MouseY : CARDINAL;
                                    EventCode      : ACode;
                                VAR SuggestedMouseDoubleKey : ACode);
    VAR
        MouseWent  : AMouseClickPoint;   (* Where on the box. *)
        FieldNo    : AFieldNo;
        Index      : CARDINAL;
        IsChoiceField : BOOLEAN;
        Len,
        Group      : CARDINAL;
        BaseField       : AFormField;
        XOff            : Anxoff;
        YOff            : Ayoff;


        PROCEDURE LocateFieldAndIndex( MouseX, MouseY : CARDINAL;
                                       VAR i : AFieldNo;
                                       VAR j : CARDINAL;
                                       VAR IsChoiceField : BOOLEAN ) : BOOLEAN;
        VAR
            Found            : BOOLEAN;

            FieldX,
            FieldEndX,
            FieldY         : CARDINAL;
            Len,
            Group, 
            IndexLimit     : CARDINAL;
    
            BaseField       : AFormField;
            XOff            : Anxoff;
            YOff            : Ayoff;
        BEGIN
                (* Well, the mouse click was somewhere within the form.
                   Look through all fields to see which one, if any, the 
                   mouse click was on. *)

            Found := FALSE;
            i := 0;
            WHILE (NOT Found) AND
                  (i <= FormRecord^.MaxField) DO
                    (* What kind of a field are we looking at now? *)
                j  := MinIndex(Form,i);  (* Temporarily, the first index position. *)
                GetFieldAttributes( FormRecord^, i, j, BaseField,
                                    XOff, YOff, Len, Group );
                IsChoiceField := (BaseField.FFType IN AFieldTypeSet{FormChoice,FormPickSet});
                    (* Most fields have only a string, in which case the only index
                       position we need is the first.  Choice fields though have 
                       subdivisions at several index postions. *)
                    (* Should we check other indices into the field? *)
                IndexLimit := j;
                IF (IsChoiceField) THEN
                    IndexLimit := BaseField.Count;
                END;          

                    (* Look at each index position of the current field.  Did
                       we get a hit?   If so, set Found to TRUE. *) 
                WHILE (NOT Found) AND
                      (j <= IndexLimit) DO
                        (* It doesn't count if the field is protected. *) 
                    IF (NOT FieldIsProtected(Form,FieldNo,FormValue^)) THEN
                            (* Locate the field's screen position. *)
                        FindFieldXY( Form, i, j, FieldX, FieldY, FieldEndX );
                        IF (NOT IsChoiceField) THEN
                            IF (Len > 0) THEN
                                INC(FieldEndX,Len-1);   (* 7/24/91 EGK *)
                            END;
                        END;
                            (* Are we on this field? *)
                        Found :=  (MouseY = FieldY) AND
                               (MouseX >= FieldX) AND
                               (MouseX <= FieldEndX);
                    END;
                    IF (NOT Found) THEN
                        INC(j);
                    END;
                END;
    
                IF (NOT Found) THEN 
                    INC(i);
                END;
            END;

            IF (Found) THEN
                IF (NOT IsChoiceField) THEN
                    INC(j,(MouseX - FieldX));
                END;
            END;

            RETURN Found;
        END LocateFieldAndIndex;


    BEGIN



        (* ****************** *)
       

            (* Figure out where they clicked. *)

        MouseWent := MouseToRegion(MouseX,MouseY);

            (* StillDown is only valid if it is in the same region as the
               original down press. *)
    
        IF (EventCode = MouseStillDown) AND (MouseWent <> DownRegion) THEN
            RETURN;
        END;

          (* A click in the help prompts at the top
             of the screen brings up the field help.   Indicate
             that action by highlighting while there. *)
        HighlightPrompt := (FormRecord^.PromptULY <= MouseY) AND (MouseY <= FormRecord^.PromptLRY)   (* in prompt area. *)
                           AND
                           (Form^.HelpLRY < Form^.HelpULY);    (* no help already showing. *)


            (* Branch based on where the mouse click happened. *)

        CASE MouseWent OF
            OnInside :
                        IF LocateFieldAndIndex(MouseX,MouseY,FieldNo,Index,IsChoiceField) THEN
                                (* A mouse still down is only honored if it is
                                   in the field in which the original down happened. *)
                            IF (EventCode = MouseStillDown) AND (FieldNo <> DownField) THEN
                                (* ignore it. *)
                            ELSE  (* either a MouseDown, or still down in same field. *)
                                IF (EventCode = MouseDown) THEN
                                    DownField := FieldNo;
                                END;
                                    (* We treat clicks within the current field
                                       differently than a click in a new field. *)
                                IF (FieldNo = CurField) THEN
                                        (* Track only on actual downs, except
                                           choice fields, which track all movements. *)
                                    IF (IsChoiceField) OR
                                       (EventCode = MouseDown) THEN
                                        IF (CurIndex <> Index) THEN 
                                            CurIndex := Index;
                                                (* Turn off the cursor. *)
                                            DisplayCursor(Form,FormValue^,CurField,CurIndex,CursorOff);
                                                (* Update the displayed value if choice. *)
                                            SetChoiceValue();  
                                        END;
                                    END;
                                ELSE  (* New field. *)
                                      (* Turn off the cursor. *)
                                    DisplayCursor(Form,FormValue^,CurField,CurIndex,CursorOff);
                                        (* Attempt to go to the new field, checkproc permitting . . . *)
                                    IF GotoField( FieldNo, CurField, CurIndex ) THEN
                                            (* But leave the index at the beginning of the 
                                               field unless it is a choice field or a string. *)
                                        GetFieldAttributes( FormRecord^, FieldNo, Index, BaseField,
                                                            XOff, YOff, Len, Group );
                                        CASE BaseField.FFType OF
                                            FormString : CurIndex := Index;
                                          | FormChoice,
                                            FormPickSet : 
                                                        CurIndex := Index;
                                                            (* Update the displayed value if choice. *)
                                                        SetChoiceValue();  
                                          ELSE
                                        END;
                                    END;
                                END;
                                SuggestedMouseDoubleKey := EditKey;
                            END;
                        ELSE
                              (* Not on a field. *)
                            IF (EventCode = MouseDown) THEN
                                Burp();
                            END;
                        END;

            ELSE        
                        (* ignore it. *)
        END;


        DownRegion := MouseWent;     (* Store globally *)


    END ProcessMouseDown;


    PROCEDURE ProcessMouseEvent( VAR Event : AnEvent );
    VAR
        MouseX,
        MouseY     : CARDINAL;
    BEGIN
        MouseX := Event.EventX;
        MouseY := Event.EventY;

            (* Now process the clicks *)

        CASE Event.EventCode OF
            MouseUp : 
                             ProcessMouseUp(MouseX,MouseY,SuggestedMouseDoubleKey);
          | MouseDouble : 
                                 (* Turn off the cursor. *)
                             DisplayCursor(Form,FormValue^,CurField,CurIndex,CursorOff);
                             PushCode(Form,SuggestedMouseDoubleKey);
          | MouseDown,
            MouseStillDown : ProcessMouseDown(MouseX,MouseY,
                                              Event.EventCode,SuggestedMouseDoubleKey);
            ELSE
        END;  

    END ProcessMouseEvent;




        (* C is the input code.
           Finished is returned as TRUE if the user has chosen to exit
           the form. 
        *) 

    PROCEDURE ProcessKeyPress( VAR C : ACode;
                               VAR Finished : BOOLEAN );
    BEGIN
         Finished := FALSE;

            (* Process the key struck.   The first step in processing
               is to trap any fancy codes that cause special checking
               or form exit.   Note that the CheckProc in this case
               has the responsibility of changing C to another code. *)

        IF ( C <= MaxCode ) AND
           ((C MOD 16) IN (CheckCodeSet[C DIV 16])) THEN
                (* Make the current field's value accessable to the
                   CheckProc. *)
                (* Note--this may cause padding with blanks. *)
            IF (NOT ConditionalCheckout(CurField,CurIndex,FieldType,
                                        CheckFieldKey,C,(HighlightOnEntry IN CurrentAttributes))) THEN
            END;
                (* Bit 15 will pass the code on down (GoTo).
                   If bit 14 of the code is set on return, then we
                   will take the code as a translation and continue.
                   Otherwise, we push it, but cancel further action. *)
            IF (C > MaxCode) THEN
                i := C MOD (MaxCode+1);
                IF (15 IN BITSET(C)) THEN
                ELSIF (14 IN BITSET(C)) THEN
                   ComputeRCodeSet(CCodeSet,RCodeSet,FALSE);  (* Disallow check codes. *)
                   IF (GoodCode(i)) THEN
                       C := i;
                       LastCodeTyped := C;
                   ELSE
                       C := 0;   (* A null key. *)
                       Burp();
                   END;
                ELSE
                    IF (13 IN BITSET(C)) THEN
                        PushCode(Form,i);
                    END;
                    C := 0;
                END;
            ELSE
                C := 0;
            END;
        END;  (* If code is in codeset. *)




        IF (C=ExitKey) THEN
            IF (Leaving(CurField,CurIndex)) THEN
                    (*  Try to leave the form. *)
                    (*  Only allow exit if this field checks out. *)
                    (*  Note that in this case we do not change the
                        value of C, the last code hit. *)
                IF ( FieldChecksOut(CurField,CheckFormExit,C2,FALSE) ) THEN
                        (* Now check all fields for acceptability. *)
                    OK := TRUE;
                    i := 0;
                    WHILE (i <= FormRecord^.MaxField) AND (OK) DO
                        IF (i = CurField) OR  (* Don't check twice. *)
                           (FieldChecksOut(i,CheckFormExit,C2,FALSE)) THEN
                            INC(i);
                        ELSE
                            OK := FALSE;
                        END;
                    END;
                ELSE
                    OK := FALSE;
                END;
                    (* Is it ok to exit the processing of this procedure? *)
                IF (OK) THEN
                    Finished := TRUE;    (* Finished the form. *)
                    RETURN;
                ELSE
                    Burp;
                    ResetCursor(CurField,CurIndex,FieldType,FALSE);
                    C := 0;  (* Attempt to leave form was denied.   This
                                code (C2) may be a code to be processed,
                                though. *)
                    PushCode(Form,C2);
                    AndMaybeGoto(CurField,CurIndex);
                    Entering(CurField,CurIndex);
                END;
            ELSE  (* not leaving. *)
                Burp;
                C := 0;   (* Attempt to leave the field was denied. *)
            END;
        ELSIF (C=CancelKey) THEN
            IF (Form^.HelpLRY >= Form^.HelpULY) AND (Form^.ModalHelp) THEN
                ClearAnyHelpText(Form);
                C := 0;   (* No further action. *)
            ELSE
                IF OkToEscapeForm( Form ) THEN (* RSC 10/16/87 *)
                    Finished := TRUE;
                    RETURN;         
                END;
                C := 0;   (* No further action. *)
            END;
        END;


            (* Special processing for Larry and Tom: Allow
               space and backspace keys to move the choice. *)

        IF (FieldType = FormChoice) THEN
            IF (C = Space) THEN C := Fwrd;
            ELSIF (C = BackSpace) THEN C := Reverse;
            END;
        END;

            (* The FieldIsFull records attempts to type past the
               end of a string field.  But, if we aren't at the end
               then, if it is on, it shouldn't be because we've
               moved. *)

        IF (FieldType <> FormChoice) THEN
            i := MaxIndex(Form,CurField);
            IF (Form^.InsertMode) THEN
                Form^.FieldIsFull := (TemporaryStringValue^[i] <> " ");
            ELSIF (CurIndex < i) THEN
                Form^.FieldIsFull := FALSE;
            END;
        END;




            (*  Take action based on the key hit. *)

        CASE C OF
            0:          (* Ignore response of 0 from CheckProc or bad
                           key hit.   Zero is a special code that we
                           reserve to do nothing. *)

             |
            DoIt:
                        IF (Leaving(CurField,CurIndex)) THEN
                            Next(CurField,CurIndex);
                            AndMaybeGoto(CurField,CurIndex);
                            Entering(CurField,CurIndex);
                                (* If there is only one unprotected
                                   field on the form, take DoIt as Exit. *)
                            IF (CurField = OldField) THEN
                                PushCode(Form,ExitKey);
                            END;
                        END;
             |
            Down:       FieldFwd(CurField,CurIndex);
             |
            Up:         FieldBack(CurField,CurIndex);
             |
            Tab:        GroupFwd(CurField,CurIndex);
             |
            RTab:       GroupBack(CurField,CurIndex);
             |
            HomeKey:    IF (Form^.LastKey[0] = HomeKey) THEN
                            IF (Form^.LastKey[1] = HomeKey) THEN
                                IF GotoField(0,CurField,CurIndex) THEN; END;
                            ELSE
                                GroupBack(CurField,CurIndex);
                                GroupFwd(CurField,CurIndex);
                            END;
                        ELSIF (FieldType <> FormChoice) THEN
                            CurIndex := 1;
                        END;
             |
            EndKey:
                        IF (Form^.LastKey[0] = EndKey) THEN
                            IF (Form^.LastKey[1] = EndKey) THEN
                                IF (Leaving(CurField,CurIndex)) THEN
                                       (* Goto the first field, and then
                                          move back by one.  This locates
                                          the last field on the form. *)
                                    CurField := 0;
                                    Prior(CurField,CurIndex);
                                    AndMaybeGoto(CurField,CurIndex);
                                    Entering(CurField,CurIndex);
                                END;
                            ELSE
                                GroupFwd(CurField,CurIndex);
                                GroupBack(CurField,CurIndex);
                            END;
                        ELSIF (FieldType <> FormChoice) THEN
                            REPEAT
                                i := CurIndex;
                                FindNextWord(TemporaryStringValue^,CurIndex,
                                             WordSeparator);
                            UNTIL (CurIndex = i);
                        END;
             |
            Fwrd:       MoveForward(CurField,CurIndex);
                        SetChoiceValue;
             |
            Reverse:    MoveBackward(CurField,CurIndex);
                        SetChoiceValue;
             |
            RollRight:  IF (FieldType <> FormChoice) THEN
                            FindNextWord(TemporaryStringValue^,CurIndex,
                                         WordSeparator);
                        ELSE
                            CurIndex :=  0;
                            MoveBackward(CurField,CurIndex);
                            SetChoiceValue;
                        END;
             |
            RollLeft:   IF (FieldType <> FormChoice) THEN
                            FindPriorWord(TemporaryStringValue^,CurIndex,
                                          WordSeparator);
                        ELSE
                            CurIndex :=  0;
                            SetChoiceValue;
                        END;
             |
                            (* Only for strings and numbers *)
            InsertKey:
                        Form^.InsertMode := NOT Form^.InsertMode;
             |
                            (* Only for strings and numbers *)
            DeleteKey:  DeleteCharacter(CurIndex);
             |
                            (* Only for strings and numbers *)
            BackSpace:  IF (Form^.FieldIsFull) AND (CurIndex = MaxIndex(Form,CurField)) THEN
                            DeleteCharacter(CurIndex);
                        ELSIF (CurIndex > 1) THEN
                            DEC(CurIndex);
                            IF (Form^.InsertMode) THEN
                                DeleteCharacter(CurIndex);
                            ELSE
                                TemporaryStringValue^[CurIndex] := " ";
                                ShowCurrentString();
                            END;
                        ELSIF (FlowLeft IN CurrentAttributes) THEN
                            FieldBack(CurField,CurIndex);
                        ELSE
                            Burp;
                        END;
              |
                            (* Only for strings and numbers *)
            EditKey:
                        IF (Numeric IN CurrentAttributes) THEN
                            IF (GetLargerNumber(YOff,TemporaryStringValue^)) THEN
                                CurIndex := 1;
                                ShowCurrentString();
                            END;
                        ELSE
                            Burp();
                        END;
              |
            EraseToEOLKey,
            AlternateEraseKey,
            EraseKey:
                        BlankRest(CurField,CurIndex);
                        DeleteCharacter(CurIndex);
              |
            HelpKey:
                        ShowHelp(YOff,TRUE);

             (* Disabled Dec. 15, 1989 AJL
              |
            GotoFieldKey:
                        GotoFieldDamnit(SelectFieldNumber(),CurField,CurIndex);
             *)

              |
            CopyToPasteKey:

                        CopyToPasteBuffer( TemporaryStringValue^ );
                        ShowCurrentString();
              |
            PasteKey:
                        DoThePaste( TemporaryStringValue^, Len, CurIndex );
                        ShowCurrentString();

            ELSE
                IF (C > MaxCode) AND (15 IN BITSET(C)) THEN
                        (* Goto command *)
                    IF GotoField(C,CurField,CurIndex) THEN; END;
                ELSE
                    C := C MOD (MaxCode+1);
                    CASE FieldType OF
                        FormString,
                        FormCard,
                        FormReal :
                                    IF (Form^.FieldIsFull) THEN
                                        Burp();
                                    END;
                                    IF (Form^.InsertMode) THEN
                                        DEC(TemporaryStringValue^[0]);
                                        s1[1] := " ";
                                        Insert(TemporaryStringValue^,s1,CurIndex);
                                    ELSE
                                        IF (Numeric IN CurrentAttributes) THEN
                                            BlankRest(CurField,CurIndex);
                                        END;
                                    END;
                                    TemporaryStringValue^[CurIndex] := CHR(C);
                                    ShowCurrentString();
                                    IF (CurIndex < MaxIndex(Form,CurField)) THEN
                                        INC(CurIndex);
                                    ELSIF (FlowRight IN CurrentAttributes) THEN
                                        FieldFwd(CurField,CurIndex);
                                    ELSE
                                        Form^.FieldIsFull := TRUE;
                                    END;
                           |
                        FormChoice:
                                        CurIndex := FindChoiceNo(
                                                        CurField,CurIndex,C);
                                        SetChoiceValue;
                        ELSE FatalError;
                    END;
            END; (* CASE FieldType *)
        END; (* CASE C *)



    END ProcessKeyPress;





BEGIN   (* MoveOver *)

    GetCurrentFormPointers;
    LastCodeTyped    := 0;



    s1[0] := 1C;           (* Set the length. *)

        (* What keys are always valid. *)
        (* All field changing codes must be set or not in ComputeRCodeSet. *)
    SetCodeBits(CCodeSet,0,MaxCode,FALSE);
        (* ExitKey and CancelKey are always valid. *)
    SetCodeBits(CCodeSet,ExitKey,ExitKey,TRUE);
    SetCodeBits(CCodeSet,CancelKey,CancelKey,TRUE);
        (* Cursor control keys. *)
    SetCodeBits(CCodeSet,Fwrd,Fwrd,TRUE);
    SetCodeBits(CCodeSet,Reverse,Reverse,TRUE);
    SetCodeBits(CCodeSet,Up,Up,TRUE);
    SetCodeBits(CCodeSet,Down,Down,TRUE);
    SetCodeBits(CCodeSet,RTab,RTab,TRUE);
    SetCodeBits(CCodeSet,Tab,Tab,TRUE);
    SetCodeBits(CCodeSet,DoIt,DoIt,TRUE);
    SetCodeBits(CCodeSet,HomeKey,HomeKey,TRUE);
    SetCodeBits(CCodeSet,EndKey,EndKey,TRUE);
    (*SetCodeBits(CCodeSet,GotoFieldKey,GotoFieldKey,TRUE);                    (* 9-Mar-89 LAA *)*)


    SetCodeBits(CCodeSet,HelpKey,HelpKey,TRUE);

    CurField := 0;
    CurIndex := MinIndex(Form,0);
    Prior(CurField,CurIndex);       (* In case field 0 is protected. *)
    Next(CurField,CurIndex);
    Entering(CurField,CurIndex);


    REPEAT
        Finished := FALSE;
        OldField := CurField;    (* Detect failure to change fields. *)

        GetFieldAttributes(FormRecord^,CurField,CurIndex,
                           BaseField,XOff,YOff,Len,Group);

        FieldType := BaseField.FFType;

            (* Move the cursor to the correct location for the
               current index within the current field.   Compute
               the correct legal character set allowed for input. *)

        ComputeRCodeSet(CCodeSet,RCodeSet,TRUE);


        IF (FieldType = FormChoice) THEN
            CurIndex := FormValue^[CurField].CardValue;      (* AJL 8/8/87 *)
        END;

            (* If the whole form has become protected, then we may end
               up on a protected field.  Only allow exit. *)

        IF (DisplayOnly IN CurrentAttributes) THEN
            SetCodeBits(RCodeSet,0,255,FALSE);
            SetCodeBits(RCodeSet,ExitKey,ExitKey,TRUE);
            SetCodeBits(RCodeSet,CancelKey,CancelKey,TRUE);
        END;

            (*  Display a cursor.  *)

        DisplayCursor(Form,FormValue^,CurField,CurIndex,CursorOn);

            (* Unless we urgently need to process user input, display
               the prompts for the current field.   The reason that
               we sometimes delay doing this is that moving through
               fields can take a lot of time if we display the prompts
               for each.  Instead, only prompt when we come to rest.
               View this as an asynchronous process that eventually
               catches up to the current field.
            *)

        IF ((Form^.PromptPending)                              (* Need to display a prompt *)
             OR (HighlightPrompt <> OldHighlight))
           AND (NOT KeyPress()) THEN                           (* Not moving to a new field. *)
            DisplayFieldPrompt(Form,FieldType,CurField,HighlightPrompt);
            OldHighlight := HighlightPrompt; 
            Form^.PromptPending := FALSE;
        END;


        WITH Form^ DO
            LastKey[1] := LastKey[0];
            LastKey[0] := LastCodeTyped;
        END;


            (* Get the next event. *)

        GetNextEvent(Form,RCodeSet,Event);




        CASE Event.EventType OF
            KeyboardEvent :
                                 (* Turn off the cursor. *)
                             DisplayCursor(Form,FormValue^,CurField,CurIndex,CursorOff);
                             C := Event.EventCode;
                                 (* Filter out unwanted key codes. *)
                             IF (GoodCode(C)) THEN
                                 (* Save a record of the last key entered. *)
                                 LastCodeTyped := C;
                                 ProcessKeyPress(C,Finished);
                             ELSE
                                 Burp;
                             END;
          | MouseEvent    :
                             LastCodeTyped := 0;    (* 7/24/91 EGK *)
                             ProcessMouseEvent(Event);
            ELSE 
                ErrorPhrase( ModuleNumber + 21 );    (*  "Unknown event type on Form." *)
        END; 
 



    UNTIL Finished; 


    CancelDoubleClick();
    ClearAnyHelpText(Form);

    RETURN C;
END MoveOver;


    (*$R=*) (*$T=*)   (* Match to beginning of MoveOver. *)





PROCEDURE PassEventToForm ( VAR Form : AForm;
                                Event : ACode  ) : BOOLEAN;
BEGIN
    IF (Form^.OpenMode = UnderUserControl) THEN
        FatalError;
    ELSE
        FatalError;
    END;
END PassEventToForm;










    (*  A Check Proc that always returns true. *)

    (*  The null value of ACheckProc   *)


PROCEDURE NullCheckProc (     Form       : AForm;
                              FieldNo    : AFieldNo;
                         VAR FormValue   : ARRAY OF AFieldValue;
                             CheckReason : ACheckReason;
                         VAR Code : CARDINAL
                        ) : BOOLEAN;
BEGIN
    Code := 0;     (* Must always return 0 to prevent code interpretation. *)
    RETURN TRUE;
END NullCheckProc;




PROCEDURE PrepareForForm (  VAR FormValue    : ARRAY OF AFieldValue;
                                FormRecord   : AFormRecordPointer
                         ) : AForm;
CONST
    StackCushion      = 4096;
    StackMinimum      = 1600;
VAR
    Form : AForm;

BEGIN
    IF (FormRecord = NIL) THEN
        FatalError();
    END;

    IF (NOT StackSpaceLeft (StackCushion)) THEN     (* 11/28/89 EGK *)
        IF (StackSpaceLeft (StackMinimum)) THEN
            ErrorPhrase(StackWarningMsg);
        ELSE
            Burp();
        END;
        RETURN NIL;
    END;

    IF (NOT Available(TSIZE(AForm))) THEN                         (* 12-Feb-88 LAA *)
        ErrorPhrase(MemoryWarningMsg);
        RETURN NIL;
    END;

    NEW(Form);
    WITH Form^ DO
        FormRecordPointer := FormRecord;
        NEW(TemporaryStringValue);
        FormValuePointer := ADR(FormValue);
    END;

    SendNotices(FormActive, BeforeActing, ADDRESS(FormRecord) );

    RETURN Form;

END PrepareForForm;






PROCEDURE RepaintForm ( Form : AFormControlBlockPointer );
VAR
    i : AFieldNo;
BEGIN
    ShowBase(Form);
        (*  Adjust all fields to our requirements and display them.  *)
    FOR i := 0 TO Form^.FormRecordPointer^.MaxField DO
        ShowThisValue(Form, i, Form^.FormValuePointer^[i]);
    END;
END RepaintForm;




PROCEDURE ComputeBoundaries(    Form          : AFormControlBlockPointer;
                            VAR ULX          : ascreenx;
                            VAR ULY          : ascreeny;
                            VAR LRX          : ascreenx;
                            VAR LRY          : ascreeny );
VAR
    MaxWidth, Width : CARDINAL;
    Line : Ayoff;
    LastLine         : ascreeny;
    FormRecord : AFormRecordPointer;
BEGIN
            (* Locate the current form record. *)

        FormRecord := Form^.FormRecordPointer;

            (* ULY is first line to be used for the form. Find the last line,
               and the widest line. *)

        LastLine := LRY;
        ULY      := LastLine - FormRecord^.MaxLine - 2;  (* -2 for box borders. *)

        MaxWidth := 1;
        FOR Line := 0 TO FormRecord^.MaxLine DO
            Width := ORD(FormRecord^.FLine[Line][0]);
            IF (Width > MaxWidth) THEN
                MaxWidth := Width;
            END;
        END;

        IF (ShadowBox IN FormRecord^.Box) THEN
            DEC(ULY);
            INC(MaxWidth,2);
        END;

        Form^.ULX := ULX;
        Form^.ULY := ULY;
        Form^.LRX := MaxWidth - 1 + ULX;
        Form^.LRY := LastLine;

        IF (Form^.LRX > 79) THEN HALT; END;

END ComputeBoundaries;





    (* SaveScreenImage -- Save the area under the form.  *)

PROCEDURE SaveScreenImage(     Form  : AFormControlBlockPointer;
                               SaveScreen  : BOOLEAN ) : BOOLEAN;
VAR
    PULX     : ascreenx;
    PULY     : ascreeny;
    PLRX     : ascreenx;
    PLRY     : ascreeny;
BEGIN
    Form^.RugSaved := FALSE;
    Form^.PromptRugSaved := FALSE;

    IF SaveScreen THEN
        WITH Form^ DO
            RugSaved := (GetRug(ULX,ULY,LRX,LRY,Form^.Rug));
            IF (NOT RugSaved) THEN
                RETURN FALSE;
            END;

            IF (FormRecordPointer^.PromptType = SeparatePrompts) THEN
                GetPromptCoordinates(Form,PULX,PULY,PLRX,PLRY);
                PromptRugSaved := GetRug(PULX,PULY,PLRX,PLRY,Form^.PromptRug);
            END;
        END;
    END;

    RETURN TRUE;
END SaveScreenImage;





(* RSC 26-Jul-89 *)
PROCEDURE LocalGetMessage(     Number   : CARDINAL;
                           VAR Text     : ARRAY OF CHAR );
BEGIN
    GetMessageForClass( Number, Forms, Text );
END LocalGetMessage;








    (* ActivateForm -- Given a Form, display it and manage it. *)


PROCEDURE ActivateForm       (     Form         : AFormControlBlockPointer;
                               VAR ULX          : ascreenx;
                               VAR ULY          : ascreeny;
                               VAR LRX          : ascreenx;
                               VAR LRY          : ascreeny;
                                   SaveScreen   : BOOLEAN;
                               VAR FormValue    : ARRAY OF AFieldValue;
                                   CheckProc    : ACheckProc ):BOOLEAN;
VAR
    FormRecord : AFormRecordPointer;
    i,j        : CARDINAL;
    C          : ACode;
BEGIN
            (* Locate the current form record. *)

        FormRecord := Form^.FormRecordPointer;

        Form^.UserCheckProc := CheckProc;

            (* Plan the position and save the screen image. *)

        ComputeBoundaries( Form, ULX, ULY, LRX, LRY );
        IF (NOT SaveScreenImage(Form,SaveScreen) ) THEN
            RETURN FALSE;
        END;

        WITH Form^ DO
            HelpULY           := 1;     (* Impossible range signals no help showing. *)
            HelpLRY           := 0;
            InsertMode        := FALSE;
            KeyStackIndex     := 0;
            ChangesMadeToForm := FALSE; (* RSC 10/16/87 *)
            LastKey[0]        := 0;
            LastKey[1]        := 0;
            QueryPrompt       := LocalGetMessage;  (* Default supplier of prompts.  RSC 26-Jul-89 *)
            UserContext       := NIL;         (* No user context set yet. *)
        END;

            (* Copy the field attributes into each
               field. *)

        Form^.DisplayEnable := FALSE;    (* Inhibit any display until base is up. *)

        FOR i := 0 TO FormRecord^.MaxField DO
           j := TemplateFieldNo(FormRecord^,i);
           FormValue[i].Private := BITSET(FormRecord^.Fields[j].Attributes);
        END;

        C := 0;   (* Make a legal code. *)

        FOR i := 0 TO FormRecord^.MaxField DO
            IF (NOT CheckProc(Form,i,FormValue,CheckFormEntry,C)) THEN; END;
        END;

            (*  Check all fields on entry in order to give the CheckProc a
                chance to alter the form, if appropriate (like changing the
                display-only attributes of a field).  *)


       Form^.DisplayEnable := TRUE;

            (*  Display the base text of the form. The
                above CheckProc may have changed it. *)

        RepaintForm( Form );

        RETURN TRUE;

END ActivateForm;







PROCEDURE CleanUpAfterForm( VAR Form : AFormControlBlockPointer );
VAR
    PULX     : ascreenx;
    PULY     : ascreeny;
    PLRX     : ascreenx;
    PLRY     : ascreeny;
BEGIN

    WITH Form^ DO
        IF (RugSaved) THEN
            PutRug(ULX,ULY,LRX,LRY,Rug);   (* Restore screen image. *)
        END;
        IF (PromptRugSaved) THEN
            GetPromptCoordinates(Form,PULX,PULY,PLRX,PLRY);
            PutRug(PULX,PULY,PLRX,PLRY,Form^.PromptRug);
        END;
        DISPOSE(TemporaryStringValue);
    END;

    DISPOSE(Form);

END CleanUpAfterForm;










    (* DOFORM *)

PROCEDURE DoForm(
                      ULX          : ascreenx;
                      ULY          : ascreeny;
                      LRX          : ascreenx;
                      LRY          : ascreeny;
                      FormID       : CARDINAL;
                      SaveScreen   : BOOLEAN;
                  VAR FormValue    : ARRAY OF AFieldValue;
                      CheckProc    : ACheckProc ): ACode;
VAR
    C          : ACode;
    FormRecord : AFormRecordPointer;
    Form       : AForm;



BEGIN
    IF (NOT Available(TSIZE(AFormRecord))) THEN                   (* 12-Feb-88 LAA *)
        ErrorPhrase(MemoryWarningMsg);
        RETURN CancelKey;
    END;

    NEW( FormRecord );
    C := CancelKey;
    IF (GetFormRecordByNumber(FormID,FormRecord^)) THEN
        Form := PrepareForForm( FormValue, FormRecord );

        (* Read the form record and set up the form on the screen. *)

        IF (Form <> NIL)  THEN
            IF (ActivateForm(Form,ULX,ULY,LRX,LRY,SaveScreen,FormValue,CheckProc)) THEN
                Form^.OpenMode := UnderOurControl;
                C := MoveOver(Form);
            END;
            CleanUpAfterForm(Form);
        END;
    END;

    DISPOSE(FormRecord);

    IF (C = CancelKey) THEN
        SendNotices(FormActive, FailureToAct, ADDRESS(FormRecord) );
    ELSE
        SendNotices(FormActive, AfterActing, ADDRESS(FormRecord) );
    END;

    RETURN C;
END DoForm;






    (* OpenForm -- An alternative to DoForm, OpenForm will create
                   the form as an output area on the screen.  Rather
                   than allowing input, it will return immediately.
                   Data may be updated via ShowValue.  When the
                   form is no longer needed on the screen, use
                   CloseForm to dispose of it. *)


PROCEDURE OpenForm(   ULX          : ascreenx;
                      ULY          : ascreeny;
                      LRX          : ascreenx;
                      LRY          : ascreeny;
                      FormHandle   : AFormHandle;
                      SaveScreen   : BOOLEAN;
                  VAR FormValue    : ARRAY OF AFieldValue;
                      CheckProc    : ACheckProc;
                  VAR Form         : AForm          ) : BOOLEAN;
VAR
   FormRecord : AFormRecordPointer;

BEGIN

        (* Get a pointer to the form definition record. *)

    GetAddressFromFormHandle(FormHandle,FormRecord);

    Form := PrepareForForm( FormValue, FormRecord );

    IF (Form = NIL) THEN RETURN FALSE; END;                       (* 12-Feb-88 LAA *)

    Form^.OpenMode := UnderUserControl;

        (* Establish the form on the screen. *)

    RETURN
        (ActivateForm(Form,ULX,ULY,LRX,LRY,SaveScreen,FormValue,CheckProc));

END OpenForm;





    (* CloseForm -- Close a form opened with OpenForm. *)

PROCEDURE CloseForm ( VAR Form : AForm );
BEGIN
    IF (Form^.OpenMode = UnderUserControl) THEN
        CleanUpAfterForm(Form);
    ELSE
        FatalError;   (* User shouldn't close a form he didn't open. *)
    END;
END CloseForm;






    (* DoFormByHandle *)

PROCEDURE DoFormByHandle(
                      ULX          : ascreenx;
                      ULY          : ascreeny;
                      LRX          : ascreenx;
                      LRY          : ascreeny;
                      FormHandle   : AFormHandle;
                      SaveScreen   : BOOLEAN;
                  VAR FormValue    : ARRAY OF AFieldValue;
                      CheckProc    : ACheckProc ): ACode;
VAR
    C           : ACode;
    Form        : AForm;
    FormRecord  : AFormRecordPointer;
BEGIN

    C := CancelKey;

    IF (OpenForm(ULX, ULY, LRX, LRY, FormHandle, SaveScreen, FormValue,
                 CheckProc, Form ) ) THEN
        C := MoveOver(Form);
        CloseForm(Form);
    END;

    GetAddressFromFormHandle(FormHandle,FormRecord);
    IF (C = CancelKey) THEN
        SendNotices(FormActive, FailureToAct, ADDRESS(FormRecord) );
    ELSE
        SendNotices(FormActive, AfterActing, ADDRESS(FormRecord) );
    END;

    RETURN C;

END DoFormByHandle;






    (* HideForm -- Reveal the previous screen image behind the
                   form. *)

PROCEDURE HideForm( Form : AForm );
BEGIN
    FatalError();
    (* Disabled Dec. 15, 1989 AJL
    IF (Form^.RugSaved) THEN
        WITH Form^ DO
            PutRug(ULX,ULY,LRX,LRY,Rug);   (* Form^.ULX, etc. *)
        END;
        Form^.RugSaved := FALSE;
    END;
    *)
END HideForm;


    (* RevealForm -- Redraw the form on the screen. *)

PROCEDURE RevealForm(           Form : AForm;
                          SaveScreen : BOOLEAN ):BOOLEAN;
BEGIN
    FatalError();
    (* Disabled Dec. 15, 1989 AJL
    IF (Form^.RugSaved) THEN
        HideForm(Form);
    END;
    IF (SaveScreenImage(Form,SaveScreen)) THEN
        RepaintForm(Form);
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
    *)
END RevealForm;




    (* MoveForm *)

PROCEDURE MoveForm(   Form         : AForm;
                      ULX          : ascreenx;
                      ULY          : ascreeny;
                      LRX          : ascreenx;
                      LRY          : ascreeny  );
VAR
    SaveScreen : BOOLEAN;
BEGIN
        (* This works much better if the rug has been saved.  If
           so, restore the screen to the way it was before form
           was showing, and then save the area under the new form
           image. *)
    FatalError();
    (* Disabled Dec. 15, 1989 AJL
    SaveScreen := Form^.RugSaved;
    HideForm(Form);
        (* Compute new screen boundaries.  Save old screen image.   Repaint form. *)
    ComputeBoundaries(Form,ULX,ULY,LRX,LRY);
    IF (RevealForm(Form,SaveScreen)) THEN; END;
    *)
END MoveForm;



    (* FindFormBoundaries -- Return the current boundaries of the
                             form. *)


PROCEDURE FindFormBoundaries(     Form         : AForm;
                              VAR ULX          : ascreenx;
                              VAR ULY          : ascreeny;
                              VAR LRX          : ascreenx;
                              VAR LRY          : ascreeny  );
BEGIN
    ULX := Form^.ULX;
    ULY := Form^.ULY;
    LRX := Form^.LRX;
    LRY := Form^.LRY;
END FindFormBoundaries;






     (*  SetFieldProtection -- Turn protection on or off. *)

PROCEDURE SetFieldProtection(    Form      : AForm;
                                 FieldNo   : AFieldNo;
                             VAR FormValue : ARRAY OF AFieldValue;
                                 On        : BOOLEAN);
VAR
    j : CARDINAL;
BEGIN
    IF (On) THEN
        INCL(FormValue[FieldNo].Private,ORD(DisplayOnly));
    ELSE
        EXCL(FormValue[FieldNo].Private,ORD(DisplayOnly));
    END;
    ShowValue(Form,FieldNo,FormValue);
END SetFieldProtection;




PROCEDURE FieldIsProtected(     Form       : AForm;
                                FieldNo : AFieldNo;
                            VAR FormValue  : ARRAY OF AFieldValue
                           ) : BOOLEAN;
BEGIN
    RETURN (DisplayOnly IN ASetOfAttributes(FormValue[FieldNo].Private));
END FieldIsProtected;








     (*  SetFieldHidden -- Turn hidden on or off. *)

PROCEDURE SetFieldHidden(    Form      : AForm;
                             FieldNo   : AFieldNo;
                         VAR FormValue : ARRAY OF AFieldValue;
                             On        : BOOLEAN);
VAR
    j : CARDINAL;
BEGIN
    IF (On) THEN
        INCL(FormValue[FieldNo].Private,ORD(Hidden));
    ELSE
        EXCL(FormValue[FieldNo].Private,ORD(Hidden));
    END;
    ShowValue(Form,FieldNo,FormValue);
END SetFieldHidden;






PROCEDURE FieldIsHidden(     Form       : AForm;
                             FieldNo : AFieldNo;
                         VAR FormValue  : ARRAY OF AFieldValue
                        ) : BOOLEAN;
BEGIN
    RETURN (Hidden IN ASetOfAttributes(FormValue[FieldNo].Private));
END FieldIsHidden;





  (*  SetFormChange -- Remember that this form has changed.  RSC 10/16/87 *)

PROCEDURE SetFormChange(     Form      : AForm   );
BEGIN
    Form^.ChangesMadeToForm := TRUE;
END SetFormChange;








PROCEDURE MaxFieldNumber (     Form : AForm ) : AFieldNo;
BEGIN
    RETURN Form^.FormRecordPointer^.MaxField;
END MaxFieldNumber;



PROCEDURE SetQueryPrompt(  Form        : AForm;
                           QueryPrompt : AQueryPromptProc );
BEGIN
    Form^.QueryPrompt := QueryPrompt;
END SetQueryPrompt;




    (* SetFormContext -- Associate an address with a form.  *)

PROCEDURE SetFormContext(    Form      : AForm;
                             Context   : ADDRESS );
BEGIN
    Form^.UserContext := Context;
END SetFormContext;



    (* QueryFormContext --

       Return the last address associated with the Form via
       SetFormContext.  If no such address, return NIL.
    *)

PROCEDURE QueryFormContext(  Form      : AForm ) : ADDRESS;
BEGIN
    RETURN Form^.UserContext;
END QueryFormContext;



    (* Put up a form that allows a user to enter a long number or
       expression.  Return the number as a string. *)



PROCEDURE DoLargerNumberForm(     Top, Bottom : ascreeny;
                                  MinDigits, MaxDigits : CARDINAL;
                              VAR StringValue : ARRAY OF CHAR ) : BOOLEAN;
VAR
    FormHandle   : AFormHandle;
    FormRecord : AFormRecordPointer;
    FormValue    : ARRAY [0..0]  OF AFieldValue;
    R            : REAL;
    Size         : CARDINAL;
    OK           : BOOLEAN;
    NumberTooBig : BOOLEAN;
    OldValue     : AStringValue;
    s            : ARRAY[0..255] OF CHAR;
BEGIN
    IF (NOT Available(TSIZE(AFormRecord)+500)) THEN                   (* 18-Nov-88 LAA *)
        ErrorPhrase(MemoryWarningMsg);
        RETURN FALSE;
    END;
    NEW(FormRecord);
    
    WITH FormRecord^ DO                                           (* 18-Nov-88 LAA *)
        ID := 9999;
        PhrasesStart := ModuleNumber+14;
        SetString(HelpKey,"NXPR");
        GetMessage(ModuleNumber+15,Title);
        MaxLine  := 0;
        MaxField := 0;
        Box := ABoxType{DoubleBox,ShadowBox};
        PromptType := SeparatePrompts;
        PromptULX := 0;
        PromptULY := 0;
        PromptLRX := maxcol;
        PromptLRY := GanttWStart - 1;
        CheckCodeSet := EmptyCodeSet;
           (* Trap and throw away the EditKey to avoid nesting. *)
        SetCodeBits(CheckCodeSet,EditKey,EditKey,TRUE);
        Table.StartField := 99;    (* no non-repeating fields. *)
                           (*         1         2         3         4         5         6         7    *)
                           (*1234567890123456789012345678901234567890123456789012345678901234567890123 *)
     (* SetString(FLine[0],'º [                                                                     ] º'); *)
        GetMessage(ModuleNumber+16,FLine[0]);
    
        WITH Fields[0] DO
            Group := 0;
            xoff := 3;  yoff := 0;
            Attributes := ASetOfAttributes{};       (* Avoid the numeric edit! *)
            FFType := FormReal;
            StLen := 69;
            Digits := MinDigits;
            SetCodeBits(CodeSet,0,MaxCode,FALSE);
        END;
    END;
    
    OK := AttachHandleToRecord(FormHandle,FormRecord^);
    
    DISPOSE(FormRecord);
    
    IF (NOT OK) THEN
        ErrorPhrase(MemoryWarningMsg);
        RETURN FALSE;
    END;
    


    Size := LengthOf(StringValue);
    
    StringToReal(StringValue,FormValue[0].RealValue,OK);
    Copy ( StringValue, OldValue );

        (* Do the form, and convert the number to a string.  Loop
           if it won't fit. *)
    
    REPEAT
        NumberTooBig := FALSE;
        OK := (DoFormByHandle( 2, Top, maxcol, Bottom,
                               FormHandle, TRUE,
                               FormValue,  NullCheckProc ) = ExitKey);
    
        IF (OK) THEN
            MakeRealString(FormValue[0],MinDigits,MaxDigits,Size,StringValue);
            Procustes(StringValue,Size);   (* Guarantee that the length is unchanged. *)

            NumberTooBig := (StringValue[1] = "*");
            IF ( NumberTooBig ) THEN
                GetMessage( ModuleNumber + 18, s ); (* Number is too big *)
                Error(s);
                Copy(OldValue, StringValue);
                StringToReal(StringValue,FormValue[0].RealValue,OK);
            END;
        END;


    UNTIL (NOT NumberTooBig);

    DiscardFormHandle( FormHandle );
    

    RETURN OK;

END DoLargerNumberForm;



PROCEDURE ChangeFormTitle( VAR Form : AForm; VAR NewTitle : ARRAY OF CHAR );
BEGIN
    Copy( NewTitle, Form^.FormRecordPointer^.Title );
END ChangeFormTitle;



BEGIN
    GuidanceMode := FALSE;
END Forms.

