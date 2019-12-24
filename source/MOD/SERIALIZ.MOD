MODULE Serialize;

    (* Modification History:

       20-Oct-86  AJL  - Avoid use of letter "O" in serial number.

       01/19/87 LAA     Merged the TLG and 2.3 versions on tag into this one.

       2/9/87   EGK     Now works with IBM and HP versions of TL and TLG.
                        Doesn't use "Q" in serial number.
                        Automatically uses correct product code.
                        Recap prints all serial numbers correctly.
       8/25/87  EGK     Disable writing of extra "balancing" characters in
                        TagIt.  This was causing problems with the compression
                        procedure.
       2/04/88  RSC     upgrade for spike: remove actual serialization.  Just
                        generate labels.
       3/02/88  RSC     revised for COMAC.  Print same label twice, then skip
                        a label.  One label and its borders is 3 print lines.
       3/29/88  RSC     Made Maureen's changes.  No SN:  No 'Promo' Add
                        educational bit.
       3/31/88  RSC     Added "Unlimited Network Use" bit.


         SPIKE Serial Number Format:

             pppcv.mm.######.zzzz

             ppp    = product code (TL- or TLG)
             c      = capabilities
             v      = major version (3)
             mm     = minor version (00)
             ###### = sequential serial number
             zzzz   = generated checksum

         for example,   TL-A3.00.1A2S3D.89FA
    *)

    FROM FileSystem        IMPORT File, Response, Lookup, GetPos, ReadByte,
                                  SetPos, WriteByte, Close, SetModify,
                                  ReadNBytes, WriteNBytes;

    IMPORT InOut;

    IMPORT ASCII;

    FROM  Options          IMPORT FileNameAndOptions, Termination,
                                  NamePartSet;

    FROM  FileMessage      IMPORT WriteResponse;

    FROM  ASCII            IMPORT EOL;

    FROM  CRC16            IMPORT CheckSum;

    FROM  RTSMain          IMPORT PSPAddress;

    FROM  SYSTEM           IMPORT ADR, SIZE, DOSCALL;

    FROM  NumberConversion IMPORT CardToString; 






CONST 
    ProductCodeLength   = 9; (* "pppcv.mm." *)
    LengthLimit         = 6; (* tag and trailer max lengths *)
    OptionsByte         = 4; (* pppCv.mm., capabilities byte position *)
    VersionStringLength = 20;
    DefaultStartHigh    = 0;               (* Search starts here. *)
    DefaultStartLow     = 0;
    MAXCARDINAL         = 0FFFFH;
VAR
    LinesPerLabel,
    LogPrinter,
    LabelPrinter,
    MaxSerialNumbers,
    DiskDriveCount,
    DiskDriveSequence,
    i,
    Count,
    MaxTasks,
    high, low,
    StartHigh, StartLow : CARDINAL;
    WhichProduct        : CARDINAL;
    Trailer,
    TagString,
    FirstTagString,
    LastTagString       : ARRAY [0..LengthLimit+1] OF CHAR;
    CheckChar           : CHAR;
    s                   : ARRAY [0..79] OF CHAR;
    S0                  : ARRAY [0..0]  OF CHAR;
    C                   : CHAR;
    ProductCode         : ARRAY [0..ProductCodeLength] OF CHAR;
    CopyExtraFile       : BOOLEAN;
    CopyFrom, CopyTo    : ARRAY [0..30] OF CHAR;
    LAN,
    Educ,
    Promo,
    Beta,
    Network,
    Magic,
    Limited,
    LogPrinterOn,
    LabelPrinterOn      : BOOLEAN;

    (* --------------  Module Printer ------------------- *)

MODULE Printer; 

    IMPORT YesOrNo, CardToString, DOSCALL; 
    IMPORT InOut; 

    EXPORT PrintString, PrintLString, PrintLn, PrintCard; 

PROCEDURE StopTest():BOOLEAN; 
BEGIN 
    RETURN YesOrNo("Cancel printing? ");
END StopTest; 



PROCEDURE PrintACharacter(Ch:CHAR; PrinterNumber : CARDINAL):BOOLEAN; 
BEGIN
    IF (PrinterNumber = 0) THEN
        DOSCALL (4H,ORD(Ch));
    ELSE
        DOSCALL (5H,ORD(Ch));
    END;
    RETURN TRUE;
END PrintACharacter;


PROCEDURE PrintString( S:ARRAY OF CHAR; PrinterNumber : CARDINAL);
VAR 
    i : CARDINAL; 
BEGIN 
    i := 0; 
    WHILE (i <= HIGH(S)) AND
          (S[i] <> 0C) AND
          (PrintACharacter(S[i],PrinterNumber)) DO
        INC(i); 
    END;
END PrintString;






PROCEDURE PrintLString(S:ARRAY OF CHAR; PrinterNumber : CARDINAL);
VAR 
    i : CARDINAL; 
BEGIN 
    i := 1; 
    WHILE (i <= HIGH(S)) AND
          (i <= ORD(S[0])) AND
          (PrintACharacter(S[i],PrinterNumber)) DO
        INC(i); 
    END;
END PrintLString; 






PROCEDURE PrintLn(PrinterNumber:CARDINAL);
VAR 
    S : ARRAY [0..3] OF CHAR; 
BEGIN 
    S[0] := 15C;
    S[1] := 12C;
    S[2] := 0C; 
    PrintString(S,PrinterNumber); 
END PrintLn;




PROCEDURE PrintCard( Num, Width, PrinterNumber : CARDINAL); 
VAR 
    S : ARRAY [0..6] OF CHAR; 
BEGIN 
    CardToString(Num,S,Width);
    PrintString(S,PrinterNumber); 
END PrintCard;


END Printer;
    (* -------------- End Module Printer ------------------- *) 




PROCEDURE NextDigit(VAR C : CHAR; VAR Carry : BOOLEAN );
BEGIN
    IF (C >= "0") AND (C < "9") THEN
        INC(C);
        Carry := FALSE;
    ELSE
        C := "0";
        Carry := TRUE;
    END;
END NextDigit;



PROCEDURE NextLetter(VAR C : CHAR; VAR Carry : BOOLEAN );
BEGIN
    C := CAP(C);
    Carry := FALSE;
    IF (C >= "0") AND (C <= "9") THEN
        NextDigit(C,Carry);
        IF (Carry) THEN
            C := "A";
            Carry := FALSE;
        END;
    ELSIF (C = "H") THEN       (* Skip I *)
        C := "J";
    ELSIF (C = "N") THEN       (* Skip O *)
        C := "P";
    ELSIF (C = "P") THEN       (* Skip Q *)
        C := "R";
    ELSIF (C >= "A") AND (C < "Z") THEN
        INC(C);
    ELSE
        C := "0";
        Carry := TRUE;
    END;
END NextLetter;



PROCEDURE BumpTag(VAR s:ARRAY OF CHAR);
VAR
    i,j,k : CARDINAL;
    Carry : BOOLEAN;
BEGIN
    i := ORD(s[0]);
    IF (i > HIGH(s)) THEN i := HIGH(s); END;
    j := i;
    Carry := TRUE;

    WHILE (i > 0) AND (Carry) DO
            (* Only allow letters in alternate pair positions. *)
        IF ( ((i-1) MOD 4) < 2 ) THEN
            NextLetter(s[i],Carry);
        ELSE
            NextDigit(s[i],Carry);
        END;
        IF (Carry) THEN
            FOR k := i TO j DO
                s[k] := "0";
            END;
            DEC(i);
        END;
    END;

    IF (i = 0) THEN
        InOut.WriteString('********** Problem--cannot make a new serial number after "');
        WriteString(s);
        InOut.WriteString('".');
        InOut.WriteLn;
        InOut.WriteLn;
        HALT;
    END;


END BumpTag;







PROCEDURE ReadString(VAR s:ARRAY OF CHAR; maxlen:CARDINAL);
CONST
    BackSpace = ASCII.bs;
VAR
    i : CARDINAL;
    C : CHAR;
BEGIN
    IF (maxlen > HIGH(s)) THEN maxlen := HIGH(s); END;
    i := 0;
    LOOP
        s[0] := CHR(i);
        InOut.Read(C);
        IF (C = BackSpace) THEN
            IF (i > 0) THEN
                InOut.Write(BackSpace);
                InOut.Write(" ");
                InOut.Write(BackSpace);
                DEC(i);
            END;
        ELSIF (C < " ") THEN
            EXIT;
        ELSIF (i >= maxlen) THEN
            InOut.Write(ASCII.bel);
        ELSE
            C := CAP(C);
            InOut.Write(C);
            INC(i);
            s[i] := C;
        END;
    END;
END ReadString;








PROCEDURE WriteString(VAR s:ARRAY OF CHAR);
VAR
    i : CARDINAL;
BEGIN
    FOR i := 1 TO ORD(s[0]) DO
        InOut.Write(s[i]);
    END;
END WriteString;





PROCEDURE GetTrailer( VAR TagString, Trailer : ARRAY OF CHAR );
VAR
    C, i, H : CARDINAL;
    s       : ARRAY [0..255] OF CHAR;
BEGIN
    s[0]  := 0C;
    FOR i := 1 TO ORD(ProductCode[0]) DO
        s[i] := ProductCode[i];
        INC( s[0] );
    END;
    C := ORD(s[0]);

    FOR i := 1 TO ORD(TagString[0]) DO
        s[C+i] := TagString[i];
        INC( s[0] );
    END;

    C := CheckSum( ADR(s[1]) ,ORD(s[0]));

    (* Convert C to 4 Hex digits *)
    Trailer[0] := 4C;  (* Trailer is 4 bytes *)
    FOR i := 4 TO 1 BY -1 DO
        H := C MOD 16;
        C := C DIV 16;
        IF (H < 10) THEN
            Trailer[ i ] := CHR(ORD("0") + H); (* Make them ascii/hex. *)
        ELSE
            Trailer[ i ] := CHR(ORD("A") + (H - 10)); (* Make them ascii/hex. *)
        END;
    END;

END GetTrailer;








PROCEDURE YesOrNo(    Prompt : ARRAY OF CHAR ) : BOOLEAN; 
VAR 
    S : ARRAY [0..30] OF CHAR;
BEGIN 
    InOut.WriteString(Prompt);
    LOOP
        InOut.WriteString(" (Yes or No) : "); 
        ReadString(S,HIGH(S));
        InOut.WriteLn;
        IF (S[0] > 0C) THEN 
            IF (CAP(S[1]) = "Y") THEN RETURN TRUE;
            ELSIF (CAP(S[1]) = "N") THEN RETURN FALSE;
            END;
        END;
        InOut.WriteString("               "); 
    END;
END YesOrNo;



PROCEDURE ItIsMagical() : BOOLEAN;

CONST  Incantation       = "SACHMO";
       IncantationLength = 6;

TYPE PSP = RECORD
                stuff: ARRAY [1..128] OF CHAR;
                size : ARRAY [0..1]   OF CHAR; (* Len and space. *)
                text : ARRAY [0..125] OF CHAR; (* start of param *)
           END;

VAR PSPPtr         : POINTER TO PSP;
    i              : CARDINAL;
    TheIncantation : ARRAY [0..IncantationLength] OF CHAR;
BEGIN
    PSPPtr         := PSPAddress;
    TheIncantation := Incantation;

    IF (ORD(PSPPtr^.size[0]) <> (IncantationLength + 1)) THEN
        RETURN FALSE;
    END;
    FOR i := 0 TO IncantationLength - 1 DO
        IF (CAP(PSPPtr^.text[i]) <> TheIncantation[i]) THEN
            RETURN FALSE;
        END;
    END;
    PSPPtr^.size[0] := 0C; (* So it is not seen by the InOut routines. *)
    PSPPtr^.size[1] := 0C; (* Add a null stopper *)
    InOut.WriteLn;
    InOut.WriteLn;
    InOut.WriteString("DANGER!!"); InOut.WriteLn;
    InOut.WriteLn;
    InOut.WriteString("Devestation mode selected!");
    InOut.WriteLn;
    InOut.WriteLn;
    RETURN YesOrNo("Did you REALY mean to select devestation mode?");

END ItIsMagical;




PROCEDURE DoSerialize();
BEGIN
    StartHigh := DefaultStartHigh;
    StartLow  := DefaultStartLow;

    InOut.WriteLn;
    InOut.WriteLn;
    InOut.WriteString("*** SERIAL NUMBER GENERATOR ***"); InOut.WriteLn;
    InOut.WriteString("Generate serial numbers for Time Line and Time Line Graphics");
    InOut.WriteLn;
    InOut.WriteLn;

    Magic := ItIsMagical();
    InOut.WriteLn;

    WhichProduct := 1;  (* Hard code TL only RSC 3/2/88 *)

    IF (WhichProduct = 2) THEN
        ProductCode := " TLGA3.00.";
    ELSE
        ProductCode := " TL-A3.00.";
    END;
    ProductCode[0] := CHR(ProductCodeLength);

    MaxTasks := 0;
    InOut.WriteLn;
    Limited := YesOrNo("Generate Limited Task   editions?");
    IF (Limited) THEN
        REPEAT
            InOut.WriteString("How many tasks maximum (10-990 by tens): ");
            InOut.ReadCard( MaxTasks ); 
            InOut.WriteLn;
        UNTIL (MaxTasks > 9) AND (MaxTasks < 991);
        MaxTasks := MaxTasks DIV 10;
    END;

    Promo := YesOrNo("Generate Not For Resale editions?");
    Beta  := YesOrNo("Generate Beta           editions?");
    LAN   := YesOrNo("Generate LAN Multi-User editions?");
    Educ  := YesOrNo("Generate Educational    editions?");
    IF (Educ AND (NOT Limited)) THEN
        Limited  := TRUE; (* Educ are ALWAYS limited! *)
        MaxTasks := 4;    (* 40 DIV 10 *)
    END;

    (* The Options byte is encoded as the letter 'A' + this bit configuration:

          1 = Programmer test mode
          2 = Limit the number of tasks
          3 = Is this a promotional version?
          4 = Is this a LAN Multi-User version?
          5 = Is this an educational version?

          3+5 = Beta edition.

          If {2,3,4} bits are ON, then the letter would be "O", confusing to
          be sure (O or 0?).  This combination is unlikely, however.
          The other possibility is the letter I (I or 1?), or just the
          Beta bit.  If it is I, make it a Z to be safe.  L is a programmer
          version, so we wont worry about that, and O is both PROMO and BETA,
          an unlikely event.  Fuck 'em.  Note that Educ/Beta/Promo versions
          are beyond the alphabet.  I guess this will work, but it'll look
          funny.

           Bad?   :                 *     *     *
           Letter : A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
          -------------------------------------------------------------
          Prog    :   Y   Y   Y   Y   Y   Y   Y   Y   Y   Y   Y   Y   Y
          Limit   :     Y Y     Y Y     Y Y     Y Y     Y Y   Y Y   Y Y
     Beta/Promo   :         Y Y Y Y         Y Y Y Y         Y Y Y Y
          LAN     :                 Y Y Y Y Y Y Y Y                 Y Y
     Beta/Educ    :                                 Y Y Y Y Y Y Y Y Y Y

          (NOTE: "Beta" is Promo + Educ!)
     *)

    ProductCode[ OptionsByte ] := CHR(  ORD(     "A"     )
                                     +  ORD(Magic        )
                                     + (ORD(Limited      ) *  2)
                                     + (ORD(Promo OR Beta) *  4)
                                     + (ORD(LAN          ) *  8)
                                     + (ORD(Educ  OR Beta) * 16)
                                     );
    IF (ProductCode[ OptionsByte ] = "I") THEN
        ProductCode[ OptionsByte ] := "Z"; (* Avoid confusion with "1" *)
    END;

    IF (Limited) THEN

      (* SINCE WE KNOW THAT MaxTasks IS IN THE RANGE 1-99, ADDING 100 WILL
         INSURE THAT Byte 0 is "1", Byte 1 is "0"-"9".  THIS IS A KLUGE,
         BUT IT WORKS, AS WE PLUG THE LENGTH BYTE BELOW!!
      *)

        CardToString( 100 + MaxTasks, TagString, 3 ); (* bytes 0 through 2 *)
        FOR i := 3 TO 6 DO
            TagString[i] := "0";
        END;
    ELSE
        TagString := " 000000";
    END;
    TagString[0] := 6C;

    InOut.WriteLn;
    InOut.WriteString("Starting serial number (");
    IF (Limited) THEN
        InOut.WriteString("4 chars): ");
        ReadString( s, 4 );
    ELSE
        InOut.WriteString("6 chars): ");
        ReadString( s, 6 );
    END;
    FOR i := 1 TO ORD(s[0]) DO
        TagString[(6-ORD(s[0])) + i] := s[i];
    END;
    InOut.WriteLn;

    InOut.WriteLn;
    InOut.WriteString("How many to generate: ");
    InOut.ReadCard( MaxSerialNumbers );
    InOut.WriteLn;
    InOut.WriteLn;
    IF (MaxSerialNumbers = 0) THEN
        RETURN;
    END;

    InOut.WriteString("We can print a list of all the serial numbers."); 
    InOut.WriteLn;
    InOut.WriteLn;

    LogPrinterOn := YesOrNo("Log serializations to printer?");

    IF (LogPrinterOn) THEN
        InOut.WriteString("What is the port number (0=AUX:, 1=PRN:)? ");
        InOut.ReadCard(LogPrinter); 
        InOut.WriteLn;
        REPEAT UNTIL YesOrNo("     Is the LOG printer Ready? ");
        PrintLn(LogPrinter);
        PrintLn(LogPrinter);
        PrintString("Log of serial numbers.",LogPrinter); 
        PrintLn(LogPrinter);
        PrintLn(LogPrinter);
        PrintString("Nmbr     Serial Number",LogPrinter);
        PrintLn(LogPrinter);
        PrintString("----     ----------------------",LogPrinter);
        PrintLn(LogPrinter);
    END;

    InOut.WriteLn;
    InOut.WriteLn;
    InOut.WriteString("We can make labels for all the serial numbers.");
    InOut.WriteLn;
    InOut.WriteLn;

    LabelPrinterOn := YesOrNo("Make labels?");

    IF (LabelPrinterOn) THEN
        InOut.WriteString("What is the port number (0=AUX:, 1=PRN:)? ");
        InOut.ReadCard(LabelPrinter); 
        InOut.WriteLn;
        REPEAT UNTIL YesOrNo("     Is the LABEL printer Ready? ");
        WHILE (YesOrNo("Align the printer?")) DO
            FOR i := 1 TO 10 DO
                PrintString("XX-X3.00.000000.XXXX",LabelPrinter);
                PrintLn(LabelPrinter);
                PrintLn(LabelPrinter);
                PrintLn(LabelPrinter);
                PrintString("XX-X3.00.000000.XXXX",LabelPrinter);
                PrintLn(LabelPrinter);
                PrintLn(LabelPrinter);
                PrintLn(LabelPrinter);
                PrintLn(LabelPrinter);
                PrintLn(LabelPrinter);
                PrintLn(LabelPrinter);
            END;
        END;
    END;

    FirstTagString := TagString;
    LastTagString[0] := 0C;
    Count            := 0;


    REPEAT
        IF (LogPrinterOn) THEN
            PrintCard(Count+1,4,LogPrinter);
            PrintString("     ",LogPrinter);
        END;

        GetTrailer(  TagString,Trailer   );

        WriteString(ProductCode);
        WriteString(TagString);
        InOut.WriteString(".");
        WriteString(Trailer);
        InOut.WriteLn;

        IF (LogPrinterOn) THEN
            PrintString("Serial ",LogPrinter);
            PrintLString(ProductCode,LogPrinter);
            PrintLString(TagString,LogPrinter); 
            PrintString(".",LogPrinter);
            PrintLString(Trailer,LogPrinter);
            PrintLn(LogPrinter);
        END;
        IF (LabelPrinterOn) THEN

        (* RSC 3/2/88 - Write two labels the same and then a blank label. *)

            FOR i := 1 TO 2 DO  (* Write 2 labels the same *)
                PrintLString(ProductCode,LabelPrinter);
                PrintLString(TagString,LabelPrinter); 
                PrintString(".",LabelPrinter);
                PrintLString(Trailer,LabelPrinter);
                PrintLn(LabelPrinter);
                PrintLn(LabelPrinter);
                PrintLn(LabelPrinter);
            END;
            PrintLn(LabelPrinter);
            PrintLn(LabelPrinter);
            PrintLn(LabelPrinter); (* Skip a label *)

        (* End of writing one label 'group' *)

        END;

        LastTagString := TagString; 
        BumpTag(TagString); 
        INC(Count); 
    UNTIL (Count = MaxSerialNumbers);

    IF (Count > 0) THEN
        InOut.WriteLn;
        InOut.WriteCard(Count,4); InOut.WriteString(" serial #s generated."); InOut.WriteLn;
        InOut.WriteLn;
        InOut.WriteString("Nos. "); WriteString(FirstTagString);
        InOut.WriteString(" through "); WriteString(LastTagString);
        InOut.WriteLn;
        InOut.WriteLn;
        InOut.WriteString("WRITE THOSE NUMBERS DOWN!");
        InOut.WriteLn;
        InOut.WriteLn;
    END;


    IF YesOrNo("Do you want a list of serial numbers on the LOG printer?") THEN 
        IF (NOT LogPrinterOn) THEN
            InOut.WriteString("What is the port number (0=AUX:, 1=PRN:)? ");
            InOut.ReadCard(LogPrinter); 
            InOut.WriteLn;
            REPEAT UNTIL YesOrNo("     Is the LOG printer Ready? ");
        END;
        InOut.WriteLn;
        TagString := FirstTagString;
        PrintLn(LogPrinter);
        PrintString("Recap of serial numbers.",LogPrinter); 
        PrintLn(LogPrinter);
        PrintLn(LogPrinter);
        PrintString("Disk     Serial",LogPrinter);
        PrintLn(LogPrinter);
        PrintString(" No.     Number",LogPrinter);
        PrintLn(LogPrinter);
        PrintString("----     ----------------------",LogPrinter);
        PrintLn(LogPrinter);
        FOR i := 1 TO Count DO
            PrintCard(i,4,LogPrinter);
            PrintString("     ",LogPrinter);
            PrintLString(ProductCode,LogPrinter);
            PrintLString(TagString,LogPrinter);
            PrintString(".",LogPrinter);
            GetTrailer(  TagString,Trailer   );
            PrintLString(Trailer,LogPrinter);
            PrintLn(LogPrinter);
            BumpTag(TagString);
       END;
        InOut.WriteLn;
        PrintLn(LogPrinter);
        PrintString("End of recap.",LogPrinter);
        PrintLn(LogPrinter);
    END;

    InOut.WriteLn;

END DoSerialize;




BEGIN
    DoSerialize();
END Serialize.
