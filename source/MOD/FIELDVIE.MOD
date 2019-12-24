IMPLEMENTATION MODULE FieldView;

(*  =========================================================================
    Last Edit : December 13, 1989 7:04PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        
        The One field form used by the spreadsheet view.

    MODIFICATION HISTORY:

        11-Mar-89  RSC  First version - a single form field for use by the
                        SpreadSheet View.
        20-Apr-89  RSC  Renamed to the FieldView, as per Andrew's request.
         3-Aug-89  RSC  Allow high order ASCII chars, as per David Bryan.
         9-Aug-89  RSC  1) Redisplay the line in videoformback when done
                           with any editing.  Otherwise the videoformdata
                           mode sticks sometimes.  (eg durring a MACRO)
                        2) Implement copy and paste.
        11-Aug-89  RSC  Import new procedures from LStrings rather than have
                        them implemented locally.  Import cut/paste keys from
                        Keys.Def, not from CutPaste.Def.

        13-Dec-89  RSC  Mouse support.
         6-Oct-90  AJL -Allow the AlternateEraseKey (Ctrl-End) to erase to eol. 
         5-Dec-90  AJL -Allow a double-click to act like F2.


    =========================================================================
*)



FROM Codes      IMPORT
    (* CONST *)     BitsPerBitSet,
    (* TYPE *)      ASetOfCodes, ACode;

FROM CutPaste   IMPORT
    (* PROC *)      CopyToPasteBuffer, PasteBuffer;

FROM Dialog     IMPORT
    (* PROC *)      Burp;

FROM Events     IMPORT
    (* TYPE *)      AnEvent, AnEventType,
    (* PROC *)      GetNextEvent, PushEvent;

FROM Helper     IMPORT
    (* TYPE *)      AScreenAction,
    (* PROC *)      GiveHelp;

FROM Kbio       IMPORT
    (* TYPE *)      ACursorType, ascreenx, ascreeny, avidmode, maxcol,
    (* PROC *)      GotoXY, PutString, SetCursorType;

FROM Keys       IMPORT
    (* CONST *)     Fwrd, Reverse, InsertKey, DeleteKey, BackSpace, HomeKey,
                    HelpKey, EndKey, EraseToEOLKey, EraseKey,
                    CopyToPasteKey, PasteKey, RollRight, RollLeft,
                    MouseDown, MouseStillDown, MouseUp, MouseDouble,
                    AlternateEraseKey, EditKey;

FROM Layout     IMPORT
    (* CONST *)     GanttWStart, GanttWEnd;

FROM LStrings   IMPORT
    (* PROC *)      Procustes, Remove, Insert, SubStr, TrimFront, TrimRear,
                    SetString, SetLengthOf, LengthOf, Fill, LJust, Copy,
                    InsertWithOverflow;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS, ADR;

FROM Words      IMPORT
    (* PROC *)      FindNextWord, FindPriorWord, StartOfWord, EndOfWord;




TYPE
    ACursorAttribute = (CursorOn, CursorOff, CursorResting);






(* Do Form View

    Process a single form field.  This allows any field type except a Choice
    field, given the right check proc.

        Preconditions

            StringToEdit     is the field's string value.
            LastEventSeen    is the LAST keycode that was hit.  This allows
                                for example, <HOME> to take you to the start
                                of the line, and <HOME><HOME> to take you to
                                the start of a form or form section.
            x, y             is the starting screen coordinates.
            FieldLength      is the width the form window should be.
            InsertMode       is TRUE if insert mode is in effect.
            PrecessKeys      is TRUE if you want keystrokes processed.
            CheckFieldView   is the keystroke check proc.  See the description
                                for "AFieldViewCheckProc".
            ValidCodes       is the set of keycodes that are valid for the
                                application.  Does not need to include arrows
                                or codes that are "command codes".  It is,
                                in fact, just a convienience for the check
                                proc.  The default check proc uses it as codes
                                that can be placed into the StringToEdit.
            TreatAsNumerics  is whether to apply numeric editing rules.
            FieldViewContext is the context address passed to DoFieldView.

        Postconditions

            StringToEdit    may have been modified by the check proc.  It is
                                exactly FieldLength bytes long.
            LastEventSeen   is  the last code that was processed by the check
                                proc, which could have been MODIFIED by the
                                check proc for communication with itself or
                                with the client.
            InsertMode      is  the way insert mode is currently set.

        Note:  When "ProcessKeys" is FALSE, then only these fields are
               relevant, the rest are ignored and unchanged:

               > StringToEdit
               > x, y
               > FieldLength
               > ProcessKeys

*)
PROCEDURE DoFieldView( VAR StringToEdit     : ARRAY OF CHAR;
                       VAR LastEventSeen    : AnEvent;
                           x                : ascreenx;
                           y                : ascreeny;
                           FieldLength      : CARDINAL;
                       VAR InsertMode       : BOOLEAN;
                           ProcessKeys      : BOOLEAN;
                           CheckFieldView   : AFieldViewCheckProc;
                           ValidCodes       : ASetOfCodes;
                           TreatAsNumerics  : BOOLEAN;
                           FieldViewContext : ADDRESS
                     );
VAR
    Event          : AnEvent;
    CursorPosition : INTEGER;
    Code           : CARDINAL;
    Continue       : BOOLEAN;


    (* This code was lifted (not verbatim) from "DisplayCursor" in Forms.Mod *)

    PROCEDURE ShowCursor( CursorAttribute : ACursorAttribute );
    VAR
        Cursorx     : ascreenx;
        CursorType  : ACursorType;
        Mode        : avidmode;
        CursorValue : ARRAY [0..1] OF CHAR;
    BEGIN
        Cursorx := (x + ascreenx(CursorPosition) ) - 1;

        CASE CursorAttribute OF
            CursorOn      : Mode           := cvideoformdata;
                            IF (InsertMode) THEN
                                CursorType := BlockCursor;
                            ELSE
                                CursorType := UnderlineCursor;
                            END;
          | CursorOff     : Mode           := videoformdata;
                            CursorType     := NoCursor;
          | CursorResting : Mode           := videorestingcursor;
                            CursorType     := NoCursor;
            ELSE HALT;
        END;

        SubStr(    StringToEdit, CursorValue, CursorPosition, 1 );
        PutString( CursorValue, Cursorx, y, Mode );

        GotoXY( Cursorx, y );
        SetCursorType( CursorType );

    END ShowCursor;


BEGIN
    IF (FieldLength > (maxcol - x)) THEN
        FieldLength := (maxcol - x);
    END;

    TrimFront( StringToEdit );
    Procustes( StringToEdit, FieldLength );
    IF (ProcessKeys) THEN
        CursorPosition := 1;
        LOOP
            PutString( StringToEdit, x, y, videoformdata );
            ShowCursor( CursorOn );
            GetNextEvent( Event );
            ShowCursor( CursorResting );
            IF (Event.EventType = MouseEvent) THEN
                WITH Event DO
                    Continue := (EventY = y);
                    IF (Continue) THEN
                        IF (EventCode = MouseDouble) THEN
                            EventCode := EditKey;
                            EventType := PseudoKeyboardEvent;
                            PushEvent(Event);
                        ELSIF (EventX >= x) AND (EventX < (x + FieldLength)) THEN
                            CursorPosition := (EventX - x) + 1;
                        END;
                    END;
                END;
            ELSE
                Continue := CheckFieldView( Event,
                                            LastEventSeen,
                                            StringToEdit,
                                            InsertMode,
                                            FieldLength,
                                            CursorPosition,
                                            ValidCodes,
                                            TreatAsNumerics,
                                            FieldViewContext);
            END;
            LastEventSeen := Event;   (* For next time *)
            Procustes( StringToEdit, FieldLength );

            IF (NOT Continue) THEN
                EXIT;
            END;

            (* To make life easy on the check proc, Let them increment or decrement
               the cursor position without regard to boundaries, and we will fix
               the cursor up here.  This is also why the cursor pos is an integer,
               because, say, a BACKTAB might be DEC( CursorPosition, 8 ); and this
               could cause the cursor to go less than zero.  No Problem!
            *)
            IF (CursorPosition < 1) THEN
                CursorPosition := 1;
            ELSIF (CursorPosition > INTEGER(FieldLength)) THEN
                CursorPosition := FieldLength;
            END;
        END;
        ShowCursor( CursorOff );
    END;

    PutString( StringToEdit, x, y, videoformback );

END DoFieldView;






PROCEDURE DoThePaste( VAR T     : ARRAY OF CHAR;
                      VAR Index : CARDINAL );
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


END DoThePaste;






(* Default Form View Check Proc

    A default check proc to handle the normal events.  See the description
    for "AFieldViewCheckProc", above.

    "ValidCodes" contains the codes that, if pressed, should be placed into
                 "StringToEdit".
*)
PROCEDURE DefaultFieldViewCheckProc( VAR Event            : AnEvent;
                                         LastEventSeen    : AnEvent;
                                     VAR StringToEdit     : ARRAY OF CHAR;
                                     VAR InsertMode       : BOOLEAN;
                                         FieldLength      : CARDINAL;
                                     VAR CursorPosition   : INTEGER;
                                         ValidCodes       : ASetOfCodes;
                                         TreatAsNumerics  : BOOLEAN;
                                         FieldViewContext : ADDRESS
                                    ) : BOOLEAN;
VAR
    Code               : ACode;
    CCursorPositionPtr : POINTER TO CARDINAL;
    TextToInsert       : ARRAY [0..1] OF CHAR;
    HelpMessageKey     : ARRAY [0..9] OF CHAR;
BEGIN

    Code := Event.EventCode;

    CASE Code OF
        Fwrd            : INC(CursorPosition);

      | Reverse         : DEC(CursorPosition);

      | HelpKey         : SetString( HelpMessageKey, "SPRDVIEW" );
                          GiveHelp(  HelpMessageKey,
                                     GanttWStart+1, GanttWEnd,
                                     RestoreTheScreen );

      | InsertKey       : InsertMode := (NOT InsertMode);

      | DeleteKey       : Remove( StringToEdit, CursorPosition, 1 );

      | BackSpace       : DEC(CursorPosition);
                          IF (CursorPosition > 0) THEN
                              Remove( StringToEdit, CursorPosition, 1 );
                          END;

      | HomeKey         : CursorPosition :=  -1;

      | EndKey          : TrimRear( StringToEdit );
                          CursorPosition := LengthOf(StringToEdit) + 1;

      | EraseKey,
        EraseToEOLKey,
        AlternateEraseKey : SetLengthOf( StringToEdit, CARDINAL(CursorPosition) - 1 );

      | RollRight       : CCursorPositionPtr := ADR(CursorPosition); (* Stranger than coersion *)
                          FindNextWord(  StringToEdit, CCursorPositionPtr^, " ");

      | RollLeft        : CCursorPositionPtr := ADR(CursorPosition); (* Stranger than coersion *)
                          FindPriorWord( StringToEdit, CCursorPositionPtr^, " ");

      | CopyToPasteKey  : CopyToPasteBuffer( StringToEdit );

      | PasteKey        : CCursorPositionPtr := ADR(CursorPosition); (* Stranger than coersion *)
                          DoThePaste( StringToEdit, CCursorPositionPtr^ );

    ELSE
        IF (Code < 255) AND
           ((Code MOD BitsPerBitSet) IN ValidCodes[ Code DIV BitsPerBitSet ]) THEN
            IF (InsertMode) THEN
                TextToInsert[0] := 1C;
                TextToInsert[1] := CHR(Code);
                DEC(    StringToEdit[0] ); (* Make room for the inserted char. *)
                Insert( StringToEdit, TextToInsert, CARDINAL(CursorPosition) );
            ELSE
                IF (TreatAsNumerics) THEN  (* Truncate following chars *)
                    SetLengthOf( StringToEdit, CARDINAL(CursorPosition) );
                END;
                StringToEdit[ CursorPosition ] := CHR(Code);
            END;
            INC(CursorPosition);
        ELSIF (Code >= ORD(" ")) AND (Code <= 250) THEN  (* A plausable charactor? *)
            Burp;
        ELSE
            RETURN FALSE;
        END;
    END;

    RETURN TRUE;

END DefaultFieldViewCheckProc;




BEGIN
END FieldView.
