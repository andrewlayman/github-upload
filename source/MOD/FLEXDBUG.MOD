IMPLEMENTATION MODULE FlexDbug;
(* Modification History:

       23-Jan-89 RSC   -Changed Storage to Space.
       23-Feb-89 AJL   -PageTable is now a pointer.
       22-Mar-89 AJL   -ShowCells had been attempting to dereference
                        empty cells.  This either printed garbage or,
                        if range checking was on, halted. 
       13-Jul-89 EGK    Removed import of "PrjtNotesKey".
       14-Aug-89 AJL    Highlight the in-memory pages.  Count dirty
                        ones.
       12-Dec-89 RSC    Added MODAL parameter to menus.
       15-Dec-89 RSC    Changed GetAnyCode to GetNextEvent.
       30-Jun-90 AJL    Import from FlexDisp.
        4-Jul-90 AJL    Rephrased ShowCells increment to avoid cardinal
                        overflow when range checking on.
       25-Jan-91 AJL    Remove import of ManualFilterKey.
*)

FROM LStrings IMPORT
    (* PROC *)      SetString, ConcatS, ConcatLS, CtoS, Procustes,
                    Overlay, Fill, Copy, Remove, Insert, SetLengthOf,
                    LengthOf;


FROM Dialog  IMPORT
    (* PROC *)      Error, FatalError, NotYetImplemented, Burp, Message;

FROM PageSupply IMPORT
    (* TYPE *)      APageClass, APageHandle,
    (* PROC *)      CreatePage, DiscardPage, RetrievePage,
                    SynchPage,
                    StartupPageClass, ShutdownPageClass;

FROM Space     IMPORT
    (* PROC *)      ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM  IMPORT
    (* TYPE *)      BYTE, TSIZE, SIZE, ADDRESS, ADR, CODE;

FROM Boxes          IMPORT ABoxAttribute, ABoxType, DrawBox;

FROM CRC16    IMPORT
    (* PROC *)      CheckSum;

FROM Events   IMPORT
    (* TYPE *)      AnEvent,
    (* PROC *)      GetNextEvent;

FROM Kbio           IMPORT ascreenx, ascreeny, avidmode, 
                           PutString, maxrow, maxcol;

FROM Menus          IMPORT Menu;

FROM Codes          IMPORT
                           MaxCode, ACode, ASetOfCodes, SetCodeBits;

FROM Keys           IMPORT 
         ExitKey, DoIt, CancelKey, Fwrd, Reverse, Up,
         Down, Tab, RTab, HelpKey, RollUp, RollDown, RollLeft,
         RollRight, OnChart, OnMenu, JoinKey, UnJoinKey, UndoKey, AddTaskKey,
         DelTaskKey, ChngTskKey, InsertKey, DeleteKey, 
         DsplyKey, AnteKey, SplitKey, GotoKey, ComputeKey,
         GotoFirstKey, GotoLastKey, GotoTodayKey, Goto1Key, Goto2Key,
         DaysKey, CalFormKey, PgUpKey, PgDnKey, RepeatKey,
         ReportsKey, ResourceFormKey, PrintFormKey, GotoNameKey,
         OptionsFormKey, OptionsMenuKey, JoinPartialKey,
         BackSpace,HomeKey,EndKey,SelectKey,TimeoutKey,DeathKey,
         GotoCurrentTaskKey, EraseKey,
         AlternateDisplayKey, NewProjectKey,
         CopyKey, EditKey, ReInsertKey, OpenKey, CloseKey, MoveUpKey,
         MoveDownKey, PromoteKey, DemoteKey, SelListKey, HistKey, 
         HelpIndexKey, TaskNotesKey, HighListKey, EraseToEOLKey,
         DependViewKey, AltUndoKey, HighList2Key, HighList3Key,
         EditBigTaskKey, NetworkKey, FileFormKey;


FROM Rugs           IMPORT ARug, GetRug, PutRug;

FROM FlexTrace      IMPORT ShowTrace, TraceOn, TraceOff, SetStepMode,
                           GetStepMode, GetTraceMatchString, SetTraceMatchString;


FROM FlexStor       IMPORT AnExtHandle;


FROM FlexData IMPORT
          MaxPages, MaxDataSize,
          MaxUserRecordsPerPage, MaxRecordsPerPage, MaxRecordSize,
          MaxGeneration, AHandlesInternals, ACellNo,
          APageNo, AGeneration, ARecordNo, ACellInfo, ACellBlock, CellBlockTable,
          ACellBlockNumber, TopCellBlock, MaxCellPerBlock,
          ACellPointer, APageSet, APageIndexArray, APageHeader, BPBS,
          APage, APagePointer, APageInfo, APageTable,
          PageTable,
          Quantity;

FROM FlexDisp IMPORT
          CtoH, AtoS, HandleToString;


    CONST
        StartX = 39;
        StartY = 3;
        EndX   = 79;
        EndY   = 23;
    TYPE
        ADisplayType = (DisplayCells, DisplayLockedCells,
                        DisplayPages, DisplayPageTable,
                        DisplayRecord, DisplayTrace, DisplayCellTable );
    VAR
        DisplayType : ADisplayType;







PROCEDURE EncodeHandle(    CellPointer: ACellPointer;
                           Generation : AGeneration;
                       VAR Handle     : AnExtHandle    );
BEGIN

   (*
CODE	SEGMENT	PARA 'code'
	ASSUME	CS:CODE


        ; Normalize the address in CellPointer.
    MOV AX, [BP+0AH]      ; AX := Offset
    MOV BX, [BP+0CH]      ; BX := Segment
    MOV DX,AX             ; DX := Offset MOD 16
    AND DX, 0000FH
    SHR AX, 1             ; AX := Offset DIV 16
    SHR AX, 1
    SHR AX, 1
    SHR AX, 1
    ADD AX, BX            ; AX := (Segment + Offset DIV 16)
        ; Now DX:AX is the normalized address
        ; Add in the Generation
    MOV DH, BYTE PTR [BP+8]
        ; Store the results
    LDS SI, [BP+4]
    MOV [SI], DX
    MOV [SI+2], AX

CODE ENDS

END
   *)

    CODE(
         8BH, 46H, 0AH,
         8BH, 5EH, 0CH,
         8BH, 0D0H,
         81H, 0E2H, 0FH, 00H,
         0D1H, 0E8H,
         0D1H, 0E8H,
         0D1H, 0E8H,
         0D1H, 0E8H,
         03H, 0C3H,
         8AH, 76H, 08H,
         0C5H, 76H, 04H,
         89H, 14H,
         89H, 44H, 02H );

END EncodeHandle;




PROCEDURE DataAddress( VAR Page : APage;
                           RecNo : ARecordNo ) : ADDRESS;
BEGIN
    RETURN ADR(Page.Data[ Page.StartAt[RecNo]] );
END DataAddress;






PROCEDURE SizeOfRecord( VAR Page    : APage;
                            RecNo   : ARecordNo ) : CARDINAL;
BEGIN
    RETURN (Page.StartAt[RecNo+1])
          -(Page.StartAt[RecNo  ]);
END SizeOfRecord;




PROCEDURE CellIsLocked( CellPointer : ACellPointer ) : BOOLEAN;
VAR
    Page     : APagePointer;
    PageNum  : CARDINAL;
    RecNo    : ARecordNo;
    Lock     : BOOLEAN;
BEGIN


    WITH CellPointer^ DO
        PageNum := ORD(PageNo);
        RecNo   := ORD(RecordNo);
    END;

    WITH PageTable^[PageNum] DO
        IF (Location = NIL) THEN
            (* Not in memory *)
            RETURN FALSE;
        END;
        Page   := Location;
    END;


    Lock := (RecNo MOD BPBS) IN ( Page^.LockSet[ RecNo DIV BPBS ] );
    RETURN Lock;

END CellIsLocked;












    PROCEDURE QuickMenu(VAR Prefix,
                            Choices:ARRAY OF CHAR;
                        VAR Choice:CARDINAL;
                            AllowHelp : BOOLEAN
                            ):BOOLEAN;
    VAR
        CodeSet : ASetOfCodes;
        Code : ACode;
    BEGIN
        SetCodeBits(CodeSet,0,MaxCode,FALSE);
        IF (NOT AllowHelp) THEN
            SetCodeBits(CodeSet,HelpKey,HelpKey,TRUE);
        END;

        LOOP
            Code := Menu(Prefix,Choices,0,0,maxcol,StartY-1,CodeSet,
                         FALSE,     (* 12-Dec-89 RSC MODAL *)
                         Choice);   (* 3/26/87 EGK *)
            IF (Code = DoIt) THEN
                RETURN TRUE;
            ELSIF (Code = CancelKey) THEN
                RETURN FALSE;
            ELSE
                Burp;
            END;
        END;
    END QuickMenu;



    PROCEDURE DumbMenu(VAR Prefix,Choices:ARRAY OF CHAR; VAR Choice:CARDINAL);
    BEGIN
        REPEAT
        UNTIL (QuickMenu(Prefix,Choices,Choice,FALSE));
    END DumbMenu;


    PROCEDURE ShowAddress( A : ADDRESS;
                           X : ascreenx;
                           Y : ascreeny;
                           mode : avidmode );
    VAR
        S  : ARRAY [0..40] OF CHAR;
    BEGIN
        AtoS(A,S);
        PutString(S,X,Y,mode);
    END ShowAddress;




    PROCEDURE ShowAPage(     PageNumber : CARDINAL;
                             x    : ascreenx;
                             y    : ascreeny;
                             Interactive : BOOLEAN ) : CARDINAL;
    VAR
        S, S2 : ARRAY [0..80] OF CHAR;
        Page  : APagePointer;
        Lines : CARDINAL;
        i     : CARDINAL;
        Mode  : avidmode;
        Cursor : CARDINAL;
        Event : AnEvent;
        C     : ACode;
        Rug   : ARug;
    BEGIN
        IF (Interactive) THEN
            IF NOT GetRug(0,0,maxcol,maxrow,Rug) THEN
                Interactive := FALSE;
                Rug := ARug(NIL);
            END;
            SetString(S,"[Up], [Down], [F]ather, [S]on, [Esc], 0..9, [Home]");
            Procustes(S,maxcol+1);
            PutString(S,0,0,videobright);
        END;

        WITH PageTable^[PageNumber] DO
            IF (NOT RetrievePage(StorageClass,PageNumber)) THEN
                FatalError();
                RETURN 0;
            END;
        END;
        (*<PARANOID
        CheckSumThePageTable();
        PARANOID>*)

        Page := PageTable^[PageNumber].Location;
        SetString(S,"Page ");
        CtoS(PageNumber,S2);
        ConcatLS(S,S2);
        ConcatS(S," Locks=");
        CtoS(Page^.Header.LockCount,S2);
        ConcatLS(S,S2);
        ConcatS(S," LastEntry=");
        CtoS(Page^.Header.LastEntry,S2);
        ConcatLS(S,S2);
        IF (Page^.Header.NeedsSqueeze) THEN
            ConcatS(S," squeeze");
        END;
        PutString(S,x,y,videocaption);

        i := 0;
        Cursor := 0;

        LOOP
            i := Cursor;
            Lines := 1;

            WHILE (i <= Page^.Header.LastEntry) AND (y+Lines <= 23) DO
                Fill(S," ",maxcol-x+1);
                WITH Page^ DO
                    CtoS(i,S2);
                    ConcatLS(S,S2);
                    Overlay(S,S2,1,5);
                    CtoS(StartAt[i+1]-StartAt[i],S2);
                    ConcatLS(S,S2);
                    Overlay(S,S2,6,5);
                    CtoS(StartAt[i],S2);
                    Overlay(S,S2,12,5);
                    Mode := videobright;
   
                    IF ((i MOD BPBS) IN (FreeSet[ i DIV BPBS]) ) THEN
                        SetString(S2,"Free");
                        Overlay(S,S2,18,4);
                        Mode := videonormal;
                    END;
                    IF ((i MOD BPBS) IN (LockSet[ i DIV BPBS]) ) THEN
                        SetString(S2,"Locked");
                        Overlay(S,S2,24,6);
                    END;
                    IF (Interactive) AND (i = Cursor) THEN 
                        Mode := cvideonormal; 
                        ShowRecord(0,StartY,StartX-1,EndY,PageNumber,Cursor,FALSE);
                    END;
                END;
                PutString(S,x,y+Lines,Mode);
                INC(i);
                INC(Lines);
            END;

            WHILE (y+Lines <= 23) DO
                Fill(S," ",maxcol-x+1);
                PutString(S,x,y+Lines,videonormal);
                INC(Lines);
            END;

            IF (NOT Interactive) THEN
        EXIT;
            END;

            GetNextEvent( Event );
            C := Event.EventCode;
            CASE C OF 
                CancelKey,
                70 (*"F"*),
                102 (*"f"*) : EXIT;
              | DoIt,
                83 (*"S"*),
                115 (*s"*)  : ShowRecord(0,0,maxcol,maxrow-1,PageNumber,Cursor,Interactive);
              | HomeKey     : Cursor := 0;
              | Up          : IF (Cursor > 0) THEN DEC(Cursor); END;
              | Down        : IF (Cursor < Page^.Header.LastEntry) THEN INC(Cursor); END;
              | 49..57      : IF (C-48 <= Page^.Header.LastEntry) THEN Cursor := C-48; END;
              ELSE Burp;
            END;

        END;

        IF (Interactive) AND (Rug <> ARug(NIL)) THEN PutRug(0,0,maxcol,maxrow,Rug); END;

            (*<RELEASE
        MaybeLetGoOfPage( Page^ );
            RELEASE>*)

        RETURN Lines;

    END ShowAPage;



    PROCEDURE ShowPages(Interactive : BOOLEAN);
    VAR
        Y  : ascreeny;
        PageNumber : CARDINAL;
        S : ARRAY [0..200] OF CHAR;
        Event : AnEvent;
        C : ACode;
        i : CARDINAL;
        Rug : ARug;
    BEGIN
        IF (Interactive) THEN
            IF NOT GetRug(0,0,maxcol,maxrow,Rug) THEN
                Interactive := FALSE;
                Rug := ARug(NIL);
            END;
            SetString(S,"[Up], [Down], [S]on, [Esc], 0..9. [Home]");
            Procustes(S,maxcol+1);
            PutString(S,0,0,videobright);
        END;

        PageNumber := 1;

        LOOP
            Fill(S," ",0);
            DrawBox(StartX,StartY,EndX,EndY,ABoxType{NoBox},S,videonormal);
            Y := StartY;
            i := 0;
            WHILE ( Y < maxrow-1 ) AND (PageNumber+i <= MaxPages) DO
                IF (PageTable^[PageNumber+i].Valid) THEN
                    Y := Y + ShowAPage(PageNumber+i,StartX,Y,FALSE);
                END;
                INC(i);
            END;

        IF (NOT Interactive) THEN EXIT; END;

            GetNextEvent( Event );
            C := Event.EventCode;
            CASE C OF 
                CancelKey   : EXIT;
              | DoIt,
                83 (*"S"*),
                115 (*s"*)  : Y := StartY + ShowAPage(PageNumber,StartX,StartY,TRUE);
              | HomeKey     : PageNumber := 1;
              | Up          : IF (PageNumber > 1) THEN DEC(PageNumber); END;
              | Down        : IF (PageNumber < MaxPages) THEN INC(PageNumber); END;
              | 49..57      : IF (C-48 <= MaxPages) THEN PageNumber := C-48; END;
              ELSE Burp;
            END;
        END;
        IF (Interactive) AND (Rug <> ARug(NIL)) THEN PutRug(0,0,maxcol,maxrow,Rug); END;

    END ShowPages;



    PROCEDURE ShowCells(    StartCellNo : CARDINAL;
                            LockedOnly  : BOOLEAN );
    VAR
        Y  : ascreeny;
        CellNumber : ACellNo;
        Count      : CARDINAL;
        S,S2  : ARRAY [0..50] OF CHAR;
        BlockNumber : ACellBlockNumber;
        CellPointer : ACellPointer;
        Handle      : AnExtHandle;
        PageNumber  : CARDINAL;
        Interactive : BOOLEAN;
    BEGIN
        Fill(S," ",0);
        DrawBox(StartX,StartY,EndX,EndY,ABoxType{NoBox},S,videonormal);

        CtoS(Quantity,S);
        PutString(S,StartX,StartY,videonormal);

                (*   123456789 123456789 1234567890 123456789 *)
        SetString(S,"Handle   PageNo RecordNo Generation");
        PutString(S,StartX,StartY+1,videocaption);
        Y := StartY+2;

        BlockNumber := 0C;
        CellNumber := 0C;
        Count := 0;

        WHILE ( Y < maxrow-1 ) AND (BlockNumber <= TopCellBlock) DO
            CellPointer := ADR(CellBlockTable[BlockNumber]^[CellNumber]);
            PageNumber := CellBlockTable[BlockNumber]^[CellNumber].PageNo;
            IF (PageNumber <> 0) AND                              (* In use. *)
               ((NOT LockedOnly) OR (CellIsLocked(CellPointer)))
               THEN

                INC(Count);                     (* Start display at StartCellNo *)
                IF (Count >= StartCellNo) THEN
                    Fill(S," ",maxcol-StartX+1);
                    EncodeHandle(CellPointer,CellPointer^.Generation,Handle);
                    HandleToString(Handle,S2);
                    Overlay(S,S2,1,8);
                 
                    WITH CellPointer^ DO
                        IF (ORD(PageNo) <> 0) THEN
                            CtoS(ORD(PageNo),S2);
                            Overlay(S,S2,10,5);
                            CtoS(ORD(RecordNo),S2);
                            Overlay(S,S2,17,5);
                            CtoS(ORD(Generation),S2);
                            Overlay(S,S2,26,5);
                                (* Is the record in memory now? *)
                            IF (PageTable^[PageNo].Valid) AND
                               (PageTable^[PageNo].Location <> NIL) 
                               THEN
                                SetString(S2,"in");
                                Overlay(S,S2,32,2);
                                    (* Show contents of first cell. *)
                                IF (Count = StartCellNo) THEN
                                    SetString(S2,"<<");
                                    Overlay(S,S2,32,2);
                                    Interactive := FALSE;  
                                    ShowRecord(0,StartY,StartX-2,maxrow-1,PageNo,ORD(RecordNo),Interactive);
                                END;
                            END;
                            PutString(S,StartX,Y,videobright);
                        END;
                    END;
                    INC(Y);
                END;
            END;

            IF (CellNumber >= MaxCellPerBlock) THEN
                INC(BlockNumber);
                CellNumber := 0C;
            ELSE
                INC(CellNumber);
            END;
        END;
    END ShowCells;


    PROCEDURE ScrollThroughCells( LockedOnly  : BOOLEAN );
    VAR
        i : CARDINAL;
        Event : AnEvent;
        C : ACode;
        Rug : ARug;
        S : ARRAY [0..255] OF CHAR;
            
    BEGIN
        IF NOT GetRug(0,0,maxcol,maxrow,Rug) THEN
            Rug := ARug(NIL);
        END;

        SetString(S,"[Up], [Down], [PgUp], [PgDn], [Esc], 0..9. [Home]");
        Procustes(S,maxcol+1);
        PutString(S,0,0,videobright);

        i := 1;

        REPEAT
            ShowCells(i,LockedOnly);

            GetNextEvent( Event );
            C := Event.EventCode;
            CASE C OF 
                CancelKey   :  
              | HomeKey     : i := 1;
              | PgUpKey     : IF (i > 10) THEN DEC(i,10); END;
              | PgDnKey     : INC(i,10);
              | Up          : IF (i > 1) THEN DEC(i); END;
              | Down        : INC(i);
              | 49..57      : i := C-48; 
              ELSE Burp;
            END;
        UNTIL (C=CancelKey);

        IF  (Rug <> ARug(NIL)) THEN PutRug(0,0,maxcol,maxrow,Rug); END;

    END ScrollThroughCells;



    PROCEDURE ShowPageTable(VAR StartEntry : CARDINAL);
    VAR
        Y  : ascreeny;
        PageNumber : CARDINAL;
        S,S2  : ARRAY [0..50] OF CHAR;
        DirtyCount : CARDINAL;
        Mode : avidmode;
    BEGIN
        DirtyCount := 0;
        Fill(S," ",0);
        DrawBox(StartX,StartY,EndX,EndY,ABoxType{NoBox},S,videonormal);

                (*   123456789 123456789 1234567890 123456789 *)
        SetString(S,"PageNo Location   HomeAddress   C Free");
        PutString(S,StartX,StartY+1,videocaption);
        Y := StartY+2;
        PageNumber := StartEntry;
        WHILE (PageNumber <= MaxPages) DO
            IF (Y < maxrow-1) THEN
                Fill(S," ",maxcol-StartX+1);
                CtoS(PageNumber,S2);
                Overlay(S,S2,1,5);
                WITH PageTable^[PageNumber] DO
                    IF (Valid) THEN
                        Mode := videonormal;
                        IF (Location <> NIL) THEN
                            Mode := videobright;
                        END;
                        PutString(S,StartX,Y,Mode);
                        ShowAddress( Location, StartX+7, Y, Mode);
                        ShowAddress( ADDRESS(HomeAddress), StartX+18, Y, Mode);
                        IF (Location <> NIL) THEN
                            Mode := videobright;
                            IF (Location^.Header.Dirty) THEN
                                SetString(S,"*");
                                PutString(S,StartX+31,Y,Mode);
                                INC(DirtyCount);
                            END;
                        END;
                        CASE StorageClass OF
                            PageFast   : SetString(S,"F");
                          | PageMedium : SetString(S,"M");
                          | PageSlow   : SetString(S,"S");
                        END;
                        PutString(S,StartX+32,Y,Mode);
                        CtoS(FreeBytes,S);
                        PutString(S,StartX+34,Y,Mode);
                    ELSE
                        PutString(S,StartX,Y,videonormal);
                    END;
                END;
                INC(Y);
            END;
            INC(PageNumber);
        END;

        SetString(S,"Dirty pages = ");
        CtoS(DirtyCount,S2);
        ConcatLS(S,S2);
        PutString(S,StartX,StartY+1,videocaption);

    END ShowPageTable;





    PROCEDURE ShowPageTableEntries(Interactive : BOOLEAN);
    VAR
        Y  : ascreeny;
        PageNumber, StartPage : CARDINAL;
        S : ARRAY [0..200] OF CHAR;
        Event : AnEvent;
        C : ACode;
        i : CARDINAL;
        Rug : ARug;
        
    BEGIN
        IF (Interactive) THEN
            IF NOT GetRug(0,0,maxcol,maxrow,Rug) THEN
                Interactive := FALSE;
                Rug := ARug(NIL);
            END;
            SetString(S,"[PgUp], [PgDown], [Esc], [Home], [Son]");
            Procustes(S,maxcol+1);
            PutString(S,0,0,videobright);
        END;

        PageNumber := 1;


        LOOP
            StartPage := PageNumber;  
            ShowPageTable(PageNumber);

        IF (NOT Interactive) THEN EXIT; END;

            GetNextEvent( Event );
            C := Event.EventCode;
            CASE C OF 
                CancelKey   : EXIT;
              | HomeKey     : PageNumber := 1;
              | PgUpKey     : IF (PageNumber > 1) THEN DEC(PageNumber); END;
              | PgDnKey     : IF (PageNumber < MaxPages) THEN INC(PageNumber); END;
              | DoIt,
                83 (*"S"*),
                115 (*s"*)  : IF (PageTable^[StartPage].Valid) THEN
                                  Y := ShowAPage(StartPage,StartX,StartY,Interactive);
                              ELSE
                                  Burp();
                              END;
              ELSE Burp;
            END;
        END;
        IF (Interactive) AND (Rug <> ARug(NIL)) THEN PutRug(0,0,maxcol,maxrow,Rug); END;

    END ShowPageTableEntries;







    PROCEDURE ShowARecord( Where : ADDRESS; Size : CARDINAL;
                             ULX, ULY, LRX, LRY : CARDINAL );
    CONST
        WordSpace = 2;
        CharSpace = 1;
        SpaceEach = WordSpace + CharSpace;
    VAR
        S, S2 : ARRAY [0..80] OF CHAR;
        PerLine : CARDINAL;
        X,Y       : CARDINAL;
        i,j       : CARDINAL;
        A         : POINTER TO ARRAY [0..8000] OF CHAR;
        CharOffset: CARDINAL;
    BEGIN
        AtoS(Where,S);
        ConcatS(S,"  Size = ");
        CtoS(Size,S2);
        ConcatLS(S,S2);
        PutString(S,ULX,ULY,videonormal);
        PerLine := (LRX-ULX+1-1) DIV (((2*SpaceEach)+1)) * 2;
        CharOffset := (WordSpace*PerLine) + ((PerLine+1) DIV 2);
        A := Where;
        Y := ULY + 1;
        X := ULX;
        i := 0;
        j := 0;
        WHILE (Y <= LRY) AND (i < Size) DO
            CtoH(ORD(A^[i]),S);
            Remove(S,1,2);
            PutString(S,X,Y,videobright);
            Fill(S,A^[i],1);
            PutString(S,ULX+1+CharOffset+(CharSpace*j),Y,videonormal);
            INC(i);
            INC(j);
            INC(X,WordSpace);
            IF (NOT ODD(i)) THEN
                INC(X);
            END;
            IF (j = PerLine) THEN
                X := ULX;
                INC(Y);
                j := 0;
            END;
        END;
    END ShowARecord;


    PROCEDURE ShowRecord(ULX : ascreenx; ULY : ascreeny;
                         LRX : ascreenx; LRY : ascreeny;
                         PageNumber : CARDINAL; RecNo : CARDINAL;
                         Interactive : BOOLEAN);
    VAR
        Y  : ascreeny;
        S,S2  : ARRAY [0..50] OF CHAR;
        Page  : APagePointer;
        Lines : CARDINAL;
        i     : CARDINAL;
        Mode  : avidmode;
        Data  : ADDRESS;
        Size  : CARDINAL;
        Event : AnEvent;
        C     : ACode;
        Rug   : ARug;
       
    BEGIN
        IF (Interactive) THEN
            IF (NOT GetRug(ULX,ULY,LRX,LRY,Rug)) THEN
                Interactive := FALSE;
                Rug := ARug(NIL);
            END;
        END;
           


        Fill(S," ",0);
        DrawBox(ULX,ULY,LRX,LRY,ABoxType{NoBox},S,videonormal);

        WITH PageTable^[PageNumber] DO
            IF (NOT RetrievePage(StorageClass,PageNumber)) THEN
                FatalError();
                RETURN;
            END;
        END;
        (*<PARANOID CheckSumThePageTable();  PARANOID>*)

        Page := PageTable^[PageNumber].Location;

        Data := DataAddress(Page^,RecNo);
        Size := SizeOfRecord(Page^,RecNo);

        SetString(S,"Page "); CtoS(PageNumber,S2); ConcatLS(S,S2);
        ConcatS(S," Record "); CtoS(RecNo,S2);     ConcatLS(S,S2);
        ConcatS(S," Size "); CtoS(Size,S2);        ConcatLS(S,S2);
        PutString(S,ULX,ULY,videonormal);

        ShowARecord( Data, Size, ULX, ULY+1, LRX, LRY );

        IF Interactive THEN
            LOOP 
               GetNextEvent( Event );
               C := Event.EventCode;
               IF (C = CancelKey) OR (C=70) OR (C=102) THEN EXIT;
               ELSE Burp();
               END;
            END;
        END;
        
        IF (Interactive) AND (Rug <> ARug(NIL)) THEN PutRug(0,0,maxcol,maxrow,Rug); END;

    END ShowRecord;


    PROCEDURE ShowCellBlockTable();
    VAR
        Y  : ascreeny;
        i  : CHAR;
        S,S2  : ARRAY [0..50] OF CHAR;
    BEGIN
        Fill(S," ",0);
        DrawBox(StartX,StartY,EndX,EndY,ABoxType{NoBox},S,videonormal);

        CtoS(ORD(TopCellBlock)+1,S);
        ConcatS(S," cell blocks at ");
        CtoS(TSIZE(ACellBlock),S2);
        ConcatLS(S,S2);
        ConcatS(S," bytes each.");
        PutString(S,StartX,StartY,videonormal);

        Y := StartY + 2; 
        i := 0C;
        WHILE ( Y < maxrow-1 ) AND (i <= TopCellBlock) DO
            AtoS(CellBlockTable[i],S);
            PutString(S,StartX,Y,videobright);
            INC(Y); INC(i);
        END;


    END ShowCellBlockTable;


    PROCEDURE GetAString( VAR S : ARRAY OF CHAR );
    VAR
        C : ACode;
        Event : AnEvent;
        S1 : ARRAY [0..1] OF CHAR;
    BEGIN
        SetLengthOf(S,0);
        LOOP
            Message(S);
            GetNextEvent( Event );
            C := Event.EventCode;
            IF (C=DoIt) OR (C=ExitKey) THEN
                EXIT;
            ELSIF (C=CancelKey) THEN
                SetLengthOf(S,0);
            ELSIF (C=BackSpace) THEN
                Remove(S,LengthOf(S),1);
            ELSE
                Fill(S1,CHR(C),1);
                ConcatLS(S,S1);
            END;
         END;
         SetLengthOf(S1,0);
         Message(S1);

    END GetAString;



    PROCEDURE SelectTraceOptions();
    VAR
        Prefix, Choices : ARRAY [0..80] OF CHAR;
        Choice          : CARDINAL;
    BEGIN
        Choice := 1;
        SetString(Prefix,"TRACE OPTIONS");
        SetString(Choices,"Step ");
        IF (GetStepMode()) THEN
            ConcatS(Choices,"Off");
        ELSE
            ConcatS(Choices,"On");
        END;
        ConcatS(Choices,",Match String");
        DumbMenu(Prefix,Choices,Choice);
        CASE Choice OF 
            1 : SetStepMode( NOT GetStepMode() );
         |  2 : GetAString( Choices );
                SetTraceMatchString( Choices );
         ELSE
        END;    

    END SelectTraceOptions;



    PROCEDURE DoMenu(Interactive:BOOLEAN);
    VAR
        Prefix, Choices : ARRAY [0..80] OF CHAR;
        Choice          : CARDINAL;
    BEGIN
        LOOP
            Choice := ORD(DisplayType)+1;
            SetString(Prefix,"DISPLAY");
            SetString(Choices,"Cells,Locked Cells,Pages,Page Table,Record,Trace,Cell Table,Trace Options");

            IF (Interactive) THEN
                ConcatS(Choices,",Quit");
            END;
            DumbMenu(Prefix,Choices,Choice);
            IF (Choice = 9) THEN
        EXIT;
            END;
            IF (Choice <= 7) THEN
                DisplayType := VAL(ADisplayType,Choice-1);
                CASE DisplayType OF
                    DisplayCells : ScrollThroughCells(FALSE);
                  | DisplayLockedCells : ScrollThroughCells(TRUE);
                  | DisplayPages : ShowPages(Interactive);
                  | DisplayPageTable : ShowPageTableEntries(Interactive);
                  | DisplayRecord    : ShowRecord(StartX,StartY,EndX,EndY,1,0,Interactive);
                  | DisplayTrace     : ShowTrace(StartX,StartY,EndX,EndY);
                  | DisplayCellTable : ShowCellBlockTable();
                END;
            ELSE
                SelectTraceOptions();
            END;
            IF (NOT Interactive) THEN
        EXIT;
            END;
        END;
    END DoMenu;


    PROCEDURE DiagnosticHook( WithMenu : CARDINAL ) : CARDINAL;
    VAR
        Rug : ARug;
    BEGIN
        TraceOff();
        IF (WithMenu > 1) THEN
            IF (WithMenu > 2) THEN
                IF (GetRug(StartX,StartY,EndX,EndY,Rug)) THEN
                    DoMenu(TRUE);
                    PutRug(StartX,StartY,EndX,EndY,Rug);
                END;
            ELSE
                DoMenu(FALSE);
            END;
        ELSIF (WithMenu > 0) THEN
            CASE DisplayType OF
                DisplayCells : ShowCells(0,FALSE);
              | DisplayLockedCells : ShowCells(0,TRUE);
              | DisplayPages : ShowPages(FALSE);
              | DisplayPageTable : ShowPageTableEntries(FALSE);
              | DisplayRecord    : ShowRecord(StartX,StartY,EndX,EndY,1,0,FALSE);
              | DisplayTrace     : ShowTrace(StartX,StartY,EndX,EndY);
              | DisplayCellTable : ShowCellBlockTable();
            END;
        END;

        TraceOn();

        RETURN Quantity;

    END DiagnosticHook;

BEGIN
    DisplayType := DisplayPages;
END FlexDbug.

