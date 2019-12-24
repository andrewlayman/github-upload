MODULE TLGlue;

    (*  TLGlue -- Andrew Layman -- January 25, 1985.
               Modified April 9, 1985 to work as an overlay to
               Time Line. *)

    (* MODIFICATION HISTORY:

       Jun 20 1986  AJL - Closed the files in case of error
                          with writing the last buffer, such as
                          full disk.
       Feb  3 1988  RSC - Spike upgrade.
       Feb 24 1988  RSC - Handle DK: in Rename().
       Aug 10 1989  KKC   Add copyright message.
       10-Oct-89  MWP - Moved text literal to phrases file.
       10-Nov-89  EGK - Many changes in MakeTheTransformation to use the
                        TempFile module instead of Logitech's Create() to
                        use temporary files.
        7-Dec-89  RSC - CTRL-BREAK support (Bug # 1876).
       11-Dec-89  RSC - Son of CTRL-BREAK support.
    *)




FROM ASCII                  IMPORT
    (* CONST *)                 EOL;

FROM Dialog                 IMPORT
    (* PROC *)                  Message, Error, FatalError;

FROM Directory              IMPORT
    (* TYPE *)                  AFileNamePart, ASetOfFileNameParts,
    (* PROC *)                  NormalizeFileName, ExtractDeviceName;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response,
    (* PROC *)                  Lookup, Close, ReadChar, WriteChar,
                                SetPos, GetPos, Create, Delete, Rename;

FROM FileAux                IMPORT
    (* PROC *)                  PrepareForIO, CheckIO, FileResultMeans;

FROM Kbio                   IMPORT
    (* PROC *)                  BreakRequested;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, ConcatLS, ConcatS, CtoS,
                                LStringToTString, Copy;

FROM MsgFile                IMPORT
    (* PROC *)                 GetMessage, ConcatMessage;

FROM PrintStatic            IMPORT
    (* VAR *)                   PrintDiskFileName;

FROM TempFile               IMPORT
    (* PROC *)                  CreateTempFile, DeleteTempFile,
                                RenameTempFile;




CONST
    ModuleNumber = 9400;


TYPE
    AnInputProcedure  = PROCEDURE (VAR File,VAR CHAR):BOOLEAN;
    AnOutputProcedure = PROCEDURE (VAR File,CHAR):BOOLEAN;
    AFileName         = ARRAY [0..81] OF CHAR;



    (*----- The filter module ---------*)

MODULE FilterModule;


IMPORT AnInputProcedure, AnOutputProcedure,  File, Response,
       SetPos, GetPos, SetString, ConcatS, ConcatLS, CtoS,
       Message, Error, GetMessage, ConcatMessage, BreakRequested;
IMPORT EOL;
IMPORT ModuleNumber;

EXPORT FilterTheText;

CONST
    MaxPages     = 2000;
    FormFeed     = 14C;
VAR
    PageCount     : CARDINAL;        (* Count of total pages. *)
    MaxPageLength : CARDINAL;        (* Length of the longest page. *)
        (*  List of widths of the widest line on each page. *)
    PageWidth     : ARRAY [0..MaxPages-1] OF CARDINAL;
    PagePosHigh   : ARRAY [0..MaxPages-1] OF CARDINAL;
    PagePosLow    : ARRAY [0..MaxPages-1] OF CARDINAL;
    PageLength    : ARRAY [0..MaxPages-1] OF CARDINAL;

    (*  ComputeWidthsAndLengths -- This will make a pass through the
                                   file and return:
                                   (1) The length of the longest page.
                                   (2) The width of the widest line on
                                       each page.
                                   (3) The count of total pages, 0..n-1
                                   (4) The starting position of each page.
                                   (5) The number of lines on each page.
                                   *)

PROCEDURE ComputeWidthsAndLengths(VAR f:File; Input:AnInputProcedure);
VAR
    Width, Length : CARDINAL;
    PageIndex     : CARDINAL;   (* Local version of page count, with max. *)
    High, Low     : CARDINAL;
    Ch            : CHAR;
    S             : ARRAY [0..80] OF CHAR;
    S2            : ARRAY [0..11] OF CHAR;


BEGIN
    MaxPageLength := 0;
    PageCount := 0;
    Length := 0;
    Width  := 0;

    LOOP
        IF (BreakRequested()) THEN  (* RSC 12-7-89 *)
            EXIT;
        END;

        GetPos(f,High,Low);
        IF (NOT Input(f,Ch)) THEN EXIT; END;

        IF (Length = 0) THEN     (* A new page. *)
            INC(PageCount);
            PageIndex := PageCount - 1;
            IF (PageIndex < HIGH(PageWidth)) THEN
                    (* Initialize its width. *)
                PageWidth[PageIndex] := 0;
                PageLength[PageIndex] := 0;
                    (* Save this page's address. *)
                PagePosHigh[PageIndex] := High;
                PagePosLow[PageIndex]  := Low;
            ELSE
                GetMessage ( ModuleNumber, S );
                (* "Too many pages of input.  Max = *)
                CtoS(HIGH(PageWidth)+1,S2);
                ConcatLS(S,S2);
                Error(S);
                RETURN;  (* RSC 2/3/88 *)
            END;
            GetMessage ( ModuleNumber + 1, S );
            (* "Reading page " *)
            CtoS(PageCount,S2);
            ConcatLS(S,S2);
            Message(S);
        END;


        IF (Ch = FormFeed) THEN
            Length := 0;
            Width := 0;
        ELSE
            IF (Width = 0) THEN    (* A new line. *)
                INC(Length);
                PageLength[PageIndex] := Length;
                IF (MaxPageLength < Length) THEN
                    MaxPageLength := Length;
                END;
            END;

            IF (Ch = EOL) THEN
                Width := 0;
            ELSE
                INC(Width);
                IF (PageWidth[PageIndex] < Width) THEN
                    PageWidth[PageIndex] := Width;
                END;
            END;
        END;
    END;

END ComputeWidthsAndLengths;





PROCEDURE MakeOneLongPage(VAR f:File;Input:AnInputProcedure;
                          VAR of:File;Output:AnOutputProcedure);
VAR
    PageIndex,
    Page,
    Line,
    Width         : CARDINAL;
    Ch            : CHAR;
    S             : ARRAY [0..80] OF CHAR;
    S2            : ARRAY [0..11] OF CHAR;

BEGIN
    FOR Line := 1 TO MaxPageLength DO
        IF (BreakRequested()) THEN
            RETURN;
        END;
        GetMessage ( ModuleNumber + 2, S );
        (* "Writing line " *)
        CtoS(Line,S2);
        ConcatLS(S,S2);
        ConcatMessage ( S, ModuleNumber + 9 );
        (* " of " *)
        CtoS(MaxPageLength,S2);
        ConcatLS(S,S2);
        Message(S);
        SetPos(f,0,0);
        FOR Page := 1 TO PageCount DO
            PageIndex := Page - 1;

            IF (PageIndex > HIGH(PageWidth)) THEN
                PageIndex := HIGH(PageWidth);
            END;
                (* Find the correct line on this page. If there
                   isn't such a line on this page,
                   we will just emit pad characters
                   for the full page width. *)
            Width := 0;
            IF (Line <= PageLength[PageIndex]) THEN
                    (* Go to the next line on this page. *)
                SetPos(f,PagePosHigh[PageIndex],PagePosLow[PageIndex]);

                    (* Copy the line from input to output. *)
                LOOP
                    IF (NOT Input(f,Ch)) THEN EXIT; END;
                    IF (Ch = EOL) OR (Ch = FormFeed) THEN EXIT; END;
                    IF (NOT Output(of,Ch)) THEN RETURN; END;
                    INC(Width);
                END;
                    (* Save this page's next line position. *)
                GetPos(f,PagePosHigh[PageIndex],PagePosLow[PageIndex]);
            END;
                (* Pad it to the correct width for this page. *)
            WHILE (Width < PageWidth[PageIndex]) DO
                IF (NOT Output(of," ")) THEN RETURN; END;
                INC(Width);
            END;
        END;
        IF (NOT (Output(of,EOL))) THEN RETURN; END;
    END;
END MakeOneLongPage;




PROCEDURE FilterTheText(VAR f:File; Input: AnInputProcedure;
                        VAR of:File; Output : AnOutputProcedure);
BEGIN
    ComputeWidthsAndLengths(f,Input);
    IF (f.eof) THEN
        MakeOneLongPage(f,Input,of,Output);
    END;
END FilterTheText;



BEGIN
END FilterModule;

     (*------ End of filter module. -----------*)











    (* ************************* ControlModule ************************* *)

MODULE ControlModule;

  IMPORT AnInputProcedure, AnOutputProcedure, Close, Copy,
         File, Response, Lookup, AFileName, Create, Delete, Rename;

  IMPORT Message, Error, FatalError, SetString, ConcatLS, ConcatS,
         FileResultMeans, CheckIO, PrepareForIO, LStringToTString,
         PrintDiskFileName, ExtractDeviceName,GetMessage, ConcatMessage;

  IMPORT  FilterTheText, CloseOutputFile,
          AFileNamePart, ASetOfFileNameParts, NormalizeFileName,
          FlushTheOutputBuffer;

  IMPORT ModuleNumber;

  IMPORT CreateTempFile, DeleteTempFile, RenameTempFile, BreakRequested;


  EXPORT MakeTheTransformation;











PROCEDURE MakeTheTransformation(
                                InputProcedure:AnInputProcedure;
                                OutputProcedure:AnOutputProcedure
                               ):BOOLEAN;
VAR
    i   : CARDINAL;
    f   : File;
    of  : File;
    Res : Response;
    fn,
    ofn : AFileName;
    S   : ARRAY [0..180] OF CHAR;
    S2  : ARRAY [0..50] OF CHAR;
BEGIN
    Copy( PrintDiskFileName, S );  (* RSC 2/24/88 expand name *)
    NormalizeFileName( S, ASetOfFileNameParts{DevicePart..ExtensionPart} );
    LStringToTString(S, fn);
    Copy (S, ofn);                  (* 11/10/89 EGK *)

    IF (fn[0] = 0C) THEN
        RETURN FALSE;
    END;


    PrepareForIO(f);
    Lookup(f, fn, FALSE);
    Res := CheckIO(f);
    IF Res = done THEN

      IF (CreateTempFile (ofn, of)) THEN        (* 11/10/89 EGK *)

              (* Do the actual transformation work. *)
          FilterTheText(f,InputProcedure,of,OutputProcedure);
              (* Did it go ok? *)
          IF (of.res <> done) OR (BreakRequested()) THEN    (* 11-Dec-89 *)
              Close(f);
              DeleteTempFile (of);
              RETURN BreakRequested();                      (* 11-Dec-89 *)
          END;
              (* Now it is time to wrap it all up. *)
          IF (NOT FlushTheOutputBuffer(of)) THEN
              Close(f);
              DeleteTempFile (of);
              RETURN FALSE;
          END;
              (* If the output file is temporary and all i/o
                 was ok, rename files. *)
          Res := CheckIO(of);
          IF (Res = done) AND (f.eof OR (f.res = done))  THEN
              PrepareForIO(f);
              Close(f);
              Delete(fn,f);      (* Delete original file. *)
              Res := CheckIO(f);
              IF (Res = done) THEN
                  IF (NOT RenameTempFile (ofn, of)) THEN    (* 11/10/89 EGK *)
                      GetMessage ( ModuleNumber + 3, S );
                      (* "Cannot rename temp file to " *)
                      ConcatLS(S,PrintDiskFileName);
                      FileResultMeans(of,S2);
                      ConcatS(S, " ");
                      ConcatLS(S,S2);
                      Error(S);
                      DeleteTempFile (of);
                      RETURN FALSE;
                  END;
              ELSE
                  GetMessage ( ModuleNumber + 4, S );
                  (* "Cannot delete untransformed " *)
                  ConcatLS(S,PrintDiskFileName);
                  ConcatS(S, " ");
                  FileResultMeans(f,S2);
                  ConcatLS(S,S2);
                  Error(S);
                  DeleteTempFile (of);
                  RETURN FALSE;
              END;
          ELSE
              Close(f);

                (* Close the output file here ONLY because if the rename
                   succeeded, the file is already closed. -- 11/10/89 EGK *)

              IF (NOT CloseOutputFile(of)) THEN RETURN FALSE; END;
          END;

      ELSE
          GetMessage ( ModuleNumber + 5, S );
          (* "Cannot create temporary output file. " *)
          FileResultMeans(of,S2);
          ConcatLS(S,S2);
          Error(S);
          RETURN FALSE;
      END;
    ELSE
      GetMessage ( ModuleNumber + 6, S );
      (* "Cannot open the print file " *)
      ConcatLS(S,PrintDiskFileName);
      ConcatS(S,"  ");
      FileResultMeans(f,S2);        (* Was "of" -- 11/10/89 EGK *)
      ConcatLS(S,S2);
      Error(S);
      RETURN FALSE;
    END;

    RETURN TRUE;
END MakeTheTransformation;


BEGIN
END ControlModule;

    (*--------------------- End ControlModule --------------------*)







PROCEDURE ReadAnInputCharacter(VAR f:File;VAR C:CHAR):BOOLEAN;
VAR
    Res : Response;
    S   : ARRAY [0..80] OF CHAR;
    S2  : ARRAY [0..50] OF CHAR;
BEGIN
    PrepareForIO(f);
    ReadChar(f,C);
    Res := CheckIO(f);
    IF (f.eof) THEN
        RETURN FALSE;
    ELSIF (Res <> done) THEN
        GetMessage ( ModuleNumber + 7, S );
        (* "Input error" *)
        FileResultMeans(f,S2);
        ConcatLS(S,S2);
        Error(S);
        RETURN FALSE;
    END;
    RETURN TRUE;
END ReadAnInputCharacter;




    (* ------------ Output module ------------------ *)


MODULE OutputModule;

IMPORT WriteChar, File, Response,
       Close;

IMPORT Message, Error, FatalError, PrepareForIO, CheckIO, FileResultMeans,
       SetString, ConcatLS, ConcatS, GetMessage, ConcatMessage;

IMPORT ModuleNumber;

IMPORT DeleteTempFile;


EXPORT WriteAnOutputCharacter, FlushTheOutputBuffer, CloseOutputFile;



CONST
    K          = 1024;
    BufferSize = 1 * K;  (* was 8 * K - RSC 2/3/88 *)

TYPE
    ABufferIndex = [0..BufferSize-1];

VAR
    OutputBuffer : ARRAY ABufferIndex OF CHAR;
    BufferCount  : [0..BufferSize];




PROCEDURE ErrorHappened( VAR f : File ) : BOOLEAN;
VAR
    S   : ARRAY [0..80] OF CHAR;
    S2  : ARRAY [0..50] OF CHAR;
    Res : Response;
BEGIN
    Res := CheckIO(f);
    IF (Res <> done) THEN
        GetMessage ( ModuleNumber + 8, S );
        (* "Output error " *)
        FileResultMeans(f,S2);
        ConcatLS(S,S2);
        Error(S);
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END ErrorHappened;



PROCEDURE WriteAnOutputCharacter(VAR f:File;C:CHAR):BOOLEAN;
BEGIN
    IF (BufferCount >= BufferSize) THEN
        IF (NOT FlushTheOutputBuffer(f)) THEN RETURN FALSE; END;
    END;

    OutputBuffer[BufferCount] := C;
    INC(BufferCount);
    RETURN TRUE;
END WriteAnOutputCharacter;



PROCEDURE FlushTheOutputBuffer(VAR f:File):BOOLEAN;
VAR
    i : CARDINAL;
BEGIN
    i := 0;
    PrepareForIO(f);
    WHILE (i < BufferCount) DO
        WriteChar(f,OutputBuffer[i]);
        IF (ErrorHappened(f)) THEN
            RETURN FALSE;
        END;
        INC(i);
    END;
    BufferCount := 0;
    RETURN TRUE;
END FlushTheOutputBuffer;


PROCEDURE CloseOutputFile(VAR f:File):BOOLEAN;
VAR
    Copyright          : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    IF (NOT FlushTheOutputBuffer(f)) THEN RETURN FALSE; END;
    PrepareForIO(f);
    DeleteTempFile (f);             (* 11/10/89 EGK *)
    RETURN (NOT ErrorHappened(f));
END CloseOutputFile;




BEGIN
    BufferCount := 0;
END OutputModule;

    (* ------------ End of Output module ------------------ *)








BEGIN
    IF (MakeTheTransformation(ReadAnInputCharacter,
                              WriteAnOutputCharacter)
                            ) THEN
    END;
END TLGlue.
