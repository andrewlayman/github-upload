MODULE TLXAForm;
    
    (* TL X A Form  - This module runs the form that is used to control
                      Artemis Export.

        CEG  9/2/88    - Initial version.
        LAA  30-Dec-88 - Moved comment so that WITH had a matching END, 
                         otherwise it wouldn't compile!
        CEG  19 Oct 89 - Added new field to form:
                         ExportSummaryTasks (EST)
                         See module XARTABLE.DEF for more details.
        TGS  26 Feb 90 - Cleanup to get it to compile
        TGS  15 Mar 90 - Removed all references to Node^, ATreeNode, etc.
        TGS  28 Mar 90 - Make the User Field names sticky.
        TGS   3 Apr 90 - Require a file name.
    *)

FROM Allocs                 IMPORT 
    (* TYPE *)                  ATaskPtr;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice,
                                AColumnDataRecord,
    (* VAR *)                   GetColumnInfo;
   
FROM ChartControl           IMPORT 
    (* TYPE *)                  AChartState,
    (* VAR *)                   ChartState;

FROM ColumnSupport          IMPORT
    (* TYPE *)                  AColumnTreeRecordPtr,
    (* TYPE *)                  AColumnTreeRecord;
    
FROM Dialog                 IMPORT
    (* PROC *)                  Burp, Error, FatalError, MultipleChoiceBox,
                                ContinuationBox, Message,
    (* TYPE *)                  ADialogOption; (* Help, NoHelp *)
                                    
FROM Directory              IMPORT
    (* TYPE *)                  AFileNamePart, ASetOfFileNameParts,
    (* PROCS *)                 NormalizeFileName, DirectoryIsReachable,
                                ExpandPath;

FROM FileAux                IMPORT
    (* PROC *)                  CheckIO, PrepareForIO;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response, Lookup,
    (* PROC *)                  Close;

FROM Forms                  IMPORT 
    (* TYPE *)                  ACheckReason, ACursorAttribute, AFieldValue, 
                                AForm, AStringValue,
    (* PROC *)                  DoForm, HighlightField, SetFieldProtection, 
                                SetFieldHidden, SetFormChange, ShowValue;

FROM FormCon                IMPORT
    (* TYPE *)                  AFieldType, AFieldNo;

FROM FormRec                IMPORT
    (* TYPE *)                  AFormRecord, ASetOfAttributes, 
                                AnAttribute, APromptType;

FROM Holder                 IMPORT
    (* TYPE *)                  AHoldType, AHoldTypeSet,
    (* PROC *)                  LocateHeldItem, HoldThis, DeleteHeldItem;

FROM IntFileIO              IMPORT
    (* TYPE *)                  AFormat;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode, maxcol, maxrow,
    (* PROC *)                  PutString;

FROM Keys                   IMPORT
    (* CONST *)                 ExitKey, EditKey;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWStart, GanttWEnd;

FROM LStrings               IMPORT
    (* PROC *)                  TrimFront, TrimRear, SubStr, SetString, Fill,
                                ConcatLS, Compare, Overlay, Procustes, LJust,
                                ConcatS, Search, SetLengthOf, Insert, StoC, 
                                Remove, Copy, LengthOf, LStringToTString;

FROM Menus                  IMPORT
    (* PROC *)                  NoYes;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM PickDirs               IMPORT
    (* PROC *)                  PickDirectory;

FROM Planner                IMPORT
    (* VAR *)                   ScheduleComputedOk;

FROM RptCommon              IMPORT
    (* PROC *)                  ColumnHeadings, 
                                GetMessageWord;

FROM Schedule               IMPORT
    (* VAR *)                   ProjectMedia;

FROM Space                  IMPORT
    (* PROC *)                  Available, ALLOCATE;

FROM SYSTEM                 IMPORT
    (* THING *)                 TSIZE, ADR;

FROM TaskColumns            IMPORT
    (* PROC *)                  CreateTaskColumnsTree, DisposeTaskColumnsTree,
                                PickTaskColumn, SearchForTaskColumn;

FROM XArTable               IMPORT
    (* TYPE *)                  AnArtemisExportTable,
                                AnArtemisType,
                                AnActivityIDSource,
                                AnArtemisCalendarType,
                                AnArtemisPeriodType,
                                AnArtemisSummaryType;


CONST
    ModuleNumber = 27000;  (* For GetMessage *)
    MAXCARDINAL  = 65535;

                            
    (* Form field numbers.*)

    TYP = 0;  (* Artemis system type. *)
    CAL = 1;  (* Calendar type. *)
    PSZ = 2;  (* If calendar is period-based, this gives the integer period size *)
    PTY = 3;  (* If calendar is period-based, this gives the period units *)
    WPN = 4;  (* Workpattern number *)
    ACT = 5;  (* Activity ID source *)
    PRE = 6;  (* Activity number prefix *)
    EST = 7;  (* Export summary tasks *)
    CSH = 8;  (* Create project summary hammock: yes,no *)
    UF1 = 9;  (* Artemis F1 user defined field definition *)
    UF2 = 10; (* Artemis F2 user defined field definition *)
    UF3 = 11; (* Artemis F3 user defined field definition *)
    UF4 = 12; (* Artemis F4 user defined field definition *)
    FNM = 13; (* File name *)
    FDR = 14; (* File directory *)


PROCEDURE CheckTheForm(    Form         : AForm;
                           FieldNo      : AFieldNo;
                       VAR FormValue    : ARRAY OF AFieldValue;
                           CheckReason  : ACheckReason;
                       VAR Code         : CARDINAL
                                                      ) : BOOLEAN;
VAR
    On, ok, NewFile         : BOOLEAN;
    s                       : ARRAY [0..79] OF CHAR;
    s1                      : ARRAY [0..39] OF CHAR;
    S2                      : ARRAY [0..255] OF CHAR;
    DisplayRecord           : AColumnTreeRecordPtr;
    Column                  : AColumnTreeRecord;
    f                       : File;
    CodeIn                  : CARDINAL;
    T                       : ATaskPtr;
    DataRecord              : AColumnDataRecord;

    (* Squish all spaces out of a text field. *)
    PROCEDURE Squish( VAR s : ARRAY OF CHAR );
    VAR
        i  : CARDINAL;
        s1 : ARRAY [0..1] OF CHAR;
    BEGIN
        TrimFront(s);
        TrimRear(s);
        SetString(s1," ");
        i := Search(s,s1,1);
        WHILE (i > 0) DO
            Remove(s,i,1);
            i := Search(s,s1,1);
        END;
    END Squish;


    (* When we enter the form, set up the protections correctly. *)

    PROCEDURE SetupForm();
    VAR
        DataType,
        DfltWidth   : CARDINAL;
        Format      : AFormat;
        On,
        ExtOptional,
        Boolean     : BOOLEAN;
    BEGIN
        (* if user selected Period based calendar *)

        IF ( (FormValue[TYP].CardValue = ORD(A2000)) 
        OR (  FormValue[TYP].CardValue = ORD(A7000)) 
        OR (  FormValue[TYP].CardValue = ORD(PROJECT)) ) THEN
            SetFieldProtection( Form, CAL, FormValue, FALSE);
            IF (FormValue[CAL].CardValue = ORD(Period)) THEN
                SetFieldProtection( Form, PSZ, FormValue, FALSE);
                SetFieldProtection( Form, PTY, FormValue, FALSE);
                SetFieldHidden( Form, PSZ, FormValue, FALSE);
                SetFieldHidden( Form, PTY, FormValue, FALSE);
            ELSE
                SetFieldProtection( Form, PSZ, FormValue, TRUE);
                SetFieldProtection( Form, PTY, FormValue, TRUE);
                SetFieldHidden( Form, PSZ, FormValue, TRUE);
                SetFieldHidden( Form, PTY, FormValue, TRUE);
            END;
        ELSE (* A6000, A9000 *)
     (*       FormValue[CAL].CardValue := ORD(Period);      *)
            SetFieldProtection( Form, CAL, FormValue, TRUE);
            SetFieldProtection( Form, PSZ, FormValue, FALSE);
            SetFieldProtection( Form, PTY, FormValue, FALSE);
        END;     

        IF ( FormValue[EST].CardValue = ORD(XMilestones) )  THEN
            SetFieldProtection( Form, CSH, FormValue, FALSE);
        ELSE
            FormValue[CSH].CardValue := 1;
            SetFieldProtection( Form, CSH, FormValue, TRUE);
        END;

    END SetupForm;

    (*
           This should be easy, but isn't.  There is a bug in the root
           in Directory.Mod such that if too much giberish is entered,
           you can get a TooLong() error.  We try to back-end patch
           that here.
    *)

    PROCEDURE AjustPath( VAR in, out : ARRAY OF CHAR ) : BOOLEAN;

    VAR
        s               : ARRAY [0..255] OF CHAR;

        Nil             : ARRAY [0..1]   OF CHAR;
        ok              : BOOLEAN;
    BEGIN
        TrimFront(in);
        TrimRear(in);
        IF (ORD(in[0]) > 0) THEN
            SetString (s, "DK:");
            IF (Compare (s, in) = 0) THEN
                ConcatS (in, ".");
            END;
            IF (in[ ORD(in[0]) ] <> "\") THEN
                ConcatS( in, "\" );
            END;
            IF NOT ((in[1] = "\")                      OR
                   ((in[2] =  ":") AND (in[3] = "\"))  OR
                   ((in[3] =  ":") AND (in[4] = "\"))) THEN
                SetString( s, "DK:.\" );
                ExpandPath( s, Nil, out );
                IF (ORD(out[0]) < 64) THEN
                    Procustes( in, 64 - ORD(out[0]) );
                ELSE
                    Copy( out, in );
                END;
            END;
        END;
        Nil[0] := 0C;
        ExpandPath( in, Nil, out );
        ok := DirectoryIsReachable( out );
        IF (NOT ok) THEN
            GetMessage (ModuleNumber+1, s);     (* "Directory offline or non-existent" *)
            Error(s);
        END;
        RETURN ok;
    END AjustPath;

BEGIN
    CodeIn := Code;
    Code := 0;  (* Init return code to "ok" *)

    IF (CheckReason = CheckFormEntry)  THEN
        IF (FieldNo = 0) THEN
            SetupForm();
        END;
        RETURN TRUE;
    END;

    (* If F2 was pressed, make sure it is for the proper fields. *)

    IF (CheckReason = CheckFieldKey) THEN
        IF (FieldNo <> UF1) AND (FieldNo <> UF2) AND
           (FieldNo <> UF3) AND (FieldNo <> UF4) AND
           (FieldNo <> FDR) THEN
            Burp;
            RETURN FALSE;
        END;
    END;

    (* RSC 9/12/88:   *)
    (* Dont bother redundant checking.  CheckFieldChange is enough. *)

    IF (CheckReason = CheckFieldEntry) THEN
        RETURN TRUE;
    END;
                                                                                                        
    (* Now, based on the field we are on, process it. *)

    WITH FormValue[ FieldNo ] DO
        CASE FieldNo OF
          TYP:
               IF ( (CardValue = ORD(A2000)) OR (CardValue = ORD(A7000)) ) THEN
                   SetFieldProtection( Form, CAL, FormValue, FALSE);
                   IF (FormValue[CAL].CardValue = ORD(Period)) THEN
                       SetFieldProtection( Form, PSZ, FormValue, FALSE);
                       SetFieldProtection( Form, PTY, FormValue, FALSE);
                       SetFieldHidden( Form, PSZ, FormValue, FALSE);
                       SetFieldHidden( Form, PTY, FormValue, FALSE);
                   ELSE
                       SetFieldProtection( Form, PSZ, FormValue, TRUE);
                       SetFieldProtection( Form, PTY, FormValue, TRUE);
                       SetFieldHidden( Form, PSZ, FormValue, TRUE);
                       SetFieldHidden( Form, PTY, FormValue, TRUE);
                   END;
               ELSIF ( CardValue = ORD(PROJECT) ) THEN
                   IF (FormValue[CAL].CardValue = ORD(Period) ) THEN
                       FormValue[CAL].CardValue := ORD(DateHours);
                   END;
                   SetFieldProtection( Form, CAL, FormValue, FALSE);
                   SetFieldProtection( Form, PSZ, FormValue, TRUE);
                   SetFieldProtection( Form, PTY, FormValue, TRUE);
                   SetFieldHidden( Form, PSZ, FormValue, TRUE);
                   SetFieldHidden( Form, PTY, FormValue, TRUE);
               ELSE (* A6000, A9000 *)
                   FormValue[CAL].CardValue := ORD(Period);
                   SetFieldProtection( Form, CAL, FormValue, TRUE);
                   SetFieldProtection( Form, PSZ, FormValue, FALSE);
                   SetFieldProtection( Form, PTY, FormValue, FALSE);
                   SetFieldHidden( Form, PSZ, FormValue, FALSE);
                   SetFieldHidden( Form, PTY, FormValue, FALSE);
               END;     
               ShowValue( Form, CAL, FormValue );
               ShowValue( Form, PSZ, FormValue );
               ShowValue( Form, PTY, FormValue );
        | CAL:
               IF ( CardValue = ORD(Period) ) THEN   (* if user selected Period based calendar *)
                   IF (  FormValue[TYP].CardValue = ORD(PROJECT) ) THEN
                       SetFieldHidden( Form, PSZ, FormValue, TRUE);
                       SetFieldHidden( Form, PTY, FormValue, TRUE);
                       SetFieldProtection( Form, PSZ, FormValue, TRUE);
                       SetFieldProtection( Form, PTY, FormValue, TRUE);
                   ELSE
                       SetFieldHidden( Form, PSZ, FormValue, FALSE);
                       SetFieldHidden( Form, PTY, FormValue, FALSE);
                       SetFieldProtection( Form, PSZ, FormValue, FALSE);
                       SetFieldProtection( Form, PTY, FormValue, FALSE);
                   END;
               ELSE
                   SetFieldHidden( Form, PSZ, FormValue, TRUE);
                   SetFieldHidden( Form, PTY, FormValue, TRUE);
                   SetFieldProtection( Form, PSZ, FormValue, TRUE);
                   SetFieldProtection( Form, PTY, FormValue, TRUE);
               END;
               ShowValue( Form, PSZ, FormValue );
               ShowValue( Form, PTY, FormValue );
               IF ((CheckReason = CheckFieldExit) 
               OR (CheckReason = CheckFormExit)) THEN
                   IF ( ( CardValue = ORD(Period) ) AND 
                        ( FormValue[TYP].CardValue = ORD(PROJECT) ) ) THEN
                       Burp();
                       RETURN FALSE;
                   END;
               END;
        | PSZ:
               IF ((CardValue <= 0) OR (CardValue > 1440)) THEN (* RSC 9/12/88 *)
                   Burp();
                   RETURN FALSE;
               END;    
        | PTY:
        | WPN:

        | EST: 
               IF ( CardValue = ORD(XMilestones) )  THEN
                   SetFieldProtection( Form, CSH, FormValue, FALSE);
               ELSE
                   FormValue[CSH].CardValue := 1;
                   SetFieldProtection( Form, CSH, FormValue, TRUE);
               END;
               ShowValue( Form, CSH, FormValue );
        | CSH:
        | ACT:
        | PRE:
               Squish( CharValue^ );
               ShowValue( Form, PRE, FormValue );
        | FNM:
               IF (CheckReason = CheckFieldExit) THEN
                   IF (FormValue[FDR].CharValue^[0] = 0C) THEN
                       Burp;
                       RETURN FALSE;
                   END;
                   Squish( CharValue^ );
                   ShowValue( Form, FNM, FormValue );
               ELSIF (CheckReason = CheckFormExit) THEN

                   Copy( FormValue[FDR].CharValue^, s );

                   ConcatLS( s, FormValue[FNM].CharValue^ );
                   ConcatS(s, "A.ART");

                   LStringToTString(s, s);
                   PrepareForIO(f);
                   Lookup(f, s, FALSE);
                   NewFile := (CheckIO(f) = unknownfile) OR (CheckIO(f) = notdone);
                   Close(f);

                   IF (NOT NewFile) THEN
                       GetMessage(ModuleNumber+3,s);  (* File exists.  If you continue it will be overwritten. *)
                       GetMessage(ModuleNumber+4,s1);  (* Artemis Export *)

                       IF (NOT ContinuationBox(s,s1,NoHelp) ) THEN
                           RETURN FALSE;
                       END;
                   END;
               END;
        | FDR:
               Squish( CharValue^ );
               IF (CheckReason = CheckFieldKey) THEN
                   Copy(CharValue^,s);
                   IF (NOT DirectoryIsReachable( s )) THEN
                       SetString(s, "DK:.\");  (* Default to this ... *)
                   END;
                   GetMessage( ModuleNumber+5, s1); (* Pick a Directory *)
                   ok := PickDirectory( GanttWStart,
                                        GanttWStart + 10,
                                        s1, s );
                   IF (NOT ok) THEN
                       RETURN FALSE;
                   END;
                   Copy(s, CharValue^);
               ELSIF ( (CheckReason = CheckFieldExit) 
               OR   (CheckReason = CheckFormExit) ) THEN
                   IF (NOT AjustPath( CharValue^, s )) THEN
                       Burp;
                       Code := CARDINAL(BITSET({15})) + FieldNo; (* GO TO <This field> *)
                       RETURN FALSE;
                   END;
               END;
               ShowValue( Form, FDR, FormValue );
        | UF1, UF2, UF3, UF4:
            IF (CheckReason = CheckFieldKey) THEN
                Copy( FormValue[FieldNo].CharValue^, Column.Name);
                IF (NOT SearchForTaskColumn( Column.Name, Column.ID )) THEN
                    Column.ID := 0;
                END;
                HighlightField( Form, FormValue, FieldNo, CursorResting);
                IF (PickTaskColumn(maxcol-29, 3, maxcol, maxrow-10, 
                                   Column.ID, Column.Name)) THEN
                    IF (FormValue[FieldNo].CardValue <> Column.ID) THEN
                        T := NIL;                             (* 08-Feb-88 LAA *)
                        GetColumnInfo(NIL,T,Column.ID,ColumnWidth,
                                      maxcol, DataRecord);
                        FormValue[FieldNo + 1].CardValue := DataRecord.CardinalValue; (* RSC 1/27/89 *)
                        SetFieldProtection(Form,FieldNo+1,FormValue,FALSE);  (* 30-Dec-87 LAA *)
                    END;
                    FormValue[FieldNo].CardValue := Column.ID;
                    Copy( Column.Name, FormValue[FieldNo].CharValue^ );
                    ShowValue(Form, FieldNo, FormValue); (* RSC 9/12/88 *)
                    SetFormChange(Form);

                    (* RSC 9/12/88: *)
                    ShowValue(Form, UF1, FormValue);
                    ShowValue(Form, UF2, FormValue);
                    ShowValue(Form, UF3, FormValue);
                    ShowValue(Form, UF4, FormValue);
                    (* *** *)
                END;
                HighlightField( Form, FormValue, FieldNo, CursorOff);
            ELSIF (CheckReason = CheckFormEntry) THEN
                Copy(FormValue[FieldNo].CharValue^, S2);
                TrimRear(S2);
                IF (LengthOf(S2) = 0) THEN
                    FormValue[FieldNo].CardValue := 0;
                END;
                (* Changed this from "CheckFieldExit" 3.Mar.90 TGS *)
                                    (*  *)
            ELSIF ((CheckReason = CheckFieldChange) 
               OR (CheckReason = CheckFormExit)) THEN
                Copy(FormValue[FieldNo].CharValue^, S2);
                TrimRear(S2);
                Column.ID := FormValue[FieldNo].CardValue;
                IF (LengthOf(S2) > 0) THEN
                    IF (NOT SearchForTaskColumn(S2, Column.ID)) THEN
                    (* argument was FormValue[FieldNo].CharValue^, FormValue[FieldNo].CardValue)) *)
                        Burp();
                        RETURN FALSE;
                    END;
                ELSE
                    FormValue[FieldNo].CardValue := 0;            (* 23-Dec-87 LAA *)
                END;
            END;
        ELSE
            FatalError();
        END;
    END;

    RETURN TRUE;

END CheckTheForm;




  (* Do the form editing.
  *)
PROCEDURE EditForm( VAR ExportTable : AnArtemisExportTable );

CONST
    FormID          = 105;
VAR
    FormValue    : ARRAY [0..15] OF AFieldValue;
    Strings      : ARRAY [1..7]  OF AStringValue;
    ok           : BOOLEAN;

    s            : ARRAY [0..255] OF CHAR;
BEGIN

 (* Build the form record *)

    BuildFormRecord( ExportTable, FormValue, Strings );

    ok := CreateTaskColumnsTree();

 (* Do the form.  If ESC is hit, don't do the export. *)

    ok := ok AND (DoForm (3, 0, maxcol, GanttWEnd, FormID,
                          TRUE, FormValue, CheckTheForm   ) = ExitKey);

    DisposeTaskColumnsTree();

    IF (ok) THEN
        BuildExportTable( FormValue, ExportTable );
    END;

    ExportTable.Ready := ok;
END EditForm;

          



 (* Build Form Record. *)

PROCEDURE BuildFormRecord( VAR ExportTable : AnArtemisExportTable;
                           VAR FormValue   : ARRAY OF AFieldValue;
                           VAR Strings     : ARRAY OF AStringValue  );
VAR
    i                       : CARDINAL;
    T                       : ATaskPtr;
    s                       : ARRAY [0..255] OF CHAR;
    DataRecord              : AColumnDataRecord;
    
    PROCEDURE GetColumnName( UserField, UserDef : CARDINAL );
    BEGIN
        FormValue[UserField].CharValue := ADR(Strings[UserField-UF1+3]);

        IF UserDef <> 0 THEN
            T := NIL; 
            GetColumnInfo(NIL, T, UserDef, ColumnName, 24, DataRecord);
            WITH DataRecord DO
                LJust(StringValue);
                TrimRear(StringValue);
                Copy(StringValue, FormValue[UserField].CharValue^);
            END;
        ELSE
            Fill(FormValue[UserField].CharValue^, " ", 24);
        END;

        FormValue[UserField].CardValue := UserDef;

    END GetColumnName;

BEGIN

    (* Fill in the starting values for the form *)

    WITH ExportTable DO

        FOR i:=0 TO 6 DO
            SetLengthOf( Strings[i], 0 );
        END;

        (* 20.Mar.90 TGS 
        FOR i:=9 TO 12 DO
            Fill(FormValue[i].CharValue^, " ", 24);
            FormValue[i].CardValue := 0;
        END;
        *)

        FormValue[TYP].CharValue := NIL;
        FormValue[TYP].CardValue := ORD(ArtemisType);

        FormValue[CAL].CharValue := NIL;
        FormValue[CAL].CardValue := ORD(CalendarType);

        FormValue[PSZ].CharValue := NIL;
        FormValue[PSZ].CardValue := PeriodSize;

        FormValue[PTY].CharValue := NIL;
        FormValue[PTY].CardValue := ORD(PeriodType);

        FormValue[WPN].CharValue := NIL;
        FormValue[WPN].CardValue := WorkpatternNumber;

        FormValue[ACT].CharValue := NIL;
        FormValue[ACT].CardValue := ORD(ActivityIDSource);
 
        FormValue[PRE].CharValue := ADR( Strings[0] );
        Copy( ActivityPrefix, FormValue[PRE].CharValue^);

        FormValue[CSH].CharValue := NIL;
        FormValue[CSH].CardValue := ORD(NOT CreateSummaryHammock);
 
        FormValue[ACT].CharValue := NIL;
        FormValue[ACT].CardValue := ORD(ActivityIDSource);

        FormValue[EST].CharValue := NIL;
        FormValue[EST].CardValue := ORD(ExportSummaryTasks);
 
        FormValue[FNM].CharValue := ADR( Strings[1] );
        Copy( FileName, FormValue[FNM].CharValue^);

        FormValue[FDR].CharValue := ADR( Strings[2] );
        Copy( FileDir, FormValue[FDR].CharValue^);

        GetColumnName(UF1, UserDef1);
        GetColumnName(UF2, UserDef2);
        GetColumnName(UF3, UserDef3);
        GetColumnName(UF4, UserDef4);

(*      TGS 20.Mar.90 *)
        (*
        T := NIL; 
        FormValue[UF1].CharValue := ADR( Strings[3] );
        GetColumnInfo(NIL, T, UserDef1, ColumnName, 24, DataRecord);
        LJust (DataRecord.StringValue);
        TrimRear (DataRecord.StringValue);
        Copy (DataRecord.StringValue, FormValue[UF1].CharValue^);
        FormValue[UF1].CardValue := UserDef1;

        T := NIL; 
        FormValue[UF2].CharValue := ADR( Strings[4] );
        GetColumnInfo(NIL, T, UserDef2, ColumnName, 24, DataRecord);
        LJust (DataRecord.StringValue);
        TrimRear (DataRecord.StringValue);
        Copy (DataRecord.StringValue, FormValue[UF2].CharValue^);
        FormValue[UF2].CardValue := UserDef2;

        T := NIL; 
        FormValue[UF3].CharValue := ADR( Strings[5] );
        GetColumnInfo(NIL, T, UserDef3, ColumnName, 24, DataRecord);
        LJust (DataRecord.StringValue);
        TrimRear (DataRecord.StringValue);
        Copy (DataRecord.StringValue, FormValue[UF3].CharValue^);
        FormValue[UF3].CardValue := UserDef3;

        T := NIL; 
        FormValue[UF4].CharValue := ADR( Strings[6] );
        GetColumnInfo(NIL, T, UserDef4, ColumnName, 24, DataRecord);
        LJust (DataRecord.StringValue);
        TrimRear (DataRecord.StringValue);
        Copy (DataRecord.StringValue, FormValue[UF4].CharValue^);
        FormValue[UF4].CardValue := UserDef4;
        *)
(* *)

    END;

END BuildFormRecord;


  (* Construct the export table from the form data 
  *)
PROCEDURE BuildExportTable( VAR FormValue   : ARRAY OF AFieldValue;
                            VAR ExportTable : AnArtemisExportTable );
BEGIN
    WITH ExportTable DO
        ArtemisType := VAL(AnArtemisType,FormValue[TYP].CardValue);
        CalendarType := VAL(AnArtemisCalendarType,FormValue[CAL].CardValue);    
        PeriodSize := FormValue[PSZ].CardValue;
        PeriodType := VAL(AnArtemisPeriodType,FormValue[PTY].CardValue);    
        WorkpatternNumber := FormValue[WPN].CardValue;
        ActivityIDSource := VAL(AnActivityIDSource,FormValue[ACT].CardValue);
        Copy( FormValue[PRE].CharValue^, ActivityPrefix );

        ExportSummaryTasks := VAL(AnArtemisSummaryType,FormValue[EST].CardValue);

        Copy( FormValue[FNM].CharValue^, FileName );
        CreateSummaryHammock := NOT VAL(BOOLEAN,FormValue[CSH].CardValue);
        Copy( FormValue[FDR].CharValue^, FileDir );
        UserDef1 := FormValue[UF1].CardValue;
        UserDef2 := FormValue[UF2].CardValue;
        UserDef3 := FormValue[UF3].CardValue;
        UserDef4 := FormValue[UF4].CardValue;
    END;
END BuildExportTable;




  (* Initialize the export table.
  *)
PROCEDURE InitExportTable( VAR ExportTable : AnArtemisExportTable );

BEGIN
    WITH ExportTable DO
        SetString(RecordID,"ART");
        ArtemisType := PROJECT;
        ActivityIDSource := SequenceNumber;
        CalendarType := DateDays; 
        PeriodSize := 1;
        PeriodType := Days;
        WorkpatternNumber := 0;
        SetLengthOf( ActivityPrefix, 0 );  (* RSC 9/12/88 *)
        ExportSummaryTasks := XMilestones;
        SetString(FileName,"EXPT");
        Copy( ProjectMedia, FileDir );
        CreateSummaryHammock := FALSE;
        UserDef1 := 15;           (* Defaults to WBS *)
        UserDef2 := 16;           (* Defaults to OBS *)
        UserDef3 := 14;           (* Defaults to AUX *)
        UserDef4 := 74;           (* Defaults to Indentation Level *)
        Ready := FALSE;
    END;
END InitExportTable;





  (* Get the existing export table from HOLDER, or initialize it.
  *)
PROCEDURE GetHeldContext( VAR ExportTable : AnArtemisExportTable );
VAR
    LExportTableP      : POINTER TO AnArtemisExportTable;
    Size,
    Class              : CARDINAL;
    Category           : AHoldTypeSet;
    Name               : ARRAY [0..9] OF CHAR;
BEGIN
    Class := 3;
    SetString( Name, "TLXAFORM" );
    IF (LocateHeldItem( Name, Class, Category, LExportTableP, Size )) THEN
        IF (Size = TSIZE(AnArtemisExportTable)) THEN
            ExportTable := LExportTableP^;
            RETURN;
        ELSE
            DeleteHeldItem( Name, Class );
        END;
    END;
    InitExportTable( ExportTable );
END GetHeldContext;




   (* Save the driver table in holder for next time.  Delete any old copies.
   *)
PROCEDURE SaveInHolder( VAR ExportTable : AnArtemisExportTable );
VAR
    Size,
    Class,
    Loop               : CARDINAL;
    ExportTableP       : POINTER TO AnArtemisExportTable;
    Category           : AHoldTypeSet;
    Name               : ARRAY [0..9] OF CHAR;
BEGIN
    SetString( Name, "TLXAFORM" );
    Class := 3;
    IF (LocateHeldItem( Name, Class, Category, ExportTableP, Size)) THEN
        DeleteHeldItem( Name, Class );
    END;
    IF (Available( TSIZE(AnArtemisExportTable) )) THEN
        NEW(ExportTableP);
        ExportTableP^ := ExportTable;
        Category      := AHoldTypeSet{HoldInDataFile,HeapNoOwner};
        HoldThis( Name, Class, Category,
                  ExportTableP, TSIZE(AnArtemisExportTable));
    END;
END SaveInHolder;


PROCEDURE OKToExport () : BOOLEAN;
VAR
    s               : ARRAY [0..199] OF CHAR;
BEGIN
    IF (Scheduled IN ChartState) AND ScheduleComputedOk THEN
        RETURN TRUE;
    ELSE
        GetMessage (ModuleNumber+2, s);    (* "Export an uncalced schedule?" *)
        RETURN NoYes (s);
    END;
END OKToExport;





  (* MAIN PROCEDURE *)

PROCEDURE DoTLXAForm;
VAR
    ExportTable : AnArtemisExportTable;
BEGIN

    GetHeldContext( ExportTable );

    IF (OKToExport()) THEN
        EditForm( ExportTable );
    ELSE
        ExportTable.Ready := FALSE;
    END;

    SaveInHolder( ExportTable );

END DoTLXAForm;

BEGIN
    DoTLXAForm;
END TLXAForm.
