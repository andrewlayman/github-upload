MODULE TlNewPrj;

(*  =========================================================================
    Last Edit : December 15, 1989 3:07PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

      RSC 10/19/87 - SPIKE version, based loosely on the Version 2 TlNewPrj.
      LAA 02-Feb-88  Removed use of LowFuel.
      AJL 11-17-88 - Pull phrases from phrases file.  
      KKC 28-Jul-89 - Give warning message if PERT view is active.
      03-Aug-89 LAA   Import NetworkData instead of NetWorkData.
      10-Aug-89 KKC   Add copyright message.
      22-Aug-89 KKC   use another message number for message number because
                      the message number must not contain anything in order
                      for DoOptions to work.
      09-Sep-89 LAA   Forced a return to the Gantt chart before this overlay
                      may be run.  This will prevent Assist/New from running
                      out of memory because of the PERT view being active.
      21-Sep-89 WKH   Don't "grow" boxes anymore, too slow
      29-Nov-89 RSC   When changing layouts, reset the current layout.
                      Bug # 1817.  I interpreted this to mean "do whatever
                      the Gantt Chart does".
      15-Dec-89 RSC   For mouse support, I changed GetAnyCode to GetNextEvent.

    =========================================================================
*)

FROM Allocs          IMPORT
   (* VARS *)           TaskTree;

FROM Boxes           IMPORT
   (* TYPE *)           ABoxType, ABoxAttribute,
   (* PROCS *)          DrawBox, GetInnerBoxSize, GetOuterBoxSize;

FROM ChartForms      IMPORT
   (* PROCS *)          SelectLayout;

FROM Codes           IMPORT
   (* TYPES *)          ACode;

FROM Dialog          IMPORT
                        MultipleChoiceBox, ADialogOption, FatalError, Burp,
                        Message, Error;

FROM Dispatcher      IMPORT
    (* PROC *)          Dispatch;

FROM Events          IMPORT
    (* TYPE *)          AnEvent, AnEventType,
    (* PROC *)          GetNextEvent;

FROM Kbio            IMPORT
   (* CONST *)          maxrow, maxcol,
   (* TYPES *)          ascreenx, ascreeny, avidmode,
   (* PROCS *)          PutString, EraseLn;

FROM Keys            IMPORT
    (* CONST *)         DsplyKey, MouseUp;

FROM LStrings        IMPORT
   (* PROCS *)          LengthOf, SetLengthOf, SetString, Copy;

FROM Menus           IMPORT 
   (* PROCS *)          NoYes, NoYesWithPrompts, WordNumber;

FROM Mouse           IMPORT
    (* PROC *)          CancelDoubleClick;

FROM MsgFile         IMPORT
   (* PROCS *)          GetMessage, ConcatMessage;  

FROM NetworkData            IMPORT
    (* TYPE *)                  AnActiveViewType,
    (* VAR  *)                  CurrentActiveView;

FROM RsrcEdit        IMPORT
   (* PROCS *)          EditResources;

FROM RsrcMod         IMPORT
    (* VARS *)          ResourceTree;

FROM Rugs            IMPORT
    (* TYPE *)          ARug,
    (* PROCS *)         GetRug, PutRug;

FROM RunMenu         IMPORT
    (* PROC *)          ExecuteMenu;

FROM Schedule        IMPORT
   (* VARS  *)          ScheduleSaved,
   (* PROCS *)          ScheduleForm, DoOptionsForm;

FROM Space           IMPORT
   (* PROCS *)          HeapAvailable;

FROM Tran2           IMPORT
    (* PROCS *)         EraseAll;

FROM TreeObjects     IMPORT
    (* TYPE *)          ATreeNode;




CONST
      ModuleNumber     = 26700;

      MaxTextStrings   = 8;

      GetPermissionBase     = 10;  (* For GetACompleteMessage *)
      RetryBase             = 20;
      ScheduleFormBase      = 30;
      ScheduleHelp          = 40;
      CalendarFormBase      = 50;
      CalendarHelp          = 60;
      ResourcesAndCostsBase = 70;
      ResourcesHelp         = 80;
      OptionsBase           = 90;
      OptionsHelp           = 100; (* oops! a little high for messages. *)
      LayoutsBase           = 110;
      LayoutsHelp           = 120;
      EraseScheduleBase     = 130;
      ReallyEraseBase       = 140;
      AllDone               = 150;

CONST
      SideRoom = 2;                   (* Room at sides of boxes, inside, before text. *)

TYPE  ATextBlock = RECORD
          TextCount    : CARDINAL;
          TextRug      : ARug;
          TextRugTaken : BOOLEAN; 
          Question     : ARRAY [0..maxcol+1] OF CHAR;
          TextStrings  : ARRAY [1..MaxTextStrings] OF
                         ARRAY [0..maxcol+1] OF CHAR;
      END;


VAR
    FirstTime   : BOOLEAN;
    s           : ARRAY[0..255] OF CHAR;




 (* GetACompleteMessage - Get message text for a complete message.

      This is here to allow future upgrade to using the phrases file.

      Preconditions  - Base number to use in message file.
      Postconditions - an array of text strings filled in.
 *)
PROCEDURE GetACompleteMessage( BaseNumber : CARDINAL;
                           VAR TextBlock  : ATextBlock );
VAR
   i : CARDINAL; 
   S : ARRAY [0..255] OF CHAR;


BEGIN
    WITH TextBlock DO
        TextCount := 0;

            (* The first line in the text file is the question. *)

        GetMessage(ModuleNumber+BaseNumber,Question);

            (* Subsequent lines, until a blank, are the box text. *)

        i := 0;
        LOOP
            IF (i > HIGH(TextStrings)) THEN
                EXIT;
            END;
            GetMessage( ModuleNumber+BaseNumber+1+i, S );
            IF (LengthOf(S)=0) THEN
                EXIT;
            END;
            INC(TextCount);
            Copy(S,TextStrings[ TextCount ] );
            INC(i);
        END;

    END;

END GetACompleteMessage;



 (* WhitherGoesTextBlock - where does the text block go on the screen,
                           given a desired row?

    Preconditions  - TextBlock   is the text to examine.
                     Row         is the suggested row.  if too large, scale
                                    it back until it is not too large.
    Postconditions - Row         is the row to put the box on.
                     MaxRow      is the last row to put the box on.
                     Col         is the col to start, so the text is centered.
                     MaxCol      is the last col, including room for the box.
 *)
PROCEDURE WhitherGoesTextBlock( VAR TextBlock : ATextBlock;
                                VAR Row,
                                    MaxRow    : ascreeny;
                                VAR Col,
                                    MaxCol    : ascreenx);
VAR
    i,
    Length,
    DeltaCol,
    DeltaRow,
    MaxLength   : CARDINAL;
    TRow        : ascreeny;
BEGIN
       Col := 2;   TRow := 2;   (* See how much room the box takes. *)
    MaxCol := 2; MaxRow := 2;
    GetOuterBoxSize( Col, TRow, MaxCol, MaxRow, ABoxType{DoubleBox, ShadowBox} );
    DeltaCol  := MaxCol - Col;
    DeltaRow  := MaxRow - TRow;
    MaxLength := 0;
    WITH TextBlock DO
        FOR i := 1 TO TextCount DO
            Length := LengthOf(TextStrings[i])+(2*SideRoom);
            IF (Length > MaxLength) THEN
                MaxLength := Length;
            END;
        END;
        INC( MaxLength, DeltaCol ); (* Allow for shadow box sides *)
            (* Keep within range. *)
        IF (MaxLength >= maxcol) THEN
            MaxLength := maxcol-1;
        END;
        Col := (maxcol - MaxLength) DIV 2;
        i   := TextCount + DeltaRow; (* Allow for shadowbox top and bottom. *)
        IF ((i + CARDINAL(Row) - 1) > maxrow) THEN
            Row := (maxrow - i) + 1;
        END;
        MaxRow := Row + (i - 1);
        MaxCol := Col + (MaxLength - 1);
    END;
END WhitherGoesTextBlock;




  (* Display Complete Message - Display a paragraph on the screen.

       Preconditions  - TextBlock  is the test to display.
                      - Row        is the row to put it on.
       Postconditions - Screen has message lines on it.
  *)
PROCEDURE DisplayCompleteMessage( VAR TextBlock  : ATextBlock;
                                      Row        : ascreeny );
VAR
    MaxCol,
    Col       : ascreenx;
    MaxRow    : ascreeny;
    i         : CARDINAL;
    Title     : ARRAY [0..1] OF CHAR;
BEGIN
    WhitherGoesTextBlock( TextBlock, Row, MaxRow, Col, MaxCol );
    WITH TextBlock DO
        TextRugTaken := GetRug( Col, Row, MaxCol, MaxRow, TextRug );
        SetLengthOf(Title, 0);
        DrawBox( Col, Row, MaxCol, MaxRow, ABoxType{DoubleBox, ShadowBox}, Title, videobright );
        GetInnerBoxSize( Col, Row, MaxCol, MaxRow, ABoxType{DoubleBox, ShadowBox} );
        FOR i := 1 TO TextCount DO
            PutString( TextStrings[i], Col+SideRoom, Row, videobright );
            IF (i <> TextCount) THEN
                INC( Row );
            END;
        END;
    END;
END DisplayCompleteMessage;


  (* Erase Complete Message - Erase a text block from the screen.

       Preconditions  - TextBlock  is the text to erase.
                      - Row        is the row to put it on.
       Postconditions - Screen area that could hold text is erased.
  *)
PROCEDURE EraseCompleteMessage( VAR TextBlock : ATextBlock;
                                    Row       : ascreeny );
VAR
    MaxRow  : ascreeny;
    i       : CARDINAL;
    MaxCol,
    Col     : ascreenx;
BEGIN
    WITH TextBlock DO
        WhitherGoesTextBlock( TextBlock, Row, MaxRow, Col, MaxCol );
        IF (TextRugTaken) THEN
            PutRug( Col, Row, MaxCol, MaxRow, TextRug );
        END;
    END;
END EraseCompleteMessage;








 (* Ask - get a complete message and ask the question.  Return the result
           of that question.

     Preconditions  - MessageNumber is where to start in the phrases.
     Postconditions - RETURN is TRUE iff they say Yes to the prompt.

  *)
PROCEDURE Ask( MessageNumber : CARDINAL) : BOOLEAN;
VAR
    TextBlock : ATextBlock;
    ok        : BOOLEAN;
BEGIN
    GetACompleteMessage( MessageNumber, TextBlock );
    DisplayCompleteMessage( TextBlock, maxrow );
    ok := (NoYes( TextBlock.Question ));
    EraseCompleteMessage( TextBlock, maxrow );
    RETURN ok;
END Ask;



 (* Get Permission  - See if they really want to set up a new schedule.

     Preconditions  - There may be a schedule in memory that we wil erase
                      FirstTime is if this new schedule has yet to be set up.

     Postconditions - RETURN TRUE if continue, FALSE if leave this overlay.
 *)

PROCEDURE GetPermission( FirstTimeMessageBase : CARDINAL;
                         NextTimeMessageBase  : CARDINAL;
                         FirstTime            : BOOLEAN ) : BOOLEAN;
VAR
    TasksInMemory,
    RsrcsInMemory,
    ok              : BOOLEAN;
    s               : ARRAY [0..1] OF CHAR;
BEGIN
    IF (FirstTime) THEN
        ok := (Ask( FirstTimeMessageBase ));
        IF (ok) THEN
            TasksInMemory := (TaskTree^.Methods^.GetFirst (TaskTree) <> NIL);    (* There are existing tasks left over. *)
            RsrcsInMemory := (ResourceTree^.Methods^.GetFirst (ResourceTree) <> NIL);
            IF (TasksInMemory OR RsrcsInMemory) AND (Ask( EraseScheduleBase )) THEN
                ok := (ScheduleSaved OR Ask( ReallyEraseBase ));
                IF (ok) THEN
                    EraseAll();
                    SetLengthOf(s,0);
                    Message(s);
                END;
            END;
        END;
    ELSE
        ok := (Ask( NextTimeMessageBase  ));
    END;
    RETURN ok;
END GetPermission;




PROCEDURE DoScheduleForms( MessageBase : CARDINAL );
VAR
    Code      : ACode;
    TextBlock : ATextBlock;
BEGIN
    IF (Ask( MessageBase )) THEN
        GetACompleteMessage( ScheduleHelp, TextBlock );
        DisplayCompleteMessage( TextBlock, 6 );
        Code := ScheduleForm();
        EraseCompleteMessage( TextBlock, 6 );
    END;
END DoScheduleForms;



PROCEDURE DoCalendarForms( MessageBase : CARDINAL );
VAR
    s         : ARRAY [0..9] OF CHAR;
    TextBlock : ATextBlock;
BEGIN
    IF (Ask( MessageBase )) THEN
        SetString(s,"TLCALNDR");               (* CONSTANT *)
        GetACompleteMessage( CalendarHelp, TextBlock );
        DisplayCompleteMessage( TextBlock, 6 );
        ExecuteMenu( s, s );
        EraseCompleteMessage( TextBlock, 6 );
    END;
END DoCalendarForms;



PROCEDURE DoResourcesAndCosts( MessageBase : CARDINAL );
VAR
    Node      : ATreeNode;
    ok        : BOOLEAN;
    TextBlock : ATextBlock;
BEGIN
    IF (Ask( MessageBase )) THEN
        Node := NIL;
        GetACompleteMessage( ResourcesHelp, TextBlock );
        DisplayCompleteMessage( TextBlock, 3 );
        EditResources();
        EraseCompleteMessage( TextBlock, 3 );
    END;
END DoResourcesAndCosts;



PROCEDURE DoOptions( MessageBase : CARDINAL );
VAR
    TextBlock : ATextBlock;
BEGIN
    IF (Ask( MessageBase )) THEN
        GetACompleteMessage( OptionsHelp, TextBlock );
        DisplayCompleteMessage( TextBlock, 3 );
        DoOptionsForm();
        EraseCompleteMessage( TextBlock, 3 );
    END;
END DoOptions;




PROCEDURE DoLayouts( MessageBase : CARDINAL );
VAR
    Code      : ACode;
    TextBlock : ATextBlock;
BEGIN
    IF (Ask( MessageBase )) THEN
        GetACompleteMessage( LayoutsHelp, TextBlock );
        DisplayCompleteMessage( TextBlock, 1 );

        (* 29-Nov-89 RSC Code from DISPATCH to do layouts. *)

        Dispatch( DsplyKey );

        EraseCompleteMessage( TextBlock, 1 );
    END;
END DoLayouts;




PROCEDURE Done();
VAR
    Event     : AnEvent;
    TextBlock : ATextBlock;
    Copyright : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    GetACompleteMessage( AllDone, TextBlock );
    DisplayCompleteMessage( TextBlock, 8 );

    REPEAT
        GetNextEvent( Event );
    UNTIL (Event.EventType <> MouseEvent) OR
          (Event.EventCode =  MouseUp);
    CancelDoubleClick();

    EraseCompleteMessage(   TextBlock, 8 );
END Done;





BEGIN

  (* Is there enough memory to do any of this? *)
    IF (NOT HeapAvailable()) THEN RETURN; END;

    FirstTime := TRUE;

    IF ( CurrentActiveView = Pertview ) THEN
        GetMessage( ModuleNumber + 97, s);      (* KKC Aug 23, 1989 *)
        Error(s);
        RETURN;                                                   (* 09-Sep-89 LAA *)
    END;

    WHILE (GetPermission( GetPermissionBase, RetryBase, FirstTime)) DO
        FirstTime := FALSE;
        DoScheduleForms(ScheduleFormBase);
        DoCalendarForms(CalendarFormBase);
        DoResourcesAndCosts(ResourcesAndCostsBase);
        DoOptions(OptionsBase);
        DoLayouts(LayoutsBase);
    END;

    IF (NOT FirstTime) THEN     
        Done();             (* Call Done only if we have got at least one *)
                            (* permission                                 *)
    END;

END TlNewPrj.
