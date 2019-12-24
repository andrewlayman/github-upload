MODULE TLGSPAGE;

(*  =========================================================================
    Last Edit : December 29, 1989 4:34PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:
        23-Jan-89 LAA/CMH   Added fields for BorderX and ImageX if the border
                            repeat flag is on.  These must be duplicated in
                            the record description of the page desc. form.
        30-Jan-89 LAA   Set ExportersOK to FALSE if esc is pressed from the
                        form.
        01-Feb-89 LAA   Indulged myself in a little clean-up work.  This
                        probably didn't actually fix anything.
        07-Feb-89 LAA   Merged in Carol's new initialization numbers, and
                        removed the "Repeat" fields, which are no longer
                        necessary.
        17-Feb-89 LAA   Removed the "Repeat Titles and Legends" field, and
                        added use of GetMessage.
        22-Mar-89 WKH   Restructured form as per marketing's design.
        22-Mar-89 WKH   Made Original Size fields into one string
        18-Apr-89 RSC   Added IlsaStatic support; Removed Holder references.
        01-Jun-89 WKH   Incorporate new setup record info, handle rotation and
                        continuous feed.
        08-Jun-89 WKH   Changed TLGSetupRecord field references so that X now
                        means Wide and Y means High.
        11-Jun-89 LAA   Corrected a Too Long error by making the array bigger.
        12-Jun-89 WKH   Only perform check of borders being too large if user
                        wants borders on each page.
        20-Jun-89 AJL   Return the code from the check proc on CheckFieldKey
                        unless it is one we explicitly handle. 
        22-Jun-89 LAA   Swap the values of plottable size High and Wide if
                        the Rotated flag is true.  Removed the presentation
                        quality choice from the form and the checkproc.  
                        Defaulted the feed orientation to Portrait if the 
                        page is exactly square.  Also fixed up the error
                        message about borders being too big.  And put in the
                        code to use the new OrigPlotArea fields of the setup
                        record.
        23-Jun-89 LAA   Edit check the Scale field so it's greater than zero.
        09-Aug-89 KKC   Add copyright message.
        28-Aug-89 WKH   New plan.  If the original dimensions of the plot did
                        not change from the previous(if any) plot, and the
                        user doesn't want to force a plot to one page, then
                        leave the scale alone.  Otherwise, force scale to
                        100%.
        20-Sep-89 WKH   Limit pagesx and pagesy to 1000 pages.
        09-Nov-89 LAA   Moved from here TLDevSet: code which determines
                        whether or not the plot area X and Y need to be
                        interchanged, or set to the papersize for continuous
                        printing.  This is necessary because the Sedona code
                        needs to know the plottable area before we ever get
                        to the TLGSPage overlay.
        17-Nov-89 WKH   Change pagesx and pagesy limit from 1000 to 50 pages
        21-Dec-89 WKH   Add field to autosave schedule before plot.
                        Also correct problem with page calculations if 
                        ImageXVirtual or ImageYVirtual is 0.
        29-Dec-89 WKH   Pay no attention to border repead field if we are
                        doing a PERT chart.

    =========================================================================
*)

FROM Codes                  IMPORT
    (* TYPE *)                  ACode, EmptyCodeSet;

FROM Dialog                 IMPORT
    (* PROC *)                  Error, ContinuationBox, FatalError, Burp;

FROM RealFormat             IMPORT
    (* VAR *)                   DefaultAmountFormat,
    (* PROC *)                  FormatAsAmount;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo, AFieldType;

FROM Forms                  IMPORT
    (* TYPE *)                  AFieldValue, AForm, ACheckReason,
                                ACursorAttribute,
    (* PROC *)                  DoForm, SetFieldProtection, ShowValue,
                                HighlightField, FieldIsProtected;

FROM Holder                 IMPORT
    (* TYPE *)                  AHoldType, AHoldTypeSet,
    (* PROC *)                  HoldThis, LocateHeldItem;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  AGraphStyle, ATLGSPageRecord,
                                ATLGSPageRecordPtr, ATLGSSetupRecord,
                                ATLGSSetupRecordPtr, AGraphicsOrientation,
                                ATLGSChartType,
    (* PROC *)                  TLGSPageRecord, TLGSSetupRecord;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow, avidmode;

FROM Keys                   IMPORT
     (* CONST *)                CancelKey, ExitKey, DoIt, EditKey;

FROM Layout                 IMPORT MenuStart, GanttWEnd;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, Copy, Compare, SetLengthOf,
                                LengthOf, TrimRear, ConcatLS, Fill, CtoS,
                                ConcatS;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, DisplayMessage, ConcatMessage;

FROM Overlays               IMPORT
    (* PROC *)                  PackageOK;

FROM Schedule               IMPORT
    (* VAR *)                   ConfigSaved;

FROM Space                  IMPORT
    (* VAR *)                   HeapAvailable,
    (* PROC *)                  ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;

FROM Text                   IMPORT
    (* TYPE *)                  AText;

CONST
    ModuleNumber            = 26200;
    Hundred                 = 100.0;


(* These are used to get messages from GetMessage *)
    NOHEAP                  = ModuleNumber + 0;
    BORDERSTOOLARGE         = ModuleNumber + 1;
    PAGESTOOLARGE           = ModuleNumber + 2;
    ORIGINALSIZE            = ModuleNumber + 20;
    PAGESACROSS             = ModuleNumber + 21;
    PAGESDOWN               = ModuleNumber + 22;

(* The following are used to initialize the FormValue array *)
    Orig                    = 0; (* Original Size: Pages Across *)
    On1P                    = 1; (* Fit plot onto one page *)
    PgAc                    = 2; (* Plot size across *)
    PgDn                    = 3; (* Plot size down *)
    Scal                    = 4; (* Scale *)
    Prev                    = 5; (* Preview plot to screen *)
    AuSv                    = 6; (* AutoSave before plot *)

    MaximumPages            = 50.00;

TYPE
    APreviousSettingsRecord = RECORD
                                ScalingFactor       : REAL;
                                NumVertPages        : REAL;
                                NumHorizPages       : REAL;
                              END;

    APreviousSettingsPtr    = POINTER TO APreviousSettingsRecord;


VAR
    TLGSPageInfo            : ATLGSPageRecordPtr;
    SetupInfo               : ATLGSSetupRecordPtr;
    PreviousSetting         : APreviousSettingsRecord;


    
PROCEDURE CalcPagesX(    ScaleFactor    : REAL;
                         RepeatBorders  : BOOLEAN;
                     VAR PagesX         : REAL   );

BEGIN                   (* CalcPagesX *)

    ScaleFactor := ScaleFactor / Hundred;

    WITH TLGSPageInfo^ DO
        IF (RepeatBorders AND (WhatsMyChart = TLGSGanttChart)) THEN (* 29-Dec-89 WKH  *)
            PagesX := ImageXVirtual * ScaleFactor;
            PagesX := PagesX / (SetupInfo^.PlotAreaWide - 
                        ScaleFactor * (Border1XVirtual + Border2XVirtual));
            IF (PagesX = 0.0) THEN
                PagesX := (ScaleFactor * (Border1XVirtual + Border2XVirtual)) /
                          SetupInfo^.PlotAreaWide;
            END;
        ELSE
            PagesX := ImageXVirtual + Border1XVirtual + Border2XVirtual;
            PagesX := (PagesX * ScaleFactor) / SetupInfo^.PlotAreaWide;
        END;
    END;

END CalcPagesX;



PROCEDURE CalcPagesY(    ScaleFactor    : REAL;
                         RepeatBorders  : BOOLEAN;
                     VAR PagesY         : REAL   );

BEGIN                   (* CalcPagesY *)

    ScaleFactor := ScaleFactor / Hundred;

    WITH TLGSPageInfo^ DO
        IF (RepeatBorders AND (WhatsMyChart = TLGSGanttChart)) THEN (* 29-Dec-89 WKH  *)
            PagesY := ImageYVirtual * ScaleFactor;
            PagesY := PagesY / (SetupInfo^.PlotAreaHigh - 
                        ScaleFactor * (Border1YVirtual + Border2YVirtual));
            IF (PagesY = 0.0) THEN
                PagesY := (ScaleFactor * (Border1YVirtual + Border2YVirtual)) /
                          SetupInfo^.PlotAreaHigh;
            END;
        ELSE
            PagesY := ImageYVirtual + Border1YVirtual + Border2YVirtual;
            PagesY := (PagesY * ScaleFactor) / SetupInfo^.PlotAreaHigh;
        END;
    END;

END CalcPagesY;


PROCEDURE CheckPAGEForm(    Form        : AForm;
                            FieldNo     : AFieldNo;
                        VAR FormValue   : ARRAY OF AFieldValue;
                            CheckReason : ACheckReason;
                        VAR Code        : CARDINAL) : BOOLEAN;
VAR
    CodeIn                  : CARDINAL;
    i                       : CARDINAL;
    BadPage                 : CARDINAL;
    ExitVal                 : BOOLEAN;
    ReturnCode              : ACode;  


    PROCEDURE ChangeFieldProtection(On : BOOLEAN);

    BEGIN
        SetFieldProtection(Form, PgAc, FormValue, On);
        SetFieldProtection(Form, PgDn, FormValue, On);
        SetFieldProtection(Form, Scal, FormValue, On);
    END ChangeFieldProtection;



    PROCEDURE FitOnto1Page(VAR ScaleFactor  : REAL;
                           VAR PagesX       : REAL;
                           VAR PagesY       : REAL);

    VAR
        BordersXVirtual     : REAL;
        BordersYVirtual     : REAL;


        PROCEDURE RealMin(r1, r2 : REAL) : REAL;

        VAR
            smallest : REAL;

        BEGIN
            IF (r1 < r2) THEN
                smallest := r1;
            ELSE
                smallest := r2;
            END;
    
            RETURN(smallest);
        END RealMin;

    BEGIN                   (* FitOnto1Page *)

        WITH TLGSPageInfo^ DO
            BordersXVirtual := Border1XVirtual + Border2XVirtual;
            BordersYVirtual := Border1YVirtual + Border2YVirtual;

            PagesX := SetupInfo^.PlotAreaWide / (ImageXVirtual + BordersXVirtual);
            PagesY := SetupInfo^.PlotAreaHigh / (ImageYVirtual + BordersYVirtual);

            ScaleFactor := RealMin(PagesX, PagesY); 

            PagesX := ((ImageXVirtual + BordersXVirtual) * ScaleFactor)
                      / SetupInfo^.PlotAreaWide;
            PagesY := ((ImageYVirtual + BordersYVirtual) * ScaleFactor)
                      / SetupInfo^.PlotAreaHigh;

            ScaleFactor := ScaleFactor * Hundred;
        END;

    END FitOnto1Page;


    PROCEDURE RestorePrevValues();

    BEGIN                   (* RestorePrevValues *)

        WITH PreviousSetting DO
            FormValue[Scal].RealValue := ScalingFactor;
            FormValue[PgDn].RealValue := NumVertPages;
            FormValue[PgAc].RealValue := NumHorizPages;
        END;

    END RestorePrevValues;


    PROCEDURE SavePrevValues();

    BEGIN                   (* SavePrevValues *)

        WITH PreviousSetting DO
            ScalingFactor := FormValue[Scal].RealValue;
            NumVertPages  := FormValue[PgDn].RealValue;
            NumHorizPages := FormValue[PgAc].RealValue;
        END;

    END SavePrevValues;



    PROCEDURE CalcScaleFromPagesX(    PagesX        : REAL;
                                      RepeatBorders : BOOLEAN;
                                      OnePage       : BOOLEAN;
                                  VAR ScaleFactor   : REAL   ): BOOLEAN;

    VAR
        R                       : REAL;

    BEGIN                       (* CalcScaleFromPagesX *)

        WITH TLGSPageInfo^ DO
            IF (RepeatBorders AND (WhatsMyChart = TLGSGanttChart)) THEN (* 29-Dec-89 WKH  *)
                R := (PagesX * SetupInfo^.PlotAreaWide) /
                     (ImageXVirtual+PagesX*(Border1XVirtual+Border2XVirtual));
            ELSE
                R := (PagesX * SetupInfo^.PlotAreaWide) /
                     (ImageXVirtual + Border1XVirtual + Border2XVirtual);
            END;
        END;

        IF (ValidateScale(R, RepeatBorders, OnePage)) THEN
            ScaleFactor := R * Hundred;
            RETURN TRUE;
        END;

        RETURN FALSE;
    
    END CalcScaleFromPagesX;



 
    PROCEDURE CalcScaleFromPagesY(    PagesY        : REAL;
                                      RepeatBorders : BOOLEAN;
                                      OnePage       : BOOLEAN;
                                  VAR ScaleFactor   : REAL   ): BOOLEAN;

    VAR
        R                       : REAL;

    BEGIN                       (* CalcScaleFromPagesY *)

        WITH TLGSPageInfo^ DO
            IF (RepeatBorders AND (WhatsMyChart = TLGSGanttChart)) THEN (* 29-Dec-89 WKH  *)
                R := (PagesY * SetupInfo^.PlotAreaHigh) /
                     (ImageYVirtual+PagesY*(Border1YVirtual+Border2YVirtual));
            ELSE
                R := (PagesY * SetupInfo^.PlotAreaHigh) /
                     (ImageYVirtual + Border1YVirtual + Border2YVirtual);
            END;
        END;

        IF (ValidateScale(R, RepeatBorders, OnePage)) THEN
            ScaleFactor := R * Hundred;
            RETURN TRUE;
        END;

        RETURN FALSE;

    END CalcScaleFromPagesY;



    PROCEDURE ValidateScale(    ScaleFactor : REAL;
                                RepeatBorder: BOOLEAN;
                                OnePage     : BOOLEAN) : BOOLEAN;

    CONST
        MaxBorderSpace      = 0.75; (* % of physical page size *)
        ScaleLowerLimit     = 0.00001;  (* times 100, so limit is 0.001 *)

    VAR
        BorderWidth         : REAL;
        BorderHeight        : REAL;
        s                   : ARRAY [0..255] OF CHAR;             (* 11-Jun-89 LAA *)
        AOK                 : BOOLEAN;

    BEGIN
        AOK := (ScaleFactor >= ScaleLowerLimit);
        WITH TLGSPageInfo^ DO
            IF ((OnePage) OR (RepeatBorder AND (WhatsMyChart = TLGSGanttChart))) THEN                 (* 22-Jun-89 LAA *)
                BorderWidth  := ScaleFactor * (Border1XVirtual+Border2XVirtual);
                BorderHeight := ScaleFactor * (Border1YVirtual+Border2YVirtual);
                IF ((BorderWidth > (SetupInfo^.PlotAreaWide * MaxBorderSpace)) OR
                    (BorderHeight > (SetupInfo^.PlotAreaHigh * MaxBorderSpace))) THEN
                        (* The border area, containing Titles, Legends & Symbols, is too large for the page. *)
                    GetMessage(BORDERSTOOLARGE, s);                   (* 17-Feb-88 LAA *) 
                    Error(s);
                    AOK := FALSE;
                END;
            END;
        END;
        RETURN(AOK);
    END ValidateScale;


    PROCEDURE ShowPagesAndScale();

    BEGIN                   (* ShowPagesAndScale *)

        ShowValue(Form, PgAc, FormValue);
        ShowValue(Form, PgDn, FormValue);
        ShowValue(Form, Scal, FormValue);

    END ShowPagesAndScale;


    PROCEDURE PageSizesCool(VAR BadPage : CARDINAL) : BOOLEAN;

    VAR
        s                   : ARRAY[0..99] OF CHAR;
        s2                  : ARRAY[0..13] OF CHAR;
        WeBeCool            : BOOLEAN;
                
    BEGIN
        WeBeCool := TRUE;

        IF (FormValue[PgAc].RealValue > MaximumPages) THEN
            WeBeCool := FALSE;
            BadPage  := PgAc;
        ELSIF (FormValue[PgDn].RealValue > MaximumPages) THEN
            WeBeCool := FALSE;
            BadPage  := PgDn;
        END;

        IF (NOT WeBeCool) THEN
            GetMessage(PAGESTOOLARGE, s);
            CtoS(TRUNC(MaximumPages), s2);
            ConcatLS(s, s2);
            Error(s);
        END;
            
        RETURN WeBeCool;
    END PageSizesCool;


BEGIN

    CodeIn  := Code;
    Code    := 0;
    ExitVal := TRUE;

    CASE CheckReason OF

    |   CheckFormEntry :
            CASE FieldNo OF
                Orig :  SetFieldProtection(Form, FieldNo, FormValue, TRUE);

            |   On1P :  ChangeFieldProtection(FormValue[FieldNo].CardValue=1);
                        IF (FormValue[FieldNo].CardValue=1) THEN
                            FitOnto1Page(FormValue[Scal].RealValue,
                                         FormValue[PgAc].RealValue,
                                         FormValue[PgDn].RealValue);
                        END;

            ELSE
            END;

    |   CheckFieldEntry :

    |   CheckFieldChange :
            CASE FieldNo OF
                On1P :  ChangeFieldProtection(FormValue[FieldNo].CardValue=1);
                        IF (FormValue[FieldNo].CardValue=1) THEN
                            FitOnto1Page(FormValue[Scal].RealValue,
                                         FormValue[PgAc].RealValue,
                                         FormValue[PgDn].RealValue);
                        ELSE
                            RestorePrevValues();
                            CalcPagesX(FormValue[Scal].RealValue,
                                       TLGSPageInfo^.Borders,
                                       FormValue[PgAc].RealValue);
                            CalcPagesY(FormValue[Scal].RealValue,
                                       TLGSPageInfo^.Borders,
                                       FormValue[PgDn].RealValue);
                        END;
                        ShowPagesAndScale();

            ELSE
            END;

    |   CheckFieldKey :
            Code := CodeIn + CARDINAL({14});    (* Whoops.  Give it back. *)

    |   CheckFieldExit :
            CASE FieldNo OF
                Scal : 
                        IF (ValidateScale(FormValue[Scal].RealValue/Hundred,
                                          TLGSPageInfo^.Borders,
                                          FormValue[On1P].CardValue=1)) THEN
                            CalcPagesX(FormValue[Scal].RealValue,
                                       TLGSPageInfo^.Borders,
                                       FormValue[PgAc].RealValue);
                            CalcPagesY(FormValue[Scal].RealValue,
                                       TLGSPageInfo^.Borders,
                                       FormValue[PgDn].RealValue);

                            (*<DEBUGGING
                            IF ((FormValue[PgAc].RealValue < 0.0) 
                                OR (FormValue[PgDn].RealValue < 0.0)) THEN
                                HALT;
                            END;
                            DEBUGGING>*)

                            ShowPagesAndScale();

                            IF (FormValue[On1P].CardValue <> 1) THEN
                                SavePrevValues();
                            END;
                        ELSE
                            ExitVal := FALSE;
                            Burp();
                        END;


            |   PgAc :  ExitVal := CalcScaleFromPagesX(FormValue[PgAc].RealValue,
                                                       TLGSPageInfo^.Borders,
                                                       FormValue[On1P].CardValue=1,
                                                       FormValue[Scal].RealValue);
                        IF (ExitVal) THEN
                            CalcPagesY(FormValue[Scal].RealValue,
                                       TLGSPageInfo^.Borders,
                                       FormValue[PgDn].RealValue);
                            ShowPagesAndScale();

                            IF (FormValue[On1P].CardValue <> 1) THEN
                                SavePrevValues();
                            END;
                        END;

            |   PgDn :  ExitVal := CalcScaleFromPagesY(FormValue[PgDn].RealValue,
                                                       TLGSPageInfo^.Borders,
                                                       FormValue[On1P].CardValue=1,
                                                       FormValue[Scal].RealValue);

                        IF (ExitVal) THEN
                            CalcPagesX(FormValue[Scal].RealValue,
                                       TLGSPageInfo^.Borders,
                                       FormValue[PgAc].RealValue);
                            ShowPagesAndScale();

                            IF (FormValue[On1P].CardValue <> 1) THEN
                                SavePrevValues();
                            END;
                        END;
            ELSE
            END;

    |   CheckFormExit : 
            ExitVal := ValidateScale(FormValue[Scal].RealValue/Hundred,
                                     TLGSPageInfo^.Borders,
                                     FormValue[On1P].CardValue=1);
            IF (NOT ExitVal) THEN                                 (* 23-Jun-89 LAA *)
                Code := CARDINAL({15} + BITSET(Scal));
            ELSIF (NOT PageSizesCool(BadPage)) THEN   (* 20-Sep-89 WKH  *)
                ExitVal := FALSE;
                Code := CARDINAL({15} + BITSET(BadPage));
            END;
    ELSE
        FatalError();
    END;

    RETURN (ExitVal);

END CheckPAGEForm;



PROCEDURE DisplayPAGEForm() : ACode;

CONST
    FormID                  = 56;
    ULX                     = 7;
    ULY                     = 7;
    LRX                     = 74;
    LRY                     = 17;

VAR
    Code                    : ACode;
    i                       : CARDINAL;
    FormValue               : ARRAY [0..6] OF AFieldValue;
    s                       : ARRAY [0..255] OF CHAR;
    Across, Down            : REAL;
    PaperFeedOrientation    : AGraphicsOrientation;
    SettingsFromLastTime    : APreviousSettingsPtr;
    Size                    : CARDINAL;
    SettingsCategory        : AHoldTypeSet;

BEGIN

    TLGSPageInfo := TLGSPageRecord();  (* RSC 18-Apr-89 *)
    SetupInfo    := TLGSSetupRecord();

    WITH SetupInfo^ DO  (* 6/1/89 WKH *)
        IF (PhysPageWide <= PhysPageHigh) THEN                     (* 22-Jun-89 LAA *)
            PaperFeedOrientation := Portrait;
        ELSE                                                      
            PaperFeedOrientation := Landscape;
        END;

        TLGSPageInfo^.Rotated := ((PhysPageWide <> PhysPageHigh) 
                                  AND (Orientation <> PaperFeedOrientation));

    END;
    

    WITH TLGSPageInfo^ DO
        FormValue[On1P].CardValue := ORD(On1Page);
        FormValue[Scal].RealValue := Scale * Hundred;
        FormValue[Prev].CardValue := ORD(Preview);
        FormValue[AuSv].CardValue := ORD(AutoSave); (* 21-Dec-89 WKH  *)
    END;

    (* Original size *)
    CalcPagesX(Hundred, TLGSPageInfo^.Borders, Across);
    CalcPagesY(Hundred, TLGSPageInfo^.Borders, Down);


    (* Look for last plot size and see if they are equal to this one *)
    (* if not, force scale to 100% if not forcing to one page *)
    SetString(s, "LastPage");

    IF (NOT LocateHeldItem(s, 1, SettingsCategory, 
                           SettingsFromLastTime, Size)) THEN
        NEW(SettingsFromLastTime);
        WITH SettingsFromLastTime^ DO
            NumVertPages  := Down;
            NumHorizPages := Across;
            ScalingFactor := 1.0;
        END;
        SettingsCategory := AHoldTypeSet{HoldTransiently, HeapNoOwner};
        HoldThis(s, 1, SettingsCategory, SettingsFromLastTime,
                 TSIZE(APreviousSettingsRecord));
    END;

    WITH SettingsFromLastTime^ DO
        IF ( (NumVertPages <> Down) OR (NumHorizPages <> Across) ) THEN
            FormValue[Scal].RealValue := Hundred;
            TLGSPageInfo^.Scale       := 1.0;   (* 28-Aug-89 WKH Had to do this! *)
            NumVertPages              := Down;
            NumHorizPages             := Across;
        END;
    END;

    NEW(FormValue[Orig].CharValue);
    GetMessage(ORIGINALSIZE, FormValue[Orig].CharValue^);

    FormatAsAmount(Across, DefaultAmountFormat, s, 20, 0, 3, FALSE);
    TrimRear(s);
    ConcatLS(FormValue[Orig].CharValue^, s);

    ConcatMessage(FormValue[Orig].CharValue^, PAGESACROSS);

    FormatAsAmount(Down, DefaultAmountFormat, s, 20, 0, 3, FALSE);
    TrimRear(s);
    ConcatLS(FormValue[Orig].CharValue^, s);

    ConcatMessage(FormValue[Orig].CharValue^, PAGESDOWN);

    (* Actual size *)
    CalcPagesX(FormValue[Scal].RealValue, TLGSPageInfo^.Borders,
               FormValue[PgAc].RealValue);
    CalcPagesY(FormValue[Scal].RealValue, TLGSPageInfo^.Borders,
               FormValue[PgDn].RealValue);

    WITH PreviousSetting DO
        ScalingFactor := FormValue[Scal].RealValue;
        NumVertPages  := FormValue[PgDn].RealValue;
        NumHorizPages := FormValue[PgAc].RealValue;
    END;


    Code := DoForm(ULX, ULY, LRX, LRY, FormID, TRUE, FormValue, CheckPAGEForm);

    IF (Code <> CancelKey) THEN
        ConfigSaved := FALSE;

        WITH TLGSPageInfo^ DO
            (* Copy stuff out of FormValue *)
            On1Page     := VAL(BOOLEAN, FormValue[On1P].CardValue);
            PagesAcross := FormValue[PgAc].RealValue;
            PagesDown   := FormValue[PgDn].RealValue;
            Scale       := FormValue[Scal].RealValue/Hundred;
            GraphStyle  := PresentationQ;                         (* 22-Jun-89 LAA *)
            Preview     := VAL(BOOLEAN, FormValue[Prev].CardValue);
            AutoSave    := VAL(BOOLEAN, FormValue[AuSv].CardValue); (* 21-Dec-89 WKH  *)
        END;
    END;

    DISPOSE(FormValue[Orig].CharValue);
    RETURN(Code);

END DisplayPAGEForm;


PROCEDURE TLPageMain();

VAR
    NoHeapMessage      : ARRAY [0..255] OF CHAR;
    Copyright          : ARRAY[0..50] OF CHAR;

BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF (NOT HeapAvailable()) THEN
            (* There isn't enought memory to use this form. *)
        GetMessage(NOHEAP, NoHeapMessage);                        
        Error(NoHeapMessage);
        PackageOK := FALSE;                                     (* 30-Jan-89 LAA *)
    ELSE
        IF (DisplayPAGEForm() <> ExitKey) THEN
            PackageOK := FALSE;                                 (* 30-Jan-89 LAA *)
        END;
    END;

END TLPageMain;


BEGIN

    TLPageMain();

END TLGSPAGE.

