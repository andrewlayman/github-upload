MODULE TLColName;

(*  =========================================================================
    Last Edit : July 3, 1991 3:46PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Supports the User-defined column names form.

    MODIFICATION HISTORY:

    14-May-90 KKC   First version
    22-Aug-90 PFG   Completed first version.
    10-Sep-90 PFG   Make into an overlay.  (Used to be ColumnNa.MOD)
    20-Sep-90 PFG   Add to the check proc:  don't allow blank column names
                    or export names.
    2-Oct-90  PFG   Add the contents of the old ColumnGoToProc to 
                    DoColumnForm() and change the context record accordingly.
    17-Oct-90 PFG   Made changes to form as per 4.5 prototype review.  Min and 
                    Max digits added (only accessible for numeric columns);
                    "Use short titles..." field removed and value calculated
                    instead.
    31-Oct-90 PFG   Move MassageColumnInfo outside of DoColumn and call it
                    before and after DoForm.  BeginUsingShort (aka 
                    "NarrowWidth") was being calculated incorrectly because
                    strings were padded with spaces after DoForm.  So only
                    short titles were ever being displayed.
    21-Nov-90 PFG   Use real maximum widths of columns when calling 
                    GetColumnInfo.  Names were sometimes truncated.
    14-Mar-91 RSC   CapData no longer needs handles and knowladge of
                    TLCaptions' whereabouts.
    25-Apr-91 RSC   Remove use of "GetInfo" proc from callers.  This is
                    two stages - stage 1 is what I am doing now, to change
                    the usage.  Stage 2 will be to remove GetInfo from the
                    context area.
    21-Jun-91 PFG   Don't allow duplicate column or export names.
     3-Jul-91 PFG   The code I put in to catch duplicates was case sensitive
                    in the case of column names.  Now it's not.
    23-Jul-91 LAA   Removed all usage of OutlineView from the context passed
                    to this overlay.  Unfortunately, the methods table for
                    that class was linked into TLLayout, which may no longer
                    be in memory when this overlay tries to call its methods.
                    This fixes bug #4768.
    =========================================================================
*)


FROM CapData                IMPORT
    (* TYPE  *)                 AFormatSpecsArray,
    (* VAR   *)                 FormatSpecs;

FROM Captions               IMPORT
    (* TYPE  *)                 AColumnInfoChoice, 
                                AColumnDataRecord;

FROM Codes                  IMPORT
    (* TYPE  *)                 ACode;

FROM ColData                IMPORT
    (* TYPE  *)                 AColumnType;

FROM ColFind                IMPORT
    (* PROC  *)                 GetColumnItem, SetColumnItem;

FROM ColForm                IMPORT
    (* CONST *)                 MaxNameLen,
                                MaxDescriptionLen,
                                MaxShortTitleLen,
                                MaxLongTitleLen,
                                MaxExportNameLen,
    (* TYPE  *)                 AColumnContext, AColumnContextPtr;

FROM ColumnSupport          IMPORT
    (* CONST *)                 FullTitle,
                                Title1,
                                Title2,
                                DefaultLength,
                                NarrowWidth,
                                NarrowTitle1,
                                NarrowTitle2,
                                FormalName,
                                MinDecimals,
                                MaxDecimals,
                                DataType,
                                DescriptionIndex,
                                OrigNameIndex,
    (* TYPE *)                  AColumnTreeRecordPtr,
                                AColumnTreeRecord;

FROM Dialog                 IMPORT 
    (* PROC  *)                 Burp, Message, Error, FatalError;


FROM FlexStor               IMPORT
    (* PROC *)                  LockObject, ReleaseObject, MakeHeapCopy;

FROM FormCon                IMPORT
    (* TYPE  *)                 AFieldNo;

FROM Forms                  IMPORT
    (* TYPE  *)                 AFieldValue, AForm, ACheckReason,
    (* PROC  *)                 DoForm, SetFieldProtection, SetFieldHidden;

FROM Keys                   IMPORT
    (* CONST *)                 ExitKey;

FROM LStrings               IMPORT
    (* PROC  *)                 SetLengthOf, Copy, ConcatLS, LengthOf,
                                Remove, LJust, TrimRear, ConcatS, Procustes,
                                Upshift, StringsEqual;

FROM MagicNum               IMPORT
    (* CONST *)                 IsRealValue, IsDuration, IsEffort, IsSlack,
                                IsDurationUnits, IsEffortUnits, 
                                RsrcLastColumn, AssBsLnLastColumn;

FROM MsgFile                IMPORT
    (* PROC  *)                 GetMessage, DisplayMessage, ConcatMessage;

FROM Overlays               IMPORT
    (* TYPE *)                  AnOverlayID,
    (* PROC *)                  ImAnInstallableOverlay, OverlayContext;

FROM OvTree                 IMPORT
    (* TYPE *)                  AnOverlayProc;

FROM Schedule               IMPORT
    (* VAR  *)                  ConfigSaved;

FROM Space                  IMPORT
    (* PROC  *)                 HeapAvailable, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  SIZE;

FROM TaskColNumbers         IMPORT
    (* CONST *)                 HighestRootColumn;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM XTabColNumbers         IMPORT
    (* CONST *)                 XTabLastColumn;




CONST

    ModuleNumber            =   16900;

    ColumnFormID            =   72;

    NAME        =   0;
    DESCR1      =   1;
    DESCR2      =   2;
    OLDNAME     =   3;
    SHORT1      =   4;
    SHORT2      =   5;
    LONG1       =   6;
    LONG2       =   7;
    USUALLEN    =   8;
    MINDIGIT    =   9;
    MAXDIGIT    =   10;
    EXPNAME     =   11;

    LastColumnFormField = 11;

TYPE
    AUserDefinedColumn       =   RECORD
        Name            :   ARRAY[0..MaxNameLen] OF CHAR;
        Description     :   ARRAY[0..MaxDescriptionLen * 2] OF CHAR;
        ShortTitle1     :   ARRAY[0..MaxShortTitleLen] OF CHAR;
        ShortTitle2     :   ARRAY[0..MaxShortTitleLen] OF CHAR;
        LongTitle1      :   ARRAY[0..MaxLongTitleLen] OF CHAR;
        LongTitle2      :   ARRAY[0..MaxLongTitleLen] OF CHAR;
        UsualTitleLength:   CARDINAL;
        MinDigits       :   CARDINAL;
        MaxDigits       :   CARDINAL;
        ExportName      :   ARRAY[0..MaxExportNameLen] OF CHAR;
        OriginalName    :   ARRAY[0..MaxNameLen] OF CHAR;
    END;


VAR
    OverlayID           : AnOverlayID;
    ColumnStringsSet    : BITSET;
    NoDecimalsAllowed   : BOOLEAN;      (*  Yikes!  Only for current column.
                                            Not reentrant.  *)
    ColumnContextPtr    :   AColumnContextPtr;  (*  Ditto.  Not reentrant.
                                            But it's needed for checking for
                                            duplicates.  *)


(*----------------------------------------------------------------------------
    CheckColumnForm --

    Check Proc for column names form.

    Preconditions:
        None.

    Postconditions:
        Values are passed back in FormValue.
----------------------------------------------------------------------------*)

PROCEDURE CheckColumnForm(
                                 Form : AForm;
                              FieldNo : AFieldNo;
                        VAR FormValue : ARRAY OF AFieldValue;
                          CheckReason : ACheckReason;
                             VAR Code : CARDINAL
                          ) : BOOLEAN;

VAR
    MsgNumber       : CARDINAL;
    ColumnItem      : CARDINAL;
    S               : ARRAY[0..255] OF CHAR;
    Result          : BOOLEAN;


    PROCEDURE HighestColumnID(TheColumnType : AColumnType) : CARDINAL;

    VAR
        LastID : CARDINAL;

    BEGIN

        CASE TheColumnType OF

            TaskColumnInfo :    LastID := HighestRootColumn;
        |   XTabColumnInfo :    LastID := XTabLastColumn;
        |   RsrcColumnInfo :    LastID := AssBsLnLastColumn;
        |   AssgColumnInfo :    LastID := RsrcLastColumn;

        ELSE
            LastID := 0;
        END;

        RETURN(LastID);

    END HighestColumnID;


    PROCEDURE NameIsDuplicate(  VAR NewName     : ARRAY OF CHAR; 
                                    ColumnItem  : CARDINAL ) : BOOLEAN;

    VAR
        ID              : CARDINAL;
        Node            : ATreeNode;
        ColumnRecord    : AColumnTreeRecordPtr;
        LastColumnID    : CARDINAL;
        i               : CARDINAL;
        Dummy           : CARDINAL;
        TempNewName,
        Name            : ARRAY [0..50] OF CHAR;
        IsDuplicate     : BOOLEAN;

    BEGIN

        IsDuplicate := FALSE;
        i := 1;

        WITH ColumnContextPtr^ DO

            ColumnRecord := CursorNode^.Methods^.GetDataObject(CursorNode);
            ID := ColumnRecord^.ID;

            LastColumnID := HighestColumnID(ColumnType);
            WHILE (NOT IsDuplicate AND (i <= LastColumnID)) DO
                IF (i <> ID) THEN       (* skip the column we're changing *)
                    GetColumnItem(PhraseModNumber, ColumnType, i,
                                    ColumnItem, FALSE, Dummy, Name );
                    IF (LengthOf(Name) <> 0) THEN
                        Upshift(Name);
                        Copy(NewName, TempNewName);
                        Upshift(TempNewName);
                        IF (StringsEqual(Name, TempNewName)) THEN
                            IsDuplicate := TRUE;
                        END;
                    END;
                END;

                INC(i);
            END;
        END;

        RETURN(IsDuplicate);

    END NameIsDuplicate;

BEGIN
    Code := 0;
    Result := TRUE;

    CASE CheckReason OF

        CheckFormEntry      :               (* 17-Oct-90 PFG *)
            IF ((FieldNo = MINDIGIT) OR (FieldNo = MAXDIGIT)) THEN
                SetFieldProtection(Form, FieldNo, FormValue, NoDecimalsAllowed);
                SetFieldHidden(Form, FieldNo, FormValue, NoDecimalsAllowed);
            END;

    |   CheckFieldExit,
        CheckFieldChange    :

            CASE FieldNo OF

                NAME, EXPNAME :  
        
                    WITH FormValue[FieldNo] DO
                        LJust(CharValue^);
                        TrimRear(CharValue^);
                        IF (LengthOf(CharValue^) = 0) THEN
                            IF (FieldNo = NAME) THEN
                                MsgNumber := 2;
                            ELSE
                                MsgNumber := 3;
                            END;
                            DisplayMessage(ModuleNumber + MsgNumber);     (* Blank names not allowed *)
                            Burp;
                            Result := FALSE;
                        ELSE        (* 19-Jun-91 PFG  Check for duplicates. *)
                            IF (FieldNo = NAME) THEN 
                                ColumnItem := FullTitle;
                            ELSE
                                ColumnItem := FormalName;
                            END;
                            IF (NameIsDuplicate(CharValue^, ColumnItem)) THEN      
                                GetMessage(ModuleNumber + 4, S);       (*  Name is a duplicate.  *)
                                ConcatLS(S, CharValue^);
                                ConcatMessage(S, ModuleNumber + 5);
                                Message(S);
                                Burp;
                                Result := FALSE;
                            END;
                        END;

                    END;
            ELSE
            END;

    ELSE
    END;

    RETURN Result;

END CheckColumnForm;




(*----------------------------------------------------------------------------
    AllocateFormValue --

    Allocate the string values for the form record.

    Preconditions:
        None.

    Postconditions:
        Returns TRUE if space could be allocated for the record; FALSE
        otherwise.
----------------------------------------------------------------------------*)

PROCEDURE AllocateFormValue(VAR FormValue : ARRAY OF AFieldValue) : BOOLEAN;

VAR
    i   : CARDINAL;
    Ok  : BOOLEAN;

BEGIN
    Ok := FALSE;
    IF HeapAvailable() THEN
        FOR i := 0 TO LastColumnFormField DO
            IF (i IN ColumnStringsSet) THEN
                NEW(FormValue[i].CharValue);
                SetLengthOf(FormValue[i].CharValue^, 0 );
            ELSE
                FormValue[i].CharValue := NIL;
            END;
        END;
        Ok := TRUE;
    END;
    RETURN Ok;
END AllocateFormValue;



(*----------------------------------------------------------------------------
    DeAllocateFormValue --

    Dispose of the FormValue record.

    Preconditions:
        AllocateFormValue must have been called first.

    Postconditions:
        None.
----------------------------------------------------------------------------*)

PROCEDURE DeAllocateFormValue( VAR FormValue : ARRAY OF AFieldValue );

VAR
    i                       :   CARDINAL;

BEGIN
    FOR i := 0 TO LastColumnFormField DO
        IF (i IN ColumnStringsSet) THEN
            DISPOSE(FormValue[i].CharValue);
            FormValue[i].CharValue := NIL;
        END;
    END;
END DeAllocateFormValue;




(*----------------------------------------------------------------------------
    MassageColumnInfo --

    Left justify column info strings and remove spaces.

    Preconditions:
        String to be massaged is in TempBuffer.  Max is the maximum length
        the string can be.

    Postconditions:
        Massaged string is passed back in Destination.  TempBuffer is
        not changed.  If TempBuffer was longer than Max, Destination is
        shortened to be of length Max.
----------------------------------------------------------------------------*)

PROCEDURE MassageColumnInfo(VAR TempBuffer      : ARRAY OF CHAR;
                                Max             : CARDINAL;
                            VAR Destination     : ARRAY OF CHAR);

BEGIN

    Copy(TempBuffer, Destination);

    LJust(Destination);

    TrimRear(Destination);

    IF (LengthOf(Destination) > Max) THEN
        SetLengthOf(Destination, Max);
    END;

END MassageColumnInfo;




(*----------------------------------------------------------------------------
    CopyFormValueToUserDefinedColumn --

    Fill the column record from the values the user put in the form.

    Preconditions:
        None.

    Postconditions:
        None.
----------------------------------------------------------------------------*)

PROCEDURE CopyFormValueToUserDefinedColumn( 
                                 VAR FormValue         : ARRAY OF AFieldValue;
                                 VAR UserDefinedColumn : AUserDefinedColumn 
                                          );
VAR
    TempDescription : ARRAY[0..255] OF CHAR;

BEGIN
    WITH UserDefinedColumn DO
        MassageColumnInfo(FormValue[NAME].CharValue^, MaxNameLen, Name);
        MassageColumnInfo(FormValue[SHORT1].CharValue^, MaxShortTitleLen, 
                                ShortTitle1);
        MassageColumnInfo(FormValue[SHORT2].CharValue^, MaxShortTitleLen, 
                                ShortTitle2);
        MassageColumnInfo(FormValue[LONG1].CharValue^, MaxLongTitleLen, 
                                LongTitle1);
        MassageColumnInfo(FormValue[LONG2].CharValue^, MaxLongTitleLen, 
                                LongTitle2);
        MassageColumnInfo(FormValue[EXPNAME].CharValue^, MaxExportNameLen, 
                                ExportName);
        MassageColumnInfo(FormValue[DESCR1].CharValue^, MaxDescriptionLen, 
                                Description);
        MassageColumnInfo(FormValue[DESCR2].CharValue^, MaxDescriptionLen, 
                                TempDescription);
        ConcatLS(Description, TempDescription);
        UsualTitleLength := FormValue[USUALLEN].CardValue;
        MinDigits := FormValue[MINDIGIT].CardValue;
        MaxDigits := FormValue[MAXDIGIT].CardValue;
    END;
END CopyFormValueToUserDefinedColumn;





(*----------------------------------------------------------------------------
    CopyUserDefinedColumnToFormValue --

    Copy the current column values into the form.

    Preconditions:
        None.

    Postconditions:
        None.
----------------------------------------------------------------------------*)

PROCEDURE CopyUserDefinedColumnToFormValue( 
                                 VAR UserDefinedColumn : AUserDefinedColumn;
                                 VAR FormValue         : ARRAY OF AFieldValue
                                         );
BEGIN
    WITH UserDefinedColumn DO
        MassageColumnInfo(Name, MaxNameLen, FormValue[NAME].CharValue^);
        MassageColumnInfo(ShortTitle1, MaxShortTitleLen, 
                                FormValue[SHORT1].CharValue^);
        MassageColumnInfo(ShortTitle2, MaxShortTitleLen, 
                                FormValue[SHORT2].CharValue^);
        MassageColumnInfo(LongTitle1, MaxLongTitleLen, 
                                FormValue[LONG1].CharValue^);
        MassageColumnInfo(LongTitle2, MaxLongTitleLen, 
                                FormValue[LONG2].CharValue^);
        MassageColumnInfo(ExportName, MaxExportNameLen, 
                                FormValue[EXPNAME].CharValue^);
        MassageColumnInfo(OriginalName, MaxNameLen, 
                                FormValue[OLDNAME].CharValue^);
        MassageColumnInfo(Description, MaxDescriptionLen, 
                                FormValue[DESCR1].CharValue^);
        IF (LengthOf(Description) > MaxDescriptionLen) THEN
            Remove(Description, 1, MaxDescriptionLen);
            MassageColumnInfo(Description, MaxDescriptionLen, 
                                FormValue[DESCR2].CharValue^);
        END;
        FormValue[USUALLEN].CardValue := UsualTitleLength;
        FormValue[MINDIGIT].CardValue := MinDigits;
        FormValue[MAXDIGIT].CardValue := MaxDigits;
    END;
END CopyUserDefinedColumnToFormValue;






(*----------------------------------------------------------------------------
    DoColumnForm --

    Do the Column Names form.

    Preconditions:
        None.

    Postconditions:
        None.
----------------------------------------------------------------------------*)

PROCEDURE DoColumnForm();

VAR
    ID                      :   CARDINAL;
    i                       :   CARDINAL;
    BeginUsingShort         :   CARDINAL;
    TempLen                 :   CARDINAL;
    Node                    :   ATreeNode;
    Code                    :   ACode;
    FormValue               :   ARRAY [0..LastColumnFormField] OF AFieldValue;
    UserDefinedColumn       :   AUserDefinedColumn;
    DataRecord              :   AColumnDataRecord;
    ColumnRecord            :   AColumnTreeRecordPtr;
    Temp                    :   ARRAY[0..255] OF CHAR;
    Copyright               :   ARRAY[0..50] OF CHAR;
    ok                      :   BOOLEAN;

BEGIN

    Copyright := "Program Copyright (c) 1990 Symantec Corporation.";

    ColumnContextPtr := OverlayContext();
    ColumnContextPtr^.Changed := FALSE;

    IF (NOT AllocateFormValue( FormValue )) THEN
        GetMessage(ModuleNumber + 1, Temp);       (* Not enough memory *)
        Error(Temp);
        RETURN;
    END;

    WITH ColumnContextPtr^ DO

        ColumnRecord := CursorNode^.Methods^.GetDataObject(CursorNode);
        ID := ColumnRecord^.ID;

        WITH UserDefinedColumn DO
            GetColumnItem(PhraseModNumber, ColumnType, ID,
                          FullTitle, FALSE, i, Name );

            GetColumnItem(PhraseModNumber, ColumnType, ID,
                          NarrowTitle1, FALSE, i, ShortTitle1 );

            GetColumnItem(PhraseModNumber, ColumnType, ID,
                          NarrowTitle2, FALSE, i, ShortTitle2 );

            GetColumnItem(PhraseModNumber, ColumnType, ID,
                          Title1, FALSE, i, LongTitle1 );

            GetColumnItem(PhraseModNumber, ColumnType, ID,
                          Title2, FALSE, i, LongTitle2 );

            GetColumnItem(PhraseModNumber, ColumnType, ID,
                          FormalName, FALSE, i, ExportName );

            GetColumnItem(PhraseModNumber, ColumnType, ID,
                          DefaultLength, TRUE, UsualTitleLength, Copyright );

            GetColumnItem(PhraseModNumber, ColumnType, ID,
                          DataType, TRUE, DataRecord.CardinalValue, Copyright );

                (* Get the data type so we can figure out if this is a
                   numeric field that has decimal places.  If it's not,
                   Min/Max Decimals have no meaning.  *)

            CASE DataRecord.CardinalValue OF
                IsRealValue,
                IsDuration,
                IsEffort,IsSlack,
                IsDurationUnits, 
                IsEffortUnits       :   
                    NoDecimalsAllowed := FALSE;

                    GetColumnItem(PhraseModNumber, ColumnType, ID,
                                  MinDecimals, TRUE, MinDigits, Copyright );

                    GetColumnItem(PhraseModNumber, ColumnType, ID,
                                  MaxDecimals, TRUE, MaxDigits, Copyright );

            ELSE
                NoDecimalsAllowed := TRUE;
            END;

            GetColumnItem(PromptModNumber, 
                            ColumnType, 
                            ID, DescriptionIndex, 
                            FALSE, i, Description);

            GetColumnItem(PhraseModNumber, 
                            ColumnType, 
                            ID, OrigNameIndex, 
                            FALSE, i, OriginalName);

            CopyUserDefinedColumnToFormValue(UserDefinedColumn, FormValue);

            Code := DoForm(13, 8, 67, 21, ColumnFormID, TRUE,
                            FormValue, CheckColumnForm);

            IF (Code = ExitKey) THEN

                CopyFormValueToUserDefinedColumn(FormValue, UserDefinedColumn);
                Changed := TRUE;
                ConfigSaved := FALSE;

                i := 0;
                Copy(Name, ColumnRecord^.Name);
                SetColumnItem(PhraseModNumber, 
                                ColumnType, 
                                ID, FullTitle, 
                                FALSE, i, Name);
                SetColumnItem(PromptModNumber, 
                                ColumnType, 
                                ID, DescriptionIndex, 
                                FALSE, i, Description);
                SetColumnItem(PhraseModNumber, 
                                ColumnType, 
                                ID, NarrowTitle1, 
                                FALSE, i, ShortTitle1);
                SetColumnItem(PhraseModNumber, 
                                ColumnType, 
                                ID, NarrowTitle2, 
                                FALSE, i, ShortTitle2);
                SetColumnItem(PhraseModNumber, 
                                ColumnType, 
                                ID, Title1, 
                                FALSE, i, LongTitle1);
                SetColumnItem(PhraseModNumber, 
                                ColumnType, 
                                ID, Title2, 
                                FALSE, i, LongTitle2);
                SetColumnItem(PhraseModNumber, 
                                ColumnType, 
                                ID, FormalName, 
                                FALSE, i, ExportName);
                SetColumnItem(PhraseModNumber, 
                                ColumnType, 
                                ID, DefaultLength, 
                                TRUE, UsualTitleLength, Temp);

                IF NOT NoDecimalsAllowed THEN
                    SetColumnItem(PhraseModNumber, 
                                    ColumnType, 
                                    ID, MinDecimals, 
                                    TRUE, MinDigits, Temp);

                    SetColumnItem(PhraseModNumber, 
                                    ColumnType, 
                                    ID, MaxDecimals, 
                                    TRUE, MaxDigits, Temp);

                        (* Captions stores MinDecimals and MaxDecimals in 
                           global storage for task columns.  Update this 
                           also.  *)

                    IF (ColumnType = TaskColumnInfo) THEN
                        FormatSpecs^[ID].Decimals := MinDigits * 16 + MaxDigits;
                    END;
                END;

                    (* Compute when to begin using short titles *)

                BeginUsingShort := LengthOf(LongTitle1);
                TempLen := LengthOf(LongTitle2);
                IF (TempLen > BeginUsingShort) THEN
                    BeginUsingShort := TempLen - 1;                    
                ELSE
                    DEC(BeginUsingShort);
                END;

                SetColumnItem(PhraseModNumber, 
                                ColumnType, 
                                ID, NarrowWidth, 
                                TRUE, BeginUsingShort, Temp);

            END;

        END;

    END;

    DeAllocateFormValue( FormValue );

END DoColumnForm;






BEGIN

    OverlayID := ImAnInstallableOverlay(DoColumnForm, AnOverlayProc(NIL));
    ColumnStringsSet := {NAME,DESCR1,DESCR2,SHORT1,SHORT2,
                         LONG1,LONG2,EXPNAME,OLDNAME};
    DoColumnForm();

END TLColName.
