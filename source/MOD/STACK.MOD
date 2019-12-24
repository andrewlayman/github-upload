IMPLEMENTATION MODULE Stack;

(*  =========================================================================
    Last Edit : June 26, 1991 6:26PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 

        Report on the contents of the stack.


    MODIFICATION HISTORY:

        23-Aug-89 RSC  First version for DEBUGGING ONLY!!
                       Based heavily on the LOGITEK module called
                       "DebugTrace".
        17-Apr-91 RSC  Use Trace to write output.
        26-Apr-91 RSC  Added Trace param.
        26-Jun-91 RSC  Added hex dump of stack contents.

    =========================================================================
*)


IMPORT SYSTEM, ASCII, Strings, RTSMain;


FROM LStrings   IMPORT
    (* PROC *)      Copy, LStringToTString, TStringToLString, Procustes,
                    ConcatS, SubStr, Insert, StringsEqual, SetString,
                    ConcatLS, CtoS, RJust, SetLengthOf, LengthOf, Fill,
                    TrimRear;


FROM OvTree IMPORT
    (* TYPE *)  AResidence, AContextListEntry,
    (* PROC *)  FindNodeFromOvlName;


FROM RTSMain IMPORT OverlayPtr, ProcedureKind, Process, ProcessDescriptor,
                    overlayList, activProcess, Status;

FROM SYSTEM  IMPORT ADR, ADDRESS, PROCESS, NEWPROCESS, TRANSFER, SS,BP, GETREG;

FROM TreeObjects IMPORT ATreeNode;





TYPE Help=  RECORD CASE CARDINAL OF
                     0: address: ADDRESS;
                   | 1: addrPtr: POINTER TO ADDRESS;
                   | 2: cardPtr: POINTER TO CARDINAL;
                   END;
             END;

VAR
    basePointer : ADDRESS;
    OutputStr   : ARRAY [0..255] OF CHAR;



(**********************************************************************)

MODULE File;

IMPORT LStringToTString;

FROM SYSTEM  IMPORT DOSCALL, ADR;
FROM ASCII   IMPORT cr, EOL;

EXPORT  Open, Close, GetPos, SetPos, GetChar;

CONST
  CtrlZ         = 32C;

  close         = 3EH;
  open          = 3DH;
  read          = 3FH;
  setpos        = 42H;

  maxBuf        = 512;

TYPE File     = RECORD  
                  handle: CARDINAL;
                  highPos, lowPos: CARDINAL;
                  buffer :  ARRAY [1..maxBuf] OF CHAR;
                  curInd, lastInd: CARDINAL;
                  eof: BOOLEAN;
               END;

VAR
    file        : File;
    FileOpen    : BOOLEAN;


  PROCEDURE AddCard(VAR highRes, lowRes: CARDINAL; 
                        highPos,lowPos, offset: CARDINAL);
  BEGIN
    highRes := highPos;
    IF lowPos <= 0FFFFH - offset THEN
      lowRes := lowPos + offset;
    ELSE
      lowRes := offset - (0FFFFH - lowPos + 1);
      INC(highRes);
    END;
  END AddCard;

  PROCEDURE SetBufPos (high,low: CARDINAL);
  BEGIN
    WITH file DO
      highPos := high;
      lowPos  := low;
      curInd  := 0;
      lastInd := 0;
      eof := FALSE;
    END;
  END SetBufPos;

PROCEDURE GetPos( VAR high, low: CARDINAL);
  (* Get current position of the file *)
BEGIN (* GetPos *)
   AddCard(high,low, file.highPos, file.lowPos, file.curInd);
END GetPos;

PROCEDURE SetPos( high, low : CARDINAL);
VAR  error : CARDINAL;
BEGIN
   DOSCALL(setpos,file.handle,0,high,low,high,low,error);
   SetBufPos(high,low);
END SetPos;

PROCEDURE GetChar(VAR ch: CHAR; VAR isEof: BOOLEAN);
   PROCEDURE NextChar;
   VAR  dummy : CARDINAL;
   BEGIN
     WITH file DO           
       IF NOT eof THEN  INC(curInd);  END;
       IF NOT eof AND (curInd>lastInd) THEN
          AddCard(highPos,lowPos,highPos,lowPos,lastInd);
          DOSCALL(read,handle,maxBuf,ADR(buffer),lastInd,dummy);
          eof := lastInd=0;
          curInd := 1;
       END;
       IF NOT eof THEN  ch := buffer[curInd];  END;
       eof   := eof OR (ch=CtrlZ);
       isEof := eof;
     END;
   END NextChar;
BEGIN
  NextChar;
  IF NOT isEof AND (ch=cr) THEN  NextChar;  ch := EOL  END;
END GetChar;





PROCEDURE Close;
VAR
  error : CARDINAL;
BEGIN
    IF (FileOpen) THEN
        DOSCALL(close,file.handle,error);
    END;
END Close;


PROCEDURE Open (    name        : ARRAY OF CHAR;
                VAR done        : BOOLEAN);
VAR
    error   : CARDINAL;
BEGIN
    Close();  (* Close any existing open file. *)

    LStringToTString( name, name );
    DOSCALL(open,ADR(name),2,file.handle,error);
    done := (error = 0);
    SetBufPos(0,0);
    FileOpen := done;
END Open;

BEGIN
    FileOpen := FALSE;
END File;


(**********************************************************************)




MODULE MapFile;

IMPORT Open, Close, SetPos, GetPos, GetChar, overlayList,
       Copy, TStringToLString, ConcatS, SubStr, Insert, StringsEqual,
       AResidence, AContextListEntry, FindNodeFromOvlName,
       ATreeNode;

FROM SYSTEM  IMPORT  ADDRESS;
FROM ASCII   IMPORT  EOL;
FROM Strings IMPORT  Concat, Assign, Pos, Delete, Length, CompareStr;
FROM RTSMain IMPORT  ProcedureKind, OverlayPtr;

EXPORT InitOverlayList, SearchMapInfo;


TYPE
  MapLineRecord = RECORD
                    address : ADDRESS;
                    text    : ARRAY [0..80] OF CHAR;
                  END;
 
  MapKind = (BeginData, 
             EndData,
             BeginCodeModule,  
             EndCodeModule,
             ProcRemoved,
             ProcCallLong,
             ProcCallShort,     
             ProcCallNested,   
             LocalModule,
             InitModule,  
             Unknow);

VAR
    ValuePos,
    LinePos  : ADDRESS;
    MapPath  : ARRAY [0..99] OF CHAR;
    openName : ARRAY [0..99] OF CHAR;



PROCEDURE InitOverlayList( VAR TheMapPath : ARRAY OF CHAR );
BEGIN
    Copy( TheMapPath, MapPath );
END InitOverlayList;





PROCEDURE SearchOverlay(instrCounter: ADDRESS; 
                       VAR overlay: OverlayPtr; VAR succ: BOOLEAN);
VAR
    PC, Base, Limit : REAL;
    Node            : ATreeNode;
    Context         : AContextListEntry;
    name            : ARRAY [0..51] OF CHAR;

    PROCEDURE AtoR( A : ADDRESS ) : REAL;
    BEGIN
        RETURN ((FLOAT(A.SEGMENT) * 16.0) + FLOAT(A.OFFSET));
    END AtoR;

BEGIN
    overlay := overlayList;
    PC      := AtoR( instrCounter );
    LOOP
        WITH overlay^ DO
            Base  := AtoR( memoryAddr );
            Limit := Base + (FLOAT(memorySize) * 16.0);
        END;
        IF (PC >= Base) AND (PC <= Limit) THEN
            TStringToLString( overlay^.overlayName, name );
            Node := FindNodeFromOvlName( name );
            IF (Node <> ATreeNode(NIL)) THEN
                Context := Node^.Methods^.GetDataObject (Node);
                IF (Context^.Residence = InMainMemory) THEN
                    succ := TRUE;
                    EXIT;
                END;
            END;
        END;
        overlay := overlay^.prev;
        IF overlay=overlayList THEN  succ:= FALSE; EXIT  END;
    END;
END SearchOverlay;


PROCEDURE ReadMapLine (VAR eof  : BOOLEAN;
                       VAR line : ARRAY OF CHAR);
VAR
  i  : CARDINAL;
  ch : CHAR;
BEGIN
  i:=0;
  LOOP
    GetChar (ch,eof);   (* Read all the line ! *)
    IF eof OR (ch = EOL) THEN 
      IF i <= HIGH (line) THEN line [i] := 0C END;  (* teminator if possible *)
      EXIT;
    END;
    IF i <= HIGH (line) THEN  (* Get only n chars *)
      line [i] := ch;
      INC (i);
    END;
  END;
END ReadMapLine;


PROCEDURE FoundMapBlocks ( VAR valuePos, linePos: ADDRESS);
VAR
    line       : ARRAY [0..80] OF CHAR;
    eofMapFile : BOOLEAN;
    lastPos    : ADDRESS;
BEGIN
  LOOP
    ReadMapLine (eofMapFile, line);
    IF eofMapFile THEN  RETURN  END;
    IF Pos('  Address         Publics by Value',line)<HIGH(line) THEN
      GetPos(valuePos.SEGMENT,valuePos.OFFSET);
      EXIT;
    END;
  END;
  linePos := NIL;
  LOOP
    GetPos(lastPos.SEGMENT,lastPos.OFFSET);
    ReadMapLine (eofMapFile, line);
    IF eofMapFile THEN  RETURN  END;
    IF Pos('Line numbers for',line)<HIGH(line) THEN
      linePos := lastPos;
      EXIT;
    END;
  END;
END FoundMapBlocks;






PROCEDURE OpenMap(overlay: OverlayPtr; VAR succ: BOOLEAN);
VAR
    TempOpenName,
    OverlayName : ARRAY [0..99] OF CHAR;
BEGIN
    WITH overlay^ DO
        TStringToLString( overlayName, OverlayName );
        IF (NOT StringsEqual(openName, OverlayName )) THEN
            Copy( OverlayName, TempOpenName );
            openName := 0C; (* Signal that it is closed. *)
            ConcatS( OverlayName, ".MAP" );
            Open(OverlayName,succ);
            IF (NOT succ) THEN
                Insert( OverlayName, MapPath, 1 );
                Open(OverlayName,succ);
                IF (NOT succ) THEN
                    RETURN;
                END;
            END;
            Copy( TempOpenName, openName );

            FoundMapBlocks (ValuePos,LinePos);
            IF ValuePos=NIL THEN  Close;  succ:= FALSE; RETURN  END;

        END;
        SetPos(ValuePos.SEGMENT,ValuePos.OFFSET);
        succ := TRUE
    END;
END OpenMap;







  PROCEDURE NumDigit (c : CHAR) : BOOLEAN;
  BEGIN
    RETURN (c >= "0") AND (c <= "9") 
  END NumDigit;

  PROCEDURE AlphabDigit (c : CHAR) : BOOLEAN;
  BEGIN
    RETURN ((c >= "A") AND (c <= "F")) 
  END AlphabDigit;

  PROCEDURE ReadCard (VAR line: ARRAY OF CHAR; VAR c:CARDINAL;
                      VAR done: BOOLEAN);
  VAR i:CARDINAL;
  BEGIN
    done := FALSE;
    i    := 0;
    WHILE (line[i]=' ') DO  INC(i);  END; 
    IF line[i]=0C THEN  RETURN  END;
    c := 0;
    LOOP
      IF NumDigit (line [i]) THEN
        c := c * 10 + ORD (line [i]) - ORD ("0");
      ELSE  EXIT
      END;
      INC (i);
    END;
    IF i=0 THEN  RETURN  END;
    Delete(line,0,i);
    done := TRUE;
  END ReadCard;

  PROCEDURE ReadAddress (VAR line: ARRAY OF CHAR; VAR addr : ADDRESS;
                         VAR done: BOOLEAN);
    PROCEDURE ReadHex(VAR val: CARDINAL);
    BEGIN
      val := 0;
      LOOP
        IF NumDigit (line [i]) THEN
          val := val * 16 + ORD (line [i]) - ORD ("0");
        ELSIF AlphabDigit(line[i]) THEN
          val := val * 16 + 10 + ORD (line [i]) - ORD ("A");
        ELSE  EXIT
        END;
        INC (i);
      END;
    END ReadHex;
  VAR i:CARDINAL;
  BEGIN
    done := FALSE;
    i    := 0;
    WHILE (line[i]=' ') DO  INC(i);  END; 
    IF line[i]=0C THEN  RETURN  END;
    ReadHex(addr.SEGMENT);
    IF line[i]<>':' THEN  RETURN  END;
    INC (i);
    ReadHex (addr.OFFSET);
    Delete(line,0,i);
    done := TRUE;
  END ReadAddress;


PROCEDURE GetRecordMapLine ( VAR rec     : MapLineRecord; 
                             VAR eof, ok : BOOLEAN );
  (* Get record line of map file : 
     Format  =>  Address   Text 
     Address = SSSS:OOOO
  *)
VAR
  line : ARRAY [0..80] OF CHAR;
BEGIN (*GetRecordMapLine*)
  LOOP    (* Skip blank line *)
    ReadMapLine (eof, line);
    IF eof THEN RETURN END;
    IF Length (line) > 9 THEN EXIT END;
  END;
  WITH rec DO
    ReadAddress (line, address,ok);
    Delete(line,0,7);
    Assign(line,text);
  END;   
END GetRecordMapLine;

PROCEDURE SearchNames(    instrCounter: ADDRESS; 
                      VAR moduleName, procName: ARRAY OF CHAR;
                      VAR procKind : ProcedureKind;
                      VAR succ     : BOOLEAN);
VAR
    EndPos  : CARDINAL;

  PROCEDURE whichInfo (text : ARRAY OF CHAR) : MapKind;
  VAR
    kind : MapKind;
  BEGIN
    CASE text [0] OF
      "$" : CASE text [1] OF
              "B" : CASE text [2] OF
                      "D" : kind := BeginData;
                    | "M" : kind := BeginCodeModule;
                    | "O" : RETURN( LocalModule );
                    ELSE    kind := Unknow;
                    END;
            | "E" : CASE text [2] OF
                      "D" : kind := EndData;
                    | "M" : kind := EndCodeModule;
                    ELSE    kind := Unknow;
                    END;
            | "I" : RETURN InitModule;
            ELSE kind := Unknow;
            END;
            IF text [3] <> "_" THEN kind := Unknow END;
            RETURN (kind);
    | "R" : kind := ProcRemoved;
    | "L" : kind := ProcCallLong;
    | "S" : kind := ProcCallShort;
    | "N" : kind := ProcCallNested;
    ELSE kind := Unknow;
    END;
    IF (text [1] <> "_" )AND(text [2] <> "_" ) THEN kind := Unknow END;
    RETURN (kind);
  END whichInfo;

VAR  done, eof : BOOLEAN;
     lastRecord, record : MapLineRecord;
     lastKind, kind     : MapKind;
    
BEGIN
   succ := FALSE;
   LOOP
     GetRecordMapLine (record, eof, done);
     IF eof OR NOT done THEN  RETURN  END;  
     kind := whichInfo (record.text);
     IF (kind=BeginCodeModule) AND 
                         (instrCounter.SEGMENT=record.address.SEGMENT) THEN
       Delete(record.text, 0, Pos ( '__', record.text )+2 );
       Assign(record.text,moduleName);
       LOOP
         GetRecordMapLine (record, eof, done);
         kind := whichInfo (record.text);
         CASE kind OF
            EndCodeModule  :  Concat('initialization',procName,procName);  
                              EXIT
         |  ProcCallLong,
            ProcCallShort,     
            ProcCallNested,
            LocalModule,
            InitModule     : IF record.address.OFFSET>instrCounter.OFFSET THEN
                               Delete(lastRecord.text,0,
                                               Pos ( '__', lastRecord.text )+2 );
                               EndPos := Pos('__', lastRecord.text);
                               IF (EndPos > HIGH(lastRecord.text)) THEN
                                   EndPos := HIGH(lastRecord.text);
                               END;
                               lastRecord.text[EndPos] := 0C;
                               Assign(lastRecord.text,procName);
                               EXIT;
                             ELSE
                               lastRecord := record;
                               IF kind=ProcCallNested THEN
                                  procKind := NestedProcedure;
                               ELSIF (kind=ProcCallShort) OR (kind=LocalModule) THEN
                                  procKind := NearProcedure;
                               ELSE
                                  procKind := FarProcedure;
                               END;
                             END;

         ELSE 
         END(*case*);
       END(*loop*);
       succ := TRUE;
       EXIT
     END(*if*);
   END(*loop*);
END SearchNames;


PROCEDURE SearchLine(overlay: OverlayPtr; instrCounter: ADDRESS; 
                     VAR modName: ARRAY OF CHAR;
                     VAR lineNum: CARDINAL);
    PROCEDURE FindLineNum;
    VAR lastNb, nb: CARDINAL;
        address: ADDRESS;
        done   : BOOLEAN;
    BEGIN
      LOOP
        ReadMapLine(eof,line);
        IF eof THEN  RETURN  END;
        LOOP
          IF line[0]=0C THEN EXIT  END;
          ReadCard(line,nb,done); 
          IF NOT done THEN  RETURN  END;
          ReadAddress(line,address,done);
          IF NOT done THEN  RETURN  END;
          IF address>instrCounter THEN  lineNum:= lastNb;  RETURN  END;
          IF address=instrCounter THEN  lineNum:= nb;      RETURN  END;
          lastNb := nb;
        END;
      END;
    END FindLineNum;

VAR
  line : ARRAY [0..80] OF CHAR;
  i    : CARDINAL;
  eof  : BOOLEAN;
BEGIN
  lineNum := 0;
  IF LinePos=NIL THEN  RETURN  END;
  i := 0;  
  WHILE (i<HIGH(modName)) AND (modName[i]<>0C) DO
    IF ('a'<=modName[i]) AND (modName[i]<='z') THEN  
       modName[i] := CAP(modName[i]);
    END;
    INC(i);
  END;
  SetPos(LinePos.SEGMENT,LinePos.OFFSET);
  LOOP
    ReadMapLine(eof,line);
    IF eof THEN  RETURN  END;
    IF Pos('Line numbers for',line)<HIGH(line) THEN
        IF Pos(modName,line)<HIGH(line) THEN  FindLineNum;  RETURN  END;
    END;
  END;
END SearchLine;


PROCEDURE SearchMapInfo (     instrCounter: ADDRESS; 
                           VAR moduleName, procName: ARRAY OF CHAR;
                           VAR procKind : ProcedureKind;
                           VAR lineNum  : CARDINAL;
                           VAR succ     : BOOLEAN);

VAR  overlay : OverlayPtr;
BEGIN
   moduleName[0] := 0C;
   procName[0]   := 0C;
   lineNum       := 0;
   SearchOverlay(instrCounter,overlay,succ);
   IF NOT succ THEN  RETURN  END;
   OpenMap(overlay,succ);
   IF NOT succ THEN  RETURN  END;
   DEC(instrCounter.SEGMENT,overlay^.codeSegment);
   SearchNames(instrCounter,moduleName,procName,procKind,succ);
   IF NOT succ THEN  RETURN  END;
   SearchLine(overlay,instrCounter,moduleName,lineNum);
END SearchMapInfo;

BEGIN
  openName[0] := 0C;
END MapFile;


(**********************************************************************)









PROCEDURE DumpHex( From, To     : ADDRESS;
                   TraceLString : ATraceProc );
VAR
    BytesToDump : POINTER TO ARRAY [0..9999] OF CHAR;
    DumpCount,
    Loop,
    Count16     : CARDINAL;
    s           : ARRAY [0..81] OF CHAR;
    Hex         : ARRAY [0..17] OF CHAR;


    PROCEDURE BtoH( B : CHAR; Column : CARDINAL );
    CONST
        WhereDigitsMultiplyer = 3;
        WhereAsciiOffset      = 55;
    VAR
        C   : CARDINAL;
    BEGIN
        C := ORD(B);
        s[ Column * WhereDigitsMultiplyer + 1 ] := Hex[(C MOD 16)+1];
        s[ Column * WhereDigitsMultiplyer     ] := Hex[(C DIV 16)+1];
        IF (C < 30) THEN
            B := ".";
        END;
        s[ WhereAsciiOffset + Column ] := B;
    END BtoH;



    PROCEDURE AtoH( A : ADDRESS; VAR s : ARRAY OF CHAR );
    VAR
        SLen,
        i   : CARDINAL;
        s1  : ARRAY [0..1]  OF CHAR;

        PROCEDURE CtoH(C : CARDINAL);
        VAR
            i   : CARDINAL;
        BEGIN
            FOR i := 1 TO 4 DO
                s1[1] := Hex[(C MOD 16)+1];
                C     := (C DIV 16);
                Insert( s, s1, 1 );
            END;
        END CtoH;

    BEGIN
        s1[0] := 1C;
        CtoH( A.OFFSET  );
        s1[1] := ":";
        Insert( s, s1, 1 );
        CtoH( A.SEGMENT );
    END AtoH;

BEGIN
    INC(From.OFFSET); (* Skip past the header (And the loop below starts with '1', too) *)
    DEC(To.OFFSET);   (* Don't include next stack item *)

    IF (To.SEGMENT <> From.SEGMENT) OR
       (To.OFFSET  <= From.OFFSET)  THEN
        SetString( s, "  " );
        AtoH( From, s );
        ConcatS( s, "  " );
        AtoH( To,   s );
        TraceLString( s );
        RETURN;
    END;
    BytesToDump := From;
    DumpCount   := To.OFFSET - From.OFFSET;

    SetString(Hex,"0123456789ABCDEF" );
    Fill( s, " ", 79 );
    Count16  := 0;
    FOR Loop := 1 TO DumpCount DO
        BtoH(BytesToDump^[Loop],Count16+1);
        INC(Count16);
        IF (Count16 = 16) THEN
            TrimRear(s);
            TraceLString(s);
            Fill( s, " ", 79 );
            Count16  := 0;
        END;
    END;

    IF (Count16 > 0) THEN
        TrimRear(s);
        TraceLString(s);
    END;

END DumpHex;







PROCEDURE Dump( VAR MapPath      : ARRAY OF CHAR;
                    TraceLString : ATraceProc );
CONST
    ProcNameLen   = 20;
    ModuleNameLen = 12;
    MaxToReport   = 20;         (* 26-Jun-91 RSC was 30 *)
VAR
    help            : Help;
    instrCounter    : ADDRESS;
    ProcsReported,
    Offset,
    Segment         : CARDINAL;
    lineNum         : CARDINAL;
    procKind        : ProcedureKind;
    moduleName      : ARRAY [0..ModuleNameLen] OF CHAR;
    procName        : ARRAY [0..ProcNameLen] OF CHAR;
    s               : ARRAY [0..5] OF CHAR;
    ok              : BOOLEAN;

BEGIN

    GETREG( BP, Offset );
    GETREG( SS, Segment );
    basePointer.SEGMENT := Segment;
    basePointer.OFFSET  := Offset;

    InitOverlayList( MapPath );

    (* The basePointer now points to the BP of our caller.  As this
       is a far call, the return address is right above the BP.

       Traverse up the stack, and for each return address, look up in the
       maps the module name, the procedure name, and maybe the line number
       if the module was linked with the /LI[ne] switch.
    *)

    help.address  := basePointer;
    procKind      := FarProcedure;
    ok            := TRUE;
    ProcsReported := 0;
    WHILE (ok) AND
          (help.cardPtr^ <> 0) (* End of stack *) AND
          (ProcsReported < MaxToReport) DO
        basePointer.OFFSET := help.cardPtr^;  (* Get next base pointer. *)
        INC(help.address,2);
        IF  (procKind = FarProcedure)  THEN
            instrCounter        := help.addrPtr^;
        ELSE
            instrCounter.OFFSET := help.cardPtr^;
        END;
        SearchMapInfo(instrCounter,moduleName,procName,procKind,lineNum,ok);
        IF (ok) THEN
            SetString( OutputStr, "Module: ");
            moduleName[ ModuleNameLen ] := 0C;  (* Insure a null terminator *)
            TStringToLString( moduleName, moduleName );
            Procustes( moduleName, ModuleNameLen );
            ConcatLS(  OutputStr, moduleName );
            ConcatS(   OutputStr, " Procedure: ");
            procName[ ProcNameLen ] := 0C;  (* Insure a null terminator *)
            TStringToLString( procName, procName );
            Procustes( procName,  ProcNameLen );
            ConcatLS(  OutputStr, procName );
            IF lineNum<>0 THEN
                ConcatS( OutputStr, " Line: " );
                CtoS( lineNum, s );
                Procustes(s, 5);
                RJust(s);
                ConcatLS( OutputStr, s );
            END;
            TraceLString(OutputStr);
        END;
        DumpHex( help.address, basePointer, TraceLString );
        help.address := basePointer;
        INC(ProcsReported);
    END;

    Close;

END Dump;






END Stack.

