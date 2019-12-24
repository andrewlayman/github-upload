IMPLEMENTATION MODULE InitTL;

(*  =========================================================================
    Last Edit : January 23, 1991 9:42AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:
    Init TL     Initialize Time Line Modules.

    Initialize misc. Time Line modules that do not need data from the config
    file.  These procedures' init code is here so that the code that does the
    initialization can be in TLStart for Time Line, and can be bound into
    stand-alone programs.



    MODIFICATION HISTORY:

    16-May-89  RSC  From TLSTart, for use by stand-alone programs and
                    Time Line.  Put init code in here for items not from
                    the config file.
    26-May-89  LAA  Moved initialization code for IlsaStatic here.
    01-Jun-89  WKH  Changed TLGSPageRecord defaults back into Sedona Units.
    10-Jun-89  LAA  Initialize the new stuff for scrolling lists of Palettes.
    13-Jun-89  LAA  Created the PaletteTrees.
    26-Jul-89  WKH  Changed default Gantt Chart time unit to Weeks.
    15-Sep-89  WKH  Changed default Color Palette to be same as HP LJ II.
    21-Sep-89  WKH  Changed default TimeUnit to days
    09-Oct-89  MWP  Moved text literal to phrases file.
    LAA  01-Dec-89  'twas the night before code-freeze, and all through
                    the house, not a damn thing was working, not even 
                    DOS!  And I just returned from enjoying my perks, to
                    find that having a DefaultPalette shared between Gantt 
                    and PERT palettes just doesn't work!  
                    Even the identical color items are not mapped to the 
                    same element of the array.  So I've changed the 
                    DefaultPalette to be an array.
    WKH  21-Dec-89  Are you kidding??? Code never freezes around here.
                    Initialize new AutoSave field for page record.
    WKH  28-Dec-89  The starship Lazlo, it's NEVER ENDING mission to be
                    re-written, seeking out new bugs, boldly crashing where
                    no programs have crashed before...
                    OK, for real, initialze the new chart type field in
                    the TLGSPage record.
    30-Mar-90 RSC   Removed Timeu unused items.  Removed import of PlotStatic.
     6-Aug-90 RSC   Updated the init of the assignment forms.
     7-Aug-90 RSC   Updated the init of the assignment forms again.
     5-Nov-90 PFG   Added Overtime Units to assignment form.
    12-Dec-90 TGS   No more Overtime Units fields on assignment form.
    20-Nov-90 TGS   Renumbered assignment form fields.
    31-Dec-90 AJL   Added OvertimeField to the set of fields which are always
                    redisplayed on the assignment form.
    16-May-91 TGS   Remove Overtime fields & renumber what's left.
    =========================================================================
*)



FROM Changer        IMPORT
    (* TYPES *)         AnAssignmentField, AnAssignmentFieldSet,
                        AFormMappingRecord,
                        AnAssignmentForm,
    (* VARS  *)         FormMappingRecords;

FROM Dialog         IMPORT
    (* PROC *)          FatalError;

FROM FlexStor       IMPORT
    (* TYPE *)          AnExtHandle, AnExtStoragePreference,
    (* PROC *)          CreateExtObjectWithSize, LockObject, ReleaseObject;

FROM Foreign        IMPORT
    (* VAR  *)          UpshiftTable, SortOrderTable,
    (* PROC *)          ExpandStringToXLAT, DoDash, DecodeString;

FROM Gantt          IMPORT
    (* VAR *)           ChartFont, SummaryFont, BaselineDetailFont,
                        BaselineSummaryFont;

FROM GraphSupport   IMPORT
    (* PROC *)          GetDefaultBorder;

FROM IlsaStatic     IMPORT
    (* TYPE *)          ATLGSTitleBlockPtr, ATLGSColorAssignmentPtr,
                        ATLGSPertRecordPtr, ATLGSGanttRecordPtr,
                        ATLGSTreeRecordPtr, ATLGSPageRecordPtr,
                        ATLGSColorAssignment,
                        ATLGSChartType, ATLGSScale, ATLGSTitlePlacement,
                        ATLGSGridStyle, ATLGSCorner, AnOrientation,
                        ATLGSTaskArrangement, ATLGSSymbology, ATLGSPosition,
                        AGraphStyle, AUserUnit, AGraphicsOrientation,
    (* CONST *)         TlgsPertTagNumber, TLGSColorTagNumber,
                        TlgsGanttTagNumber, TLGSTreeTagNumber,
                        TILG, TXHD, BRDR, ASOF, MJGD, MNGD, PAGE,
                        BKHD, DATA, TKBR, F1FG, F1BG, F2FG, F2BG,
                        F3FG, F3BG, OSTK, AOTK, OSBR, AOTB, MILE,
                        BASE, ACMT, SLAK, PTILG, PTXHD, PBRDR, PPAGE, 
                        PBKHD, PBKCH, PBKTB, PF1FG, PF1BG, PF2FG, PF2BG, 
                        PF3FG, PF3BG, POPST, PAOTK, POPSB, PAOBX, PMSBX, 
                        PPTDP, 
    (* VAR *)           DefaultPalette, PaletteTree, 
    (* PROC *)          GetDefaultFontSpecs, LockTLGSTitleBlock,
                        UnlockTLGSTitleBlock, TLGSPertRecord,
                        TLGSGanttRecord, TLGSPageRecord, TLGSTreeRecord;

FROM LStrings       IMPORT
    (* PROC *)          SetString, SetLengthOf, Copy, Fill;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage;

FROM RealFormat     IMPORT
    (* Var *)           DefaultAmountFormat,
                        DefaultCurrencyFormat;

FROM Text           IMPORT
    (* TYPE *)          AText;

FROM TimeFormat     IMPORT
    (* Var *)           DefaultDateAndTimeFormat,
                        DefaultDateFormat,
                        DefaultTimeFormat;

FROM Timei          IMPORT
    (* CONST*)          MinDate,
    (* TYPE *)          ADurationUnit;

FROM TreeObjects    IMPORT
    (* PROC *)          CreateTreeNode, CreateTree;

FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS,
    (* PROC *)          TSIZE;



CONST
    ModuleNumber    = 5000;   (* For GetMessage. *)







PROCEDURE SetupFonts();
VAR
    s   : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+3,s);
    ExpandStringToXLAT(s,ChartFont);
    GetMessage(ModuleNumber+4,s);                                (* 09-Jun-87 LAA *)
    ExpandStringToXLAT(s,SummaryFont);
    GetMessage(ModuleNumber+5,s);
    ExpandStringToXLAT(s,BaselineDetailFont);
    GetMessage(ModuleNumber+6,s);
    ExpandStringToXLAT(s,BaselineSummaryFont);
END SetupFonts;








PROCEDURE InitRealAndTimeFormat();
VAR i : CARDINAL;
BEGIN

    WITH DefaultDateAndTimeFormat[0] DO
        Unit := Days;
        Size := 2;
        Text := FALSE;
        SetString(FillChar," ");
        SetString(FollowBy,"-");
    END;
    WITH DefaultDateAndTimeFormat[1] DO
        Unit := Months;
        Size := 3;
        Text := TRUE;
        SetString(FollowBy,"-");
    END;
    WITH DefaultDateAndTimeFormat[2] DO
        Unit := Years;
        Size := 2;
        Text := FALSE;
        SetString(FillChar,"0");
        SetString(FollowBy," ");
    END;
    WITH DefaultDateAndTimeFormat[3] DO
        Unit := Hours;
        Size := 2;
        Text := FALSE;
        SetString(FillChar," ");
        SetString(FollowBy,":");
    END;
    WITH DefaultDateAndTimeFormat[4] DO
        Unit := Minutes;
        Size := 2;
        Text := FALSE;
        SetString(FillChar,"0");
        SetString(FollowBy," ");
    END;

    DefaultDateFormat := DefaultDateAndTimeFormat;
    FOR i := 3 TO 4 DO
        DefaultDateFormat[i].Size := 0;
        SetLengthOf (DefaultDateFormat[i].FollowBy, 0);
    END;

    DefaultTimeFormat := DefaultDateAndTimeFormat;
    FOR i := 0 TO 2 DO
        DefaultTimeFormat[i].Size := 0;
        SetLengthOf (DefaultTimeFormat[i].FollowBy, 0);
    END;

END InitRealAndTimeFormat;








PROCEDURE InitAssForms();
VAR Loop : CARDINAL;
    Form : AnAssignmentForm;
BEGIN
    FOR Form := ResourceForm TO FixedCostForm DO
        WITH FormMappingRecords[ Form ] DO
            FOR Loop := 1 TO HIGH( FieldTable ) DO
                FieldTable[Loop] := NoField;
            END;
            CASE Form OF
                ResourceForm : FieldCount     := 16;
                               RedisplayMask  := AnAssignmentFieldSet{
                                                  NumberField,
                                                  PercentageField,
                                                  TotalAsTime,
                                                  TotalUnits,
                                                  ModeIndicator1,
                                                  ModeIndicator2,
                                                  ModeIndicator3,
                                                  TotalBucks,
                                                  ActualQuantityField,
                                                  ActualUnitsField,
                                                  ActualBucksField,
                                                  YetToGoQuantityField,
                                                  YetToGoUnitsField,
                                                  YetToGoBucksField};

                               AllocateChars  := AnAssignmentFieldSet{
                                                  ResourceNameField,
                                                  ModeIndicator1,
                                                  ModeIndicator2,
                                                  ModeIndicator3,
                                                  TotalBucks,
                                                  ActualUnitsField,
                                                  ActualBucksField,
                                                  YetToGoUnitsField,
                                                  YetToGoBucksField};
                                                 
                               FieldTable[0]  := ResourceNameField;
                               FieldTable[1]  := NumberField;
                               FieldTable[2]  := PercentageField;
                               FieldTable[3]  := TotalAsTime;
                               FieldTable[4]  := TotalUnits;
                               FieldTable[5]  := ModeIndicator1;
                               FieldTable[6]  := ModeIndicator2;
                               FieldTable[7]  := ModeIndicator3;
                               FieldTable[8]  := TotalBucks;
                               FieldTable[9]  := BillableField;
                               FieldTable[10] := ActualQuantityField;
                               FieldTable[11] := ActualUnitsField;
                               FieldTable[12] := ExtraCostsField;
                               FieldTable[13] := ActualBucksField;
                               FieldTable[14] := YetToGoQuantityField;
                               FieldTable[15] := YetToGoUnitsField;
                               FieldTable[16] := YetToGoBucksField;
                                                 
              | UnitCostForm : FieldCount     := 10;

                               RedisplayMask  := AnAssignmentFieldSet{
                                                  TotalQuantity,
                                                  TotalBucks,
                                                  ActualQuantityField,
                                                  ActualBucksField,
                                                  YetToGoQuantityField,
                                                  YetToGoBucksField};

                               AllocateChars  := AnAssignmentFieldSet{
                                                  ResourceNameField,
                                                  UnitOfMeasureField,
                                                  TotalBucks,
                                                  ActualBucksField,
                                                  YetToGoBucksField};
                               
                               FieldTable[0]  := ResourceNameField;
                               FieldTable[1]  := UnitOfMeasureField;
                               FieldTable[2]  := TotalQuantity;
                               FieldTable[3]  := TotalBucks;
                               FieldTable[4]  := BillableField;
                               FieldTable[5]  := UnitOfMeasureField;
                               FieldTable[6]  := ActualQuantityField;
                               FieldTable[7]  := ActualBucksField;
                               FieldTable[8]  := UnitOfMeasureField;
                               FieldTable[9]  := YetToGoQuantityField;
                               FieldTable[10] := YetToGoBucksField;

              | FixedCostForm: FieldCount     := 4;

                               RedisplayMask  := AnAssignmentFieldSet{
                                                  TotalQuantity,
                                                  ActualQuantityField,
                                                  YetToGoQuantityField };

                               AllocateChars  := AnAssignmentFieldSet{
                                                  ResourceNameField };

                               FieldTable[0]  := ResourceNameField;
                               FieldTable[1]  := TotalQuantity;
                               FieldTable[2]  := BillableField;
                               FieldTable[3]  := ActualQuantityField;
                               FieldTable[4]  := YetToGoQuantityField;
            ELSE
                FatalError();  (* New Forms? *)
            END;
        END;
    END;

END InitAssForms;





    (* ExpandStringToInvertedXLAT -- Produce a translation table for
                                     a collating sequence.  For example,
                                     the source "ABC" would produce a
                                     table that would translate A to 0,
                                     B to 1, C to 2, and all other letters
                                     to 377C.  *)
PROCEDURE ExpandStringToInvertedXLAT( VAR Source    : ARRAY OF CHAR;
                                      VAR XLAT      : ARRAY OF CHAR   );
VAR
    i,Count  : CARDINAL;
    S        : ARRAY [0..255] OF CHAR;
    Table    : ARRAY [0..255] OF CHAR;
BEGIN
    DecodeString(Source,S);
    Count := 0;
    DoDash(S,Table,Count);
        (* Fill Table with high values *)
    i := 0;
    WHILE( i <= HIGH(XLAT)) DO
        XLAT[i] := 377C;         (* All sort high, except those listed. *)
        INC(i);
    END;
        (* Invert the table *)
    i := 0;
    WHILE ( i <= HIGH(XLAT)) AND (i < Count) DO
        XLAT[ ORD( Table[ i ] ) ]  := CHR(i);
        INC(i);
    END;
END ExpandStringToInvertedXLAT;





PROCEDURE SetTranslationCodes();
VAR
    S : ARRAY [0..255] OF CHAR;
BEGIN
    GetMessage(ModuleNumber+1,S);
    IF (S[0] > 0C) THEN
        ExpandStringToXLAT(S,UpshiftTable);
    END;
    GetMessage(ModuleNumber+2,S);
    IF (S[0] > 0C) THEN
        ExpandStringToInvertedXLAT(S,SortOrderTable);
    END;
END SetTranslationCodes;




PROCEDURE InitIlsaStatic();

VAR
    TitleBlock              : ATLGSTitleBlockPtr;
    Palette                 : ATLGSColorAssignmentPtr;
    PertRecord              : ATLGSPertRecordPtr;
    GanttRecord             : ATLGSGanttRecordPtr;
    TreeRecord              : ATLGSTreeRecordPtr;
    PageRecord              : ATLGSPageRecordPtr;
    Client                  : ATLGSChartType;
    Handle                  : AnExtHandle;

    PROCEDURE InitTitleBlock();

    VAR
        i                   : CARDINAL;

    BEGIN                   (* InitTitleBlock *)

        WITH TitleBlock^ DO
            ExistTitle                := FALSE;
            TitlePlace                := SUpLeft;
            TitleBorder.LineWidth     := GetDefaultBorder();
            TitleBorder.CornerRadius  := 0;
            ExistLegend               := FALSE;
            LegendPlace               := SUpLeft;
            LegendBorder.LineWidth    := GetDefaultBorder();
            LegendBorder.CornerRadius := 0;
            ExistSymbol               := FALSE;
            SymbolPlace               := SUpLeft;
            SymbolBorder.LineWidth    := GetDefaultBorder();
            SymbolBorder.CornerRadius := 0;

            FOR i := 1 TO HIGH(Title) DO
                SetLengthOf(Title[i].LineOfText, 0);
                GetDefaultFontSpecs(Title[i].TextSpec);
            END;

            FOR i := 1 TO HIGH(Legend) DO
                SetLengthOf(Legend[i].LineOfText, 0);
                GetDefaultFontSpecs(Legend[i].TextSpec);
            END;
        END;

    END InitTitleBlock;



    (*  InitPalette 

        Initialize the colors for a default palette of the indicated type.
        In this version, Pert and Tree palettes are treated the same.

        Preconditions:
            The Palette must have been allocated and locked (so FlexStor
            must be initialized.

        Postconditions:
            The Palette will have all its fields init'd to valid values.
    *)

    PROCEDURE InitPalette(    Palette       : ATLGSColorAssignmentPtr;     (* 01-Dec-89 LAA *)
                              Chart         : ATLGSChartType         );

    BEGIN                   (* InitPalette *)

        WITH Palette^ DO
            Tag   := TLGSColorTagNumber;
            ID    := 0;
            Notes := AText(NIL);
            SetLengthOf(Name, 0);
            PaletteFlags := {};
            Fill(Spare, 0C, HIGH(Spare));
            SetLengthOf(Spare, 0);
        END;

        IF (Chart = TLGSGanttChart) THEN
            WITH Palette^ DO
                ColorFor[TILG] := 4;  (* Black *) (* 15-Sep-89 WKH *)
                ColorFor[TXHD] := 4;  (* Black *)
                ColorFor[BRDR] := 4;  (* Black *)
                ColorFor[ASOF] :=24;  (* Blue *)           
                ColorFor[MJGD] := 4;  (* Black *)          
                ColorFor[MNGD] := 4;  (* Black *)          
                ColorFor[PAGE] := 3;  (* White *)
                ColorFor[BKHD] := 3;  (* White *)
                ColorFor[DATA] := 3;  (* White *)
                ColorFor[TKBR] := 3;  (* White *)
                ColorFor[F1FG] :=11;  (* Brown *)          
                ColorFor[F1BG] := 3;  (* While *)          
                ColorFor[F2FG] :=27;  (* Purple *)         
                ColorFor[F2BG] := 3;  (* While *)          
                ColorFor[F3FG] := 8;  (* Red *)            
                ColorFor[F3BG] := 3;  (* White *)          
                ColorFor[OSTK] := 4;  (* Black *)
                ColorFor[AOTK] := 4;  (* Black *)
                ColorFor[OSBR] :=24;  (* Blue *)           
                ColorFor[AOTB] :=24;  (* Blue *)           
                ColorFor[MILE] :=24;  (* Blue *)           
                ColorFor[BASE] :=20;  (* Green *)          
                ColorFor[ACMT] := 8;  (* Red *)            
                ColorFor[SLAK] := 4;  (* Black *)
            END;
        ELSE
            WITH Palette^ DO
                ColorFor[PTILG] := 4;  (* Black *) (* 15-Sep-89 WKH *)
                ColorFor[PTXHD] := 4;  (* Black *)
                ColorFor[PBRDR] :=24;  (* Blue *)
                ColorFor[PPAGE] := 3;  (* White *)           
                ColorFor[PBKHD] := 3;  (* While *)          
                ColorFor[PBKCH] := 3;  (* White *)          
                ColorFor[PBKTB] := 3;  (* White *)
                ColorFor[PF1FG] := 8;  (* Red *)
                ColorFor[PF1BG] := 3;  (* White *)
                ColorFor[PF2FG] :=20;  (* Green *)
                ColorFor[PF2BG] := 3;  (* White *)          
                ColorFor[PF3FG] :=16;  (* Yellow *)          
                ColorFor[PF3BG] := 3;  (* White *)         
                ColorFor[POPST] := 4;  (* Black *)          
                ColorFor[PAOTK] := 4;  (* Black *)            
                ColorFor[POPSB] :=24;  (* Blue *)          
                ColorFor[PAOBX] :=24;  (* Blue *)
                ColorFor[PMSBX] := 8;  (* Red *)
                ColorFor[PPTDP] := 4;  (* Black*)           
            END;
        END;

    END InitPalette;




    PROCEDURE InitPertRecord();

    BEGIN                   (* InitPertRecord *)

        WITH PertRecord^ DO
            Tag                       := TlgsPertTagNumber;
            ID                        := 0;
            Compressed                := FALSE;
            Group                     := SDays;
            TaskBoxStyle              := Thin;
            TaskBoxCorners            := Square;
            TaskBoxShadows            := FALSE;
            DependLineStyle           := Thin;
            DependLineCorners         := Square;
            DependLineShadows         := FALSE;
            PeriodicPert              := FALSE;
            TaskArrangement           := Actual;

            GetDefaultFontSpecs(DefaultSpec);
            SetLengthOf (Name, 0);
            SetLengthOf (Layout, 0);
            SetLengthOf (Palette, 0);                             (* 10-Jun-89 LAA *)
            Fill(Spare, 0C, HIGH(Spare));
            SetLengthOf(Spare, 0);
        END;

    END InitPertRecord;




    PROCEDURE InitGanttRecord();

    BEGIN                   (* InitGanttRecord *)

        WITH GanttRecord^ DO
            Tag                       := TlgsGanttTagNumber;
            ID                        := 0;
            Group                     := SDays;
            TimeScale                 := 0.0;
            HorizGrid                 := FALSE;
            VertGrid                  := FALSE;
            ExtraSpacing              := FALSE;
            IndentLevel               := 1;

            GetDefaultFontSpecs(DefaultSpec);
            Leading := DefaultSpec.Leading;  (* 5/22/89 WKH temporary, should remove this field, redundant *)
            SetLengthOf(Name, 0);
            SetLengthOf(Layout, 0);
            SetLengthOf (Palette, 0);                             (* 10-Jun-89 LAA *)
            GridStyle  := Thin;
            Corners    := Square;

            WITH Label1 DO
                ColumnID := 0;
                Width    := 0;
                Position := SLeft;
            END;

            Label2 := Label1;
            Label3 := Label1;
            Label4 := Label1;

            Symbology  := Piston;
            SetLengthOf(Starting, 0);
            StartDate  := MinDate;
            SetLengthOf(Ending, 0);
            EndDate    := MinDate;
            ShowActuals := FALSE;

            Fill(Spare, 0C, HIGH(Spare));
            SetLengthOf(Spare, 0);
        END;

    END InitGanttRecord;




    PROCEDURE InitTreeRecord();

    BEGIN                   (* InitTreeRecord *)

        WITH TreeRecord^ DO
            Tag                       := TLGSTreeTagNumber;
            ID                        := 0;
            Shadows                   := FALSE;
            Orientation               := Tall;
            GridStyle                 := Thin;   (* 3/22/89 WKH *)
            Corners                   := Square; (* 3/22/89 WKH *)

            GetDefaultFontSpecs(DefaultSpec);
            Leading := DefaultSpec.Leading;  (* 5/22/89 WKH temporary, should remove this field, redundant *)
            SetLengthOf (Name, 0);
            SetLengthOf (Layout, 0);
            SetLengthOf (Palette, 0);                             (* 10-Jun-89 LAA *)
            Fill(Spare, 0C, HIGH(Spare));
            SetLengthOf(Spare, 0);
        END;

    END InitTreeRecord;




    PROCEDURE InitPageRecord();

    BEGIN                   (* InitPageRecord *)

        WITH PageRecord^ DO
            (* Initialize Defaults *)
            ImageXVirtual    := 11000.0;
            ImageYVirtual    := 8500.0;
            Border1XVirtual  := 1000.0;
            Border2XVirtual  := 1000.0;
            Border1YVirtual  := 1000.0;
            Border2YVirtual  := 1000.0;
            Scale            := 1.0;
            On1Page          := FALSE;
            Borders          := FALSE;
            GraphStyle       := DraftQ;
            Preview          := TRUE;
            Rotated          := FALSE;
            AutoSave         := FALSE;  (* 21-Dec-89 WKH  *)
            WhatsMyChart     := TLGSGanttChart; (* 28-Dec-89 WKH  *)
            Fill(Spare, 0C, HIGH(Spare));
            SetLengthOf(Spare, 0);
        END;

    END InitPageRecord;




BEGIN                       (* InitIlsaStatic *)

    FOR Client := TLGSGanttChart TO TLGSTreeChart DO
        TitleBlock := LockTLGSTitleBlock(Client);
        InitTitleBlock();
        UnlockTLGSTitleBlock(Client);
        IF (CreateTree(PaletteTree[Client])) THEN END;            (* 13-Jun-89 LAA *)

        IF ((NOT CreateExtObjectWithSize(Handle, ExtSlow, TSIZE(ATLGSColorAssignment)))  (* 01-Dec-89 LAA *)
           OR (NOT CreateTreeNode(DefaultPalette[Client]))) THEN
            FatalError();
        END;

        WITH DefaultPalette[Client]^.Methods^ DO
            SetDataObject(DefaultPalette[Client], ADDRESS(Handle));
        END;

        IF (LockObject(Handle, Palette) <> TSIZE(ATLGSColorAssignment)) THEN
            FatalError();
        END;
        InitPalette(Palette, Client);
        ReleaseObject(Handle);
    END;

    PertRecord := TLGSPertRecord();
    GanttRecord := TLGSGanttRecord(0.0);
    TreeRecord := TLGSTreeRecord();
    PageRecord := TLGSPageRecord();

    InitPertRecord();
    InitGanttRecord();
    InitTreeRecord();
    InitPageRecord();

END InitIlsaStatic;




PROCEDURE InitTimeLineModules();
BEGIN
    SetupFonts();
    InitAssForms();
    InitRealAndTimeFormat();
    SetTranslationCodes();
    InitIlsaStatic();                                             (* 26-May-89 LAA *)
END InitTimeLineModules;




BEGIN
END InitTL.


