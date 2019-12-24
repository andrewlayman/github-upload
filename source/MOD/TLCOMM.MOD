MODULE TLComm;

   (* TL Comm   Communications form

         3-Apr-89 RSC First Version.
        12-Jun-89 MWP Added support for Null devices.
         4-Jul-89 MWP Seeing as how we have a field on the comm form
                      for the device name, why don't we put something
                      in it!
       09-Aug-89  KKC Add copyright message.
   *)

FROM CommStatic IMPORT
    (* TYPE *)      ACommFormContext, AMethod, ABaudRate, ADataBits, AStopBits,
                    AParity, AProtocol, ADOSDevice;

FROM Dialog     IMPORT
    (* PROC *)      FatalError;

FROM FormCon    IMPORT
    (* TYPE *)      AFieldNo;

FROM Forms      IMPORT
    (* TYPE *)      ACheckReason, AStringValue, AForm, AFieldValue,
    (* PROC *)      DoForm, ShowValue, SetFieldHidden, SetFieldProtection;

FROM Kbio       IMPORT
    (* CONST *)     maxcol;

FROM Keys       IMPORT
    (* CONST *)     ExitKey;

FROM Layout     IMPORT
    (* CONST *)     GanttWEnd;

FROM LStrings   IMPORT
    (* PROC *)      Fill, SubStr, ConcatLS, LengthOf,
                    TrimRear, LJust, LStringToTString, Procustes,
                    Search, Insert, Remove, Copy, SetLengthOf,SetString;

FROM Overlays   IMPORT
    (* TYPE *)      AnOverlayID,
(*<VERSION3
                    AnOverlayProc,
VERSION3>*)
    (* PROC *)      OverlayContext, ImAnInstallableOverlay;

(*<VERSION4*)
FROM OvTree     IMPORT
    (* TYPE *)      AnOverlayProc;
(*VERSION4>*)

FROM PrintStatic IMPORT
                    OutputDeviceName;


FROM SYSTEM     IMPORT
    (* TYPE *)      ADR;







VAR
    OverlayID   : AnOverlayID;






CONST
    DEV     = 0;        (* Device's full name *)
    MTH     = 1;        (* Method: Serial/Parallel/Use DOS *)
    PPN     = 2;        (* Parallel Port Number *)
    SPN     = 3;        (* Serial Port Number *)
    BR      = 4;        (* Baud Rate *)
    DB      = 5;        (* Data Bits *)
    SB      = 6;        (* Stop Bits *)
    PAR     = 7;        (* Parity *)
    TIM     = 8;        (* Time Out *)
    SEC     = 9;        (* Time Out seconds *)
    PRO     = 10;       (* Protocol *)
    DOS     = 11;       (* DOS Device *)


TYPE
    AFormFieldSet    = SET OF [DEV..DOS];

CONST
    ParallelSet      = AFormFieldSet{PPN};
    SerialSet        = AFormFieldSet{SPN,BR,SB,DB,PAR,TIM,SEC,PRO};
    DOSSet           = AFormFieldSet{DOS};




PROCEDURE CheckCommForm (     Form        : AForm;
                              FieldNo     : AFieldNo;
                          VAR FormValue   : ARRAY OF AFieldValue;
                              CheckReason : ACheckReason;
                          VAR Code        : CARDINAL ):BOOLEAN;
VAR
    Method      : AMethod;
    BaudRate    : ABaudRate;
    DataBits    : ADataBits;


    PROCEDURE Setup( Bits : AFormFieldSet; On : BOOLEAN );
    VAR
        Loop : CARDINAL;
    BEGIN
        FOR Loop := DEV TO DOS DO
            IF (Loop IN Bits) THEN
                SetFieldProtection( Form, Loop, FormValue, On );
                SetFieldHidden(     Form, Loop, FormValue, On );
            END;
        END;
    END Setup;


    PROCEDURE SerialProtection();
    BEGIN
        IF (Method = Serial) THEN
            DataBits := ADataBits(CHR( FormValue[ DB ].CardValue ));
            BaudRate := ABaudRate(CHR( FormValue[ BR ].CardValue ));

            ShowValue( Form, SB, FormValue );

            SetFieldProtection( Form, SB,  FormValue, (BaudRate = B300) );
            SetFieldProtection( Form, PAR, FormValue, (DataBits = D8) );

            SetFieldProtection( Form, SEC, FormValue, (FormValue[ TIM ].CardValue = 0) );
            SetFieldHidden(     Form, SEC, FormValue, (FormValue[ TIM ].CardValue = 0) );
        END;
    END SerialProtection;



BEGIN
    Code := 0;

    IF (CheckReason <> CheckFieldChange) AND
       (CheckReason <> CheckFormEntry)   THEN
        RETURN TRUE;
    END;

    Method := AMethod(CHR(FormValue[ MTH ].CardValue));

    CASE FieldNo OF
        MTH  :
            CASE Method OF
                Parallel    : Setup( ParallelSet, FALSE );
                              Setup( SerialSet,   TRUE  );
                              Setup( DOSSet,      TRUE  );

              | Serial      : Setup( ParallelSet, TRUE  );
                              Setup( SerialSet,   FALSE );
                              Setup( DOSSet,      TRUE  );
                              SerialProtection();

              | DOSDevice   : Setup( ParallelSet, TRUE  );
                              Setup( SerialSet,   TRUE  );
                              Setup( DOSSet,      FALSE );

              | NullDevice  : Setup( ParallelSet, TRUE );
                              Setup( SerialSet,   TRUE );
                              Setup( DOSSet,      TRUE );
            ELSE
                FatalError();
            END;

      | BR :
            BaudRate := ABaudRate(CHR( FormValue[ BR ].CardValue ));
            IF (BaudRate = B300) THEN
                FormValue[ SB ].CardValue := ORD( S2 );
            ELSE
                FormValue[ SB ].CardValue := ORD( S1 );
            END;
            SerialProtection();

      | DB :
            DataBits := ADataBits(CHR( FormValue[ DB ].CardValue ));
            IF (DataBits = D8) THEN
                FormValue[ PAR ].CardValue := ORD(None);
                ShowValue( Form, PAR, FormValue );
            END;
            SerialProtection();

      | TIM :
            SerialProtection();

      | SEC :
            IF (FormValue[ SEC ].CardValue > 655) THEN
                FormValue[ SEC ].CardValue := 655;  (* Max allowed. *)
                ShowValue( Form, SEC, FormValue );
            END;
    ELSE
    END;

    RETURN TRUE;
END CheckCommForm;









PROCEDURE CommForm();
CONST
     FormID = 59;
VAR
    Context      : POINTER TO ACommFormContext;
    Loop, i      : CARDINAL;
    FormValue    : ARRAY [DEV..DOS] OF AFieldValue;
    StringField  : AStringValue;
    Copyright    : ARRAY[0..50] OF CHAR;

BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Context := OverlayContext();

    WITH Context^ DO

        FormValue[DEV].CharValue := ADR(StringField);

        Copy (DeviceName, FormValue[DEV].CharValue^); (* Display only *)

        FormValue[MTH].CardValue := ORD(Method);
        FormValue[PPN].CardValue := ParallelPortNumber;
        FormValue[SPN].CardValue := SerialPortNumber;
        FormValue[BR ].CardValue := ORD(BaudRate);
        FormValue[DB ].CardValue := ORD(DataBits);
        FormValue[SB ].CardValue := ORD(StopBits);
        FormValue[PAR].CardValue := ORD(Parity);
        FormValue[PRO].CardValue := ORD(Protocol);
        FormValue[DOS].CardValue := ORD(DOSDev);                (* MWP *)
        IF (TimeOut = 65535) THEN
            FormValue[SEC].CardValue := 10;
            FormValue[TIM].CardValue := 0;  (* FALSE *)
        ELSE
            FormValue[SEC].CardValue := TimeOut DIV 100;
            FormValue[TIM].CardValue := 1;  (* TRUE *)
        END;

        FormCode := DoForm( 2, 0, maxcol, GanttWEnd,
                            FormID,    TRUE,
                            FormValue, CheckCommForm);

        IF (FormCode = ExitKey) THEN
            Method              := AMethod(CHR(FormValue[MTH].CardValue));
            ParallelPortNumber  := FormValue[PPN].CardValue;
            SerialPortNumber    := FormValue[SPN].CardValue;
            BaudRate            := ABaudRate(CHR(FormValue[BR ].CardValue));
            DataBits            := ADataBits(CHR(FormValue[DB ].CardValue));
            StopBits            := AStopBits(CHR(FormValue[SB ].CardValue));
            Parity              := AParity(CHR(FormValue[PAR].CardValue));
            Protocol            := AProtocol(CHR(FormValue[PRO].CardValue));

            (* MWP *)
            DOSDev              := ADOSDevice(CHR(FormValue[DOS].CardValue));
            IF (FormValue[TIM].CardValue = 0) THEN
                TimeOut         := 65535;
            ELSE
                TimeOut         := FormValue[SEC].CardValue * 100;
            END;
        END;
    END;

END CommForm;








BEGIN

    OverlayID := ImAnInstallableOverlay( CommForm, AnOverlayProc(NIL) );
    CommForm();

END TLComm.
