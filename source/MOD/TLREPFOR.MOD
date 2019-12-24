MODULE TLREPFOR;

(*  =========================================================================
    Last Edit : September 12, 1989 2:39PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description:


    MODIFICATION HISTORY:

       Dec. 7, 1985, AJL  - Blank file names converted to REPORT.TXT

       Dec. 14, 1985  AL - Check that the directory entered for
                           a filename exists.

       Feb  16, 1988 RSC - Cleaned up file name parsing.
       Feb  24, 1988 RSC - Default DK:REPORT.TXT better.
       10-Jan-89 RSC    Changed Storage to Space    .

       Apr 19, 1989    KKC - New variables in Formvalue:
                                NNotesLines, ReportHeaderTextIn and
                                PrintActiveFilters
                             call CreateReportHeaderNotes.
       May 4, 1989     KKC - Import CreateReportHeaderNotes from
                             PrintCaptions instead of PrintSupport
       May 25, 1989    KKC - Move note window up 4 and right 1.
                             Highlight field before editing notes
                             and UnHighlight field after it.
      20-Jun-89 AJL  -Return the passed-in code from the CheckProc unless
                      we explicitly override it.
                     -Made the header notes text box larger.
      09-Aug-89 KKC  -Add copyright message.
      16-Aug-89 KKC  -Check valid input for top, left, bottom right
                      margins in report form.
      12-Sep-89 WKH  -Make notes text window bigger for compressed video.
      22-Sep-89 MWP  -Make sure all margins are at least set to 1.
      30-Nov-89 MWP  -Test margins on form exit to make sure that
                      left is less than right, and top is less than bottom.
    =========================================================================
*)


FROM   Boxes       IMPORT ABoxType, ABoxAttribute;

FROM   Space       IMPORT ALLOCATE, DEALLOCATE;

FROM   Codes     IMPORT  ACode;

FROM   Dialog    IMPORT  Error;

FROM   Edits     IMPORT  EditText;

FROM   Forms     IMPORT  AFieldValue, DoForm, ShowValue, AForm,
                         ACheckReason, SetFieldProtection,
                         SetFormChange,
                         HighlightField, ACursorAttribute;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldNo;

FROM   Layout    IMPORT  GanttWEnd;

FROM   Keys      IMPORT  ExitKey, UndoKey, ChngTskKey;

FROM   LStrings  IMPORT  SubStr, ConcatLS, Fill,
                         LJust, TrimRear, StoC, CtoS, ConcatS,
                         Copy, TrimFront, LengthOf, Procustes, Insert;

FROM   Directory  IMPORT NormalizeFileName,
                         ExtractFileNameParts, AFileNamePart,
                         ASetOfFileNameParts, DirectoryIsReachable;

FROM   PrintStatic IMPORT APrintCB, PrintCB, PrintDiskFileName,
                          AControlStyle, APrinterStyle,
                          NNotesPrintLines, ReportHeaderTextIn,
                          ReportActiveFilters;

FROM   PrintCaptions IMPORT
    (* PROG *)            CreateReportHeaderNotes;

FROM   MsgFile     IMPORT GetMessage, DisplayMessage;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol, maxrow;

FROM Text          IMPORT CopyLine, AssignLine, Compress, LineExists;

CONST
    ModuleNumber = 13200;    (* For GetMessage *)
    NoSuchDirectory = 10909;
    STYL                =   0;
    CTRL                =   1;
    FN                  =   2;
    TM                  =   3;
    BM                  =   4;
    LM                  =   5;
    RM                  =   6;
    ReportHeaderNotes   =   7;
    NNotesLines         =   8;
    PrintActiveFilters  =   9;

    LastField           =   9;

    MaxRightMargin      =   230;

PROCEDURE CheckFileName(VAR LFileName:ARRAY OF CHAR):BOOLEAN;
VAR
    Device, Name, Extension : ARRAY [0..9] OF CHAR;
    FileName,
    Directory : ARRAY [0..81]  OF CHAR;
    S         : ARRAY [0..255] OF CHAR;
BEGIN
    IF (LFileName[0] = 0C) THEN
        GetMessage(ModuleNumber+2,LFileName); (* "DK:REPORT.TXT" *)
    END;

    Copy( LFileName, FileName );
    NormalizeFileName(    FileName, ASetOfFileNameParts{DevicePart..ExtensionPart});
    ExtractFileNameParts( FileName, Device, Directory, Name, Extension);
    IF (Name[0]=0C) THEN
        DisplayMessage(ModuleNumber+1);   (*  "Please enter a file name."  *)
        RETURN FALSE;
    ELSIF (NOT DirectoryIsReachable(FileName)) THEN
        GetMessage(NoSuchDirectory,S);    (* "No such directory as "  *)
        ConcatLS(S,Device);
        ConcatLS(S,Directory);
        Error(S);
        RETURN FALSE;
    END;
    RETURN TRUE;
END CheckFileName;

(*----------------------------------------------------------------------------
    GetReportHeaderNotes -- Copy from tlschfor.mod. KKC

    Retrieve the first line of the report header description text.
----------------------------------------------------------------------------*)

PROCEDURE GetReportHeaderNotes(VAR Line          : ARRAY OF CHAR);

BEGIN                       (* GetReportHeaderNotes *)

    Fill(Line, " ", 0);
    IF LineExists(ReportHeaderTextIn, 0) THEN
        CopyLine(ReportHeaderTextIn, 0, Line);
    END;
    Procustes(Line, HIGH(Line));

END GetReportHeaderNotes;

(*----------------------------------------------------------------------------
    PutReportHeaderNotes -- Copy from tlschfor.mod . KKC

    Replace the first line of the report header description text.
----------------------------------------------------------------------------*)

PROCEDURE PutReportHeaderNotes(VAR Line          : ARRAY OF CHAR);

VAR
    s                       : ARRAY [0..80] OF CHAR;

BEGIN                       (* PutReportHeaderNotes *)

    TrimRear(Line);
    IF NOT AssignLine(Line, 0, ReportHeaderTextIn) THEN
        GetMessage( ModuleNumber + 7, s ); (* "Report Header description not saved: out of memory." *)
        Error(s);
    END;
    Compress(ReportHeaderTextIn);

END PutReportHeaderNotes;


PROCEDURE CheckPrinterForm(    Form         : AForm;
                               FieldNo      : AFieldNo;
                           VAR FormValue    : ARRAY OF AFieldValue;
                               CheckReason  : ACheckReason;
                           VAR Code         : CARDINAL
                                                   ) : BOOLEAN;
VAR
    i                       : CARDINAL;
    InCode                  : CARDINAL;
    ok                      : BOOLEAN;
    Title                   : ARRAY [0..41] OF CHAR;
    s                       : ARRAY [0..255] OF CHAR;
    Changed                 : BOOLEAN;
    PreemptedTheCode        : BOOLEAN;

    PROCEDURE PlugMargins;
    BEGIN
        WITH PrintCB.ControlStrings[PrintCB.ControlStyle] DO
            IF ( TopMargin <= 0 ) THEN
               TopMargin := 1;
            END;

            IF ( BottomMargin <= 0 ) THEN
               BottomMargin := 1;
            END;

            IF ( LeftMargin <= 0 ) THEN
               LeftMargin := 1;
            END;

            IF ( RightMargin <= 0 ) THEN
               RightMargin := 1;
            END;

            FormValue[TM].CardValue := TopMargin;
            FormValue[BM].CardValue := BottomMargin;
            FormValue[LM].CardValue := LeftMargin;
            FormValue[RM].CardValue := RightMargin;
        END;
        ShowValue(Form,TM,FormValue);
        ShowValue(Form,BM,FormValue);
        ShowValue(Form,LM,FormValue);
        ShowValue(Form,RM,FormValue);
    END PlugMargins;

BEGIN

    InCode := Code;
    Code := 0;
    PreemptedTheCode := FALSE;


    IF (FieldNo = STYL) THEN
        WITH PrintCB DO
            Style := VAL(APrinterStyle, FormValue[STYL].CardValue);
                (* Only change the ControlStyle if the output device
                   is changed. *)
            IF (CheckReason = CheckFieldChange) AND (InCode <> UndoKey) THEN
                CASE Style OF
                    OutToPrinter:    IF (ControlStyle >= WPNormal) THEN
                                         ControlStyle := PrinterNormal;
                                     END;
                   |OutToDisk:       ControlStyle := WPNormal;
                    ELSE             ControlStyle := NoControls;
                END;
                FormValue[CTRL].CardValue := ORD(ControlStyle);
            END;
        END;
        ShowValue(Form,CTRL,FormValue);
        SetFieldProtection(Form,FN,FormValue,(PrintCB.Style <> OutToDisk) );
        PlugMargins;
    ELSIF (FieldNo = CTRL) THEN
        PrintCB.ControlStyle := VAL(AControlStyle, FormValue[1].CardValue);
        PlugMargins;
    ELSIF (FieldNo = FN) THEN
        IF (CheckReason = CheckFieldExit) THEN            (* 12/14/85 AJL *)
            TrimRear(FormValue[FN].CharValue^);           (* 12/7/85 AJL *)
            ok := (CheckFileName(FormValue[FN].CharValue^));
            ShowValue(Form,FN,FormValue);
            RETURN (ok);
        END;
    ELSIF (FieldNo >= TM) AND (FieldNo <= RM) THEN
        IF ( FormValue[FieldNo].CardValue <= 0 ) THEN
            GetMessage(ModuleNumber + 8, s ); (* Please enter a positive number *)
            Error(s);
            RETURN FALSE;
        END;
        IF ( FormValue[RM].CardValue > MaxRightMargin ) THEN
            GetMessage(ModuleNumber + 9, s ); (* Right margin is too large. *)
            Error(s);
            RETURN FALSE;
        END;

        IF (CheckReason   = CheckFormExit)  THEN
           IF ( FormValue[LM].CardValue >= FormValue[RM].CardValue ) OR  (* 30-Nov-89 MWP *)
              ( FormValue[TM].CardValue >= FormValue[BM].CardValue ) THEN
               GetMessage(ModuleNumber + 10, s ); (* Right margin is too large. *)
               Error(s);
               RETURN FALSE;
           END;
        END;

        WITH PrintCB.ControlStrings[PrintCB.ControlStyle] DO
            TopMargin := FormValue[TM].CardValue;
            BottomMargin := FormValue[BM].CardValue;
            LeftMargin := FormValue[LM].CardValue;
            RightMargin := FormValue[RM].CardValue;
        END;
    ELSIF (FieldNo = PrintActiveFilters) THEN
        ReportActiveFilters := VAL( BOOLEAN,
                                     FormValue[PrintActiveFilters].CardValue);

    ELSIF (FieldNo = NNotesLines) THEN
        NNotesPrintLines := FormValue[FieldNo].CardValue;
    ELSIF (FieldNo = ReportHeaderNotes) THEN
        PutReportHeaderNotes(FormValue[FieldNo].CharValue^);
        IF (InCode = ChngTskKey) AND (CheckReason = CheckFieldKey) THEN
            GetMessage(ModuleNumber + 3, Title);
            HighlightField( Form, FormValue, FieldNo, CursorResting);
            EditText(1,10,79,maxrow-6, ABoxType{ShadowBox, DoubleBox}, Title, ModuleNumber,
                     ReportHeaderTextIn, Changed);
            HighlightField( Form, FormValue, FieldNo, CursorOff);
            IF (Changed) THEN
                SetFormChange( Form );
            END;
            GetReportHeaderNotes(FormValue[FieldNo].CharValue^);
            ShowValue(Form, FieldNo, FormValue);
            PreemptedTheCode := TRUE;
        END;
    END;


        (* This test added 12/14/85, AJL. Modified 2/16/88 by RSC  *)

    IF (CheckReason   = CheckFormExit)  AND
       (FieldNo       = FN)             AND
       (PrintCB.Style = OutToDisk)      THEN
        ok := (CheckFileName(FormValue[FN].CharValue^));
        ShowValue(Form,FN,FormValue);
        RETURN ok;
    END;

      (* 20-Jun-89 AJL   Return the passed-in code from the CheckProc unless
                         we explicitly override it.  *)

    IF (CheckReason = CheckFieldKey) AND (NOT PreemptedTheCode) THEN
        Code := InCode + CARDINAL({14});
    END;

    RETURN TRUE;
END CheckPrinterForm;






    (*  DoPrinterForm  -- Allow printer parameters to be changed. *)

PROCEDURE DoPrinterForm;
VAR
    FormValue : ARRAY [0..LastField] OF AFieldValue;
    OldPrintCB : APrintCB;
    Copyright  : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    CreateReportHeaderNotes();
    OldPrintCB := PrintCB;

    WITH OldPrintCB DO
        FormValue[0].CardValue := ORD(Style);
        FormValue[1].CardValue := ORD(ControlStyle);
    END;

    NEW(FormValue[FN].CharValue);
    Copy(PrintDiskFileName,FormValue[FN].CharValue^);
    FormValue[PrintActiveFilters].CardValue := ORD(ReportActiveFilters);
    FormValue[NNotesLines].CardValue := NNotesPrintLines;
    NEW(FormValue[ReportHeaderNotes].CharValue);
    FormValue[ReportHeaderNotes].CharValue^[0] := 0C;
    GetReportHeaderNotes(FormValue[ReportHeaderNotes].CharValue^);

    IF (DoForm(0,GanttWEnd,maxcol,GanttWEnd,5,TRUE,FormValue,CheckPrinterForm)=ExitKey) THEN
        Copy( FormValue[FN].CharValue^, PrintDiskFileName );
        PutReportHeaderNotes(FormValue[ReportHeaderNotes].CharValue^);
    ELSE
        PrintCB := OldPrintCB;
    END;

    DISPOSE(FormValue[ReportHeaderNotes].CharValue);
    DISPOSE(FormValue[FN].CharValue);

END DoPrinterForm;


BEGIN
    DoPrinterForm;
END TLREPFOR.










