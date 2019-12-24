MODULE TLPltFrm;

 (* MODIFICATION HISTORY:

       Sept - RSC - First conversion from PlotLine for SPIKE.

       11/9/87  RSC - Allow overlay parameters from TLWHAT rather than via
                      dispatcher.
       17-Feb-88 LAA    If the context is nil, use the call chain as context.
       20-May-88 LAA    Error messages from Gantt form check proc.
        2-Jan-89 RSC    Added references to StringsEqual() rather than Compare().
        6-Feb-89 RSC    Changed the use of an abort flag in holder to PackageOK.
       09-Aug-89 KKC    Add copyright message.
        9-Oct-89 MWP    Removed text literals.
       21-Feb-90 KKC    Remove UpScale, DownScale from import.
  *)

FROM Codes                  IMPORT ACode;

FROM Dialog                 IMPORT Error, Burp, Message;

FROM FormCon                IMPORT AFieldNo;

FROM Forms                  IMPORT AForm, AFieldValue, DoForm, ACheckReason,
                                 SetFieldProtection, ShowValue, NullCheckProc,
                                 AStringValue, SetFieldHidden, FieldIsHidden,
                                 FindFieldXY, MaxIndex,
                                 ACursorAttribute, HighlightField;

FROM Holder                 IMPORT AHoldTypeSet, LocateHeldItem;

FROM Keys                   IMPORT ExitKey, CancelKey;

FROM Kbio                   IMPORT maxrow, maxcol;

FROM Layout                 IMPORT GanttWEnd;

FROM LStrings               IMPORT SetString, Copy, ConcatLS, ConcatS, Upshift,
                                   StringsEqual, LJust, TrimRear;

FROM MsgFile                IMPORT GetMessage, DisplayMessage;

FROM Overlays               IMPORT
    (* VARS *)                  PackageOK,
    (* PROCS *)                 OverlayContext, OverlayCallChain;

FROM PlotStatic             IMPORT PlotterRecord, NetPlotRecord,
                                   GanttPlotRecord, APlotType, ALabelType,
                                   AGanttLabelType, PlotType;

FROM Schedule               IMPORT ConfigSaved;

FROM SYSTEM                 IMPORT ADR, ADDRESS;

FROM Timeu                  IMPORT ATimeUnit;



CONST
    ModuleNumber            = 18900;

VAR
    i                       : CARDINAL;





PROCEDURE CheckForPlotter();
CONST
    Class           = 10000;            (* TLWHAT item *)
VAR
    Name            : ARRAY [0..20] OF CHAR;
    Category        : AHoldTypeSet;
    Where           : ADDRESS;
    Size            : CARDINAL;
    s               : ARRAY [0..99] OF CHAR;
BEGIN
    SetString (Name, "TLGPLOT");
    IF (NOT LocateHeldItem (Name, Class, Category, Where, Size)) THEN
        GetMessage (ModuleNumber+3, s);
        Error (s);
        PackageOK := FALSE;
    END;
END CheckForPlotter;



CONST
    SCALE                   = 0;
    PER                     = 1;
    TNAME                   = 2;
    DBL                     = 3;
    LEVEL                   = 4;
    MAJGD                   = 5;
    MINGD                   = 6;
    WBSNO                   = 7;
    DUR                     = 8;
    ESTRT                   = 9;
    EEND                    = 10;
    LSTRT                   = 11;
    LEND                    = 12;
    FSLAC                   = 13;
    TSLAC                   = 14;
    STAT                    = 15;



PROCEDURE CheckNetworkForm (    Form        : AForm;
                                n           : AFieldNo;
                            VAR FormValue   : ARRAY OF AFieldValue;
                                CheckReason : ACheckReason;
                            VAR Code        : CARDINAL ):BOOLEAN;
BEGIN
    Code := 0;
    IF (CheckReason <> CheckFieldChange) THEN
        RETURN TRUE;
    END;
    IF (n = SCALE) THEN  (*  PeriodsPerInch  *)
        WITH FormValue[SCALE] DO
            IF (RealValue < 1.0) OR (RealValue > 15.0) THEN
                    (*  Enter a number from 1.0 to 15.0 *)
                DisplayMessage(ModuleNumber + 1);                 (* 20-May-88 LAA *)
                Burp;
                RETURN FALSE;
            END;
        END;
    END;
    RETURN TRUE;
END CheckNetworkForm;



PROCEDURE GetLinesIndex( Yes : BOOLEAN;  Period : ATimeUnit ) : CARDINAL;
BEGIN
    IF (Yes) THEN
        IF (Period < Days) THEN
            RETURN 1;
        ELSE
            RETURN ORD(Period) - ORD(Days) + 1;
        END;
    ELSE
        RETURN 0;
    END;
END GetLinesIndex;







PROCEDURE SetLinesIndex( Index : CARDINAL; VAR Yes : BOOLEAN;  VAR Period : ATimeUnit );
BEGIN
    IF (Index > 0) THEN
        Yes := TRUE;
        Period := VAL(ATimeUnit, Index+ORD(Days)-1 );
    ELSE
        Yes := FALSE;
        Period := Days;
    END;
END SetLinesIndex;






PROCEDURE CheckGanttForm (    Form        : AForm;
                              n           : AFieldNo;
                          VAR FormValue   : ARRAY OF AFieldValue;
                              CheckReason : ACheckReason;
                          VAR Code        : CARDINAL ):BOOLEAN;

BEGIN                       (* CheckGanttForm *)

    Code := 0;
    IF (n = SCALE) THEN  (*  PeriodsPerInch  *)
        IF (CheckReason = CheckFieldExit) THEN
            WITH FormValue[SCALE] DO
                IF (RealValue < 1.0) OR (RealValue > 15.0) THEN
                        (*  Enter a number from 1.0 to 15.0 *)
                    DisplayMessage(ModuleNumber + 1);             (* 20-May-88 LAA *)
                    Burp();
                    RETURN FALSE;
                END;
            END;
        END;
    ELSIF (n = DBL) THEN
        IF ((CheckReason = CheckFieldChange)
           OR (CheckReason = CheckFormEntry)) THEN
            SetFieldProtection(Form, n+1, FormValue, FormValue[n].CardValue <> 2);
            SetFieldHidden(Form, n+1, FormValue, FormValue[n].CardValue <> 2);
        END;
    ELSIF (n = LEVEL) THEN                                        (* 20-May-88 LAA *)
        IF (CheckReason = CheckFieldExit) THEN
            IF (FormValue[n].CardValue = 0) THEN
                    (*  Enter a number greater than zero.  *)
                DisplayMessage(ModuleNumber + 2);
                Burp();
                RETURN FALSE;
            END;
        END;
    END;
    RETURN TRUE;

END CheckGanttForm;




PROCEDURE DoGanttForm;

CONST
    FormNumber = 101;

VAR
    Code      : ACode;
    FormValue : ARRAY [0..15] OF AFieldValue;

BEGIN

        (*  The following kludges have been made:
                Task name on bar is stored in GanttPlotRecord.Descr
                Double space all tasks is stored in PlotterRecord.DrawBordersFlag
                Double space tasks is stored in PlotterRecord.BarSpacing
                WBS number is stored in GanttPlotRecord.AdditionalLabel
        *)

    WITH GanttPlotRecord DO
        FormValue[SCALE].RealValue  := PeriodsPerInch;
        FormValue[PER].CardValue    := ORD(HorizPeriod) - ORD(Days);
        FormValue[TNAME].CardValue  := ORD(Descr);
        FormValue[DBL].CardValue    := PlotterRecord.BarSpacing MOD 256;
        FormValue[LEVEL].CardValue  := PlotterRecord.BarSpacing DIV 256;
        IF (FormValue[LEVEL].CardValue = 0) THEN                  (* 20-May-88 LAA *)
            FormValue[LEVEL].CardValue := 1;
        END;
        FormValue[MAJGD].CardValue  := GetLinesIndex(MajorLineYes,MajorLinePeriod);
        FormValue[MINGD].CardValue  := GetLinesIndex(MinorLineYes,MinorLinePeriod);
        FormValue[WBSNO].CardValue  := ORD(AdditionalLabel);
        FormValue[DUR].CardValue    := ORD(DurColumn);
        FormValue[ESTRT].CardValue  := ORD(ESColumn);
        FormValue[EEND].CardValue   := ORD(EFColumn);
        FormValue[LSTRT].CardValue  := ORD(LSColumn);
        FormValue[LEND].CardValue   := ORD(LFColumn);
        FormValue[FSLAC].CardValue  := ORD(FFColumn);
        FormValue[TSLAC].CardValue  := ORD(TFColumn);
        FormValue[STAT].CardValue   := ORD(StatusColumn);
    END;

    Code := DoForm(0,0,maxcol,maxrow-1,FormNumber,TRUE,FormValue,CheckGanttForm);

    IF (Code <> CancelKey) THEN

        WITH GanttPlotRecord DO
            PeriodsPerInch   :=  FormValue[SCALE].RealValue;
            HorizPeriod      :=  VAL(ATimeUnit, FormValue[PER].CardValue + ORD(Days) );
            VisSpace         := ( FormValue[2].CardValue = 1 );
            Descr            := ( FormValue[TNAME].CardValue = 1 );
            PlotterRecord.BarSpacing
                 := FormValue[LEVEL].CardValue * 256 + FormValue[DBL].CardValue;
            SetLinesIndex(FormValue[MAJGD].CardValue,MajorLineYes,MajorLinePeriod) ;
            SetLinesIndex(FormValue[MINGD].CardValue,MinorLineYes,MinorLinePeriod) ;
            AdditionalLabel  := VAL(AGanttLabelType, FormValue[WBSNO].CardValue);
            DurColumn        := ( FormValue[DUR].CardValue = 1 );
            ESColumn         := ( FormValue[ESTRT].CardValue = 1 );
            EFColumn         := ( FormValue[EEND].CardValue = 1 );
            LSColumn         := ( FormValue[LSTRT].CardValue = 1 );
            LFColumn         := ( FormValue[LEND].CardValue = 1 );
            FFColumn         := ( FormValue[FSLAC].CardValue = 1 );
            TFColumn         := ( FormValue[TSLAC].CardValue = 1 );
            StatusColumn     := ( FormValue[STAT].CardValue = 1 );
        END;

        CheckForPlotter();

    ELSE
        PackageOK := FALSE;
    END;

END DoGanttForm;







CONST
    LOWL                    = 3;
    LOWR                    = 4;
    GDMAJ                   = 5;
    GDMIN                   = 6;
    DEPND                   = 7;



PROCEDURE DoNetworkForm;

CONST
    FormNumber = 102;

VAR
    FormValue : ARRAY [0..7] OF AFieldValue;
    Code : ACode;

BEGIN

    WITH NetPlotRecord DO
        FormValue[SCALE].RealValue  := PeriodsPerInch;
        FormValue[PER].CardValue  := ORD(HorizPeriod) - ORD(Days);
        FormValue[TNAME].CardValue  := ORD(TaskNames);
        FormValue[LOWL].CardValue  := ORD(LowerLeftLabel);
        IF (LowerLeftLabel > WBSNoL) THEN
            DEC(FormValue[LOWL].CardValue);
        END;
        FormValue[LOWR].CardValue  := ORD(LowerRightLabel);
        IF (LowerRightLabel > WBSNoL) THEN
            DEC(FormValue[LOWR].CardValue);
        END;
        FormValue[GDMAJ].CardValue := GetLinesIndex(MajorLineYes,MajorLinePeriod);
        FormValue[GDMIN].CardValue := GetLinesIndex(MinorLineYes,MinorLinePeriod);
        FormValue[DEPND].CardValue  := ORD(DependencyCriterion);
    END;

    Code := DoForm(0,0,maxcol,maxrow-1,FormNumber,TRUE,FormValue,CheckNetworkForm);

    IF (Code <> CancelKey) THEN

        WITH NetPlotRecord DO
            PeriodsPerInch   :=  FormValue[SCALE].RealValue ;
            HorizPeriod      :=  VAL(ATimeUnit, FormValue[PER].CardValue + ORD(Days) );
            TaskNames        :=  ODD(FormValue[TNAME].CardValue);
            LowerLeftLabel   := VAL(ALabelType, FormValue[LOWL].CardValue);
            IF (LowerLeftLabel > WBSNoL) THEN
                INC(LowerLeftLabel);
            END;
            LowerRightLabel  := VAL(ALabelType, FormValue[LOWR].CardValue);
            IF (LowerRightLabel > WBSNoL) THEN
                INC(LowerRightLabel);
            END;
            SetLinesIndex(FormValue[GDMAJ].CardValue,MajorLineYes,MajorLinePeriod) ;
            SetLinesIndex(FormValue[GDMIN].CardValue,MinorLineYes,MinorLinePeriod) ;
            DependencyCriterion := FormValue[DEPND].CardValue;
        END;

        CheckForPlotter();

    ELSE
        PackageOK := FALSE;
    END;

END DoNetworkForm;




CONST
    PTYPE                   = 0;
    SOLID                   = 1;
    ENSUM                   = 2;
    ENPEN                   = 3;
    TPEN                    = 4;
    MPEN                    = 5;
    H1PEN                   = 6;
    H2PEN                   = 7;
    H3PEN                   = 8;
    MAJOR                   = 9;
    MINOR                   = 10;
    BLPEN                   = 11;
    DPPEN                   = 12;
    PSIZE                   = 13;
    SPEED                   = 14;



PROCEDURE CheckPlotterForm(    Form        : AForm;
                               n           : AFieldNo;
                           VAR FormValue   : ARRAY OF AFieldValue;
                               CheckReason : ACheckReason;
                           VAR Code        : CARDINAL
                          ):BOOLEAN;
VAR
    Hide                    : BOOLEAN;

BEGIN

    Code := 0;
    IF (CheckReason = CheckFormEntry) THEN
        IF (n = ENSUM) THEN
            Hide := (FormValue[ENSUM].CardValue = 0);
            SetFieldHidden(Form,ENPEN,FormValue,Hide);
            SetFieldProtection(Form,ENPEN,FormValue,Hide);
        END;
    ELSIF (CheckReason = CheckFieldChange) THEN
        IF (n = ENSUM) THEN
            Hide := (FormValue[ENSUM].CardValue = 0);
            SetFieldHidden(Form,ENPEN,FormValue,Hide);
            SetFieldProtection(Form,ENPEN,FormValue,Hide);
        END;
    END;

    RETURN TRUE;

END CheckPlotterForm;







PROCEDURE DoPlotterForm;

CONST
    FormNumber = 100;

VAR
    i           : CARDINAL;
    Code        : ACode;
    FormValue   : ARRAY [0..14] OF AFieldValue;
    StringValue : AStringValue;

BEGIN
    WITH PlotterRecord DO
        IF (NOT SolidBarsAllowed) THEN
            SolidBars := FALSE;
        END;

        FormValue[PTYPE].CharValue := ADR(StringValue);
        Copy(Name,FormValue[PTYPE].CharValue^);

        FormValue[SOLID].CardValue := ORD(SolidBars);
        FormValue[ENSUM].CardValue := BorderPen;
        FormValue[ENPEN].CardValue := HighlightPenNums[1] - 1;
        FormValue[TPEN].CardValue := GanttPlotRecord.ActivityPen - 1;
        FormValue[MPEN].CardValue := GanttPlotRecord.MilestonePen - 1;
        FormValue[H1PEN].CardValue := HighlightPenNums[3] - 1;
        FormValue[H2PEN].CardValue := HighlightPenNums[4] - 1;
        FormValue[H3PEN].CardValue := HighlightPenNums[5] - 1;
        FormValue[MAJOR].CardValue := GanttPlotRecord.MajorLinePen - 1;
        FormValue[MINOR].CardValue := GanttPlotRecord.MinorLinePen - 1;
        FormValue[BLPEN].CardValue := HighlightPenNums[2] - 1;
        FormValue[DPPEN].CardValue := NetPlotRecord.LinkPen - 1;

        FormValue[PSIZE].CardValue := ORD(PaperSize) - ORD("A");
        IF (PenSpeed = 0) THEN
            i := 0;
        ELSE
            i := (PenSpeed+1) DIV 2;
        END;
        FormValue[SPEED].CardValue := i;
    END;

    Code := DoForm(0,0,maxcol,maxrow-1,FormNumber,TRUE,FormValue,
                   CheckPlotterForm );

    IF (Code = ExitKey) THEN
        WITH PlotterRecord DO
            SolidBars := (FormValue[SOLID].CardValue = 1);
            BorderPen := FormValue[ENSUM].CardValue;
            HighlightPenNums[1] := FormValue[ENPEN].CardValue + 1;
            GanttPlotRecord.ActivityPen := FormValue[TPEN].CardValue + 1;
            NetPlotRecord.ActivityPen := FormValue[TPEN].CardValue + 1;
            GanttPlotRecord.MilestonePen := FormValue[MPEN].CardValue + 1;
            NetPlotRecord.MilestonePen := FormValue[MPEN].CardValue + 1;
            HighlightPenNums[3] := FormValue[H1PEN].CardValue + 1;
            HighlightPenNums[4] := FormValue[H2PEN].CardValue + 1;
            HighlightPenNums[5] := FormValue[H3PEN].CardValue + 1;
            GanttPlotRecord.MajorLinePen := FormValue[MAJOR].CardValue + 1;
            NetPlotRecord.MajorLinePen := FormValue[MAJOR].CardValue + 1;
            GanttPlotRecord.MinorLinePen := FormValue[MINOR].CardValue + 1;
            NetPlotRecord.MinorLinePen := FormValue[MINOR].CardValue + 1;
            HighlightPenNums[2] := FormValue[BLPEN].CardValue + 1;
            NetPlotRecord.LinkPen := FormValue[DPPEN].CardValue + 1;
            PaperSize := CHR( ORD("A") + FormValue[PSIZE].CardValue );
                (* Pen Speed is 0, 1, 3, 5, 7, 9 *)
            i := FormValue[SPEED].CardValue;
            IF (i = 0) THEN
                PenSpeed := 0;
            ELSE
                PenSpeed := (i * 2) - 1;
            END;
        END;
        ConfigSaved := FALSE;
    END;

END DoPlotterForm;



PROCEDURE DoAPlotForm();
VAR
    Context     : POINTER TO ARRAY [0..255] OF CHAR;
    s           : ARRAY [0..255] OF CHAR;
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Context := OverlayContext();
    IF (Context = NIL) THEN                                       (* 17-Feb-88 LAA *)
        Context := OverlayCallChain();
    END;

    LJust(    Context^ );
    TrimRear( Context^ );
    Upshift(  Context^ );

    GetMessage (ModuleNumber+4, s);
    (* "PLOTFORM"  *)
    IF (StringsEqual( Context^, s )) THEN   (* RSC 1/2/88 *)
        DoPlotterForm();
        RETURN;
    END;

    GetMessage (ModuleNumber+5, s);
    (* "NETWORKFORM"  *)
    IF (StringsEqual( Context^, s )) THEN   (* RSC 1/2/88 *)
        PlotType := NetworkPlot;
        DoNetworkForm();
        RETURN;
    END;

    GetMessage (ModuleNumber+6, s);
    (* "GANTTFORM" *)
    IF (StringsEqual( Context^, s )) THEN   (* RSC 1/2/88 *)
        PlotType := GanttPlot;
        DoGanttForm();
        RETURN;
    END;
(*
    SetString(s,"SETGANTTPLOT");
    IF (StringsEqual( Context^, s )) THEN   (* RSC 1/2/88 *)
        PlotType := GanttPlot;
        RETURN;
    END;

    SetString(s,"SETNETWORKPLOT");
    IF (StringsEqual( Context^, s )) THEN   (* RSC 1/2/88 *)
        PlotType := NetworkPlot;
        RETURN;
    END;
*)
    GetMessage (ModuleNumber+7, s);
    (*  "Unknown TLWHAT.CFG context for TLPLTFRM :'" *)
    ConcatLS(  s, Context^ );
    ConcatS(   s, "'"      );
    Error(s);
    PlotType := GanttPlot; (* So there is SOME default. *)

END DoAPlotForm;




BEGIN

    (*
    WITH PlotterRecord DO
        PenSpeed := 0;
        BorderPen := 0;
        FOR i := 1 TO 5 DO
            HighlightPenNums[i] := 0;
        END;
        PaperSize := "A";
    END;

    WITH GanttPlotRecord DO
        MajorLinePen := 0;
        MinorLinePen := 0;
        ActivityPen := 0;
        MilestonePen := 0;
    END;

    WITH NetPlotRecord DO
        MajorLinePen := 0;
        MinorLinePen := 0;
        ActivityPen := 0;
        MilestonePen := 0;
        LinkPen := 0;
    END;
    *)

    DoAPlotForm();

END TLPltFrm.
