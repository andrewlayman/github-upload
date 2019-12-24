MODULE VirCheck;

      (* Purpose : Check the TIMELINE.EXE file for virus corruption.
                   We do this by checking whether the start of the 
                   .exe file has a specific checksum, on the theory
                   that most virusses would need to modify the very
                   beginning of the .exe file, or at least the
                   load point.

                   Improvements would be to:

                   1.  Check that the code at the starting execution 
                       address is unmodified.

         Parameters (passed as an LString in the context area,
                    separated by commas):
             A.  CheckSum of the first 6000 bytes of the .EXE file.
             B.  File size, DIV 10000H
             C.  File size, MOD 10000H.

             As of Sept 19, 1991, these values are 56739,3,53288

         Effect: If the .exe file appears altered, then put up a warning.


         MODIFICATION HISTORY:

         Jan 15, 1990 AJL -- Original Version.


       *)




FROM CRC16 IMPORT
    (* PROC *)        CheckSum;

FROM Dialog IMPORT
    (* PROC *)        Message, Error;

FROM FileAux IMPORT
    (* VAR *)         EXEPath;

FROM FileOpen IMPORT
    (* PROC *)        RequestFileOpenReadOnly;

FROM FileSystem IMPORT
    (* TYPE *)        File, Response,
    (* PROC *)        Length, SetPos, ReadNBytes, Close;

FROM LStrings   IMPORT 
    (* PROC *)        SetString, ConcatS, ConcatLS, CtoS, StoC;

FROM Overlays   IMPORT
    (* PROC *)        OverlayContext;

FROM Paranoia       IMPORT
    (* TYPE *)          AProgramState,
    (* VAR  *)          InitializationOK, ProgramState;

FROM SegWords   IMPORT
    (* PROC *)        WordNumber;

FROM SYSTEM     IMPORT
    (* PROC *)        ADR, SIZE;



CONST
    SampleSize = 6000;

TYPE
    ASample = ARRAY [0..SampleSize-1] OF CHAR;


VAR
    f : File;
    S      : ARRAY [0..255] OF CHAR;
    SupposedToBe : ARRAY [1..4] OF CARDINAL;
    SPTR   : POINTER TO ARRAY [0..255] OF CHAR;  (* Context parameters. *)
    Clean  : BOOLEAN;



PROCEDURE GetParameters( VAR Parameters : ARRAY OF CARDINAL);
VAR
    i,j    : CARDINAL;
    S      : ARRAY [0..255] OF CHAR;
BEGIN
    FOR i := 1 TO HIGH(Parameters) DO
        WordNumber(SPTR^,i,S);
        j := 1;
        Parameters[i-1] := StoC(S,j);
    END;
END GetParameters;



PROCEDURE OpenTL( VAR f : File ): BOOLEAN;
VAR
    FileName: ARRAY [0..19] OF CHAR;
    Description : ARRAY [0..79] OF CHAR;
BEGIN
    SetString(FileName,"TIMELINE.EXE");
    SetString(Description,"Time Line EXE File");
    RETURN RequestFileOpenReadOnly(EXEPath,FileName,Description,f);
END OpenTL;


PROCEDURE TakeSample(VAR f : File; VAR Sample : ASample) : BOOLEAN;
VAR
    CountRead : CARDINAL;
BEGIN
    SetPos(f,0,0);
    ReadNBytes(f,ADR(Sample),HIGH(Sample)+1,CountRead);
    IF (CountRead = HIGH(Sample)+1) AND (f.res = done) THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END TakeSample;





PROCEDURE CheckTheStart(VAR f : File):BOOLEAN;
VAR
    Sum : CARDINAL;
    Sample : ASample;
    ok : BOOLEAN;
BEGIN
        (* If we cannot open the file, or read it, give up. *)
    ok := TRUE;
    IF (TakeSample(f,Sample)) THEN
        Sum := CheckSum(ADR(Sample),HIGH(Sample)+1);
        ok := (Sum = SupposedToBe[1]);
        IF (NOT ok) THEN
            VirusWarning("A",Sum);
        END;
    END;
    RETURN ok;

END CheckTheStart;


PROCEDURE CheckLength(VAR f : File):BOOLEAN;
VAR
    High, Low : CARDINAL;
    ok : BOOLEAN;
BEGIN
    Length(f,High,Low);
    ok := (High = SupposedToBe[2]);
    IF (NOT ok) THEN
        VirusWarning("B",High);
    END;
    ok := ok AND (Low  = SupposedToBe[3]);
    IF (NOT ok) THEN
        VirusWarning("C",Low);
    END;
    RETURN ok;
END CheckLength;



PROCEDURE VirusWarning(Code : CHAR; Sum : CARDINAL);
VAR
    S : ARRAY [0..255] OF CHAR;
    S2 : ARRAY [0..10] OF CHAR;
BEGIN
        (* Print the code to tell us what went wrong. *) 
    SetString(S,Code);
    CtoS(Sum,S2);
    ConcatLS(S,S2);
    Message(S);

    SetString(S,"Possible virus infection in Timeline.exe file.");
    Error(S);
    InitializationOK := FALSE;
END VirusWarning;
    




BEGIN
        (* Read our parameters and decode into an array of key numbers. *)
    SPTR := OverlayContext();
    GetParameters(SupposedToBe);


        (* Provided that we are successful at opening the .exe file,
           check key aspects of it against the parameters. *)

    IF (OpenTL(f)) THEN
        Clean := CheckLength(f);
        IF ( CheckTheStart(f) AND Clean) THEN
        ELSE
            (* Virus problem?  Parameters problem? *)
        END;
    END;
    Close(f); 
END VirCheck.
