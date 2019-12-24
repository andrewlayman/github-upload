MODULE TLChkSum;

(*  =========================================================================
    Last Edit : January 5, 1990 4:51PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        vast checking code for checksumming tl's code.

    MODIFICATION HISTORY:

    =========================================================================
*)

FROM AsciiIO    IMPORT
    (* PROC *)      ReadString, OpenInputFile;

FROM BTStorage  IMPORT
    (* TYPE *)      AStorageProc,
    (* PROC *)      ALLOCATE, DEALLOCATE;

FROM CRC16      IMPORT
    (* PROC *)      CheckSum;

FROM Dialog     IMPORT
    (* PROC *)      Barf;

FROM FileSystem IMPORT
    (* TYPE *)      File,
    (* PROC *)      Close;

FROM FlexStor   IMPORT
    (* TYPE *)      ALockObjectProc, AReleaseObjectProc, AnExtHandle,
    (* PROC *)      LockObject, ReleaseObject, ReleaseUnchangedObject;

FROM Keyboard   IMPORT
    (* TYPE *)      AYesNoProcedure, AGetCodeProcedure,
                    GetAnyCode, KeyPress;

FROM LStrings   IMPORT
    (* PROC *)      SetString, StoC, LStringToTString, Upshift;

FROM Notices    IMPORT
    (* TYPE *)      AnOccasion, AStep,
    (* PROC *)      RegisterForNotices;

FROM Overlays   IMPORT
    (* TYPE *)      AnOverlayID,
    (* PROC *)      ImALockedOverlay, InstallNewProcedure;

FROM OvTree     IMPORT
    (* TYPE *)      AnOverlayProc, AContextListEntry;

FROM Paranoia   IMPORT
    (* TYPE *)      AProgramState,
    (* VAR  *)      ProgramState;

FROM ParmLine   IMPORT
    (* PROC *)      GetOption;

FROM RTSMain    IMPORT
    (* TYPE *)      OverlayDescriptor, OverlayPtr,
    (* VAR  *)      overlayList;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADDRESS, SETREG, GETREG, SWI, AX, CX, DX, ADR;

FROM Video      IMPORT
    (* TYPE *)      AVideoOutputProc, AVideoPutAttributeProc,
                    AVideoCaptureProc,
    (* PROC *)      PutAttribute, PutStringWithAttribute, GetImageLine,
                    PutImageLine;

FROM Words      IMPORT
    (* PROC *)      ParseString;






TYPE
    ACheckSummRecord = RECORD
        OverlayName     : ARRAY [1..10] OF CHAR;
        LastSegmentStart,
        LastCheckSumm,
        CodeParas       : CARDINAL;
    END;


    ACheckSumThisType   = ( DoNotices, DoFlexStor, DoVideo, DoKbio,
                            DoAlloc, Do6, Do7, Do8, Do9
                          );

    ACheckSumThisSet    = SET OF ACheckSumThisType;




CONST
    MaxOverlays         = 220;

VAR
    OverlayID           : AnOverlayID;
    CheckSumThisSet     : ACheckSumThisSet;
    CheckSummRecord     : ARRAY [1..MaxOverlays] OF ACheckSummRecord;
    RecordCount         : CARDINAL;
    SkipStartup         : BOOLEAN;



PROCEDURE LoadDatabase() : BOOLEAN;
VAR
    i,
    Entry   : CARDINAL;
    f       : File;
    s1,
    Name,
    Desc    : ARRAY [0..19]  OF CHAR;
    s       : ARRAY [0..255] OF CHAR;
    ok      : BOOLEAN;
BEGIN
    RecordCount := 0;
    SetString( Name, "MAPTABLE.LST" );
    SetString( Desc, "No shit!");

    ok := OpenInputFile( Name, Desc, f );

    IF (ok) THEN
        WHILE (ReadString(Name,f,0C,s)) DO
            Upshift(s);
            i := 1;
            ParseString(s,i,s1);
            INC(RecordCount);
            IF (RecordCount > MaxOverlays) THEN
                HALT;
            END;
            WITH CheckSummRecord[RecordCount] DO
                LastCheckSumm    := 0;
                LastSegmentStart := 0;
                LStringToTString(s1,OverlayName);
                Entry := RecordCount;
                IF (NOT SearchList(OverlayName,Entry)) OR
                   (Entry <> RecordCount) THEN
                    HALT;   (* Not in sorted order, Wayne!! *)
                END;
                ParseString(s,i,s1);
                i         := 1;
                CodeParas := StoC(s1,i);
            END;
        END;
    END;

    Close(f);

    RETURN ok;

END LoadDatabase;


    (* SearchList -- Search a sorted table for a record with a key.
            Do a binary search.

         Preconditions:  Entries are in sorted order.
                         Context : Passed intact to "Compare".
                         Last    : High value of list.
         Postconditions: Last    : Entry item was found at, or
                                   Entry JUST LESS THAN value.
                         RETURN is TRUE if found, FALSE if Last > value.
    *)
PROCEDURE SearchList( VAR Context   : ARRAY OF CHAR;
                      VAR Last      : CARDINAL ): BOOLEAN;
TYPE
    AComparison          = (LessThan, Equal, GreaterThan);

VAR
    LowBound,
    Target   : CARDINAL;


    PROCEDURE Compare(     Where : CARDINAL;
                       VAR Entry : ARRAY OF CHAR ) : AComparison;
    VAR
        i   : CARDINAL;
        C1,
        C2  : CHAR;
    BEGIN
        WITH CheckSummRecord[Where] DO
            FOR i := 1 TO 8 DO
                C1 := CAP(Entry[i-1]);  (* arrays passed as 0..n-1! *)
                C2 := OverlayName[i];   (* part of a rec:   1..n    *)
                IF (C1 < C2) THEN
                    RETURN LessThan;
                ELSIF (C1 > C2) THEN
                    RETURN GreaterThan;
                ELSIF (C1 = 0C) THEN        (* Both the same, both 0C *)
                    RETURN Equal;
                END;
            END;
        END;

        RETURN Equal;

    END Compare;


BEGIN
    LowBound := 1;

    REPEAT
        Target := (LowBound + Last) DIV 2;

        CASE Compare( Target, Context ) OF
          LessThan    : Last     := Target - 1;
        | Equal       : Last     := Target;
                        RETURN TRUE;           (* Found! *)
        | GreaterThan : LowBound := Target + 1;
        ELSE
            HALT;
        END;
    UNTIL (LowBound > Last);

    RETURN FALSE;

END SearchList;





PROCEDURE GetOverlayEntry(     Overlay  : OverlayPtr;
                           VAR Entry    : CARDINAL   );
BEGIN
    Entry := RecordCount;

    IF (NOT SearchList(Overlay^.overlayName,Entry)) THEN
        HALT;   (* Not in list?  Shame on Wayne's REXX code! *)
    END;

END GetOverlayEntry;






PROCEDURE CheckSummEverything();
VAR
    Overlay         : OverlayPtr;
    Entry,
    NewCheckSum     : CARDINAL;


    PROCEDURE DoCheckSumm( CodeStart, CodeParaLength : CARDINAL ) : CARDINAL;
    CONST
        CheckSummEachTime   = 32768;
        CheckSummParas      = CheckSummEachTime DIV 16;
    VAR
        A       : ADDRESS;
        i,
        Count,
        Last,
        Result  : CARDINAL;
    BEGIN
        A.SEGMENT   := CodeStart;
        A.OFFSET    := 0;

        (* Do the check summ for perhaps several 32K chunks, then for
           the last chunk of less than or equal to 32K.
           The CodeParaLength is the number of bytes div 16.
           So, (N*16)/32768 == N/(32768/16) == N / 2048.
        *)
        Count := CodeParaLength  DIV CheckSummParas;
        Last  := (CodeParaLength MOD CheckSummParas) * 16;

        Result := 0;
        FOR i  := 1 TO Count DO
(*$R-*)
            INC(Result,CheckSum(A,CheckSummEachTime));
(*$R=*)
            INC(A.SEGMENT,CheckSummParas);
        END;

(*$R-*)
        INC(Result,CheckSum(A,Last));
(*$R=*)
        RETURN Result;

    END DoCheckSumm;

BEGIN
    IF (SkipStartup AND (ProgramState < TLMainRunning)) THEN
    ELSE
        Overlay := overlayList;     (* From RTSMain *)

        REPEAT
            GetOverlayEntry( Overlay, Entry );

            WITH CheckSummRecord[Entry] DO
                IF (Overlay^.codeSegment <> LastSegmentStart) THEN
                    LastSegmentStart := Overlay^.codeSegment; (* Position changed? *)
                    LastCheckSumm    := 0;
                END;

                NewCheckSum := DoCheckSumm( Overlay^.codeSegment, CodeParas );
                IF (LastCheckSumm = 0) THEN
                    LastCheckSumm := NewCheckSum;
                ELSIF (LastCheckSumm <> NewCheckSum) THEN
                    CheckSumThisSet := ACheckSumThisSet{};  (* Stop further checking *)
                    Barf();
                    Barf();
                    Barf();
                    Barf();
                    HALT;           (* We may be in an overlay. *)
                END;
            END;

            Overlay := Overlay^.next;

        UNTIL (Overlay = overlayList);
    END;

END CheckSummEverything;





PROCEDURE CatchNotices(     Occasion    : AnOccasion;
                            Step        : AStep;
                            Context     : ADDRESS   ) : BOOLEAN;
VAR
    Entry,
    i           : CARDINAL;
    SearchMe    : ARRAY [0..25] OF CHAR;
    StrPtr      : AContextListEntry;
BEGIN
    IF (Occasion = OverlayCall) AND
       (Context <> NIL)         THEN
        StrPtr := Context;
        LStringToTString(StrPtr^.OverlayName, SearchMe);
        Entry := RecordCount;
        IF (SearchList(SearchMe,Entry)) THEN
            CheckSummRecord[Entry].LastCheckSumm := 0;
        END;
    END;

    IF (DoNotices IN CheckSumThisSet) THEN
        CheckSummEverything();
    END;

    RETURN TRUE;

END CatchNotices;







VAR
    OldPutStringWithAttribute   : AVideoOutputProc;
    OldPutAttribute             : AVideoPutAttributeProc;
    OldGetImageLine             : AVideoCaptureProc;
    OldPutImageLine             : AVideoCaptureProc;
    OldGetCode                  : AGetCodeProcedure;
    OldKeyPress                 : AYesNoProcedure;
    OldLockObject               : ALockObjectProc;
    OldReleaseObject            : AReleaseObjectProc;
    OldReleaseUnchangedObject   : AReleaseObjectProc;
    OldALLOCATE                 : AStorageProc;
    OldDEALLOCATE               : AStorageProc;





PROCEDURE OurGetCode() : CARDINAL;
BEGIN
    IF (DoKbio IN CheckSumThisSet) THEN
        CheckSummEverything();
    END;

    RETURN OldGetCode();

END OurGetCode;




PROCEDURE OurKeyPress() : BOOLEAN;
BEGIN
    IF (DoKbio IN CheckSumThisSet) THEN
        CheckSummEverything();
    END;

    RETURN OldKeyPress();

END OurKeyPress;




PROCEDURE XPutStringWithAttribute ( VAR s : ARRAY OF CHAR;
                                        x : CARDINAL;
                                        y : CARDINAL;
                                        a : BITSET );
BEGIN
    OldPutStringWithAttribute( s, x, y, a );
    IF (DoVideo IN CheckSumThisSet) THEN
        CheckSummEverything();
    END;
END XPutStringWithAttribute;







PROCEDURE XPutAttribute ( x     : CARDINAL;
                          y     : CARDINAL;
                          Count : CARDINAL;
                          a     : BITSET );
BEGIN
    OldPutAttribute( x, y, Count, a );
    IF (DoVideo IN CheckSumThisSet) THEN
        CheckSummEverything();
    END;
END XPutAttribute;




PROCEDURE XGetImageLine( x      : CARDINAL;
                         y      : CARDINAL;
                         Count  : CARDINAL;
                         Line   : ADDRESS );
BEGIN
    OldGetImageLine( x, y, Count, Line );
    IF (DoVideo IN CheckSumThisSet) THEN
        CheckSummEverything();
    END;
END XGetImageLine;





PROCEDURE XPutImageLine( x      : CARDINAL;
                         y      : CARDINAL;
                         Count  : CARDINAL;
                         Line   : ADDRESS );
BEGIN
    OldPutImageLine( x, y, Count, Line );
    IF (DoVideo IN CheckSumThisSet) THEN
        CheckSummEverything();
    END;
END XPutImageLine;



PROCEDURE XLockObject(       Handle      : AnExtHandle;
                         VAR Data        : ADDRESS  ) : CARDINAL;
BEGIN
    IF (DoFlexStor IN CheckSumThisSet) THEN
        CheckSummEverything();
    END;

    RETURN OldLockObject(Handle,Data);

END XLockObject;




PROCEDURE XReleaseObject(    Handle : AnExtHandle );
BEGIN
    OldReleaseObject(Handle);
    IF (DoFlexStor IN CheckSumThisSet) THEN
        CheckSummEverything();
    END;
END XReleaseObject;




PROCEDURE XReleaseUnchangedObject(    Handle : AnExtHandle );
BEGIN
    OldReleaseUnchangedObject(Handle);
END XReleaseUnchangedObject;





PROCEDURE XALLOCATE( VAR A  : ADDRESS;  C : CARDINAL );
BEGIN
    IF (DoAlloc IN CheckSumThisSet) THEN
        CheckSummEverything();
    END;
    OldALLOCATE(A,C);
END XALLOCATE;




PROCEDURE XDEALLOCATE( VAR A  : ADDRESS;  C : CARDINAL );
BEGIN
    OldDEALLOCATE(A,C);
    IF (DoAlloc IN CheckSumThisSet) THEN
        CheckSummEverything();
    END;
END XDEALLOCATE;






PROCEDURE InitParanoiaLevel();
VAR
    C, i            : CARDINAL;
    ParanoiaLevel   : CARDINAL;
    Option,
    s               : ARRAY [0..255] OF CHAR;
    Found           : BOOLEAN;

BEGIN
    CheckSumThisSet := ACheckSumThisSet{DoNotices,DoFlexStor,DoVideo,DoKbio,DoAlloc};

    SetString( s, "CHKSUM" );
    GetOption( s, Found, Option );

    SkipStartup := TRUE;

    IF (Found) THEN
        IF (Option[1]="N") THEN
            SkipStartup := FALSE;
        ELSE
            i               := 1;
            ParanoiaLevel   := StoC( Option, i );
            CheckSumThisSet := ACheckSumThisSet(ParanoiaLevel);
        END;
    END;

END InitParanoiaLevel;





BEGIN
    IF (LoadDatabase()) THEN
        InitParanoiaLevel();
        RegisterForNotices( AllOccasions, CatchNotices );
        InstallNewProcedure(ADR(GetAnyCode), PROC(OurGetCode), ADR(OldGetCode));
        InstallNewProcedure(ADR(KeyPress),PROC(OurKeyPress), ADR(OldKeyPress));
        InstallNewProcedure(ADR(PutStringWithAttribute), PROC(XPutStringWithAttribute), ADR(OldPutStringWithAttribute));
        InstallNewProcedure(ADR(PutAttribute), PROC(XPutAttribute), ADR(OldPutAttribute));
        InstallNewProcedure(ADR(GetImageLine), PROC(XGetImageLine), ADR(OldGetImageLine));
        InstallNewProcedure(ADR(PutImageLine), PROC(XPutImageLine), ADR(OldPutImageLine));
        InstallNewProcedure(ADR(LockObject), PROC(XLockObject), ADR(OldLockObject));
        InstallNewProcedure(ADR(ReleaseObject), PROC(XReleaseObject), ADR(OldReleaseObject));
        InstallNewProcedure(ADR(ReleaseUnchangedObject), PROC(XReleaseUnchangedObject), ADR(OldReleaseUnchangedObject));
        InstallNewProcedure(ADR(ALLOCATE), PROC(XALLOCATE), ADR(OldALLOCATE));
        InstallNewProcedure(ADR(DEALLOCATE), PROC(XDEALLOCATE), ADR(OldDEALLOCATE));
        OverlayID := ImALockedOverlay( AnOverlayProc(NIL), AnOverlayProc(NIL) );
    END;

END TLChkSum.

