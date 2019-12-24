MODULE TL3Cnfg;

(*$S+*)

    (* MODIFICATION HISTORY:
        08-Aug-88 KKC - Created from TLStart.mod and LoadCommon.mod
        10-Aug-89 KKC - Add copyright message.
        11-Aug-89 KKC - Add three blank lines between procedures.
        22-Aug-89 KKC - Copy GetPrinterTable from tlstart.mod
        24-Aug-89 EGK - Import procs from FilterUtility instead of FilterRc.
        28-Sep-89 KKC - Take out a debugging message.
        19-Oct-89 MWP - Make array size 255 for phrases file messages.
                        It was 82 bytes long, which caused a 'Too Long Msg'.
        31-Oct-89 EGK - Changed usage of GetSignature to follow new format,
                        just like TLITL3 and TLITL4.
        24-Oct-90 TGS - Pay attention to "CONFIG IS <path>" command-line parm.
        21-Jan-91 RSC - Remove Fiscal Calendar.
        15-Feb-91 AJL   Remove ChartCodeSet.
        16-Aug-91 PFG   Added an argument to the layouts info procs (from
                        LoadCommon) that tell them whether to adjust for
                        changes in column numbers.
    *)


FROM Boxes                  IMPORT  
    (* VAR   *)                 TransparentShadow;

FROM Chart                  IMPORT  
    (* PROC  *)                 ResetChart, MChToday;

FROM ChartControl           IMPORT  
    (* TYPE  *)                 AChartState,
    (* PROC  *)                 UnSetState;

FROM Codes                  IMPORT  
    (* TYPE  *)                 ASetOfCodes,
    (* VAR   *)                 EmptyCodeSet,
    (* PROC  *)                 SetCodeBits;

FROM CodeSets               IMPORT  
    (* VAR   *)                 CommandCodes, MenuCodeSet, 
                                FormsCodeSet;

FROM Dialog                 IMPORT  
    (* PROC  *)                 FatalError, Error;

FROM Directory              IMPORT
    (* PROC *)                  ExpandPath;        

FROM FileAux                IMPORT  
    (* VAR   *)                 OverlayPath,
    (* PROC  *)                 CheckIO;

FROM FileOpen               IMPORT
    (* PROC  *)                 RequestFileOpenReadOnly;

FROM FileSystem             IMPORT  
    (* TYPE  *)                 File, Response, 
    (* PROC  *)                 Close;

FROM FlexStor               IMPORT
    (* TYPE  *)                 AnExtHandle, AnExtStoragePreference,
                                AnExtStatus,
    (* PROC  *)                 CreateExtObjectWithSize, SetExtData,
                                LockObject, ReleaseObject, GetExtStatus; 

FROM FilterRc               IMPORT  
    (* TYPE  *)                 AFilterRecordPointer, AFltrType, AFilterMatch,
                                AFilterRecord, 
    (* VAR   *)                 RevealFilter, HighlightFilter, FilterTree,
    (* PROC *)                  DeleteFilter;

FROM Filters                IMPORT
    (* PROC  *)                 ShowFilterLight;

FROM FilterUtility          IMPORT
    (* PROC  *)                 CreateFilter, SortFilters,
                                FindFilterByName;

FROM GaGa                   IMPORT
    (* PROC  *)                 GetGaGaMessage;

FROM Gantt                  IMPORT  
    (* VAR   *)                 ChartFont, SummaryFont, BaselineDetailFont,
                                BaselineSummaryFont;

FROM Holder                 IMPORT  
    (* TYPE  *)                 AHoldType, AHoldTypeSet,
    (* PROC  *)                 LocateHeldItem, 
                                DeleteHeldItem, HoldThis;

FROM Kbio                   IMPORT  
    (* CONST *)                 maxcol,
    (* TYPE  *)                 avidmode, ascreeny, ACursorType, ascreenx,
    (* VAR   *)                 vidctrl, soundon, maxrow, VersionString, 
    (* PROG  *)                 PutAttribute, KbioInit, SetCursorType, 
                                PutString, GetAnyCode;

FROM Keys                   IMPORT
    (* CONST *)                 CancelKey, Up, Down, DoIt, ComputeKey, 
                                OnMenu, InsertKey, DeleteKey, CopyKey,
                                OpenKey, CloseKey, MoveUpKey, MoveDownKey, 
                                PromoteKey, DemoteKey, EditKey, HelpKey, 
                                ExitKey, HelpIndexKey, UndoKey, ReInsertKey, 
                                AltUndoKey, DaysKey, RedoKey;

FROM LoadCommon             IMPORT  
    (* PROC  *)                 SkipRecordBody, GetCalendar, 
                                GetSignature, 
                                GetTheEnvironment,
                                GetMemosInfo, GetLayoutsInfo,
                                GetNetLayoutsInfo, ReadTaskNumber,
                                ReadFilterNumber, ReadFilterName,
                                AttachNodeOnTree, ReadOldFormatTextLine,
                                SignatureError;

FROM LStrings               IMPORT 
    (* PROC  *)                 SetString, ConcatLS, SetLengthOf, 
                                StringsEqual, LengthOf, Copy, ConcatS;

FROM MsgFile                IMPORT 
    (* PROC  *)                 GetMessage;

FROM ParmLine               IMPORT
    (* PROC *)                  GetOption;

FROM PrintStatic            IMPORT  
    (* TYPE  *)                 APrinterStyle, AControlStyle, APortType, 
                                AProtocol,
    (* VAR   *)                 PrintCB, PrintXLAT, 
                                TranslateOverlay, ReportSettings;

FROM ReadAscii              IMPORT  
    (* PROC  *)                 ReadBoolean, ReadCardinal, ReadReal,
                                ReadTimeUnit, ReadDate;

FROM RecordIO               IMPORT  
    (* PROC  *)                 ReadRecord, ReadString, ReadRecordPreface,
                                ReadRecordBody, ReadStringBody;

FROM Schedule               IMPORT  
    (* VAR   *)                 ProjectMedia, InstalledFlag,
                                RetrievalName, FullScheduleName;

FROM Space                  IMPORT
    (* PROC  *)                 Available, ALLOCATE;

FROM Subfiles               IMPORT  
    (* PROC  *)                 StartFileInput, StartSubfileInput;

FROM SYSTEM                 IMPORT  
    (* PROC  *)                 SIZE, ADR, ADDRESS, TSIZE;

FROM RealFormat             IMPORT
    (* Var   *)                 DefaultAmountFormat, DefaultCurrencyFormat;

FROM TaskFind               IMPORT
    (* PROC  *)                 TaskFindBegin, TaskFindEnd;

FROM Text                   IMPORT
    (* TYPE  *)                 AText,
    (* PROC  *)                 Compress, AssignLine, CreateText;

FROM TimeFormat             IMPORT
    (* Var   *)                 DefaultDateAndTimeFormat, DefaultDateFormat,
                                DefaultTimeFormat;

FROM Transfer               IMPORT
    (* TYPE  *)                 AHeaderRecord;

FROM TreeObjects            IMPORT
    (* TYPE  *)                 ATreeNode;

CONST
    ModuleNumber            = 8200;   (* For GetMessage. *)


CONST
     MaxWidth               = 255;  (* KKC  Aug 22, 1989 *)
     PrinterTableType       = 12;
     FileNamesType          = 13;
     VideoType              = 14;
     PreferencesType        = 15;
     CodeSetsType           = 16;
     FontsType              = 17;
     FiltersType            = 19;
     HeldItemsType          = 20;





PROCEDURE GetPrinterTable(VAR f:File);
VAR
    Type          : CARDINAL;
    Length        : CARDINAL;
    Version       : CARDINAL;
    TextPos       : CARDINAL;
    s             : ARRAY[0..MaxWidth] OF CHAR;


    PROCEDURE ReadOldPrintCBRecord();
    TYPE
        AnOldControlGroup = RECORD
                        Init         : ARRAY [0..80] OF CHAR;
                        Terminate    : ARRAY [0..80] OF CHAR;
                        NewPage      : ARRAY [0..20] OF CHAR;
                        NewLine      : ARRAY [0..20] OF CHAR;
                        Normal       : ARRAY [0..30] OF CHAR;
                        Bold         : ARRAY [0..30] OF CHAR;
                        TopMargin,
                        BottomMargin,
                        LeftMargin,
                        RightMargin  : CARDINAL;
                        Pause        : BOOLEAN;
                        FillerByte   : CHAR;    (* MAKE EVEN LENGTHED *)
                    END;

        AnOldPrintCBRecord = RECORD
                            (* Where is the output directed. *)
                        Style    : APrinterStyle;
                            (* Margins currently in use? *)
                        TopMargin,
                        BottomMargin,
                        LeftMargin,
                        RightMargin  : CARDINAL;
                            (* If a printer, which one. *)
                        PrinterNumber : CARDINAL;
                            (* What kind of control sequences. *)
                        ControlStyle      : AControlStyle;
                            (* Serial or parallel printer or DOS calls *)
                        PortType     : APortType;
                            (* These next fields are used only if
                               we are using a serial port.   The port
                               number is then stored in PrinterNumber. *)
                        BaudRate,
                        StopBits,
                        NumberOfBits : CARDINAL;
                        ParityBit,
                        EvenParity   : BOOLEAN;
                        Protocol     : AProtocol;
                            (* Some useful filler. *)
                        Filler1      : ARRAY [0..15] OF CARDINAL;
                            (* The secret controls. *)
                        ControlStrings : ARRAY AControlStyle OF AnOldControlGroup;
                    END;
    VAR
        i           : AControlStyle;
        OldPrintCB  : AnOldPrintCBRecord;
        ok          : BOOLEAN;
    BEGIN
        ReadRecordBody(f,Length,ADR(OldPrintCB),SIZE(OldPrintCB));
        WITH OldPrintCB DO
            PrintCB.Style           := Style;
            PrintCB.TopMargin       := TopMargin;
            PrintCB.BottomMargin    := BottomMargin;
            PrintCB.LeftMargin      := LeftMargin;
            PrintCB.RightMargin     := RightMargin;
            PrintCB.PrinterNumber   := PrinterNumber;
            PrintCB.ControlStyle    := ControlStyle;
            PrintCB.PortType        := PortType;
            PrintCB.BaudRate        := BaudRate;
            PrintCB.StopBits        := StopBits;
            PrintCB.NumberOfBits    := NumberOfBits;
            PrintCB.ParityBit       := ParityBit;
            PrintCB.EvenParity      := EvenParity;
            PrintCB.Protocol        := Protocol;
            FOR i := PrinterNormal TO NoControls DO
                WITH OldPrintCB.ControlStrings[i] DO
                    IF (LengthOf( Init ) = 0) THEN
                        PrintCB.ControlStrings[i].Init := AText(NIL);
                    ELSE
                        PrintCB.ControlStrings[i].Init := CreateText();
                        ok := AssignLine( Init, 0, PrintCB.ControlStrings[i].Init );
                    END;
                    IF (LengthOf( Terminate ) = 0) THEN
                        PrintCB.ControlStrings[i].Terminate := AText(NIL);
                    ELSE
                        PrintCB.ControlStrings[i].Terminate := CreateText();
                        ok := AssignLine( Terminate, 0, PrintCB.ControlStrings[i].Terminate );
                    END;
                    Copy( NewPage, PrintCB.ControlStrings[i].NewPage );
                    Copy( NewLine, PrintCB.ControlStrings[i].NewLine );
                    Copy( Normal,  PrintCB.ControlStrings[i].Normal  );
                    Copy( Bold,    PrintCB.ControlStrings[i].Bold    );
                    PrintCB.ControlStrings[i].TopMargin     := TopMargin;
                    PrintCB.ControlStrings[i].BottomMargin  := BottomMargin;
                    PrintCB.ControlStrings[i].LeftMargin    := LeftMargin;
                    PrintCB.ControlStrings[i].RightMargin   := RightMargin;
                    PrintCB.ControlStrings[i].Pause         := Pause;
                END;
            END;
        END;

    END ReadOldPrintCBRecord;

BEGIN

    IF (NOT StartSubfileInput(f,PrinterTableType,Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        CASE Type OF
            1  :  ReadOldPrintCBRecord();
          | 2  :  ReadRecordBody(f,Length,ADR(PrintXLAT[OutToPrinter]),SIZE(PrintXLAT[OutToPrinter]));
          | 3  :  ReadRecordBody(f,Length,ADR(PrintXLAT[OutToDisk]),SIZE(PrintXLAT[OutToDisk]));
          | 4  :  ReadStringBody(f,Length,TranslateOverlay);
          | 5  :  ReadRecordBody(f,Length,ADR(ReportSettings),SIZE(ReportSettings));
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

END GetPrinterTable;




PROCEDURE GetVideo(VAR f:File);
VAR
    Version     :   CARDINAL;
    Type        :   CARDINAL;
    Length      :   CARDINAL;
BEGIN
    IF (StartSubfileInput(f,VideoType,Version)) THEN
        LOOP
            ReadRecordPreface(f,Type,Length);
            CASE Type OF
                1:    ReadRecordBody(f,Length,ADR(vidctrl),SIZE(vidctrl));
              | 2:    ReadRecordBody(f,Length,ADR(TransparentShadow),SIZE(TransparentShadow));
              | 0FFH : EXIT;
            ELSE
                SkipRecordBody (f, Length);         (* 12/6/88 EGK *)
            END;
        END;
    END;
END GetVideo;




PROCEDURE GetPreferences( VAR f : File );
VAR
    Version     :   CARDINAL;
    Type        :   CARDINAL;
    Length      :   CARDINAL;
BEGIN
    IF (StartSubfileInput(f,PreferencesType,Version)) THEN
        LOOP
            ReadRecordPreface(f,Type,Length);
            CASE Type OF
                1:    ReadRecordBody(f,Length,ADR(soundon),SIZE(soundon));
              | 2:    ReadRecordBody(f,Length,ADR(InstalledFlag),SIZE(InstalledFlag));
              | 3:    ReadRecordBody(f, Length, ADR(DefaultDateAndTimeFormat),          (* 09-Nov-88 LAA *)
                                     SIZE(DefaultDateAndTimeFormat));
              | 4:    ReadRecordBody(f, Length, ADR(DefaultDateFormat),
                                     SIZE(DefaultDateFormat));
              | 5:    ReadRecordBody(f, Length, ADR(DefaultTimeFormat),
                                     SIZE(DefaultTimeFormat));
              | 6:    ReadRecordBody(f, Length, ADR(DefaultAmountFormat),
                                     SIZE(DefaultAmountFormat));
              | 7:    ReadRecordBody(f, Length, ADR(DefaultCurrencyFormat),
                                     SIZE(DefaultCurrencyFormat));
              | 0FFH : EXIT;
            ELSE
                SkipRecordBody (f, Length);         (* 12/6/88 EGK *)
            END;
        END;
    END;

END GetPreferences;




PROCEDURE GetCodeSets(VAR f:File);
VAR
    Version : CARDINAL;
    DummyCodeSet : ASetOfCodes;

    PROCEDURE GetCodeSet (VAR CodeSet:ASetOfCodes);
    VAR
        Type : CARDINAL;
    BEGIN
        ReadRecord(f,Type,ADR(CodeSet),SIZE(CodeSet));
    END GetCodeSet;

BEGIN
    IF (StartSubfileInput(f,CodeSetsType,Version)) THEN
        GetCodeSet(CommandCodes);
        GetCodeSet(MenuCodeSet);                                  (* 09-Nov-88 LAA *)
        GetCodeSet(FormsCodeSet);
        GetCodeSet(DummyCodeSet);
    END;
    MenuCodeSet := EmptyCodeSet;
    SetCodeBits(MenuCodeSet, OnMenu, OnMenu, TRUE);
    SetCodeBits(MenuCodeSet, InsertKey, InsertKey, TRUE);         (* 10-Feb-88 LAA *)
    SetCodeBits(MenuCodeSet, DeleteKey, DeleteKey, TRUE);
    SetCodeBits(MenuCodeSet, CopyKey, CopyKey, TRUE);
    SetCodeBits(MenuCodeSet, OpenKey, OpenKey, TRUE);
    SetCodeBits(MenuCodeSet, CloseKey, CloseKey, TRUE);
    SetCodeBits(MenuCodeSet, EditKey, ComputeKey, TRUE);          (* 11-Feb-88 LAA *)
    SetCodeBits(MenuCodeSet, HelpIndexKey, UndoKey, TRUE);
    SetCodeBits(MenuCodeSet, ReInsertKey, AltUndoKey, TRUE);
    SetCodeBits(MenuCodeSet, DaysKey, RedoKey, TRUE);
END GetCodeSets;



PROCEDURE GetFonts(VAR f:File);
VAR
    Version : CARDINAL;
    Type    : CARDINAL;
    Length  : CARDINAL;
    GlobalFontsInFile : BOOLEAN;
BEGIN
    GlobalFontsInFile := FALSE;
    IF (NOT StartSubfileInput(f,FontsType,Version))
        THEN RETURN;
    END;

    LOOP
        ReadRecordPreface(f,Type,Length);
        CASE Type OF
          | 2:    ReadRecordBody(f,Length,ADR(ChartFont),SIZE(ChartFont));
          | 3:    ReadRecordBody(f,Length,ADR(SummaryFont),SIZE(SummaryFont));
          | 4:    ReadRecordBody(f,Length,ADR(BaselineDetailFont),SIZE(BaselineDetailFont));
          | 5:    ReadRecordBody(f,Length,ADR(BaselineSummaryFont),SIZE(BaselineSummaryFont));
          | 9:    ReadRecordBody(f,Length,ADR(GlobalFontsInFile),SIZE(GlobalFontsInFile));
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

END GetFonts;




PROCEDURE DuplicatesOK( VAR z : ARRAY OF CHAR ) : BOOLEAN;
BEGIN
    RETURN TRUE;
END DuplicatesOK;





PROCEDURE GetHeldItems(VAR f:File);
VAR
    Version,
    Type,
    Length,
    Class,
    Size            : CARDINAL;
    Handle          : AnExtHandle;
    Where           : ADDRESS;
    Category        : AHoldTypeSet;
    Name            : ARRAY [0..30] OF CHAR;
    ExistsFlag      : BOOLEAN;
    CreateFlag      : BOOLEAN;

    PROCEDURE NotWanted( VAR ItemName : ARRAY OF CHAR ) : BOOLEAN;
    CONST
        TLDRItem        = "TLDR";
        TLSRItem        = "TLSR";
    VAR
        TmpName         : ARRAY[0..25] OF CHAR;
        Reject          : BOOLEAN;
    BEGIN
        SetString(TmpName, TLDRItem);
        Reject := StringsEqual(TmpName, ItemName );
        IF ( NOT Reject ) THEN
            SetString(TmpName, TLSRItem);
            Reject := StringsEqual(TmpName, ItemName );
        END;
        RETURN ( Reject );
    END NotWanted;

BEGIN
    IF (StartSubfileInput(f,HeldItemsType,Version)) THEN
        LOOP
            ReadRecordPreface(f,Type,Length);
            CASE Type OF
                1 :     (* Name *)
                    ReadStringBody(f,Length,Name);
                    Category := AHoldTypeSet{};
                    Class    := 0;

            |   2 :     (* Class *)
                    ReadRecordBody(f,Length,ADR(Class),SIZE(Class));

            |   3 :     (* Category *)
                    ReadRecordBody(f,Length,ADR(Category),SIZE(Category));

            |   4 :     (* Data item *)
                    IF ( NotWanted(Name) ) THEN
                        SkipRecordBody(f,Length);
                    ELSE
                        ExistsFlag := (LocateHeldItem(Name,Class,Category,Where,Size));

                        (* If it exists, but with a different size, blast the
                            version now in memory.   RSC 10/17/88.
                            If it exists with the same size, we just store the
                            new data at the location of the old data.  EGK 11/1/88.
                        *)
                        CreateFlag := TRUE;

                        IF (ExistsFlag) THEN
                            IF NOT (AllowDuplicates IN Category) THEN
                                IF (ErrorIfDuplicate IN Category) THEN
                                    FatalError();
                                ELSIF (Length <> Size) THEN
                                    DeleteHeldItem (Name, Class);
                                ELSE
                                    CreateFlag := FALSE;
                                END;
                            END;
                        END;

                        IF (CreateFlag) THEN
                            Size := Length;   (* RSC 1/26/88 *)
                            IF (HoldInFlexStor IN Category) THEN
                                IF (GetExtStatus() = ExtGood) AND
                                   (CreateExtObjectWithSize( Handle, ExtSlow, Size )) THEN
                                    Size := LockObject( Handle, Where );
                                ELSE
                                    RETURN;  (* No room for this item? *)
                                END;
                            ELSE
                                IF (Available( Size )) THEN
                                    ALLOCATE(Where,Size);
                                ELSE
                                    RETURN;  (* No room for this item? *)
                                END;
                            END;
                            INCL (Category, HeapNoOwner);
                        ELSIF (HoldInFlexStor IN Category) THEN
                            Handle := AnExtHandle (Where);
                            Size := LockObject (Handle, Where);
                        END;

                            (* Load the data item into memory. *)

                        ReadRecordBody(f,Length,Where,Size);

                        IF (HoldInFlexStor IN Category) THEN
                            ReleaseObject (Handle);
                        END;
                        IF (CreateFlag) THEN
                            IF (HoldInFlexStor IN Category) THEN
                                Where := ADDRESS(Handle);
                            END;
                            HoldThis(Name,Class,Category,Where,Size);
                        END;
                    END;

            |   0FFH :
                    EXIT;        (* End of subfile. *)

            ELSE
                SkipRecordBody(f,Length);
            END;
        END;
    END;
END GetHeldItems;




PROCEDURE GetFiltersInfo( VAR f:File );
VAR
    Version                 : CARDINAL;
    Type                    : CARDINAL;
    Length                  : CARDINAL;
    FilterNumber            : CARDINAL;
    HighlightNo             : CARDINAL;
    Node                    : ATreeNode;
    OldFilter               : ATreeNode;
    OldFilterRecord,
    TempFilterRecord        : AFilterRecordPointer;
    Header                  : AHeaderRecord;
    SavingInTree            : BOOLEAN;
    AllowThisOne            : BOOLEAN;
    FilterRecord            : AFilterRecord;


    PROCEDURE FilterAltered ( OldOne      : ATreeNode;
                              NewOne      : ATreeNode   );
    VAR
        i           : CARDINAL;

    BEGIN
        IF (RevealFilter = OldOne) THEN
            RevealFilter := NewOne;
        END;
        FOR i := 3 TO 5 DO
            IF (HighlightFilter[i] = OldOne) THEN
                HighlightFilter[i] := NewOne;
            END;
        END;
    END FilterAltered;


        (* Store the filter record from the stack variable into the
           Tree Node's FlexStor object. *)

    PROCEDURE CompleteFilter();
    VAR
        FilterHandle       : AnExtHandle;
    BEGIN
        IF (Node <> NIL) THEN                   (* 18-Feb-88 LAA *)
            Compress(FilterRecord.Notes);
            FilterHandle := AnExtHandle(Node^.Methods^.GetDataObject (Node));
            IF (NOT SetExtData(FilterHandle,ADR(FilterRecord),SIZE(FilterRecord))) THEN
                FatalError();
            END;
            Node := NIL;
        END;
    END CompleteFilter;


     PROCEDURE InitVersion4Filters(VAR FilterRecord : AFilterRecord);
     VAR
        FilterType              : AFltrType;
     BEGIN
        WITH FilterRecord DO
            NeedsUpdate := FALSE;
            FOR FilterType := FDataField1 TO FDataField2 DO           (* 07-Jul-89 LAA *)
                DataField[FilterType].FieldId := 0;
                SetLengthOf(DataField[FilterType].CompareTo, 0);
                DataField[FilterType].CompareAs := ItMatches;
                DataField[FilterType].Inverted := FALSE;              (* 16-Jul-89 LAA *)
            END;
        END;
     END InitVersion4Filters;

BEGIN
    IF (NOT StartSubfileInput(f,FiltersType,Version)) THEN
        RETURN;
    END;

    SavingInTree := TRUE;
    HighlightNo := 1;
    Node := NIL;

    TaskFindBegin();

    LOOP
        ReadRecordPreface(f,Type,Length);
        IF (CheckIO(f) <> done) THEN EXIT; END;

        IF ((Type >= 10) OR (Type < 1)) AND (Type <> 100) THEN          (* 7/13/89 EGK *)

                (* We are in a loop reading filter records from the
                   file.  Each filter is represented by a long series
                   of data records.  Each type 0 record is the beginning
                   of a new filter.  There is no explicit end of filter
                   record.
                   If there is any preceding filter being read, finish it.
                 *)
            CompleteFilter();
        END;

        CASE Type OF
            0  :

                      (* Standard header for all tree items. *)
                  ReadRecordBody (f, Length, ADR(Header), SIZE(Header));

          | 1  :
                      (* Create a new filter.  However, in order to avoid
                         holding a lock on it for a long time, we will
                         do our work temporarily on a filter record variable
                         allocated on the stack.  This gets stored into
                         the TreeNode by CompleteFilter().  AJL  6/5/89. *)

                  IF (NOT CreateFilter (Node)) THEN RETURN; END;

                  ReadRecordBody(f,Length,ADR(FilterRecord),SIZE(FilterRecord));
                  InitVersion4Filters(FilterRecord);
                  FilterRecord.Notes := AText(NIL);

                  AllowThisOne := TRUE;
                  OldFilter    := FindFilterByName (FilterRecord.Name);
                  IF (OldFilter <> NIL) AND (SavingInTree) THEN

                      OldFilterRecord := OldFilter^.Methods^.LockFlexStorDataObject (OldFilter);
                      FilterAltered (OldFilter, Node);
                      OldFilter^.Methods^.UnlockUnchangedDataObject (OldFilter);
                      OldFilterRecord := NIL;
                      DeleteFilter (OldFilter);
                  END;

                  IF (AllowThisOne) THEN
                      FilterRecord.antetask := NIL;    (* Don't want random pointers. *)
                      FilterRecord.desctask := NIL;
                      FilterRecord.Notes := AText (NIL);

                      IF (SavingInTree) THEN
                          AttachNodeOnTree (FilterTree, Node, Header.Level);
                          Node^.Methods^.SetAttributes (Node, Header.Attributes);
                      ELSE
                          IF (HighlightFilter[HighlightNo] <> NIL) THEN
                              DeleteFilter (HighlightFilter[HighlightNo]);
                          END;
                          HighlightFilter[HighlightNo] := Node;
                          INC (HighlightNo);
                      END;
                  END;

          | 2  :  IF (AllowThisOne) THEN
                      ReadTaskNumber(f,Length,FilterRecord.antetask);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 3  :  IF (AllowThisOne) THEN
                      ReadTaskNumber(f,Length,FilterRecord.desctask);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 4  :  IF (AllowThisOne) THEN
                      ReadDate(f,Length,FilterRecord.startdate);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 5  :  IF (AllowThisOne) THEN
                      ReadDate(f,Length,FilterRecord.enddate);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;

          | 10 :  EXIT;

          | 11  : ReadFilterNumber (f, Length, HighlightFilter[3]);
          | 12  : ReadFilterNumber (f, Length, HighlightFilter[4]);
          | 13  : ReadFilterNumber (f, Length, HighlightFilter[5]);

          | 30 :  EXIT;

          | 31  : ReadFilterName (f, Length, HighlightFilter[3]);
          | 32  : ReadFilterName (f, Length, HighlightFilter[4]);
          | 33  : ReadFilterName (f, Length, HighlightFilter[5]);

          | 100 : IF (AllowThisOne) THEN
                      ReadOldFormatTextLine(f, Length, FilterRecord.Notes);
                  ELSE
                      SkipRecordBody(f,Length);
                  END;
          | 0FFH : EXIT;
          ELSE    SkipRecordBody(f,Length);
        END;
    END;

    TaskFindEnd();

    SortFilters();
    UnSetState(Filtered);

END GetFiltersInfo;




PROCEDURE GetFileNames(VAR f:File);
VAR
    Version       :     CARDINAL;
BEGIN
    IF (StartSubfileInput(f,FileNamesType,Version)) THEN
        ReadString(f,RetrievalName);
        ReadString(f,ProjectMedia);
    END;
END GetFileNames;





PROCEDURE GetCnfg (VAR FileName   : ARRAY OF CHAR ) : BOOLEAN;
VAR
    i,j             : CARDINAL;
    cnfgfile        : File;
    TempOverlayPath, DefaultPath,
    s               : ARRAY [0..80] OF CHAR;
    OptionName      : ARRAY [0..9]  OF CHAR;
    ok              : BOOLEAN;
BEGIN

(*    GetMessage(ModuleNumber+5,s); *)  (*  "Version 3 configuration file"  *)

    (* 24-Oct-90 TGS *)
    SetString(OptionName, "CONFIG");
    SetString(DefaultPath, "DK:;");
    GetOption(OptionName, ok, s);
    IF (ok) THEN
        ExpandPath(s, DefaultPath, TempOverlayPath);
        ConcatS(TempOverlayPath, ";");
    ELSE
        Copy( DefaultPath, TempOverlayPath );
    END;

    ConcatLS(  TempOverlayPath, OverlayPath );
    IF (NOT RequestFileOpenReadOnly(TempOverlayPath,FileName,s,cnfgfile)) THEN
        RETURN FALSE;
    END;

    IF (NOT StartFileInput(cnfgfile)) THEN
        Close(cnfgfile);
        RETURN FALSE;
    END;

    IF (CheckIO(cnfgfile) <> done) THEN
        RETURN FALSE;
    END;

    GetHeldItems(cnfgfile);
    GetVideo(cnfgfile);

    i := 0;
    LOOP
        CASE i OF
            |   0:
                   ok := GetSignature(cnfgfile,j);  (* 31-Oct-89 EGK *)
                   IF (ok) THEN
                       ok := (j = 300);
                       IF (NOT ok) THEN
                           SignatureError(300,j);
                       END;
                   END;
                   IF (NOT ok) THEN
                       EXIT;
                   END;

            |   1: GetCalendar(cnfgfile);
            |   2: GetPreferences(cnfgfile);
            |   3: GetCodeSets(cnfgfile);
            |   4: GetFonts(cnfgfile);
            |   5: GetPrinterTable(cnfgfile);
            |   6: GetMemosInfo(cnfgfile);
            |   7: GetNetLayoutsInfo(cnfgfile, DuplicatesOK, TRUE, FALSE);
            |   8: GetFiltersInfo(cnfgfile);
            |   9: GetLayoutsInfo(cnfgfile, DuplicatesOK, TRUE, FALSE);
            |  10: GetTheEnvironment(cnfgfile);
            |  11: GetFileNames(cnfgfile);
        ELSE
            EXIT;
        END;

        IF ( NOT (CheckIO(cnfgfile) = done) ) THEN
            EXIT;
        END;
        INC(i);
    END;

    Close(cnfgfile);
    IF (CheckIO(cnfgfile) <> done) THEN
        RETURN FALSE;
    END;
    MChToday();
    ResetChart();
    RETURN TRUE;
END GetCnfg;




PROCEDURE ReadVersion3ConfigFile();
VAR
    s          :    ARRAY [0..255] OF CHAR;                         (* 19-Oct-89 MWP *)
    Copyright  :    ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    SetString( s, "TLCNFG3.DAT" );
    IF (NOT GetCnfg(s) )  THEN
        GetMessage(ModuleNumber+22,s);   (*  "Unable to read verions 3 Configuration file."  *)
        Error(s);
    END;
END ReadVersion3ConfigFile;

BEGIN
    ReadVersion3ConfigFile();
END TL3Cnfg.

