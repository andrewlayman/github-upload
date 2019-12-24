MODULE TLPrtFrm;


(*  TL Printer From - Set up printer parameters.

    Modification History:

         12-Jun-89  MWP  First version.
         04-Jul-89  MWP  Seeing as how we have a field on the comm form
                         for the device name, why don't we put something
                         in it!
         06-Jul-89  WKH/
                    MWP  Fix references to variables that weren't declared
                         correctly.

         10-May-91  RSC  Remove global memory passed to overlays.

*)


IMPORT PrintStatic;

FROM CommStatic IMPORT
    (* TYPE *)      ACommFormContext, AMethod,   ABaudRate,  AStopBits,
                    ADataBits,        AProtocol, ADOSDevice, AParity,
    (* CONST *)     HighestMethod,   HighestBaudRate, HighestDataBits,
                    HighestStopBits, HighestParity,   HighestProtocol,
                    HighestDOSDevice;

FROM Keys       IMPORT
    (* CONST *)     CancelKey;

FROM SYSTEM     IMPORT
    (* TYPE *)      ADR;

FROM LStrings   IMPORT
    (* PROC *)      SetString, Copy, ConcatLS,
                    SetLengthOf;

FROM Overlays   IMPORT
    (* PROC *)      CallOverlayWithContext;


CONST
    ModuleNumber            = 29600;




PROCEDURE InitializeCommFormContext( VAR CommFormContext : ACommFormContext );
BEGIN

    WITH CommFormContext DO

        FormCode            := 0;
        Method              := Parallel;
        ParallelPortNumber  := 1;
        SerialPortNumber    := 0;
        BaudRate            := B2400;
        DataBits            := D8;
        StopBits            := S1;
        Parity              := None;
        TimeOut             := 65535;  (* No time out *)
        Protocol            := ClearToSend;
        DOSDev              := LPT1;


        FormCode            := 0;

        IF (PrintStatic.PrintCB.PortType = PrintStatic.PortSerial) THEN
            Method := Serial;
        ELSIF  (PrintStatic.PrintCB.PortType = PrintStatic.PortDOS)  THEN
            Method := DOSDevice;
        ELSE
            Method := Parallel;
        END;

        IF ( Method = Parallel ) THEN
           ParallelPortNumber  := PrintStatic.PrintCB.PrinterNumber;
           SerialPortNumber    := 0;
        ELSIF ( Method = Serial ) THEN
           ParallelPortNumber  := 0;
           SerialPortNumber    := PrintStatic.PrintCB.PrinterNumber;
        ELSE
           ParallelPortNumber  := 0;
           SerialPortNumber    := 1;
        END;

        IF ( Method = Serial ) THEN

        CASE PrintStatic.PrintCB.BaudRate OF
                300   :
                      BaudRate := B300;
            |   600   :
                      BaudRate := B600;
            |   1200  :
                      BaudRate := B1200;
            |   2400  :
                      BaudRate := B2400;
            |   4800  :
                      BaudRate := B4800;
            |   9600  :
                      BaudRate := B9600;
            ELSE
                      BaudRate := B300;
            END;

        IF ( PrintStatic.PrintCB.NumberOfBits = 7 ) THEN
           DataBits            := D7;
        ELSE
           DataBits            := D8;
        END;

        IF ( PrintStatic.PrintCB.StopBits = 1 ) THEN
           StopBits            := S1;
        ELSE
           StopBits            := S2;
        END;


        IF (PrintStatic.PrintCB.ParityBit) THEN
            IF (PrintStatic.PrintCB.EvenParity) THEN
                Parity := Even;
            ELSE
                Parity := Odd;
            END;
        ELSE
            Parity     := None;
        END;

        TimeOut             := 65535;  (* No time out *)

        CASE PrintStatic.PrintCB.Protocol OF
              PrintStatic.NoProtocol   :
                 Protocol            := Auto;
            | PrintStatic.CheckCTS     :
                 Protocol            := ClearToSend;
            | PrintStatic.XonXoff      :
                 Protocol            := XONXOFF;
            ELSE
                 Protocol            := Auto;
            END;
        END;

        IF (PrintStatic.PrintCB.PortType = PrintStatic.PortDOS) THEN (* Was DOS? *)
          CASE PrintStatic.PrintCB.PrinterNumber OF
                  0  :
                     DOSDev              := PRN;
                | 1  :
                     DOSDev              := LPT1;
                | 2  :
                     DOSDev              := LPT2;
                | 3  :
                     DOSDev              := COM1;
                | 4  :
                     DOSDev              := COM2;
                | 5  :
                     DOSDev              := COM3;
                | 6  :
                     DOSDev              := AUX;
              ELSE
                   DOSDev                := LPT1;
              END;
        ELSE
            DOSDev              := LPT1;
        END;

        SetLengthOf(DeviceName, 0);
        ConcatLS ( DeviceName, PrintStatic.OutputDeviceName );
    END;

END InitializeCommFormContext;


PROCEDURE SaveCommFormContext( VAR CommFormContext : ACommFormContext );
BEGIN

    WITH CommFormContext DO

        CASE Method OF
            Serial     :
                 PrintStatic.PrintCB.PortType := PrintStatic.PortSerial;
                 PrintStatic.PrintCB.PrinterNumber := SerialPortNumber;
          | Parallel   :
                 PrintStatic.PrintCB.PortType := PrintStatic.PortParallel;
                 PrintStatic.PrintCB.PrinterNumber := ParallelPortNumber;
          | DOSDevice  :
                 PrintStatic.PrintCB.PortType := PrintStatic.PortDOS;
                 PrintStatic.PrintCB.PrinterNumber := ORD(DOSDev);
          | NullDevice :
                 PrintStatic.PrintCB.PortType := PrintStatic.PortNull;
          ELSE
          END;

        IF ( Method = Serial ) THEN
           CASE BaudRate OF
                  B300   :
                         PrintStatic.PrintCB.BaudRate :=  300;
               |  B600   :
                         PrintStatic.PrintCB.BaudRate :=  600;
               |  B1200  :
                         PrintStatic.PrintCB.BaudRate :=  1200;
               |  B2400  :
                         PrintStatic.PrintCB.BaudRate :=  2400;
               |  B4800  :
                         PrintStatic.PrintCB.BaudRate :=  4800;
               |  B9600  :
                         PrintStatic.PrintCB.BaudRate :=  9600;
               ELSE
                         PrintStatic.PrintCB.BaudRate :=  300;
               END;

           IF ( DataBits = D7 ) THEN
                PrintStatic.PrintCB.NumberOfBits := 7;
           ELSE
                PrintStatic.PrintCB.NumberOfBits := 8;
           END;

           IF (  StopBits = S1 ) THEN
                PrintStatic.PrintCB.StopBits := 1;
           ELSE
                PrintStatic.PrintCB.StopBits := 2;
           END;

           CASE Parity OF
               Even :
                    PrintStatic.PrintCB.ParityBit := TRUE;
                    PrintStatic.PrintCB.EvenParity := TRUE;
            |  Odd  :
                    PrintStatic.PrintCB.ParityBit := TRUE;
                    PrintStatic.PrintCB.EvenParity := FALSE;
            |  None :
                    PrintStatic.PrintCB.ParityBit := FALSE;
            ELSE
            END;

           CASE Protocol OF
               Auto        :
                    PrintStatic.PrintCB.Protocol :=  PrintStatic.NoProtocol;
            |  ClearToSend :
                    PrintStatic.PrintCB.Protocol :=  PrintStatic.CheckCTS;
            |  XONXOFF     :
                    PrintStatic.PrintCB.Protocol :=  PrintStatic.XonXoff;
            ELSE
            END;
        END;
    END;

END SaveCommFormContext;


PROCEDURE PrintForm ();
VAR
    CommFormContext         : ACommFormContext; (* 10-May-91 RSC  *)
    s                       : ARRAY [0..21] OF CHAR;
BEGIN
    InitializeCommFormContext(CommFormContext);

    SetString( s, "\TLFBASE(TLCOMM)" );

    IF (CallOverlayWithContext( s, ADR(CommFormContext) ) AND
       (CommFormContext.FormCode <> CancelKey)) THEN
        SaveCommFormContext(CommFormContext);
    END;
END PrintForm;




BEGIN

    PrintForm ();
END TLPrtFrm.
