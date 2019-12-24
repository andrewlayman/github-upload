MODULE TLWBSMan;


  (*    Display and process WBS Generator Manager form.

        MODIFICATION HISTORY:

         09-Apr-89  MWP  In the beginning...
          3-Jul-89  MWP  Fixed bug causing Alwyas Show not being able to
                         be set to Yes beyond the fifth segment level.
          3-Jul-89  MWP  If user selects F10 to exit form, check if
                         Always Show is set to Yes that the Null character
                         is not blank.
         11-Jul-89  MWP  If a blank row is encountered between to valid
                         rows on the WBS form, get rid of it. ( The blank
                         row, of course. )
         17-Jul-89  MWP  Re-structuring of the WBS form. Remove literal
                         addressing of form values.
         28-Jul-89  MWP  Do not check for CheckFieldKey.
         29-Jul-89  MWP  Check for duplicate characters in Character Seq. on
                         field exit instead of on form exit.
         10-Aug-89  KKC  Add copyright message.
         23-Aug-89  MWP  Set Always show and Null fields of first WBS Segment
                         to Yes, and '0' with the fields protected. Hide the
                         field.
         29-Aug-89  MWP  If Always Show is set to No, set all subsequent
                         Always Show fields to hidden and protected.
         12-Sep-89  LAA  Removed import of Holder (no longer used).
         12-Oct-89  MWP  Fixed problem with always show.
         19-Oct-89  MWP  If an Always Show field is set to No, all following
                         Always Show fields should always stay hidden and
                         protected. It was possible to change or define
                         a new character sequence field and have the always
                         show field become unprotected.
         28-Nov-89  MWP  Remove spaces from Prefix, Char Seq, Fill and Follow
                         by fields.
         30-Nov-89  LAA  Did a little optimization of the RemoveSpaces proc.
                         I also changed some constants in the check proc which
                         refered to specific fields, to the constant 
                         identifiers for those fields.
         14-Sep-91  EGK  Set ScheduleSaved to FALSE when done.
  *)

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState;

FROM Dialog         IMPORT
    (* PROC *)              Burp, Error;

FROM Foreign        IMPORT
    (* PROC *)              DoDash;

FROM Forms          IMPORT
    (* TYPE *)              AFieldValue, AForm, ACheckReason,
    (* PROCS *)             DoForm, ShowValue, SetFieldProtection,SetFieldHidden;

FROM FormCon        IMPORT
    (* TYPE *)              AFieldNo;

FROM Keys           IMPORT
    (* CONST *)             ExitKey;

FROM Kbio           IMPORT
    (* CONST *)             maxrow, maxcol;

FROM Layout         IMPORT
    (* CONST *)             GanttWStart, GanttWEnd;

FROM LStrings       IMPORT
    (* PROCS *)             SetString, LJust, Copy, TrimRear,
                            SetLengthOf, LengthOf,
                            TrimFront, Search;

FROM MsgFile       IMPORT
    (* PROC *)              GetMessage;

FROM Schedule               IMPORT 
    (* VAR   *)                 ScheduleSaved;

FROM Space          IMPORT
    (* PROCS *)             HeapAvailable, ALLOCATE, DEALLOCATE;

FROM WBSCommon      IMPORT
    (* CONST *)             SizeMinColOffset,
                            SizeMaxColOffset,
                            CharSeqColOffset,
                            StartWithColOffset,
                            AlwaysShowColOffset,
                            NullColOffset,
                            FollowByColOffset,
                            MaxWbsRows,
                            MinWbsSize,
                            MaxWbsSize,
                            MaxFormEntriesPerRow,
                            MaxFormEntries,
                            WBSModuleNumberBase,
    (* TYPE *)              AShowMethod,
                            AnWBSFormsValue,
                            AWBSPtr,
    (* PROC *)              SetWBSValues, SaveWBSValues, InitializeWBSColumns;

FROM SYSTEM         IMPORT
    (* THINGS *)            SIZE, TSIZE, ADDRESS, ADR;


CONST
    WBSFORMID     =   64;
    ModuleNumber  =   WBSModuleNumberBase + 10;
    AlwaysShowOff =   999;


 (* Check The Form - Standard Form Check procedure.  *)
PROCEDURE CheckTheForm(    Form         : AForm;
                           FieldNo      : AFieldNo;
                       VAR FormValue    : ARRAY OF AFieldValue;
                           CheckReason  : ACheckReason;
                       VAR Code         : CARDINAL
                                                      ) : BOOLEAN;
CONST
    PREFIX                  = 0;
    CHARCOUNT               = 1;
    CHARSEQ                 = 0;
    START                   = 1;
    SIZEMIN                 = 2;
    SIZEMAX                 = 3;
    SHOW                    = 4;
    NULL                    = 5;
    FOLLOW                  = 6;
    MAXFIELD                = 7;
    ENDFIELDS               = ( 14 * MAXFIELD ) + 2;
VAR
    Column,
    WhatField,
    RowEntry,
    Loop, Sum               : CARDINAL;
    Result,
    Protection,
    NonValidRowEncountered  : BOOLEAN;
    Message                 : ARRAY [0..255] OF CHAR;

    (* Starting at the current row to end of rows, set the  Null field
       to hidden and protected.
       For Current row + 1 to end of rows, set the Always Show field
       to hidden and protcted.
    *)
    PROCEDURE SetShowToFalseToEnd ( RowStartFieldNo : CARDINAL );
    VAR
       Loop                 :  CARDINAL;
    BEGIN
           FOR Loop := RowStartFieldNo TO ENDFIELDS BY MAXFIELD DO
               FormValue[Loop].CardValue := 0;
               ShowValue( Form, Loop, FormValue );

               (* Don't protect the current row's Always Show field. *)
               IF ( Loop > RowStartFieldNo ) THEN                         (* 29-Aug-89 MWP *)
                  SetFieldProtection(Form,Loop,FormValue,TRUE);
                  SetFieldHidden    (Form,Loop,FormValue,TRUE);
                  FormValue[Loop].CardValue := AlwaysShowOff;
               END;

               SetFieldProtection(Form,Loop + 1,FormValue,TRUE);
               SetFieldHidden    (Form,Loop + 1,FormValue,TRUE);
           END;

    END SetShowToFalseToEnd;


    (* Check all previous occurences of Always Show for No values.
       If we find a No, return TRUE.
    *)
    PROCEDURE ArePreviousShowsSetToFalse ( Row : CARDINAL ) : BOOLEAN;
    VAR
       Loop                 :  CARDINAL;
    BEGIN
           FOR Loop := ( SHOW + 2 + MAXFIELD ) TO FieldNo - MAXFIELD BY MAXFIELD DO  (* 21-Aug-89 MWP *)
               (* Make sure this isn't a blank row first! *)
               IF (FormValue[Loop - 4].CharValue^[0] > 0C) AND
                  (FormValue[Loop].CardValue = 0) THEN
                   RETURN TRUE;
               END;
           END;
           RETURN FALSE;

    END ArePreviousShowsSetToFalse;


    PROCEDURE  ProtectAllRow ( RowStartFieldNo : CARDINAL );
    VAR
       Loop                 :  CARDINAL;
    BEGIN

        FOR Loop := RowStartFieldNo TO RowStartFieldNo + FollowByColOffset DO
            SetFieldProtection(Form,Loop,FormValue,TRUE);
            SetFieldHidden    (Form,Loop,FormValue,TRUE);
        END;

        FormValue[ RowStartFieldNo + AlwaysShowColOffset ].CardValue := AlwaysShowOff;

        SetFieldProtection(Form,RowStartFieldNo + CharSeqColOffset,FormValue,FALSE);
        SetFieldHidden    (Form,RowStartFieldNo + CharSeqColOffset,FormValue,FALSE);

    END ProtectAllRow;


    PROCEDURE  UnProtectAllRow ( RowStartFieldNo : CARDINAL);
    VAR
       Loop                 :  CARDINAL;
    BEGIN

        FOR Loop := RowStartFieldNo TO RowStartFieldNo + FollowByColOffset DO
            SetFieldProtection(Form,Loop,FormValue,FALSE);
            SetFieldHidden    (Form,Loop,FormValue,FALSE);
        END;

        IF (FormValue[RowStartFieldNo + AlwaysShowColOffset].CardValue <> 1) THEN
            SetFieldProtection ( Form,
                                 RowStartFieldNo + NullColOffset,
                                 FormValue,
                                 TRUE );
            SetFieldHidden ( Form,
                             RowStartFieldNo + NullColOffset,
                             FormValue,
                             TRUE );



            (* If we are on at least the second row, check the previous row
               to see if it is both valid, ( i.e not blank ) and if it's
               Always Show is set to Yes, then do not protect this rows
               Always Show.
            *)
            IF ( RowStartFieldNo > MAXFIELD + 2 ) THEN

               IF (FormValue[ ( RowStartFieldNo - MAXFIELD ) + AlwaysShowColOffset].CardValue <> 1) THEN
                   SetFieldProtection ( Form,
                                        RowStartFieldNo + AlwaysShowColOffset,
                                        FormValue,
                                        TRUE );
                   SetFieldHidden ( Form,
                                    RowStartFieldNo + AlwaysShowColOffset,
                                    FormValue,
                                    TRUE );
               END;
            END;
        END;

        IF ( RowStartFieldNo < MAXFIELD + 2 ) THEN
          (* Set Always show and Null fields at first level to protected.
             By definition, they are always set to Yes, and something
          *)
          SetFieldProtection(Form,6,FormValue,TRUE);                (* 21-Aug-89 MWP *)
          SetFieldProtection(Form,7,FormValue,TRUE);
          SetFieldHidden    (Form,6,FormValue,TRUE);
          SetFieldHidden    (Form,7,FormValue,TRUE);
        END;

    END UnProtectAllRow;


    PROCEDURE TestStartWithChar ( RowStartFieldNo : CARDINAL) : BOOLEAN;
    VAR
       j                    : CARDINAL;
       StartWithChar,
       CharSeqChar          : CHAR;
       ExpandedSeq          : ARRAY[0..255] OF CHAR;
    BEGIN

        (* If there is no Start With character entered, or the
           Start With character is not the first or second character
           in the Character Sequence field, return FALSE. *)

        IF (FormValue[ RowStartFieldNo + StartWithColOffset ].CharValue^[0] = 0C) THEN
            RETURN FALSE;
        ELSE
            StartWithChar := FormValue[ RowStartFieldNo + StartWithColOffset ].CharValue^[1];
            CharSeqChar   := FormValue[ RowStartFieldNo + CharSeqColOffset ].CharValue^[1];

            IF ( StartWithChar <> CharSeqChar ) AND
               ( ORD(StartWithChar) <> ORD(CharSeqChar) + 1 ) THEN
               RETURN FALSE;
            END;

            IF ( StartWithChar = CharSeqChar ) THEN
               FormValue[ RowStartFieldNo + StartWithColOffset ].CardValue := 0;
            ELSE
               FormValue[ RowStartFieldNo + StartWithColOffset ].CardValue := 1;
            END;
        END;

        RETURN TRUE;

    END TestStartWithChar;


    PROCEDURE ResetStartWithChar ( RowStartFieldNo : CARDINAL);
    VAR
       j                    : CARDINAL;
       CharSeqChar          : CHAR;
       ExpandedSeq          : ARRAY[0..255] OF CHAR;

    BEGIN
       CharSeqChar   := FormValue[ RowStartFieldNo + CharSeqColOffset ].CharValue^[1];
       FormValue[ RowStartFieldNo + StartWithColOffset ].CardValue := 0;

       (* Test if the first value is numeric or not. We are trying to
          show a small modicum of intelligence here.
       *)
       IF ( ORD(CharSeqChar) >= 48 ) AND
          ( ORD(CharSeqChar) <= 57 ) THEN

          j := 1;

          DoDash ( FormValue[ RowStartFieldNo + CharSeqColOffset ].CharValue^,
                   ExpandedSeq,
                   j );

          IF ( j > 1 ) THEN
             CharSeqChar := ExpandedSeq[2];
             FormValue[ RowStartFieldNo + StartWithColOffset ].CardValue := 1;
          ELSE
             CharSeqChar := ExpandedSeq[1];
          END;
       END;

       SetLengthOf ( FormValue[ RowStartFieldNo + StartWithColOffset ].CharValue^, 1 );

       FormValue[ RowStartFieldNo + StartWithColOffset ].CharValue^[1] := CharSeqChar;
       ShowValue( Form, RowStartFieldNo + StartWithColOffset, FormValue );

    END ResetStartWithChar;


    PROCEDURE  ValidateCharSeq ( RowStartFieldNo : CARDINAL ) : BOOLEAN;
    VAR
       j                    : CARDINAL;
       s                    : ARRAY[0..255] OF CHAR;
       MatchSeq             : ARRAY [0..2] OF CHAR;
    BEGIN

          j := 1;

          DoDash ( FormValue[ RowStartFieldNo + CharSeqColOffset ].CharValue^,
                   s,
                   j );

          IF ( j <= 2 ) THEN
              GetMessage( ModuleNumber + 2, s );
              Error ( s );
              RETURN FALSE;
          END;

          s[0] := CHR(j - 1);

          SetString ( MatchSeq, ".." );

          (* We have already examined the first value. *)
          j := 1;

          j := Search ( s,
                        MatchSeq,
                        j );

          IF ( j > 0 ) THEN
              GetMessage( ModuleNumber + 3, s );
              Error ( s );
              RETURN FALSE;
          END;

          RETURN TRUE;
    END ValidateCharSeq;


    PROCEDURE AdjustMinAndMaxValues ( RowStartFieldNo: CARDINAL );
    BEGIN
        IF (FormValue[ RowStartFieldNo + SizeMaxColOffset ].CardValue = 0 ) AND
           (FormValue[ RowStartFieldNo + SizeMinColOffset ].CardValue = 0 ) THEN
            FormValue[ RowStartFieldNo + SizeMaxColOffset ].CardValue := 2;
            ShowValue( Form, RowStartFieldNo + SizeMaxColOffset, FormValue );
            FormValue[ RowStartFieldNo + SizeMinColOffset ].CardValue := 2;
            ShowValue( Form, RowStartFieldNo + SizeMinColOffset, FormValue );
        END;

    END AdjustMinAndMaxValues;

    PROCEDURE EnsureNullNotInCharSeq ( RowStartFieldNo : CARDINAL ) : BOOLEAN;
    VAR
        j                   : CARDINAL;
        ExpandedFormSeq     : ARRAY [0..255] OF CHAR;
    BEGIN
        IF ( LengthOf ( FormValue[ RowStartFieldNo + NullColOffset ].CharValue^) > 0 ) THEN

            IF ( FormValue[ RowStartFieldNo + CharSeqColOffset ].CharValue^[1] =
                 FormValue[ RowStartFieldNo + NullColOffset ].CharValue^[1] ) THEN
                 RETURN FALSE;
            END;


            j := 1;

            DoDash ( FormValue[ RowStartFieldNo + CharSeqColOffset ].CharValue^,
                     ExpandedFormSeq,
                     j );

            ExpandedFormSeq[0] := CHR(j - 1);


            (* We have already examined the first value. *)
            j := 2;

            j := Search ( ExpandedFormSeq,
                          FormValue[ RowStartFieldNo + NullColOffset ].CharValue^,
                          j );

            IF ( j > 0 ) THEN
                RETURN FALSE;
            END;
        END;

        RETURN TRUE;
    END EnsureNullNotInCharSeq;


    PROCEDURE CheckFollowByForWildCard ( RowStartFieldNo : CARDINAL ) : BOOLEAN;
    VAR
        i, j,
        Len                 :  CARDINAL;
        CharSeq             :  ARRAY [0..255] OF CHAR;
        MatchSeq            :  ARRAY [0..1] OF CHAR;
        ok                  :  BOOLEAN;
    BEGIN

        Len := LengthOf ( FormValue[ RowStartFieldNo + FollowByColOffset ].CharValue^ );

        j := 1;

        DoDash ( FormValue[ RowStartFieldNo + CharSeqColOffset ].CharValue^,
                 CharSeq,
                 j );

        CharSeq[0] := CHR(j - 1);

        SetLengthOf ( MatchSeq, 1 );

        ok := FALSE;
        i := 1;

        LOOP
            IF ( i > Len ) THEN
               EXIT
            END;

            IF ( FormValue[ RowStartFieldNo + FollowByColOffset ].CharValue^[i] <> '?' ) THEN

               MatchSeq[ 1 ] := FormValue[ RowStartFieldNo + FollowByColOffset ].CharValue^[i];

               j := 1;

               j := Search ( CharSeq,
                             MatchSeq,
                             j );

               IF ( j = 0 ) THEN
                   ok := TRUE;
                   EXIT;
               END;
            END;
            INC(i);
        END;

        RETURN ok;

    END CheckFollowByForWildCard;

    PROCEDURE SetCharacterLenFld ();
    BEGIN
       Sum := 0;
       Sum := Sum + LengthOf ( FormValue[0].CharValue^ );

       FOR Loop := 2 TO 99 BY MAXFIELD DO
          IF ( LengthOf ( FormValue[ Loop + CharSeqColOffset ].CharValue^ ) > 0 ) THEN
            Sum := Sum + FormValue[ Loop + SizeMaxColOffset ].CardValue;
            Sum := Sum + LengthOf ( FormValue[ Loop + FollowByColOffset ].CharValue^ );
          END;
       END;

       FormValue[ 1 ].CardValue := Sum;
       SetFieldProtection(Form,1,FormValue,FALSE);
       ShowValue( Form, 1, FormValue );
       SetFieldProtection(Form,1,FormValue,TRUE);

    END SetCharacterLenFld;

    PROCEDURE  CheckForDuplicateCharacters ( CharSeq : ARRAY OF CHAR ) : BOOLEAN;
    VAR
        i, j, CharLen       : CARDINAL;
        Holding             : ARRAY [0..255] OF BOOLEAN;
        s                   : ARRAY [0..255] OF CHAR;
    BEGIN
       FOR i := 0 TO 255 DO
          Holding[ i ] := FALSE;
       END;

       j := 1;

       DoDash ( CharSeq,
                s,
                j );

       IF ( j = 0 ) THEN
           GetMessage( ModuleNumber + 2, s );
           Error ( s );
           RETURN FALSE;
       END;

       s[0] := CHR(j - 1);

       CharLen := LengthOf ( s );

       FOR i := 0 TO CharLen DO
          IF ( Holding[ ORD(s[i]) ] = TRUE ) THEN
             (* Holding[] has been loaded with this value previously *)
             RETURN FALSE;
          ELSE
             Holding[ ORD(s[i]) ] :=TRUE;
          END;
       END;

       RETURN TRUE;
    END CheckForDuplicateCharacters;



    PROCEDURE  FindNextAlwaysShowToUnHide ();
    VAR
        FieldNo, Column,
        Cycle : CARDINAL;
        NextValid : BOOLEAN;
    BEGIN
        Cycle   := 0;
        FieldNo := 13;
        Column  := 9;
        NextValid := FALSE;

        WHILE ( FieldNo + Cycle < ENDFIELDS ) DO
           IF ( LengthOf ( FormValue[Column + Cycle].CharValue^ ) > 0) THEN
              (* If we find an Always Show set to No, leave. There are not
                 supposed to be any following Always Show fields opened.
              *)
              IF ( FormValue[ FieldNo + Cycle ].CardValue = 0 ) THEN   (* 19-Oct-89 MWP*)
                   RETURN;
              END;
              IF ( FormValue[ FieldNo + Cycle ].CardValue <> AlwaysShowOff ) AND
                 ( NOT NextValid ) THEN
                     NextValid := TRUE;
              ELSE
                 IF ( FormValue[ FieldNo + Cycle ].CardValue = AlwaysShowOff ) THEN
                    FormValue[ FieldNo + Cycle ].CardValue := 0;
                    SetFieldProtection( Form,
                                        FieldNo + Cycle,
                                        FormValue,
                                        FALSE );
                    SetFieldHidden ( Form,
                                     FieldNo + Cycle,
                                     FormValue,
                                     FALSE );

                    RETURN;
                 END;
              END;
           END;
           Cycle := Cycle + MAXFIELD;
        END;

    END FindNextAlwaysShowToUnHide;

    PROCEDURE  NoMoreAlwaysShow () : BOOLEAN;
    VAR
        Column,
        Cycle : CARDINAL;
        NextValid : BOOLEAN;
    BEGIN

        Cycle   := MAXFIELD;
        Column  := FieldNo - AlwaysShowColOffset;
        NextValid := FALSE;

        WHILE ( FieldNo + Cycle < ENDFIELDS ) DO
           IF ( LengthOf ( FormValue[Column + Cycle].CharValue^ ) > 0) THEN
              IF ( FormValue[ FieldNo + Cycle ].CardValue <> AlwaysShowOff ) THEN
                 RETURN TRUE;
              END;
           END;
           Cycle := Cycle + MAXFIELD;
        END;

        RETURN FALSE;

    END NoMoreAlwaysShow;

    PROCEDURE  RemoveSpaces ( VAR Input : ARRAY OF CHAR );        (* 28-Nov-89 MWP *)
    VAR
        i, j, k : CARDINAL;
    BEGIN

        i := LengthOf ( Input );
        k := 0;

        FOR j := 1 TO i DO                                        (* 30-Nov-89 LAA *)
           IF ( Input[j] <> ' ' ) THEN
              INC(k);
              Input[k] := Input[j];
           END;
        END;
        SetLengthOf(Input, k);

    END RemoveSpaces;



BEGIN
    Code   := 0;
    Result := TRUE;

    WhatField := FieldNo;


    IF ( FieldNo > CHARCOUNT ) THEN                               (* 30-Nov-89 LAA *)
       DEC(WhatField);
       DEC(WhatField);
       WhatField := WhatField MOD MAXFIELD;
    END;

    IF (CheckReason = CheckFormEntry) THEN

       IF ( FieldNo = PREFIX ) OR ( FieldNo = CHARCOUNT ) THEN
          SetFieldProtection(Form,CHARCOUNT,FormValue,TRUE);
          (* Set Always show and Null fields at first level to protected.
             By definition, they are always set to Yes, and something
          *)
          SetFieldProtection(Form,FOLLOW,FormValue,TRUE);                (* 21-Aug-89 MWP *)  (* 30-Nov-89 LAA *)
          SetFieldProtection(Form,MAXFIELD,FormValue,TRUE);
          SetFieldHidden    (Form,FOLLOW,FormValue,TRUE);
          SetFieldHidden    (Form,MAXFIELD,FormValue,TRUE);
          RETURN TRUE;
       END;
    END;

    IF ( CheckReason = CheckFieldEntry ) THEN
       RETURN TRUE;
    END;

    IF ( CheckReason = CheckFieldExit ) THEN                      (* 28-Jul-89 MWP *)
       IF ( WhatField = AlwaysShowColOffset ) THEN
          IF ( FormValue[FieldNo].CardValue = 1 ) THEN
             IF ( NOT NoMoreAlwaysShow () ) THEN
                FindNextAlwaysShowToUnHide ();
             END;
          END;
       END;
       RETURN TRUE;
    END;

    IF ( FieldNo = PREFIX ) THEN                                  (* 30-Nov-89 LAA *)

       RemoveSpaces ( FormValue[FieldNo].CharValue^ );            (* 28-Nov-89 MWP *)
       ShowValue( Form, FieldNo, FormValue );

       SetCharacterLenFld ();
       RETURN TRUE;
    END;

    IF ( FieldNo = CHARCOUNT ) THEN                               (* 30-Nov-89 LAA *)

       SetCharacterLenFld ();
       RETURN TRUE;
    END;

    IF ( CheckReason = CheckFormExit ) THEN

       Sum := 0;
       Sum := Sum + LengthOf ( FormValue[0].CharValue^ );

       FOR Loop := 2 TO 99 BY MAXFIELD DO
          IF ( LengthOf ( FormValue[ Loop + CharSeqColOffset ].CharValue^ ) > 0 ) THEN
            Sum := Sum + FormValue[ Loop + SizeMaxColOffset ].CardValue;
            Sum := Sum + LengthOf ( FormValue[ Loop + FollowByColOffset ].CharValue^ );
          END;

          IF ( FormValue[Loop + AlwaysShowColOffset].CardValue <> 0) AND
             ( LengthOf ( FormValue[ Loop + NullColOffset ].CharValue^) = 0 ) THEN
                GetMessage ( ModuleNumber + 5, Message );
                Error ( Message );
                RETURN FALSE;
          END;
       END;

       IF ( Sum > MaxWbsSize ) THEN
          GetMessage( ModuleNumber + 1, Message );
          (* "Field totals exceed WBS character limit" *)
          Error ( Message );
          RETURN FALSE;
       END;
       RETURN TRUE;
    END;

    CASE WhatField OF
         SIZEMIN :
           Column := FieldNo - SizeMinColOffset;

           IF ( ( FormValue[FieldNo].CardValue < MinWbsSize ) OR
                ( FormValue[FieldNo].CardValue > MaxWbsSize ) ) AND
                ( LengthOf ( FormValue[ Column + CharSeqColOffset ].CharValue^ ) <> 0 ) THEN
                 Burp ();
                 Result := FALSE;
           ELSE
               IF ( FormValue[FieldNo].CardValue >
                    FormValue[ Column + SizeMaxColOffset ].CardValue ) THEN
                   FormValue[ Column + SizeMaxColOffset ].CardValue := FormValue[FieldNo].CardValue;
                   ShowValue( Form, Column + SizeMaxColOffset , FormValue );
               END;

               IF ( FormValue[ FieldNo ].CardValue <>
                    FormValue[ Column + SizeMaxColOffset ].CardValue ) THEN
                  IF ( FormValue[ Column + FollowByColOffset ].CharValue^[0] = 0C ) THEN
                     SetString (FormValue[ Column + FollowByColOffset ].CharValue^, ".");
                     ShowValue( Form, Column + FollowByColOffset, FormValue );
                  END;
               END;

               SetCharacterLenFld ();
           END;


    |    SIZEMAX :
           Column := FieldNo - SizeMaxColOffset;

           IF ( ( FormValue[FieldNo].CardValue < MinWbsSize ) OR
                ( FormValue[FieldNo].CardValue > MaxWbsSize ) ) AND
                ( LengthOf ( FormValue[ Column + CharSeqColOffset ].CharValue^ ) <> 0 ) THEN
                 Burp ();
                 Result := FALSE;
           ELSE
              IF ( FormValue[ FieldNo ].CardValue <
                   FormValue[ Column + SizeMinColOffset ].CardValue) THEN
                  FormValue[ FieldNo ].CardValue :=
                  FormValue[ Column + SizeMinColOffset ].CardValue;
                  ShowValue( Form, FieldNo, FormValue );
              END;

              IF (FormValue[FieldNo].CardValue <> FormValue[Column + SizeMinColOffset].CardValue) AND
                 (FormValue[ Column + FollowByColOffset ].CharValue^[0] = 0C) THEN
                 SetString (FormValue[ Column + FollowByColOffset ].CharValue^, ".");
                 ShowValue( Form, Column + FollowByColOffset, FormValue );
              END;
              SetCharacterLenFld ();
           END;

    |    CHARSEQ :
           Column := FieldNo - CharSeqColOffset;

           RemoveSpaces ( FormValue[FieldNo].CharValue^ );            (* 28-Nov-89 MWP *)

           IF ( FormValue[FieldNo].CharValue^[0] = 0C) THEN
               ProtectAllRow ( Column );
               SetCharacterLenFld ();
               (* If this row is blanked out, make sure that the next row's
                  Always Show field is NOT Hidden if all the rows above
                  are hidden.
               *)
               IF (CheckReason <> CheckFormEntry) THEN
                     FindNextAlwaysShowToUnHide ();
               END;
           ELSE
               IF ( CheckReason <> CheckFormEntry ) AND
                  ( NOT ValidateCharSeq ( Column ) ) THEN
                   Burp ();
                   Result := FALSE;
               ELSE
                   IF ( NOT CheckForDuplicateCharacters (FormValue[ FieldNo ].CharValue^) ) THEN
                       GetMessage ( ModuleNumber + 4, Message );
                       Error ( Message );
                       RETURN FALSE;
                   END;

                   UnProtectAllRow ( Column );

                   IF ( NOT TestStartWithChar ( Column ) ) THEN
                      ResetStartWithChar ( Column );
                   END;

                   AdjustMinAndMaxValues ( Column );
                   SetCharacterLenFld ();
                   IF ( CheckReason <> CheckFormEntry ) THEN
                       FindNextAlwaysShowToUnHide ();
                   END;
               END;
           END;

    |    START   :

           Column := FieldNo - StartWithColOffset;

           IF ( NOT TestStartWithChar ( Column ) ) THEN
              ResetStartWithChar ( Column );
           END;

    |    SHOW    :
           Column := FieldNo - AlwaysShowColOffset;

           (* Do not process first segment's values. *)
           IF ( FieldNo < MAXFIELD + 2 ) THEN
              RETURN TRUE;
           END;


           (* If the user has selected No for Always Show, set all following
              Always Show fields to No, hidden and protected.
           *)
           IF (FormValue[FieldNo].CardValue = 0) THEN
               SetShowToFalseToEnd ( FieldNo );
           ELSIF (FormValue[FieldNo].CardValue = 1) THEN
               (* If the user has selected Yes, and there are previous Show
                  values set to No, complain, else allow them to have their
                  way with us.
               *)

               (* Are we past the first row? and are there previus values set to
                  No? *)

               IF ( FieldNo > MAXFIELD + 2 ) AND
                  ( ArePreviousShowsSetToFalse ( Column ) ) THEN
                  Burp ();
                  FormValue[FieldNo].CardValue := 0;
                  ShowValue( Form, FieldNo, FormValue );
                  Result := FALSE;
               ELSE
                  IF ( FieldNo > MAXFIELD + 2 ) THEN
                     SetFieldProtection(Form,Column + NullColOffset,FormValue,FALSE);
                     SetFieldHidden    (Form,Column + NullColOffset,FormValue,FALSE);
                  END;
               END;
           ELSE
           END;

    |    NULL    :
           Column := FieldNo - NullColOffset;

           (* Make sure  that the NULL character is NOT included within the
              character sequence field. If it is, complain and set field to
              NULL value.
           *)

           IF ( CheckReason <> CheckFormEntry ) THEN
              RemoveSpaces ( FormValue[FieldNo].CharValue^ );            (* 28-Nov-89 MWP *)
              ShowValue( Form, FieldNo, FormValue );

              IF ( FormValue[ Column + AlwaysShowColOffset ].CardValue <> 0) AND
                 ( LengthOf ( FormValue[ FieldNo ].CharValue^) = 0 ) THEN
                    Burp ();
                    Result := FALSE;
              END;
           END;

    |    FOLLOW  :
           Column := FieldNo - FollowByColOffset;

           RemoveSpaces ( FormValue[FieldNo].CharValue^ );            (* 28-Nov-89 MWP *)
           ShowValue( Form, FieldNo, FormValue );

           IF ( LengthOf ( FormValue[FieldNo].CharValue^ ) = 0) THEN

              IF (FormValue[ Column + SizeMinColOffset ].CardValue <>
                  FormValue[ Column + SizeMaxColOffset ].CardValue) THEN
                 Burp ();
                 Result := FALSE;
              END;
           ELSE
               (* Check for following conditions :
                  1. That the follow by sequence is NOT all '?'s.
                  2. That there is at least one unique identifier within
                     the sequence.
               *)
               IF ( NOT CheckFollowByForWildCard ( Column ) ) THEN
                 Burp ();
                 Result := FALSE;
               END;
           END;
           SetCharacterLenFld ();
    ELSE
    END;

    RETURN Result;

END CheckTheForm;


PROCEDURE StartUsingFormValue ( VAR FormValue : ARRAY OF AFieldValue;
                                    WBSFormP   : AWBSPtr ) : BOOLEAN;
VAR
    Message                 : ARRAY [0..255] OF CHAR;
    Loop, j                 : CARDINAL;
BEGIN
    IF ( NOT HeapAvailable () ) THEN                                (* 18-Aug-89 MWP *)
      GetMessage ( ModuleNumber + 6, Message );
      (* "Not enough memory to display WBS manager form." *)
      Error ( Message );
      RETURN FALSE;
    END;

    WITH WBSFormP^ DO

       NEW(FormValue[0].CharValue);
       Copy ( Prefix, FormValue[0].CharValue^ );

       FormValue[ 1 ].CardValue := 0;

       j := 0;

       FOR Loop := 2 TO 99 BY MaxFormEntriesPerRow DO
          FormValue[ Loop + SizeMinColOffset ].CardValue := WBSColumns[j].SizeMin;
          FormValue[ Loop + SizeMaxColOffset ].CardValue := WBSColumns[j].SizeMax;

          NEW(FormValue[ Loop + CharSeqColOffset ].CharValue);
          Copy ( WBSColumns[j].CharacterSequence,
                 FormValue[ Loop + CharSeqColOffset ].CharValue^ );

          NEW(FormValue[ Loop + StartWithColOffset ].CharValue);
          Copy ( WBSColumns[j].StartWith,
                 FormValue[ Loop + StartWithColOffset ].CharValue^ );

          FormValue[ Loop + StartWithColOffset ].CardValue := WBSColumns[j].StartOffset;

          FormValue[ Loop + AlwaysShowColOffset ].CardValue :=
          ORD(WBSColumns[j].AlwaysShow);

          NEW(FormValue[ Loop + NullColOffset ].CharValue);
          IF ( LengthOf ( WBSColumns[j].Null ) = 0 ) THEN
              SetString ( FormValue[ Loop + NullColOffset ].CharValue^, "0" );
          ELSE
              Copy ( WBSColumns[j].Null,
                     FormValue[ Loop + NullColOffset ].CharValue^ );
          END;

          NEW(FormValue[ Loop + FollowByColOffset ].CharValue);
          Copy ( WBSColumns[j].FollowBy,
                 FormValue[ Loop + FollowByColOffset ].CharValue^ );

          INC(j);
      END;
    END;

    (* Set the first segments Always Show to Yes and Null value to '0' *)
    FormValue[ 2 + AlwaysShowColOffset ].CardValue := 1;
    SetString ( FormValue[ 2 + NullColOffset ].CharValue^, "0" );

    RETURN TRUE;

END StartUsingFormValue;


PROCEDURE TerminateUsingFormValue(VAR FormValue : ARRAY OF AFieldValue;
                                      WBSFormP  : AWBSPtr );
VAR
    Loop, j                 : CARDINAL;
BEGIN
    WITH WBSFormP^ DO

       LJust( FormValue[0].CharValue^);
       TrimRear( FormValue[0].CharValue^);
       Copy ( FormValue[0].CharValue^, Prefix );


       j := 0;
       FOR Loop := 2 TO ( MaxFormEntries ) + 1 BY MaxFormEntriesPerRow DO
           IF ( LengthOf ( FormValue[ Loop + CharSeqColOffset ].CharValue^ ) > 0 ) THEN
              WBSColumns[j].SizeMin := FormValue[ Loop + SizeMinColOffset ].CardValue;
              WBSColumns[j].SizeMax := FormValue[ Loop + SizeMaxColOffset ].CardValue;

              LJust   ( FormValue[ Loop + CharSeqColOffset ].CharValue^);
              TrimRear( FormValue[ Loop + CharSeqColOffset ].CharValue^);
              Copy ( FormValue[ Loop + CharSeqColOffset ].CharValue^,
                     WBSColumns[j].CharacterSequence );

              LJust   ( FormValue[ Loop + StartWithColOffset ].CharValue^);
              TrimRear( FormValue[ Loop + StartWithColOffset ].CharValue^);
              Copy ( FormValue[ Loop + StartWithColOffset ].CharValue^,
                     WBSColumns[j].StartWith );

              WBSColumns[j].StartOffset := FormValue[ Loop + StartWithColOffset ].CardValue;

              IF ( FormValue[ Loop + AlwaysShowColOffset ].CardValue = 0 ) OR
                 ( FormValue[ Loop + AlwaysShowColOffset ].CardValue = AlwaysShowOff ) THEN
                  WBSColumns[j].AlwaysShow := AShowMethod(No);
              ELSE
                  WBSColumns[j].AlwaysShow := AShowMethod(Yes);
              END;

              LJust   ( FormValue[ Loop + NullColOffset ].CharValue^);
              TrimRear( FormValue[ Loop + NullColOffset ].CharValue^);
              Copy ( FormValue[ Loop + NullColOffset ].CharValue^,
                     WBSColumns[j].Null );

              LJust   ( FormValue[ Loop + FollowByColOffset ].CharValue^);
              TrimRear( FormValue[ Loop + FollowByColOffset ].CharValue^);
              Copy ( FormValue[ Loop + FollowByColOffset ].CharValue^,
                     WBSColumns[j].FollowBy );
              INC ( j );
           END;
       END;

      FOR Loop := j TO HIGH( WBSColumns ) DO                     (* 11-Jul-89 MWP *)
         WBSColumns[ Loop ].SizeMin := 0;
         WBSColumns[ Loop ].SizeMax := 0;
         SetLengthOf ( WBSColumns[ Loop ].CharacterSequence, 0 );
         SetLengthOf ( WBSColumns[ Loop ].StartWith, 0 );
         WBSColumns[ Loop ].StartOffset := 0;
         WBSColumns[ Loop ].AlwaysShow := No;
         SetLengthOf ( WBSColumns[ Loop ].Null, 0 );
         SetLengthOf ( WBSColumns[ Loop ].FollowBy, 0 );
      END;
    END;
END TerminateUsingFormValue;


PROCEDURE CleanUpAfterForm ( VAR FormValue : ARRAY OF AFieldValue;
                                 WBSFormP  : AWBSPtr );
VAR
    Loop, j                 : CARDINAL;
BEGIN
    WITH WBSFormP^ DO

       DISPOSE(FormValue[0].CharValue);
       FormValue[0].CharValue := NIL;

       j := 0;

       FOR Loop := 2 TO  MaxFormEntries + 1 BY MaxFormEntriesPerRow DO
           DISPOSE(FormValue[ Loop + CharSeqColOffset ].CharValue);
           FormValue[ Loop + CharSeqColOffset ].CharValue := NIL;

           DISPOSE(FormValue[ Loop + StartWithColOffset ].CharValue);
           FormValue[ Loop + StartWithColOffset ].CharValue := NIL;

           DISPOSE(FormValue[ Loop + NullColOffset ].CharValue);
           FormValue[ Loop + NullColOffset ].CharValue := NIL;

           DISPOSE(FormValue[ Loop + FollowByColOffset ].CharValue);
           FormValue[ Loop + FollowByColOffset ].CharValue := NIL;

           INC ( j );
       END;
    END;

END CleanUpAfterForm;

 (*
  * Do The Form.
 *)
PROCEDURE DoWBSForm( WBSFormP  : AWBSPtr ) : BOOLEAN;               (* 15-Aug-89 MWP *)
VAR
    FormValue               : ARRAY [0..100] OF AFieldValue;
    ok, FormExit            : BOOLEAN;
BEGIN
    ok := StartUsingFormValue ( FormValue, WBSFormP );

    (* Do the form.  If ESC is hit, don't do the report. *)

    IF ( ok ) THEN
       FormExit := ( DoForm ( 0,
                              GanttWEnd,
                              maxcol,
                              maxrow-1,
                              WBSFORMID,
                              TRUE,
                              FormValue,
                              CheckTheForm ) = ExitKey );


        IF ( FormExit ) THEN
            TerminateUsingFormValue ( FormValue, WBSFormP );
        ELSE
          ok := FALSE;
        END;
        CleanUpAfterForm ( FormValue, WBSFormP );
    END;

    RETURN ok;

END DoWBSForm;


PROCEDURE SetUpWBS ();
VAR
    FormName                :    ARRAY[0..10] OF CHAR;
    ok                      :    BOOLEAN;
    WBSRecordP              :    AWBSPtr;
    Copyright               :    ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    SetString ( FormName, "TLWBS" );
    IF ( NOT SetWBSValues ( FormName, WBSRecordP ) ) THEN
        RETURN;
    END;

    ok := DoWBSForm ( WBSRecordP );

    IF ( ok ) THEN
        SaveWBSValues ( FormName, WBSRecordP );
        ScheduleSaved := FALSE;         (* 9/14/91 EGK *)
        UnSetState (Formatted);
    END;

END SetUpWBS;


BEGIN

    SetUpWBS ();

END TLWBSMan.
