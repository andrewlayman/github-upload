IMPLEMENTATION MODULE Printers;

    (* MODIFICATION HISTORY:

       21 Feb 89  AJL -First version, built mostly of parts removed from
                       TL 3.0 PrintSupport.  Functional differences are
                       a.  Serial timeout will end early if the device
                           becomes ready.
                       b.  Message is not printed during serial timeout
                           period.

                       This version has scaffolding for more than one printer.
                       That may be overkill, and some code size could be
                       saved by only having one printer, globally declared.

        4 May 89  MWP  Added support for second direct serial port access.
       12 Jun 89  MWP  Added support for outputting to a Null device.
       28-Nov-89  EGK  Put calls to PrepareForIO and CheckIO in
                       OutputACharacter so that in "DOS Device" mode, we
                       can respond to DOS critical errors the same way that
                       we do to errors in parallel and serial mode.
    *)

FROM   Dialog    IMPORT  Message, Error, FatalError, Burp, WarningBox;


FROM   FileAux   IMPORT  CheckIO, PrepareForIO;

FROM   FileSystem   IMPORT  File, Response;

FROM   Kbio      IMPORT  BreakRequested, ClearBreak;

FROM   LStrings  IMPORT  SetString, SubStr, ConcatLS, Fill,
                         LJust, TrimRear, StoC, CtoS, ConcatS,
                         Search, Remove, Copy, SetLengthOf,
                         LStringToTString, TrimFront, Insert;

FROM   SYSTEM     IMPORT DOSCALL, ADR, SETREG, SWI, GETREG, CODE, AX, DX;

FROM   MsgFile    IMPORT  GetMessage, ConcatMessage, DisplayMessage;

IMPORT RS232;


CONST
    MaxPrinters        = 1;

TYPE
    APrinterRecord     =  RECORD
                              Options : APrinterOptionsBlock;
                              QueryUser : AUserQueryProc;
                              PrinterFileHandle : CARDINAL; (* For DOS calls *)
                              ReceivedString        : ARRAY [0..51] OF CHAR;
                              Open                  : BOOLEAN;
                          END;

    APrinterConnection = CARDINAL;

    AReadyProcedure = PROCEDURE ( CARDINAL ) : BOOLEAN;


CONST
    ModuleNumber = 10900;          (* For GetMessage  *)


VAR
    PrinterArray : ARRAY [0..MaxPrinters - 1] OF APrinterRecord;



PROCEDURE Delay(Centiseconds:CARDINAL;
                Port        : CARDINAL;
                EarlyExit : AReadyProcedure );
CONST
    GetTime = 2CH;
VAR
    Ch : CHAR;
    HourMinute,SecondCentisecond, OldSecondCentisecond  : CARDINAL;
    i : CARDINAL;
    j : CARDINAL;
BEGIN
                (*  Delay  *)
    DOSCALL(GetTime,HourMinute,OldSecondCentisecond);
    OldSecondCentisecond := OldSecondCentisecond MOD 100H;
    WHILE (Centiseconds > 0) AND (NOT EarlyExit( Port )) DO
        REPEAT
            DOSCALL(GetTime,HourMinute,SecondCentisecond);
            SecondCentisecond := SecondCentisecond MOD 100H;
        UNTIL (SecondCentisecond <> OldSecondCentisecond);
        j := (100 + SecondCentisecond - OldSecondCentisecond) MOD 100;
        IF (j < Centiseconds) THEN
            DEC(Centiseconds,j);
        ELSE
            Centiseconds := 0;
        END;
        OldSecondCentisecond := SecondCentisecond;
    END;
END Delay;



    (* CheckProtocol -- This implements the common portions of both
                        the XON/XOFF and ETX/ACK protocols.
                        XON/XOFF call (FALSE,XON,XOFF),
                        ETX/ACK  call (TRUE,ACK,0C)      *)


PROCEDURE CheckProtocol(  VAR Printer : APrinterRecord;
                              Paused:BOOLEAN;
                              Go,Stop:CHAR):BOOLEAN;
VAR
    Received : BOOLEAN;
    s1       : ARRAY [0..1] OF CHAR;
    CharRead : CHAR;
    ms       : ARRAY [0..255] OF CHAR;
BEGIN
    LOOP
        IF (NOT Printer.Open) THEN
            RETURN FALSE;
        ELSIF BreakRequested() THEN
            ClearBreak;
            GetMessage(ModuleNumber+18,ms);  (* "You pressed Break."*)
            IF (Printer.QueryUser(ms)) THEN
                ClosePrinterRecord(Printer);       (* Assume printer problems. *)
                RETURN FALSE;
            END;
        END;
(* <MWP> 04-May-89 *)
        RS232.BusyRead ( Printer.Options.SerialPort, CharRead,Received);
        IF (Received) THEN
            WITH Printer DO
                IF (ORD(ReceivedString[0]) >= HIGH(ReceivedString)) THEN
                    Remove(ReceivedString,1,1);
                END;
                Fill(s1,CharRead,1);
                ConcatLS(ReceivedString,s1);
            END;

            IF (CharRead = Go) THEN
                Paused := FALSE;
                Fill(ms," ",0);
            ELSIF (CharRead = Stop) AND (Stop <> 0C) THEN
                Paused := TRUE;
                GetMessage(ModuleNumber+3,ms);   (*  "Busy"  *)
            ELSE
                GetMessage(ModuleNumber+4,ms);   (*  "Unexpected serial input: "  *)
                ConcatLS(ms,Printer.ReceivedString);
            END;
            Message(ms);
        ELSIF (NOT Paused) THEN
            RETURN TRUE;
        END;
    END;
END CheckProtocol;





PROCEDURE OutputIsReady( VAR Printer : APrinterRecord;
(* <MWP> 04-May-89 *)
                             Ready:AReadyProcedure;
                             MessageNumber : CARDINAL):BOOLEAN;
VAR
    ms : ARRAY [0..80] OF CHAR;
BEGIN
    LOOP
        IF (NOT Printer.Open) THEN
            EXIT;
(* <MWP> 04-May-89 *)
        ELSIF (NOT Ready( Printer.Options.SerialPort )) THEN
            Delay(Printer.Options.TimeOut,Printer.Options.SerialPort,Ready);       (*   Wait. *)
(* <MWP> 04-May-89 *)
            IF NOT Ready ( Printer.Options.SerialPort ) THEN
                Burp(); Burp(); Burp();
                GetMessage(MessageNumber,ms);
                IF (Printer.QueryUser(ms)) THEN
                    ClosePrinterRecord(Printer);
                END;
            END;
        ELSE
            RETURN TRUE;
        END;
    END;
    RETURN FALSE;
END OutputIsReady;





PROCEDURE SerialCharacterOutput( VAR Printer : APrinterRecord;
                                     Ch:CHAR);
BEGIN
    IF (OutputIsReady(Printer,RS232.DataSetReady,ModuleNumber+5)) THEN
(* <MWP> 04-May-89 *)
        RS232.Write ( Printer.Options.SerialPort, Ch );
    END;
END SerialCharacterOutput;






PROCEDURE OutputACharacter( VAR Printer : APrinterRecord;
                                TheChar:CHAR):BOOLEAN;
CONST
    Good = 0;
    Die  = 1;
    Retry = 2;
CONST
    XON   = 21C;
    XOFF  = 23C;
    ETX   =  3C;
    ACK   =  6C;
VAR
    PrinterNumber : CARDINAL;
    ErrorNumber   : CARDINAL;
    C             : CARDINAL;
    Ch            : CHAR;
    ms            : ARRAY [0..60] OF CHAR;
    DummyFile     : File;


    PROCEDURE CheckIt(C:CARDINAL):CARDINAL;
    BEGIN
        IF ( (BITSET(2900H) * BITSET(C)) <> {})  THEN
            GetMessage(ModuleNumber+6,ms);  (* "Printer error" *)
            Burp; Burp; Burp;
            IF (Printer.QueryUser(ms)) THEN
                RETURN Die;
            END;
            RETURN Retry;
        END;
        RETURN Good;
    END CheckIt;



    PROCEDURE CheckDOS( C, ErrorNumber : CARDINAL ) : CARDINAL;
    BEGIN
        IF ((C <> 1) OR (ErrorNumber <> 0) OR
            (CheckIO(DummyFile) <> done)) THEN      (* 11/28/89 EGK *)
            GetMessage(ModuleNumber+6,ms);  (* "Printer error" *)
            Burp; Burp; Burp;
            IF (Printer.QueryUser(ms)) THEN
                RETURN Die;
            END;
            RETURN Retry;
        END;
        RETURN Good;
    END CheckDOS;


BEGIN
    Ch := TheChar; (* Local variable *)
    IF (NOT Printer.Open) THEN
        (* If not open, do not attempt to print. *)
    ELSE

        IF (Printer.Options.Method = Serial) THEN

            CASE Printer.Options.Protocol OF
                CheckCTS:
                          (*  "Printer not ready (CTS)."  *)
                    IF (NOT OutputIsReady(Printer,RS232.ClearToSend,ModuleNumber+7)) THEN
                        RETURN FALSE;
                    END;
                  |
                XonXoff:
                    IF (NOT CheckProtocol(Printer,FALSE,XON,XOFF)) THEN
                        RETURN FALSE;
                    END;
                  |
                EnqAck:
                    SerialCharacterOutput(Printer,ETX);
                    IF (NOT CheckProtocol(Printer,TRUE,ACK,0C)) THEN
                        RETURN FALSE;
                    END;
                ELSE  ;
            END;

            SerialCharacterOutput(Printer,Ch);

        ELSIF (Printer.Options.Method = PrintDOS) THEN
            LOOP
                PrepareForIO (DummyFile);           (* 11/28/89 EGK *)
                DOSCALL( 40H, Printer.PrinterFileHandle, 1, ADR(Ch), C, ErrorNumber );
                CASE CheckDOS(C, ErrorNumber) OF
                      Good:  EXIT;
                    | Die:   RETURN FALSE;
                    ELSE (* RETRY *)
                END;
            END;

        ELSIF (Printer.Options.Method = Parallel) THEN
            PrinterNumber := Printer.Options.ParallelPort;
            LOOP
                LOOP
                    SETREG(DX,PrinterNumber); (* Printer # *)
                    SETREG(AX,0200H);         (* AH = 2 :: Status *)
                    SWI(17H);                    (* Check printer status *)
                    GETREG(AX,C);
                    CASE CheckIt(C) OF
                        Good:     EXIT;
                      | Die:      RETURN FALSE;
                      ELSE        ;
                    END;
                END;

                C := ORD(Ch);
                SETREG(DX,PrinterNumber);       (* Printer # *)
                SETREG(AX,C);                   (* AH := 0, AL := char *)
                SWI(17H);                          (* Print the character. *)
                GETREG(AX,C);                   (* Get status bits.     *)
                CASE CheckIt(C) OF
                    Good:   EXIT;
                   |Die:    RETURN FALSE;
                   ELSE        ;
                END;
            END;  (* End loop. *)

        ELSE   (* Null Device - throw characters away. *)
        END;
    END;
    RETURN TRUE;
END OutputACharacter;




PROCEDURE XPrintACharacter( VAR Printer : APrinterConnection;
                                TheChar:CHAR):BOOLEAN;
BEGIN
    IF OutputACharacter( PrinterArray[Printer], TheChar ) THEN
        RETURN TRUE;
    ELSE
        ClosePrinterRecord( PrinterArray[Printer] );
        RETURN FALSE;
    END;
END XPrintACharacter;






    (*  OpenPrinter -- Attempt to open the printer.  Set
                       FileIsOpen to TRUE iff successful.   *)


PROCEDURE OpenPrinterRecord( VAR Printer : APrinterRecord):BOOLEAN;

CONST
    Access = 1; (* Write (0=read,2=read/write) *)

VAR
    ErrorNumber : CARDINAL;
    i           : CARDINAL;
    ok          : BOOLEAN;
    FileName    : ARRAY [0..10] OF CHAR;
BEGIN


    IF (Printer.Options.Method = Serial) THEN
        WITH Printer.Options DO
(* <MWP> 04-May-89 *)

            IF (SerialPort <> 0) AND
               (SerialPort <> 1) THEN (* Not yet implemented. *)
                RETURN FALSE;
            END;

            RS232.Init(SerialPort, BaudRate,StopBits,ParityBit,EvenParity,
                                DataBits,ok);
            IF (Protocol >= XonXoff) THEN
                RS232.StartReading;     (* Start the input interrupt handler. *)
            END;
            Printer.ReceivedString[0] := 0C;
        END;

     ELSIF (Printer.Options.Method = PrintDOS) THEN

        WITH Printer DO

            (* Open the file with a DOS file HANDLE for later output calls. *)

            PrinterFileHandle := 0;

            CASE Options.DOSDevice OF
               0 : PrinterFileHandle := 4;  (* PRN: *)
             | 1 : FileName := "LPT1";
             | 2 : FileName := "LPT2";
             | 3 : FileName := "LPT3";
             | 4 : FileName := "COM1";
             | 5 : FileName := "COM2";
             | 6 : PrinterFileHandle := 3;  (* AUX: *)
            ELSE
                FatalError();
            END;

            i := PrinterFileHandle;
            IF (i = 0) THEN
                DOSCALL(3DH, ADR(FileName), Access, i, ErrorNumber );
                Open := (ErrorNumber = 0);
                PrinterFileHandle := i;
            END;
        END;
    END;

    Printer.Open := TRUE;
    RETURN TRUE;
END OpenPrinterRecord;






PROCEDURE XOpenPrinter   ( VAR Printer : APrinterConnection;
                               Options : APrinterOptionsBlock;
                               HowToQuery : AUserQueryProc ) : BOOLEAN;
VAR
    ErrorNumber : CARDINAL;
    i           : CARDINAL;
BEGIN
        (* Find an unopened slot in the printer table. *)
    i := 0;
    WHILE (i <= HIGH(PrinterArray)) AND (PrinterArray[i].Open) DO
        INC(i);
    END;

    IF (i > HIGH(PrinterArray)) THEN
        RETURN FALSE;
    END;

    Printer := i;
    PrinterArray[i].Options := Options;
    PrinterArray[i].QueryUser := HowToQuery;

    RETURN OpenPrinterRecord(PrinterArray[Printer]);
END XOpenPrinter;












    (* ClosePrinterRecord -- If the printer file is open, close it. *)

PROCEDURE ClosePrinterRecord( VAR Printer : APrinterRecord );
VAR
    ErrorNumber : CARDINAL;
    S : ARRAY [0..255] OF CHAR;
BEGIN
    WITH Printer DO
        IF (Open) THEN
            IF (Options.Method = Serial)  AND
               (Options.Protocol >= XonXoff) THEN
                RS232.StopReading;     (* Stop the input interrupt handler. *)
            END;
            IF (Options.Method = PrintDOS) THEN

              (* If the handle is not one of the pre-defined handles,
                 close the dos file, freeing it up. *)

                IF (PrinterFileHandle > 4) THEN
                    DOSCALL( 3EH, PrinterFileHandle, ErrorNumber );
                END;
            END;
        END;

        Open := FALSE;
    END;
END ClosePrinterRecord;





    (* ClosePrinter -- If the printer file is open, close it. *)

PROCEDURE XClosePrinter( VAR Printer : APrinterConnection );
BEGIN
    ClosePrinterRecord(PrinterArray[Printer]);
END XClosePrinter;




PROCEDURE XQueryPrinterIsOpen( Printer : APrinterConnection ) : BOOLEAN;
BEGIN
    RETURN PrinterArray[Printer].Open;
END XQueryPrinterIsOpen;






PROCEDURE Init;
VAR
    i : CARDINAL;
BEGIN
    FOR i := 0 TO HIGH(PrinterArray) DO
        PrinterArray[i].Open := FALSE;
    END;
    OpenPrinter := XOpenPrinter;
    QueryPrinterIsOpen := XQueryPrinterIsOpen;
    ClosePrinter := XClosePrinter;
    PrintACharacter := XPrintACharacter;
END Init;


BEGIN
    Init();
END Printers.
