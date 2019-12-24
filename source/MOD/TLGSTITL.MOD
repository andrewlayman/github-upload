IMPLEMENTATION MODULE TLGSTitle;     (*  Time Line Graphics Title sub-form  *)

    (*  MODIFICATION HISTORY
        08-Dec-88 LAA   Allow 6 options for placement of the Title, Legend,
                        and Symbols.
        16-Dec-88 LAA   Protection base on Symbols (No, Yes) was reversed.
        27-Jan-89 LAA   Cleaned up a few things, but didn't change the 
                        functioning.
        18-Apr-89 RSC   Moved the definition for a title block into IlsaStatic
                        and expect the clients to pass the pointer to it
                        in to this module.  Removed PlotCommon.
        10-May-89 WKH   GetDefaultFontSpecs now comes from IlsaStatic instead
                        of FontName.
        11-May-89 WKH   Make TLGSTitle have the responsibility of retrieving
                        a title block
        29-May-89 LAA   Adjusted for the TitleBlocks being stored in FlexStor.
        05-Jul-89 WKH   Fixed problem with Titles, Legends, and Symbols
                        conflicting when they really aren't
        25-Jul-89 WKH   Add support for different messages for Title, Legend,
                        Symbol placement conflicts.
        13-Nov-89 RSC   Changed BTStorage to Space.
    *)

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE;

FROM Codes                  IMPORT 
                                ACode, EmptyCodeSet;

FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  ContinuationBox, FatalError, Error, Burp,
                                Message, WarningBox;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo, AFieldType;

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue, AForm, ACheckReason,
                                ACursorAttribute,
    (* PROC *)                  DoForm, SetFieldProtection, NullCheckProc,
                                ShowValue, HighlightField, FindFormBoundaries,
                                SetFieldHidden, FieldIsHidden;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSTitleBlock, ATLGSTitleBlockPtr,
                                ATextLine, ATLGSScale, ATLGSChartType,
                                ATLGSTitlePlacement,
    (* PROC *)                  LockTLGSTitleBlock, GetDefaultFontSpecs,
                                UnlockTLGSTitleBlock;

FROM Keys                   IMPORT 
                                CancelKey, ExitKey, EditKey, DoIt;

FROM LStrings               IMPORT 
    (* PROC *)                  Fill, SetString, TrimRear, ConcatS, 
                                LengthOf, SetLengthOf, Copy, Compare,
                                ConcatLS, CtoS;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Schedule               IMPORT
                                ScheduleSaved;

FROM Space                  IMPORT
    (* PROC *)                  HeapAvailable;

FROM SYSTEM                 IMPORT 
                                TSIZE;

FROM Text                   IMPORT
    (* TYPE *)                  AText;

FROM TypoGraph              IMPORT
    (* TYPE *)                  ATypoAttribute, ASetOfTypoAttributes, 
                                ATypoPlacement, ATypoLineSpec, 
                                ATypoBorderSpec, ATypoSpec;

CONST
    ModuleNumber            = 25600;
    FormID                  = 54;

    (* Define meaningful names for indices into FormValue array *)
    Tit1                    = 0;  (* Title Area line 1 *)
    Tit2                    = 1;  (* Title Area line 2 *)
    Tit3                    = 2;  (* Title Area line 3 *)       
    TitP1                   = 3;  (* Title Placement field 1*)
    TitP2                   = 4;  (* Title Placement field 2*)
    Leg1                    = 5;  (* Legend Area line 1 *)
    Leg2                    = 6;  (* Legend Area line 2 *)
    Leg3                    = 7;  (* Legend Area line 3 *)
    Leg4                    = 8;  (* Legend Area line 4 *)        
    Leg5                    = 9;  (* Legend Area line 5 *)
    LegP1                   = 10; (* Legend At field 1*)
    LegP2                   = 11; (* Legend At field 2*)
    Syms                    = 12; (* Symbols field *)
    SymP1                   = 13; (* Symbols At field 1 *)
    SymP2                   = 14; (* Symbols At field 2 *)

    (* Offsets into phrases file for phrases used by this module *)
    NoHeapMsg               = 0;
    LegTitConflictMsg       = 1;
    SymTitConflictMsg       = 2;
    SymLegConflictMsg       = 3;

VAR
    ReportTitles            : ATLGSTitleBlockPtr;

PROCEDURE CheckForm (    Form        : AForm;
                         FieldNo     : AFieldNo;
                     VAR FormValue   : ARRAY OF AFieldValue;
                         CheckReason : ACheckReason;
                     VAR Code        : CARDINAL ):BOOLEAN;

    PROCEDURE ExistsText(StartFieldNo,
                         StopFieldNo   : CARDINAL) : BOOLEAN;

    VAR
        i                   : CARDINAL;
        Exists              : BOOLEAN;

    BEGIN
        Exists := FALSE;
        i      := StartFieldNo;
        LOOP
            IF (i > StopFieldNo) THEN
                EXIT;
            ELSE
                TrimRear(FormValue[i].CharValue^);
                IF (LengthOf(FormValue[i].CharValue^) > 0) THEN
                    Exists := TRUE;
                    EXIT;
                END;
            END;
            INC(i);
        END;
        RETURN(Exists);
    END ExistsText;


    PROCEDURE Oops(    FieldNo              : CARDINAL);

    VAR
        ErrorString         : ARRAY [0..255] OF CHAR;
        i                   : CARDINAL;

    BEGIN                   (* Oops *)

        CASE FieldNo OF         (* 25-Jul-89 WKH *)
            TitP1 : i := LegTitConflictMsg;
        |   SymP1 : i := SymTitConflictMsg;
        |   LegP1 : i := SymLegConflictMsg;
        ELSE
            FatalError();
        END;

        GetMessage(ModuleNumber + i, ErrorString);
        Error(ErrorString);
        LooksGood := FALSE;
        Code := CARDINAL({15}) + FieldNo; (*Goto offending field*)

    END Oops;


VAR
    i                       : CARDINAL;
    CodeIn                  : CARDINAL;
    TempField               : AFieldValue;
    TPlace                  : ATLGSTitlePlacement;
    LPlace                  : ATLGSTitlePlacement;
    SPlace                  : ATLGSTitlePlacement;
    KeyStruck               : ACode;
    Found                   : BOOLEAN;
    Protect                 : BOOLEAN;
    LooksGood               : BOOLEAN;
    s                       : ARRAY [0..10] OF CHAR;

BEGIN
    CodeIn    := Code;
    Code      := 0;
    LooksGood := TRUE;

    CASE CheckReason OF
        CheckFormEntry   :
            CASE FieldNo OF
                Syms :
                    Protect := NOT VAL(BOOLEAN, FormValue[FieldNo].CardValue);
                    SetFieldProtection(Form, SymP1, FormValue, Protect);
                    SetFieldHidden(Form, SymP1, FormValue, Protect);
                    SetFieldProtection(Form, SymP2, FormValue, Protect);
                    SetFieldHidden(Form, SymP2, FormValue, Protect);
            |   Tit1,
                Tit2,
                Tit3 : 
                    Protect := NOT (ExistsText(Tit1, Tit3));
                    SetFieldProtection(Form, TitP1, FormValue, Protect);
                    SetFieldHidden(Form, TitP1, FormValue, Protect);
                    SetFieldProtection(Form, TitP2, FormValue, Protect);
                    SetFieldHidden(Form, TitP2, FormValue, Protect);
            |   Leg1,
                Leg2,
                Leg3,
                Leg4,
                Leg5 : 
                    Protect := NOT (ExistsText(Leg1, Leg5));
                    SetFieldProtection(Form, LegP1, FormValue, Protect);
                    SetFieldHidden(Form, LegP1, FormValue, Protect);
                    SetFieldProtection(Form, LegP2, FormValue, Protect);
                    SetFieldHidden(Form, LegP2, FormValue, Protect);
            ELSE
            END;
    |   CheckFormExit    :
            CASE FieldNo OF
                TitP1 :
                    EncodePlacement(FormValue[TitP1].CardValue, 
                                    FormValue[TitP2].CardValue, TPlace);
                    EncodePlacement(FormValue[LegP1].CardValue, 
                                    FormValue[LegP2].CardValue, LPlace);
                    EncodePlacement(FormValue[SymP1].CardValue, 
                                    FormValue[SymP2].CardValue, SPlace);
                    IF ((NOT FieldIsHidden(Form, LegP1, FormValue)) AND
                        (NOT FieldIsHidden(Form, TitP1, FormValue)) AND
                        (TPlace = LPlace)) THEN
                        Oops(TitP1);
                    END;
                    IF ((NOT FieldIsHidden(Form, SymP1, FormValue)) AND
                        (NOT FieldIsHidden(Form, TitP1, FormValue)) AND
                        (TPlace = SPlace)) THEN
                        Oops(SymP1);
                    END;
                    IF ((NOT FieldIsHidden(Form, LegP1, FormValue)) AND
                        (NOT FieldIsHidden(Form, SymP1, FormValue)) AND
                        (LPlace = SPlace)) THEN
                        Oops(LegP1);
                    END;

            ELSE
            END;
    |   CheckFieldEntry  :
    |   CheckFieldChange :
            CASE FieldNo OF
                Syms :
                    Protect := NOT VAL(BOOLEAN, FormValue[FieldNo].CardValue);
                    SetFieldProtection(Form, SymP1, FormValue, Protect);
                    SetFieldHidden(Form, SymP1, FormValue, Protect);
                    SetFieldProtection(Form, SymP2, FormValue, Protect);
                    SetFieldHidden(Form, SymP2, FormValue, Protect);
            ELSE
            END;
    |   CheckFieldExit   :
            CASE FieldNo OF
                Tit1,
                Tit2,
                Tit3 : 
                    Protect := NOT (ExistsText(Tit1, Tit3));
                    SetFieldProtection(Form, TitP1, FormValue, Protect);
                    SetFieldHidden(Form, TitP1, FormValue, Protect);
                    SetFieldProtection(Form, TitP2, FormValue, Protect);
                    SetFieldHidden(Form, TitP2, FormValue, Protect);
            |   Leg1,
                Leg2,
                Leg3,
                Leg4,
                Leg5 : 
                    Protect := NOT (ExistsText(Leg1, Leg5));
                    SetFieldProtection(Form, LegP1, FormValue, Protect);
                    SetFieldHidden(Form, LegP1, FormValue, Protect);
                    SetFieldProtection(Form, LegP2, FormValue, Protect);
                    SetFieldHidden(Form, LegP2, FormValue, Protect);
            ELSE
            END;
    |   CheckFieldKey    :
    ELSE
        FatalError();
    END;

    RETURN LooksGood;

END CheckForm;


PROCEDURE EnoughHeapSpace() : BOOLEAN;

VAR
    NoHeapMessage           : ARRAY [0..255] OF CHAR;
    Continue                : BOOLEAN;
    HeapSpaceAvail          : BOOLEAN;

BEGIN
    Continue := TRUE;
    HeapSpaceAvail := HeapAvailable();

    IF (NOT HeapSpaceAvail) THEN
        GetMessage(ModuleNumber + NoHeapMsg, NoHeapMessage);
        Error(NoHeapMessage);
        Continue := FALSE;
    END;

    RETURN (Continue);

END EnoughHeapSpace;


PROCEDURE DecodePlacement(    Placement     : ATLGSTitlePlacement;
                          VAR TopBottom     : CARDINAL;
                          VAR LeftRtCenter  : CARDINAL);

BEGIN                       (* DecodePlacement *)

    TopBottom := ORD(Placement) DIV 3;
    LeftRtCenter := ORD(Placement) MOD 3;

END DecodePlacement;



PROCEDURE EncodePlacement(    TopBottom     : CARDINAL;
                              LeftRtCenter  : CARDINAL;
                          VAR Placement     : ATLGSTitlePlacement);
                          
BEGIN                       (* EncodePlacement *)

    Placement := VAL(ATLGSTitlePlacement, TopBottom * 3 + LeftRtCenter);

END EncodePlacement;









PROCEDURE ExecForm(    ParentForm        : AForm;
                       LocalReportTitles : ATLGSTitleBlockPtr ) : ACode;
VAR
    Code                    : ACode;
    i                       : CARDINAL;
    j                       : CARDINAL;
    FormValue               : ARRAY [0..14] OF AFieldValue;
    BottomX                 : CARDINAL;
    BottomY                 : CARDINAL;

BEGIN

    ReportTitles := LocalReportTitles;

    WITH ReportTitles^ DO
        FOR i:= Tit1 TO Tit3 DO
            NEW(FormValue[i].CharValue);
            Copy(Title[i - Tit1 + 1].LineOfText, FormValue[i].CharValue^);
        END;

        DecodePlacement(TitlePlace, FormValue[TitP1].CardValue, 
                        FormValue[TitP2].CardValue);
        DecodePlacement(LegendPlace, FormValue[LegP1].CardValue, 
                        FormValue[LegP2].CardValue);
        DecodePlacement(SymbolPlace, FormValue[SymP1].CardValue, 
                        FormValue[SymP2].CardValue);

        FormValue[Syms].CardValue := ORD(ExistSymbol);

        FOR i := Leg1 TO Leg5 DO
            NEW(FormValue[i].CharValue);
            Copy(Legend[i - Leg1 + 1].LineOfText, FormValue[i].CharValue^);
        END;
    END;

    (* goforit *)
    FindFormBoundaries(ParentForm, i, j, BottomX, BottomY);
    Code := DoForm(0, 0, BottomX, BottomY - 1, FormID, TRUE, FormValue, CheckForm);

    IF (Code <> CancelKey) THEN
        ScheduleSaved := FALSE;
        WITH ReportTitles^ DO
            EncodePlacement(FormValue[TitP1].CardValue, 
                            FormValue[TitP2].CardValue, TitlePlace);
            EncodePlacement(FormValue[LegP1].CardValue, 
                            FormValue[LegP2].CardValue, LegendPlace);
            EncodePlacement(FormValue[SymP1].CardValue, 
                            FormValue[SymP2].CardValue, SymbolPlace);
            ExistSymbol  := VAL(BOOLEAN, FormValue[Syms].CardValue);
            
            (* Boolean fields *)
            (* See if there is any title text and if so, save it *)
            ExistTitle := FALSE;
            FOR i := Tit1 TO Tit3 DO
                TrimRear(FormValue[i].CharValue^);
                IF (LengthOf(FormValue[i].CharValue^) > 0) THEN
                    ExistTitle := TRUE;
                END;
                Copy(FormValue[i].CharValue^, Title[i-Tit1+1].LineOfText);
                DISPOSE(FormValue[i].CharValue);
            END;
            
            (* Boolean fields *)
            (* See if there is any Legend text and if so, save it *)
            ExistLegend := FALSE;
            FOR i := Leg1 TO Leg5 DO
                TrimRear(FormValue[i].CharValue^);
                IF (LengthOf(FormValue[i].CharValue^) > 0) THEN
                    ExistLegend := TRUE;
                END;
                Copy(FormValue[i].CharValue^, Legend[i-Leg1+1].LineOfText);
                DISPOSE(FormValue[i].CharValue);
            END;
        END;
    END;

    RETURN(Code);
END ExecForm;



PROCEDURE EditPageDescrip(    ParentForm   : AForm;
                              ChartType    : ATLGSChartType );

VAR
    TitleBlock              : ATLGSTitleBlockPtr;                 (* 29-May-89 LAA *)

BEGIN

    IF (EnoughHeapSpace()) THEN
        TitleBlock := LockTLGSTitleBlock(ChartType);
        IF (ExecForm(ParentForm, TitleBlock) = ExitKey) THEN END;
        UnlockTLGSTitleBlock(ChartType);
    END;

END EditPageDescrip;



BEGIN
END TLGSTitle.


