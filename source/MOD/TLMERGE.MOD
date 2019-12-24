MODULE TLMerge;

    (* TL MERGE - Merge two files with subfiles into a third, prefering
                  the second to the first.  The first application for this
                  is to merge forms files.

                  Approach:

                        Build a list containing the merged sub file numbers
                        of the two files.  In another pass, use this list
                        to re-read the source files and write them to the
                        dest file.

                        the NEW file is merged ON TOP of the OLD file into
                        the DEST file.

                        New FIle, Old File, and Dest File are all command
                        line parameters (NEW, OLD, and DEST), so ....

         TLMERGE new=dk:tlforms3.tlg old=tlforms3.old dest=tlforms3.dat

         DANGER!!   Gelded routines enclosed!!


         RSC 11/15/88 - Added DELETE and KEEP parameters.
     *)

(* ****** IMPORT DebugPMD; ******* *)

FROM RTSMain      IMPORT PSPAddress;

FROM Sounds       IMPORT Sound, NoSound;

FROM SYSTEM       IMPORT SIZE, ADDRESS, ADR, INBYTE, OUTBYTE, BYTE,
                         SETREG, ENABLE, DISABLE, GETREG, DI,
                         DOSCALL, SWI, CX, AX, BX, DX;




CONST
    MaxSubfiles =  100;  (* Maximum subfiles for new file! *)
    MaxLength   = 8192;  (* Buffer for copying. *)

    MAXCARDINAL = 65535;



TYPE
    ASourceFile  = (NoFile, TheOldFile, TheNewFile);

    ASubfileDescriptor = RECORD
        SubfileNum,
        Vers         : CARDINAL;
        WhichFile    : ASourceFile;
        SkipThis     : BOOLEAN;     (* Turned on by KEEP *)
    END;

    ASubfileList = ARRAY [1..MaxSubfiles] OF ASubfileDescriptor;

VAR
    RecordArea    : ARRAY [0..MaxLength-1] OF CHAR;



    (* Captain Dunsel

                (Ref. Star Trek, Episode "The Ultimate Computer", in which
                      Capt. James T. Kirk is replaced by M5, the Multitronic
                      Unit.  Admiral Wesley calls Kirk "Captain Dunsel",
                      Dunsel being a Star Fleet Academy term for "a useless
                      part; something which serves no usefull purpose".
                      Shortly after that, M5 starts the killings ....)

       This internal module replicates routines in other Time Line utility
       modules, like KBIO, DIALOG, and MESSAGE.  They are here to keep this
       program down to a reasonable size (not 140KB!).  In comments are the
       original module names these procedures mimic.
    *)

MODULE CaptainDunsel;


IMPORT
       MAXCARDINAL,

       PSPAddress,

       Sound, NoSound,

       SIZE, ADDRESS, ADR, INBYTE, OUTBYTE, BYTE,
       SETREG, ENABLE, DISABLE, GETREG, DI, DOSCALL, SWI, CX, AX, BX, DX;



EXPORT
       (* FROM Subfiles *) StartFileOutput, EndFileOutput, StartSubfileOutput,
                           EndSubfileOutput, StartFileInput, StartSubfileInput,
       (* FROM RecordIO *) WriteRecord, ReadRecordPreface, ReadRecordBody,
                           ReadRecord,
       (* FROM ParmLine *) GetOption,
       (* FROM LStrings *) CtoS, ConcatS, ConcatLS, SetString,
       (* FROM Dialog   *) Error,
       (* FROM Kbio     *) Print,
       (* DOSFunctions  *) OpenFile, SetPos, Close;




CONST
    CMaxFiles   = 3;  (* Maximum files for us to deal with. *)
 
VAR
    y             : CARDINAL;   (* Current screen y position *)
    Sex32Positive : BOOLEAN;

    FilesOpen     : CARDINAL;
    FileList      : ARRAY [1..CMaxFiles] OF RECORD
                        Name    : ARRAY [0..79] OF CHAR;
                        BDirty  : BOOLEAN;
                        EOF     : BOOLEAN;
                        Handle,
                        Record,
                        High,
                        Low     : CARDINAL;
                        Buffer  : ARRAY [0..1023] OF CHAR;
                    END;

CONST
    SOF                = 0F0H;
    SOSF               = 0F1H;
    EOF                = 0FEH;
    EOSF               = 0FFH;
    DIRR               = 0F2H;
    EmptySubfileNumber = 0FFFFH;
    RecordTag          =  55H;


TYPE
    ADirectoryEntry = RECORD
                          SubfileNumber   : CARDINAL;
                          Low,
                          High            : CARDINAL;
                          VersionNo       : CARDINAL;
                      END;
    ASubfileHeader  = RECORD
                          SubfileNumber   : CARDINAL;
                      END;
    AStartOfFileRecord = RECORD
                            SexWordLow,
                            SexWordHigh : CARDINAL;
                            Application : ARRAY [0..1] OF CHAR;
                            Version     : CARDINAL;
                        END;



    (*  StartFileOutput -- Write a header to the file and reserve
                           room for a subfile directory. *)

PROCEDURE StartFileOutput     (VAR F               : CARDINAL;
                                   SubfileCount    : CARDINAL );
VAR
    DirectoryEntry   : ADirectoryEntry;
    StartOfFileRecord : AStartOfFileRecord;
BEGIN
    StartOfFileRecord.SexWordLow  := 1234H;
    StartOfFileRecord.SexWordHigh := 5678H;
    StartOfFileRecord.Application := "TL";
    StartOfFileRecord.Version     := 0;
    WriteRecord(F,SOF,ADR(StartOfFileRecord),SIZE(StartOfFileRecord));    (* File header. *)

    DirectoryEntry.SubfileNumber := EmptySubfileNumber;

    WHILE (SubfileCount > 0) DO
        WriteRecord(F,DIRR,ADR(DirectoryEntry),SIZE(DirectoryEntry));
        DEC(SubfileCount);
    END;
END StartFileOutput;





    (*  EndFileOutput  -- Write an end of file marker. *)

PROCEDURE EndFileOutput       (VAR F               : CARDINAL );
VAR
    i : CARDINAL;
BEGIN
    WriteRecord(F,EOF,ADR(i),0);    (* File ender. *)
END EndFileOutput;


    (*  ReadRecord -- Reads a record into a buffer.  Also returns
                      the type code. *)

PROCEDURE ReadRecord (VAR F             : CARDINAL;
                      VAR Type          : CARDINAL;
                          RecordAddress : ADDRESS;
                          MaxLength     : CARDINAL);
VAR
    Length : CARDINAL;
BEGIN
    ReadRecordPreface(F,Type,Length);
    ReadRecordBody(F,Length,RecordAddress,MaxLength);
END ReadRecord;




PROCEDURE PositionToDirectory(VAR F       : CARDINAL;
                                  Number  : CARDINAL ):BOOLEAN;
VAR
    FileHeader   : CARDINAL;
    DirectoryEntry   : ADirectoryEntry;
    WasHigh, WasLow  : CARDINAL;
    Type             : CARDINAL;
BEGIN

    SetPos(F,0,0);
    ReadRecord(F,Type,ADR(FileHeader),0);
    LOOP
        GetPos(F,WasHigh, WasLow);
        ReadRecord(F,Type,ADR(DirectoryEntry),SIZE(DirectoryEntry));
        IF (Type <> DIRR) THEN RETURN FALSE; END;
        IF (DirectoryEntry.SubfileNumber = Number) THEN
            SetPos(F,WasHigh,WasLow);
            RETURN TRUE;
        END;
    END;
END PositionToDirectory;



    (*  StartSubfileOutput -- Fill in a directory entry for the
                              indicated subfile.  The position
                              recorded is the current file position.
                              Write a subfile header. *)

PROCEDURE StartSubfileOutput  (VAR F               : CARDINAL;
                                   SubfileNumber   : CARDINAL;
                                   Version         : CARDINAL);
VAR
    DirectoryEntry   : ADirectoryEntry;
    WasHigh, WasLow  : CARDINAL;
    SubfileHeader    : ASubfileHeader;
BEGIN
    GetPos(F,WasHigh,WasLow);
    IF (PositionToDirectory(F,EmptySubfileNumber)) THEN
        DirectoryEntry.SubfileNumber := SubfileNumber;
        WITH DirectoryEntry DO
            High := WasHigh;
            Low  := WasLow;
            VersionNo := Version;
        END;
        WriteRecord(F,DIRR,ADR(DirectoryEntry),SIZE(DirectoryEntry));
        SubfileHeader.SubfileNumber := SubfileNumber;
        SetPos(F,WasHigh,WasLow);
        WriteRecord(F,SOSF,ADR(SubfileHeader),SIZE(SubfileHeader));
    ELSE
        BadStructure(F);   (* Not enough directory entries were preallocated. *)
    END;
END StartSubfileOutput;









    (* EndSubfileOutput -- Write an end of subfile mark. *)

PROCEDURE EndSubfileOutput  (VAR F               : CARDINAL;
                                 SubfileNumber   : CARDINAL  );
BEGIN
    WriteRecord(F,EOSF,ADR(SubfileNumber),SIZE(SubfileNumber));
END EndSubfileOutput;







    (* StartFileInput -- Check the file for valid format *)

PROCEDURE StartFileInput      (VAR F               : CARDINAL     ):BOOLEAN;
VAR
    Type : CARDINAL;
    StartOfFileRecord : AStartOfFileRecord;
BEGIN
    IF (F > 0) THEN
        StartOfFileRecord.SexWordHigh := 0000H;  (* Assume the worst. *)

        ReadRecord(F,Type,ADR(StartOfFileRecord),SIZE(StartOfFileRecord));
        IF (Type <> SOF) THEN
            BadStructure(F);
        END;

        Sex32Positive := (StartOfFileRecord.SexWordHigh = 5678H);
    END;
    RETURN TRUE;
END StartFileInput;








    (* StartSubfileInput -- Position to the correct spot to begin
                            reading subfile data. *)

PROCEDURE StartSubfileInput   (VAR F               : CARDINAL;
                                   SubfileNumber   : CARDINAL;
                               VAR Version         : CARDINAL):BOOLEAN;
VAR
    DirectoryEntry   : ADirectoryEntry;
    SubfileHeader : ASubfileHeader;
    Type          : CARDINAL;
BEGIN

    IF (PositionToDirectory(F,SubfileNumber)) THEN
        ReadRecord(F,Type,ADR(DirectoryEntry),SIZE(DirectoryEntry));
        IF (Type <> DIRR) THEN
            BadStructure(F);
        END;
        Version := DirectoryEntry.VersionNo;
            (* Set the position.  Make allowances for different orders
               of high-vs low 16 bits. *)
        IF (Sex32Positive) THEN
            SetPos(F,DirectoryEntry.High, DirectoryEntry.Low);
        ELSE
            SetPos(F,DirectoryEntry.Low, DirectoryEntry.High);
        END;
        ReadRecord(F,Type,ADR(SubfileHeader),SIZE(SubfileHeader));
        IF (Type <> SOSF) OR (SubfileHeader.SubfileNumber <> SubfileNumber) THEN
            BadStructure(F);
        END;
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END StartSubfileInput;




 (* RECORD I O *)

PROCEDURE BadStructure(VAR F:CARDINAL);
VAR
    s : ARRAY [0..80] OF CHAR;
BEGIN
    SetString(s, "This is not a Time Line file:" );
    ConcatLS( s, FileList[ F ].Name );
    Error(s);
    HALT;
END BadStructure;



PROCEDURE WriteRecord(VAR F             : CARDINAL;
                          Type          : CARDINAL;
                          RecordAddress : ADDRESS;
                          Length        : CARDINAL);
VAR
    j : CARDINAL;
    P : POINTER TO ARRAY [1..20001] OF CHAR;
BEGIN
    WriteByte(F,CHR(RecordTag));
    WriteByte(F,CHR(Type));
    P := ADR(Length);
    WriteByte(F,P^[1]);  (* WAS Write Word! *)
    WriteByte(F,P^[2]);
    P := RecordAddress;
    FOR j := 1 TO Length DO
        WriteByte(F,P^[j]);
    END;
END WriteRecord;



    (*  ReadRecordPreface -- Reads the preface of the record, returning
                             the Type and Length of the following record
                             body. *)

PROCEDURE ReadRecordPreface( VAR F      : CARDINAL;
                             VAR Type   : CARDINAL;
                             VAR Length : CARDINAL    );
VAR
    C  : CHAR;
    P  : POINTER TO ARRAY [1..2] OF CHAR;
BEGIN
    ReadByte(F,C);                   (* Tag Field *)
    IF (FileEOF(F)) OR (ORD(C) <> RecordTag) THEN
        BadStructure(F);
    END;

    ReadByte(F,C);
    Type := ORD(C);

    P := ADR(Length);
    ReadByte(F,P^[1]);
    ReadByte(F,P^[2]);
  (* WAS:
    ReadWord(F,Length);               (*  Count field in file. *)
  *)

    IF (FileEOF(F)) THEN
        Type   := 0FFH;
        Length := 0;
    END;
END ReadRecordPreface;







    (*  ReadRecordBody -- After a call to ReadRecordPreface, reads
                          the record body. *)

PROCEDURE ReadRecordBody( VAR F             : CARDINAL;
                              Length        : CARDINAL;
                              RecordAddress : ADDRESS;
                              MaxLength     : CARDINAL);
VAR
    P : POINTER TO ARRAY [1..9999] OF CHAR;
    i : CARDINAL;
    C : CHAR;
    IgnoreN : CARDINAL;
BEGIN
    IgnoreN := 0;

    IF (Length > MaxLength) THEN
    	IgnoreN := Length - MaxLength;
        Length  := MaxLength;
    END;

    P := ADDRESS(RecordAddress);
    FOR i := 1 TO Length DO
        ReadByte( F, P^[i] );
        IF (FileEOF(F)) THEN
            BadStructure(F);
        END;
    END;
    FOR i := Length + 1 TO MaxLength DO
        P^[i] := 0C;
    END;

        (* In case there were more bytes in the file than we can
           find room for. *)

    WHILE (IgnoreN > 0) DO
        ReadByte(F,C);
        IF (FileEOF(F)) THEN
            RETURN;
        END;
        DEC(IgnoreN);
    END;
END ReadRecordBody;








 (* PARM LINE *)

PROCEDURE GetOption(     Option : ARRAY OF CHAR;
                     VAR Found  : BOOLEAN;
                     VAR Param  : ARRAY OF CHAR );
TYPE
    PSP = RECORD
              stuff: ARRAY [1..128] OF CHAR;
              text : ARRAY [0..127] OF CHAR
          END;
VAR 
    i, j   : CARDINAL;
    PSPPtr : POINTER TO PSP;
BEGIN 

    PSPPtr   := PSPAddress; 
    Found    := FALSE;

    (* Find the keyword *)

    i    := 1;
    WHILE (NOT Found) DO
        WHILE (i <= ORD(PSPPtr^.text[0])) AND  (* FIND START OF PARAM *)
              (PSPPtr^.text[i] = " ")     DO
            INC(i);
        END;
        IF (i > ORD(PSPPtr^.text[0])) THEN  (* Not found *)
            RETURN;
        ELSIF (CAP(PSPPtr^.text[i]) = Option[0]) THEN (* Found a start! *)
            j := i;
            WHILE (i <= ORD(PSPPtr^.text[0]))          AND
                  ((i-j) <= HIGH(Option))              AND
                  (CAP(PSPPtr^.text[i]) = Option[i-j]) DO
                INC(i);
            END;
            IF ((i-j) > HIGH(Option)) THEN
                Found := TRUE;
            END;
        ELSE
            WHILE (i <= ORD(PSPPtr^.text[0])) AND  (* SKIP OVER GAP *)
                  ((PSPPtr^.text[i] = " ")     OR
                   (PSPPtr^.text[i] = "="))    DO
                INC(i);
            END;
            WHILE (i <= ORD(PSPPtr^.text[0])) AND  (* SKIP OVER ARG *)
                  (PSPPtr^.text[i] <> " ")     DO
                INC(i);
            END;
        END;
    END;

    WHILE (i <= ORD(PSPPtr^.text[0])) AND  (* SKIP OVER GAP *)
          ((PSPPtr^.text[i] = " ")     OR
           (PSPPtr^.text[i] = "="))    DO
        INC(i);
    END;

    (* Now get the value.  As a TString. *)

    j := i;
    WHILE (i <= ORD(PSPPtr^.text[0])) AND
          (PSPPtr^.text[i] <> " ")     DO
        Param[i-j] := PSPPtr^.text[i];
        INC(i);
    END;

    Param[i-j] := 0C;  (* Make it a TString. *)

END GetOption;






  (* LSTRINGS *)


PROCEDURE SetString (VAR Target:ARRAY OF CHAR; Source:ARRAY OF CHAR);
VAR
    i : CARDINAL;
BEGIN
    IF (HIGH(Source) >= HIGH(Target)) THEN  HALT;  END;
    FOR i := 0 TO HIGH(Source) DO
        Target[i+1] := Source[i];
    END;
    Target[0] := CHR(HIGH(Source)+1);
END SetString;


PROCEDURE ConcatS  (VAR Target:ARRAY OF CHAR; Addend: ARRAY OF CHAR);
VAR
    ti,ai : CARDINAL;
BEGIN
    IF (HIGH(Addend)+ORD(Target[0]) >= HIGH(Target)) THEN HALT; END;

    ti := ORD(Target[0]);
    FOR ai := 0 TO HIGH(Addend) DO
        INC(ti);
        Target[ti] := Addend[ai];
    END;
    Target[0] := CHR(ti);
END ConcatS;


PROCEDURE ConcatLS (VAR Target:ARRAY OF CHAR; Addend: ARRAY OF CHAR);
VAR
    ti,ai : CARDINAL;
BEGIN
    IF (ORD(Addend[0])+ORD(Target[0]) > HIGH(Target)) THEN HALT; END;

    ti := ORD(Target[0]);
    FOR ai := 1 TO ORD(Addend[0]) DO
        INC(ti);
        Target[ti] := Addend[ai];
    END;
    Target[0] := CHR(ti);
END ConcatLS;


PROCEDURE CtoS     (Card:CARDINAL; VAR String:ARRAY OF CHAR);
VAR
    i,j : CARDINAL;
    digits : ARRAY [0..5] OF CHAR;    (* Assume max. is 65535 *)
BEGIN
    j := 0;
    REPEAT
        digits[j] := CHR(ORD("0")+(Card MOD 10));
        Card := Card DIV 10;
        INC(j);
    UNTIL (Card = 0);
    IF (j > HIGH(String)) THEN HALT; END;
    FOR i := 1 TO j DO
        String[i] := digits[j-i]
    END;
    String[0] := CHR(j);
END CtoS;


  (* DIALOG *)


PROCEDURE Error( VAR os : ARRAY OF CHAR );
CONST
    DirectConsoleInput  = 0700H;
    DOSCall             =   21H;
VAR
    i    : CARDINAL;
    s    : ARRAY [0..79] OF CHAR;
    Char : CHAR;
BEGIN
    Print( os, FALSE );
    SetString( s, "(Press [ESC])." );
    Print( s, FALSE );
    SETREG(AX, DirectConsoleInput); 
    SWI( DOSCall );
    GETREG(AX, Char );
    WHILE (ORD(Char) <> 27) DO   (* 27=ESC *)
        Sound( 440 );
        FOR i := 1 TO MAXCARDINAL DO END;
        NoSound;
        SETREG(AX, DirectConsoleInput); 
        SWI( DOSCall );
        GETREG(AX, Char );
    END;
END Error;





  (* KBIO *)

PROCEDURE Print ( VAR s : ARRAY OF CHAR; Normal : BOOLEAN );
CONST
    maxrow              = 24;
    maxcol              = 79;
    BIOSVideoInterrupt  = 10H;

    x  =  0;
VAR
    m, yx,
    i, len : CARDINAL;
    a      : BITSET;
BEGIN
    len := ORD(s[0]);
    IF (len = 0) THEN RETURN
    ELSIF (len > HIGH(s)) THEN HALT;
    END;

    yx := ((y*0100H) + x);     (*  (y,x) position. *)

    IF (Normal) THEN a := BITSET( 07H ); ELSE a := BITSET( 70H ); END;

    i := 1;
    WHILE (i <= len) DO

            (* Set cursor position. *)

        SETREG(DX,yx);           (* Row, Column *)
        SETREG(BX,0);            (* Page        *)
        SETREG(AX,0200H);        (* SetCursorPosition *)
        SWI(BIOSVideoInterrupt);    (* Call the ROM BIOS *)

            (* Write a character. *)

        m := 0900H  + ORD(s[i]);       (* Function 9 (write), char *)
        SETREG(CX,1); 
        SETREG(BX,a);               (* Page 0, attribute *) 
        SETREG(AX,m); 
        SWI(BIOSVideoInterrupt);

        INC(i);
        INC(yx);
    END;

    INC(y);  (* Next time, next row. *)

END Print;


(* ********************* START OF DOS FUNCTIONS  ******************** *)

 (*
    These functions replace functions in FileSystem in order to save space.
 *)


PROCEDURE DOSError( ErrorNumber : CARDINAL;
                VAR FileName    : ARRAY OF CHAR );
VAR
    s    : ARRAY [0..5] OF CHAR;
    s1   : ARRAY [0..80] OF CHAR;
BEGIN
    CtoS( ErrorNumber, s );
    SetString( s1, "File error " );
    ConcatLS( s1, s );
    IF (FileName[0] <> 0C) THEN
        ConcatS(  s1, " on file " );
        ConcatLS( s1, FileName );
    END;
    Error(s1);
    SetString( s1, "This unexpected error in TLMERGE will cause the INSTALL to fail!");
    Error(s);
    HALT;
END DOSError;


  (* Assumption:  if Create = FALSE, Read access only.
                  if Create = TRUE,  Read/Write access (and create file).
  *)
PROCEDURE OpenFile( VAR LName   : ARRAY OF CHAR;
                    VAR Channel : CARDINAL;
                        Create  : BOOLEAN   );
CONST
    OpenFunc   = 03DH;
    CreateFunc = 03CH;
VAR
    i,
    ErrorWord : CARDINAL;
    LHandle   : CARDINAL;
    Offset    : CARDINAL;
BEGIN
    IF Create THEN
        DOSCALL( CreateFunc, ADR(LName), 0, LHandle, ErrorWord );
    ELSE
        DOSCALL( OpenFunc,   ADR(LName), 0, LHandle, ErrorWord );
    END;

    INC( FilesOpen );
    WITH FileList[ FilesOpen ] DO
        i := 0;
        WHILE (i < HIGH(Name)) AND (LName[i] <> 0C) DO
            Name[i+1] := LName[i];
            INC(i);
        END;
        Name[0] := CHR(i);
        High    := 0;
        Low     := 0;
        Record  := MAXCARDINAL;
        Handle  := LHandle;
        BDirty  := FALSE;
        EOF     := FALSE;
    END;
    Channel := FilesOpen;
    IF (ErrorWord <> 0) THEN
        DOSError(ErrorWord, FileList[ Channel ].Name );
    END;
    Synchronize( Channel, Offset );
END OpenFile;


PROCEDURE Close( Channel : CARDINAL );
CONST
    CloseFunc   = 03EH;
VAR
    ErrorWord : CARDINAL;
BEGIN
    FlushBuffer( Channel );
    DOSCALL( CloseFunc, FileList[ Channel ].Handle, ErrorWord );
    IF (ErrorWord <> 0) THEN
        DOSError(ErrorWord, FileList[ Channel ].Name );
    END;
END Close;


PROCEDURE FlushBuffer( Channel : CARDINAL );
CONST
    WriteFunc  = 040H;
    SeekFunc   = 042H;

    OverflowPoint = (MAXCARDINAL DIV 1024) + 1;
VAR
    Written,
    ErrorWord   : CARDINAL;
    BHigh, BLow,
    OHigh, OLow : CARDINAL;
BEGIN
    WITH FileList[ Channel ] DO
        IF (BDirty) THEN
            BLow  := (Record MOD OverflowPoint) * 1024;
            BHigh := (Record DIV OverflowPoint);
            DOSCALL( SeekFunc, Handle, 0, BHigh, BLow, OHigh, OLow, ErrorWord );
            IF (ErrorWord <> 0) THEN
                DOSError(ErrorWord, Name );
            END;
            DOSCALL( WriteFunc, Handle, 1024, ADR(Buffer), Written, ErrorWord );
            IF (ErrorWord <> 0) THEN
                DOSError(ErrorWord, Name );
            END;
            BDirty := FALSE;
        END;
    END;
END FlushBuffer;


PROCEDURE SetPos( Channel, LHigh, LLow : CARDINAL );
BEGIN
    WITH FileList[ Channel ] DO
        High := LHigh;
        Low  := LLow;
    END;
END SetPos;


PROCEDURE GetPos( Channel     : CARDINAL;
              VAR LHigh, LLow : CARDINAL );
BEGIN
    WITH FileList[ Channel ] DO
        LHigh := High;
        LLow  := Low;
    END;
END GetPos;



PROCEDURE WriteByte( Channel : CARDINAL; C : CHAR );
VAR
    Offset : CARDINAL;
BEGIN
    Synchronize( Channel, Offset );
    WITH FileList[ Channel ] DO
        Buffer[Offset] := C;
        IF (Low < MAXCARDINAL) THEN
            INC(Low);
        ELSE
            Low := 0;
            INC(High);
        END;
        BDirty := TRUE;
    END;
END WriteByte;


PROCEDURE ReadByte( Channel : CARDINAL; VAR C : CHAR );
VAR
    Offset : CARDINAL;
BEGIN
    Synchronize( Channel, Offset );
    WITH FileList[ Channel ] DO
        C := Buffer[Offset];
        IF (Low < MAXCARDINAL) THEN
            INC(Low);
        ELSE
            Low := 0;
            INC(High);
        END;
    END;
END ReadByte;


  (* INTERNAL PROCEDURE *)

PROCEDURE Synchronize( Channel : CARDINAL; VAR Offset : CARDINAL );
VAR
    BHigh, BLow, OHigh, OLow,
    CountRead,
    Err,
    NRecord : CARDINAL;
CONST
    OverflowPoint = (MAXCARDINAL DIV 1024) + 1;
    ReadFunc      = 03FH;
    SeekFunc      = 042H;
BEGIN
    WITH FileList[ Channel ] DO
        NRecord := (High * OverflowPoint) + (Low DIV 1024);
        IF (NRecord <> Record) THEN
            FlushBuffer( Channel );
            Record := NRecord;
            BLow   := (Record MOD OverflowPoint) * 1024;
            BHigh  := (Record DIV OverflowPoint);
            DOSCALL( SeekFunc, Handle, 0, BHigh, BLow, OHigh, OLow, Err );
            IF (Err <> 0) THEN
                DOSError(Err, Name );
            END;
            DOSCALL( ReadFunc, Handle, 1024, ADR(Buffer), CountRead, Err );
            EOF := ((Err = 0) AND (CountRead = 0));
            IF (Err <> 0) THEN
                DOSError( Err, Name );
            END;
        END;
        Offset := Low MOD 1024;
    END;
END Synchronize;



PROCEDURE FileEOF( Channel : CARDINAL ) : BOOLEAN;
BEGIN
    RETURN FileList[ Channel ].EOF;
END FileEOF;



(* ********************* END OF DOS FUNCTIONS  ******************** *)

BEGIN
    y         := 4;  (* Initial cursor position *)
    FilesOpen := 0;
END CaptainDunsel;


(* *********************** END OF INTERNAL MODULES **************** *)



    (* Initialize Subfile List -

                Initialize the list of subfiles for the target file.
    *)
PROCEDURE InitializeSubfileList( VAR SubfileList : ASubfileList );
VAR
    i : CARDINAL;
BEGIN
    FOR i := 1 TO MaxSubfiles DO
        SubfileList[ i ].WhichFile := NoFile;
        SubfileList[ i ].SkipThis  := FALSE;
    END;
END InitializeSubfileList;





 (* Lookup Keyword

                Find the passed keywords argument.
                Open the file, creating it if requested.
  *)
PROCEDURE LookupKeyword( Keyword : ARRAY OF CHAR;
                     VAR Channel : CARDINAL;
                         Create  : BOOLEAN   );
VAR
    i, j     : CARDINAL;
    Name,
    Param    : ARRAY [0..255] OF CHAR;
    Found    : BOOLEAN;
BEGIN
    Param[0] := 0C;
    GetOption( "PATH",  Found, Param );
    GetOption( Keyword, Found, Name  );
    IF (NOT Found) THEN
        SetString( Param, "Bad syntax.  Format is:" );
        Print( Param, FALSE );
        SetString( Param, "TLMERGE OLD=<file> DEST=<file> [PATH=<path>] [NEW=<file>]" );
        Print( Param, FALSE );
        SetString( Param, "                    [KEEP=<subfspec>] [DELETE=<subfspec>]" );
        Print( Param, FALSE );
        SetString( Param, "<subfspec> is like '3,5..9,12..22,50'" );
        Error(     Param );
        HALT;
    END;
    i := 0; j := 0;
    WHILE (Param[i] <> 0C) DO INC(i); END;
    WHILE (Name[j]  <> 0C) DO Param[i] := Name[j]; INC(i); INC(j); END;
    Param[i] := 0C;
    OpenFile( Param, Channel, Create );

END LookupKeyword;



 (* Kluge Subfile Directory Reading

        DANGER!!  WARNING!!  WILL!!  PENNY!!  DR.SMITH!!

        This procedure reads one entry from the file's subfile directory.
        This facility is not offered by Subfiles, and so it is implemented
        here.  As this uses data structures known to Subfiles, it is a
        kluge.  This is done to avoid reading the entire file just to see
        what subfiles are in it.
 *)
PROCEDURE KlugeSubfileDirectoryReading(     Keyword : ARRAY OF CHAR;
                                        VAR f       : CARDINAL;
                                        VAR Subfile,
                                            Version : CARDINAL ) : BOOLEAN;
TYPE
    ADirectoryEntry = RECORD
                          SubfileNumber   : CARDINAL;
                          Low,
                          High            : CARDINAL;
                          VersionNo       : CARDINAL;
                      END;
CONST
    DIRR        = 0F2H;  (* SECRET Directory RECORD NUMBER! *)
VAR
    DirectoryEntry : ADirectoryEntry;
    Type           : CARDINAL;
BEGIN
    ReadRecord( f, Type, ADR(DirectoryEntry), SIZE(DirectoryEntry) );
    IF (Type <> DIRR) THEN RETURN FALSE; END;
    Subfile := DirectoryEntry.SubfileNumber;
    Version := DirectoryEntry.VersionNo;
    RETURN (Subfile < MAXCARDINAL);  (* MAXCARD is EOD.  This is not ALWAYS *)
                                     (* true, but is for all our files      *)
END KlugeSubfileDirectoryReading;





PROCEDURE AddToSubfileList( WhichSource      : ASourceFile;
                            Subfile, Version : CARDINAL;
                        VAR SubfileList      : ASubfileList );
VAR
    i   : CARDINAL;
BEGIN
    FOR i := 1 TO MaxSubfiles DO
        WITH SubfileList[i] DO
            IF (WhichFile = NoFile) THEN
                WhichFile  := WhichSource;
                SubfileNum := Subfile;
                Vers       := Version;
                RETURN;                 (* NOT FOUND EXIT POINT *)
            ELSIF (SubfileNum = Subfile) THEN
                WhichFile  := WhichSource;
                Vers       := Version;
                RETURN;                 (* UPDATED EXIT POINT *)
            END;
        END;
    END;
    HALT;  (* TOO MANY SUBFILES IN THE SOURCES! *)
END AddToSubfileList;








PROCEDURE BuildSource(     Keyword     : ARRAY OF CHAR;
                           WhichSource : ASourceFile;
                       VAR f           : CARDINAL;
                       VAR SubfileList : ASubfileList );
VAR
    Subfile, Version : CARDINAL;
BEGIN
    LookupKeyword( Keyword, f, FALSE );
    IF StartFileInput( f ) THEN
        WHILE (KlugeSubfileDirectoryReading( Keyword, f,
                                             Subfile, Version )) DO
            AddToSubfileList( WhichSource, Subfile, Version, SubfileList );
        END;
    ELSE
        HALT;  (* In case the FILE wasn't bad, but structure is. *)
    END;
END BuildSource;




 (* From LStrings, adapted to work with TStrings. *)

PROCEDURE StoC( VAR Source:ARRAY OF CHAR; VAR Index: CARDINAL ) : CARDINAL;
VAR
    Card, n : CARDINAL;
BEGIN
    Card := 0;
    WHILE (Source[Index] <> 0C) AND
          (Source[Index] = " ") DO        INC(Index);
    END;
    WHILE (Source[Index] <> 0C) AND
          (Source[Index] >= "0")    AND
          (Source[Index] <= "9")         DO
        n := ORD(Source[Index]) - ORD("0");
        IF (Card > 6553) OR ((Card = 6553) AND (n > 5)) THEN
            RETURN 65535;
        END;
        Card := (Card * 10) + n;
        INC(Index)
    END;
    RETURN Card;
END StoC;





    (* Delete the subfiles whose numbers are found in SubfileList. *)

PROCEDURE DeleteSubfiles( VAR SubfileNumbers : ARRAY OF CHAR;
                          VAR SubfileList    : ASubfileList );
VAR
    StartingSubfile,
    EndingSubfile,
    Where,
    Subfile          : CARDINAL;


    PROCEDURE RemoveFromSubfileList( Subfile          : CARDINAL;
                                 VAR SubfileList      : ASubfileList );
    VAR
        i   : CARDINAL;
    BEGIN
        FOR i := 1 TO MaxSubfiles DO
            WITH SubfileList[i] DO
                IF (SubfileNum = Subfile) THEN
                    WhichFile  := NoFile;
                    SubfileNum := 0;
                    Vers       := 0;
                    RETURN;                 (* DELETED.  EXIT. *)
                END;
            END;
        END;
    END RemoveFromSubfileList;


BEGIN
    Where := 0;

    LOOP
        CASE SubfileNumbers[Where] OF
           "0".."9" :
            StartingSubfile := StoC( SubfileNumbers, Where );
            EndingSubfile   := StartingSubfile;
            IF (SubfileNumbers[Where]   = ".") AND
               (SubfileNumbers[Where+1] = ".") THEN
                INC(Where,2);
                EndingSubfile := StoC( SubfileNumbers, Where );
            END;
            FOR Subfile := StartingSubfile TO EndingSubfile DO
                RemoveFromSubfileList( Subfile, SubfileList );
            END;

        |  " ", "," :
            INC( Where );
        |  0C :
            EXIT;
        ELSE
            INC( Where );  (* Junk? *)
        END;
    END;

END DeleteSubfiles;






    (* Keep the subfiles whose numbers are found in SubfileList. *)

PROCEDURE KeepSubfiles( VAR SubfileNumbers : ARRAY OF CHAR;
                        VAR SubfileList    : ASubfileList );
VAR
    StartingSubfile,
    EndingSubfile,
    Where, i,
    Subfile          : CARDINAL;
BEGIN

    FOR i := 1 TO MaxSubfiles DO
        SubfileList[i].SkipThis := TRUE;  (* Logicly delete it *)
    END;

    Where := 0;
    LOOP
        CASE SubfileNumbers[Where] OF
           "0".."9" :
            StartingSubfile := StoC( SubfileNumbers, Where );
            EndingSubfile   := StartingSubfile;
            IF (SubfileNumbers[Where]   = ".") AND
               (SubfileNumbers[Where+1] = ".") THEN
                INC(Where,2);
                EndingSubfile := StoC( SubfileNumbers, Where );
            END;
            FOR Subfile := StartingSubfile TO EndingSubfile DO
                FOR i := 1 TO MaxSubfiles DO
                    IF (SubfileList[i].SubfileNum = Subfile) THEN
                        SubfileList[i].SkipThis := FALSE;  (* Logicly put it back *)
                    END;
                END;
            END;

        |  " ", "," :
            INC( Where );
        |  0C :
            EXIT;
        ELSE
            INC( Where );  (* Junk? *)
        END;
    END;

END KeepSubfiles;







 (* Build Dest -

        Read throught the subfile list we built and use that to read from
        either of the two source files and write to the dest file.
 *)
PROCEDURE BuildDest(     Keyword     : ARRAY OF CHAR;
                     VAR OldFile,
                         NewFile,
                         DestFile    : CARDINAL;
                     VAR SubfileList : ASubfileList );
VAR
    i             : CARDINAL;
    RecordAddress : ADDRESS;

    PROCEDURE SaveASubfile( VAR f     : CARDINAL;
                                Index : CARDINAL ) : BOOLEAN;
    VAR
        Length,
        Type,
        SubfileNumber,
        Version         : CARDINAL;
    BEGIN
        SubfileNumber := SubfileList[Index].SubfileNum;
        Version       := SubfileList[Index].Vers;
        IF (StartSubfileInput( f, SubfileNumber, Version )) THEN
            StartSubfileOutput( DestFile, SubfileNumber, Version );
            ReadRecordPreface( f, Type, Length );
            WHILE (Type <> 0FFH) DO
                IF (Length > MaxLength) THEN HALT; END;
                ReadRecordBody( f, Length, RecordAddress, MaxLength );
                WriteRecord( DestFile, Type, RecordAddress, Length );
                ReadRecordPreface( f, Type, Length );
            END;
            EndSubfileOutput(   DestFile, SubfileNumber );
            RETURN TRUE;
        END;
        RETURN FALSE;
    END SaveASubfile;

BEGIN
    LookupKeyword( Keyword, DestFile, TRUE );
    StartFileOutput( DestFile, MaxSubfiles );

    SetPos(OldFile,0,0);
    IF (NewFile > 0) THEN
        SetPos(NewFile,0,0);
    END;
    IF (NOT (StartFileInput( OldFile )   AND
             StartFileInput( NewFile ))) THEN
        HALT;
    END;

    RecordAddress := ADR( RecordArea ); (* Workspace for xfers *)

    FOR i := 1 TO MaxSubfiles DO
        IF (NOT SubfileList[i].SkipThis) THEN
            CASE SubfileList[i].WhichFile OF
              TheOldFile : IF (NOT SaveASubfile( OldFile, i )) THEN
                               RETURN;
                           END;
            | TheNewFile : IF (NOT SaveASubfile( NewFile, i )) THEN
                               RETURN;
                           END;
            ELSE  (* NoFile *)
            END;
        END;
    END;

    EndFileOutput( DestFile );

END BuildDest;






 (* Merge -
                Merge two files into a third.

                Read each file once to build the merge list.
                Use the merge list to re-read the source files and
                        build the dest file.
 *)

PROCEDURE Merge();
VAR
    OldFile,
    NewFile,
    DestFile     : CARDINAL;
    SubfileList  : ASubfileList;
    DeleteOption : BOOLEAN;
    KeepOption   : BOOLEAN;
    KeepParam,
    Param        : ARRAY [0..99] OF CHAR;
BEGIN

    InitializeSubfileList( SubfileList );
    
    BuildSource( "OLD", TheOldFile, OldFile, SubfileList );

    GetOption( "DELETE", DeleteOption, Param );
    GetOption( "KEEP",   KeepOption,   KeepParam );

    IF (NOT DeleteOption) AND (NOT KeepOption) THEN
        BuildSource( "NEW", TheNewFile, NewFile, SubfileList );
    ELSE
        NewFile := 0;
    END;

    (* If both KEEP and DELETE are specified, first KEEP, then DELETE.
       this means that you KEEP a certain range, then DELETE things within
       that range.  More useable than DELETE, then KEEP.
    *)
    IF (KeepOption) THEN
        KeepSubfiles( KeepParam, SubfileList );
    END;
    IF (DeleteOption) THEN
        DeleteSubfiles( Param, SubfileList );
    END;

    BuildDest( "DEST", OldFile, NewFile, DestFile, SubfileList );

    Close( OldFile  );
    IF (NewFile <> 0) THEN
        Close( NewFile  );
    END;
    Close( DestFile );

END Merge;





CONST
    DiskReset = 0DH;    (* MS-DOS Disk Reset function number. *)

BEGIN
    Merge;
    DOSCALL(DiskReset);   (* Force DOS flush buffers. *)
END TLMerge.
