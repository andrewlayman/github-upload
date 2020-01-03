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
       20-Jan-91 AJL    Revised to use the new FlexStor, FlexData and
                        FlexHash modules.  
*)

FROM LStrings IMPORT
    (* PROC *)      SetString, ConcatS, ConcatLS, CtoS, Procustes,
                    Overlay, Fill, Copy, Remove, Insert, SetLengthOf,
                    LengthOf;


FROM Dialog  IMPORT
    (* PROC *)      Error, FatalError, NotYetImplemented, Burp, Message;

FROM FlexHash    IMPORT
    (* CONST *)    MaxItemsToKeep, MaxBytesToKeep, HashTableSize,
    (* TYPE  *)    AHashRecord,
    (* VAR   *)    Clock, ItemsInMemory, BytesInMemory, LockedBytesInMemory,
                   HashTable, HashRecords,
                   OutstandingLocks, MostOutstandingLocks, TotalLocksEver,
                   Hits, Misses, MaxBytesInMemory, MaxLockedBytesInMemory,
                   MemoryFlushNotices;

FROM Layout      IMPORT
                   MaxRow, MaxColumn;

FROM LongConvert IMPORT
    (* PROC *)     LongToString; 

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
        ADisplayType = (DisplayCells, DisplayMemory,
                        DisplayPages, DisplayPageTable,
                        DisplayRecord, DisplayTrace, DisplayCellTable,
                        DisplayStats );
    VAR
        DisplayType : ADisplayType;
        OldHits,
        OldMisses     : LONGINT;







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
            IF NOT GetRug(0,0,maxcol,MaxRow,Rug) THEN
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
                    ELSE
                        CtoS(ORD(Generation[i]),S2);
                    END;
                    Overlay(S,S2,18,LengthOf(S2));
                    Mode := videonormal;


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
                115 (*s"*)  : ShowRecord(0,0,maxcol,MaxRow-1,PageNumber,Cursor,Interactive);
              | HomeKey     : Cursor := 0;
              | Up          : IF (Cursor > 0) THEN DEC(Cursor); END;
              | Down        : IF (Cursor < Page^.Header.LastEntry) THEN INC(Cursor); END;
              | 49..57      : IF (C-48 <= Page^.Header.LastEntry) THEN Cursor := C-48; END;
              ELSE Burp;
            END;

        END;

        IF (Interactive) AND (Rug <> ARug(NIL)) THEN PutRug(0,0,maxcol,MaxRow,Rug); END;

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
            IF NOT GetRug(0,0,maxcol,MaxRow,Rug) THEN
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
            WHILE ( Y < MaxRow-1 ) AND (PageNumber+i <= MaxPages) DO
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
        IF (Interactive) AND (Rug <> ARug(NIL)) THEN PutRug(0,0,maxcol,MaxRow,Rug); END;

    END ShowPages;



    PROCEDURE ShowCells(    StartCellNo : CARDINAL );
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

        WHILE ( Y < MaxRow-1 ) AND (BlockNumber <= TopCellBlock) DO
            CellPointer := ADR(CellBlockTable[BlockNumber]^[CellNumber]);
            PageNumber := ORD(CellBlockTable[BlockNumber]^[CellNumber].PageNo);
            IF (PageNumber <> 0) THEN

                INC(Count);                     (* Start display at StartCellNo *)
                IF (Count >= StartCellNo) THEN
                    Fill(S," ",maxcol-StartX+1);
                    EncodeHandle(CellPointer,0C,Handle);
                    HandleToString(Handle,S2);
                    Overlay(S,S2,1,8);
                 
                    WITH CellPointer^ DO
                        IF (ORD(PageNo) <> 0) THEN
                            CtoS(ORD(PageNo),S2);
                            Overlay(S,S2,10,5);
                            CtoS(ORD(RecordNo),S2);
                            Overlay(S,S2,17,5);
                                (* Is the record in memory now? *)
                            IF (PageTable^[ORD(PageNo)].Valid) AND
                               (PageTable^[ORD(PageNo)].Location <> NIL) 
                               THEN
                                SetString(S2,"in");
                                Overlay(S,S2,32,2);
                                    (* Show contents of first cell. *)
                                IF (Count = StartCellNo) THEN
                                    SetString(S2,"<<");
                                    Overlay(S,S2,32,2);
                                    Interactive := FALSE;  
                                    ShowRecord(0,StartY,StartX-2,MaxRow-1,
                                               ORD(PageNo),ORD(RecordNo),
                                               Interactive);
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


    PROCEDURE ScrollThroughCells( );
    VAR
        i : CARDINAL;
        Event : AnEvent;
        C : ACode;
        Rug : ARug;
        S : ARRAY [0..255] OF CHAR;
            
    BEGIN
        IF NOT GetRug(0,0,maxcol,MaxRow,Rug) THEN
            Rug := ARug(NIL);
        END;

        SetString(S,"[Up], [Down], [PgUp], [PgDn], [Esc], 0..9. [Home]");
        Procustes(S,maxcol+1);
        PutString(S,0,0,videobright);

        i := 1;

        REPEAT
            ShowCells(i);

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

        IF  (Rug <> ARug(NIL)) THEN PutRug(0,0,maxcol,MaxRow,Rug); END;

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
            IF (Y < MaxRow-1) THEN
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
            IF NOT GetRug(0,0,maxcol,MaxRow,Rug) THEN
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
        IF (Interactive) AND (Rug <> ARug(NIL)) THEN PutRug(0,0,maxcol,MaxRow,Rug); END;

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
        Fill(S," ",0);
        DrawBox(ULX,ULY,LRX,LRY,ABoxType{NoBox},S,videonormal);

        IF (Where = NIL) THEN
            SetString(S,"NIL");
        ELSE
            AtoS(Where,S);
        END;
        ConcatS(S,"  Size = ");
        CtoS(Size,S2);
        ConcatLS(S,S2);
        PutString(S,ULX,ULY,videonormal);

        IF (Where = NIL) THEN
            RETURN;
        END;

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
        
        IF (Interactive) AND (Rug <> ARug(NIL)) THEN PutRug(0,0,maxcol,MaxRow,Rug); END;

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
        WHILE ( Y < MaxRow-1 ) AND (i <= TopCellBlock) DO
            AtoS(CellBlockTable[i],S);
            PutString(S,StartX,Y,videobright);
            INC(Y); INC(i);
        END;


    END ShowCellBlockTable;






    PROCEDURE ShowMemory(  Interactive : BOOLEAN );
    VAR
        S, S2 : ARRAY [0..80] OF CHAR;
        Lines : CARDINAL;
        i     : CARDINAL;
        Mode  : avidmode;
        Cursor : CARDINAL;
        Event : AnEvent;
        C     : ACode;
        Rug   : ARug;
        y     : ascreeny;
        x     : ascreenx;
        HashRecord : AHashRecord;

        PROCEDURE GetRecordN(     n : CARDINAL;
                              VAR HashRecord : AHashRecord ):BOOLEAN;
        CONST
            Null = 0;                   (* Null link. *)
        VAR
            HashTableIndex, HashRecordIndex : CARDINAL;
        BEGIN
            HashTableIndex := 0;
                (* Search each table slot. *)
            WHILE (HashTableIndex <= HIGH(HashTable)) DO
                HashRecordIndex := HashTable[ HashTableIndex ];
                    (* Search the chain for the record with the Handle in it. *)
                WHILE (HashRecordIndex <> Null) DO
                    HashRecord := HashRecords[ HashRecordIndex ];
                    WITH HashRecord DO
                        IF (n = 0) THEN
                            RETURN TRUE;
                        END;
                        HashRecordIndex := Next;
                    END;
                    DEC(n);
                END;
                INC(HashTableIndex);
            END;
            RETURN FALSE;
        END GetRecordN;

    BEGIN
        IF (Interactive) THEN
            IF NOT GetRug(0,0,maxcol,MaxRow,Rug) THEN
                Interactive := FALSE;
                Rug := ARug(NIL);
            END;
            SetString(S,"[Up], [Down], [S]on, [Esc], 0..9, [Home]");
            Procustes(S,maxcol+1);
            PutString(S,0,0,videobright);
        END;

        i := 0;
        Cursor := 0;

        y := StartY;
        x := StartX;
                   (*123456789 123456789 123456 *)
        SetString(S,"i  Handle  Size  L Time  D ");
        PutString(S,StartX,StartY,videonormal);

        LOOP
            i := Cursor;
            Lines := 1;

            WHILE (i <= HIGH(HashRecords)) AND (y+Lines <= 23) DO
                Fill(S," ",maxcol-x+1);
                IF (GetRecordN(i,HashRecord)) THEN
                    WITH HashRecord DO
                        CtoS(i,S2);
                        ConcatLS(S,S2);
                        Overlay(S,S2,1,2);           (* Index,  1..2 *)
                        HandleToString(Handle,S2);   (* Handle  4..10 *)
                        Overlay(S,S2,4,7);
                        IF (Handle <> AnExtHandle(NIL)) THEN
                            CtoS(Size,S2);               (* Size   12..16 *) 
                            Overlay(S,S2,12,5);
                            CtoS(Locks,S2);              (* Locks  18..18 *) 
                            Overlay(S,S2,18,1);
                            CtoS(Time,S2);               (* Time   20..24 *) 
                            Overlay(S,S2,20,5);
                            IF (Dirty) THEN              (* Dirty  26..26 *)
                                SetString(S2,"D");
                                Overlay(S,S2,26,1);
                            END;
                        END;
                        Mode := videonormal;
    
    
                        IF (Interactive) AND (i = Cursor) THEN 
                            Mode := cvideonormal;
                            ShowARecord( Loc, Size, 0, StartY, StartX-1, EndY );
                        END;
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
                CancelKey : EXIT;
              | DoIt,
                83 (*"S"*),
                115 (*s"*)  :

                        IF (GetRecordN(Cursor,HashRecord)) THEN
                            ShowARecord( HashRecord.Loc, 
                                         HashRecord.Size,
                                         0, StartY, maxcol, MaxRow-1 );
                            REPEAT
                                GetNextEvent( Event );
                            UNTIL (Event.EventCode = CancelKey);
                        END;

              | HomeKey     : Cursor := 0;
              | Up          : IF (Cursor > 0) THEN DEC(Cursor); END;
              | Down        : IF (Cursor < HIGH(HashRecords)) THEN INC(Cursor); END;
              | 49..57      : IF (C-48 < HIGH(HashRecords)-1) THEN Cursor := C-48; END;
              ELSE Burp;
            END;

        END;

        IF (Interactive) AND (Rug <> ARug(NIL)) THEN PutRug(0,0,maxcol,MaxRow,Rug); END;

    END ShowMemory;



    PROCEDURE ShowStats();
    CONST
        LeftStartX = 0;
        RightStartX = 39;
    VAR
        Y  : ascreeny;
        S,S2  : ARRAY [0..50] OF CHAR;
        RecentHits, RecentMisses : LONGINT;
    BEGIN
        Fill(S," ",0);
        DrawBox(0,StartY,MaxColumn,EndY,ABoxType{NoBox},S,videonormal);
        SetString(S," ItemsInMemory:          ");
        CtoS(ItemsInMemory,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+1,videonormal);

        SetString(S," BytesInMemory:          ");
        LongToString(BytesInMemory,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+2,videonormal);

        SetString(S," LockedBytesInMemory:    ");
        LongToString(LockedBytesInMemory,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+3,videonormal);

        SetString(S," OutstandingLocks:       ");
        CtoS(OutstandingLocks,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+4,videonormal);

        SetString(S," MostOutstandingLocks:   ");
        CtoS(MostOutstandingLocks,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+6,videonormal);

        SetString(S," TotalLocksEver:         ");
        LongToString(TotalLocksEver,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+7,videonormal);

        SetString(S," Hits:                   ");
        LongToString(Hits,S2);  ConcatLS(S,S2);  ConcatS(S,"  ");
        LongToString( (Hits * 100L) DIV (Hits+Misses), S2);
        ConcatLS(S,S2); ConcatS(S,"%");
        PutString(S,LeftStartX,StartY+8,videonormal);

        SetString(S," Misses:                 ");
        LongToString(Misses,S2);  ConcatLS(S,S2);   ConcatS(S,"  ");
        LongToString( (Misses * 100L) DIV (Hits+Misses), S2);
        ConcatLS(S,S2); ConcatS(S,"%");

        PutString(S,LeftStartX,StartY+9,videonormal);

        SetString(S," MaxBytesInMemory:       ");
        LongToString(MaxBytesInMemory,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+11,videonormal);

        SetString(S," MaxLockedBytesInMemory: ");
        LongToString(MaxLockedBytesInMemory,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+12,videonormal);

        SetString(S," MemoryFlushNotices:     ");
        LongToString(MemoryFlushNotices,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+13,videonormal);

        SetString(S," Quantity:               ");
        CtoS(Quantity,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+15,videonormal);

        SetString(S," HashTableSize:          ");
        CtoS(HashTableSize,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+16,videonormal);

        SetString(S," MaxBytesToKeep:         ");
        LongToString(MaxBytesToKeep,S2);  ConcatLS(S,S2);
        PutString(S,LeftStartX,StartY+17,videonormal);

            (* How many hits since the last time we displayed stats. *)
        RecentHits := Hits - OldHits;
        RecentMisses := Misses - OldMisses;
        SetString(S," Recent Hits:            ");
        LongToString(RecentHits,S2);  ConcatLS(S,S2);  ConcatS(S,"  ");
        LongToString( (RecentHits * 100L) DIV (RecentHits+RecentMisses), S2);
        ConcatLS(S,S2); ConcatS(S,"%");
        PutString(S,RightStartX,StartY+1,videonormal);
        SetString(S," Recent Misses:          ");
        LongToString(RecentMisses,S2);  ConcatLS(S,S2);  ConcatS(S,"  ");
        LongToString( (RecentMisses * 100L) DIV (RecentHits+RecentMisses), S2);
        ConcatLS(S,S2); ConcatS(S,"%");
        PutString(S,RightStartX,StartY+2,videonormal);

        OldHits := Hits;
        OldMisses := Misses;


    END ShowStats;


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
            SetString(Choices,"Cells,Memory,Pages,Page Table,Record,Trace,Cell Table,Stats,Trace Options");

            IF (Interactive) THEN
                ConcatS(Choices,",Quit");
            END;
            IF (NOT QuickMenu(Prefix,Choices,Choice,FALSE)) OR
               (Choice = 10) THEN
        EXIT;
            END;
            IF (Choice <= 8) THEN
                DisplayType := VAL(ADisplayType,Choice-1);
                CASE DisplayType OF
                    DisplayCells : ScrollThroughCells();
                  | DisplayMemory : ShowMemory(Interactive);
                  | DisplayPages : ShowPages(Interactive);
                  | DisplayPageTable : ShowPageTableEntries(Interactive);
                  | DisplayRecord    : ShowRecord(StartX,StartY,EndX,EndY,1,0,Interactive);
                  | DisplayTrace     : ShowTrace(StartX,StartY,EndX,EndY);
                  | DisplayCellTable : ShowCellBlockTable();
                  | DisplayStats     : ShowStats();
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
                IF (GetRug(0,0,MaxColumn,MaxRow,Rug)) THEN
                    DoMenu(TRUE);
                    PutRug(0,0,MaxColumn,MaxRow,Rug);
                END;
            ELSE
                DoMenu(FALSE);
            END;
        ELSIF (WithMenu > 0) THEN
            CASE DisplayType OF
                DisplayCells : ShowCells(0);
              | DisplayMemory : ShowMemory(FALSE);
              | DisplayPages : ShowPages(FALSE);
              | DisplayPageTable : ShowPageTableEntries(FALSE);
              | DisplayRecord    : ShowRecord(StartX,StartY,EndX,EndY,1,0,FALSE);
              | DisplayTrace     : ShowTrace(StartX,StartY,EndX,EndY);
              | DisplayCellTable : ShowCellBlockTable();
              | DisplayStats     : ShowStats();
            END;
        END;

        TraceOn();

        RETURN Quantity;

    END DiagnosticHook;

BEGIN
    DisplayType := DisplayPages;
    OldHits     := 0L;
    OldMisses   := 0L;
END FlexDbug.

