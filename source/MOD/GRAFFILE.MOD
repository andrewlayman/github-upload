IMPLEMENTATION MODULE GrafFile;

    (*  MODIFICATION HISTORY
        30-Mar-89 LAA   Created this module to support TLG/S device
                        installation.

         7-Apr-89 RSC   Added a context to the "For All" call.
        23-Jun-89 LAA   Fixed a bug in ForAllGrafFileSections which was
                        causing the first section to be processed twice.
    *)

FROM ASCII                  IMPORT
    (* CONST *)                 EOL;

FROM FileAux                IMPORT
    (* PROC *)                  CheckIO;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response,
    (* PROC *)                  GetPos, SetPos, Reset, SetRead, SetWrite,
                                ReadChar, WriteChar, WriteNBytes, WriteByte;

FROM LStrings               IMPORT
    (* PROC *)                  Remove, CtoS, StoC, Fill, ConcatLS, Copy,
                                TrimFront, TrimRear, SetLengthOf, LengthOf;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, ADDRESS;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  CreateText, DiscardText, AppendLine, 
                                LineExists, TextExists, CopyLine;



CONST
    CtrlZ                   = 32C;
    SectionPreambleChar     = "$";
    CommentPreambleChar     = "-";





PROCEDURE ValidateFile(VAR F                : File);

BEGIN                       (* ValidateFile *)
END ValidateFile;





PROCEDURE EndOfFile(VAR F                   : File): BOOLEAN;

BEGIN                       (* EndOfFile *)

    RETURN (((F.res = notdone) OR (F.res = done)) AND (F.eof));

END EndOfFile;






PROCEDURE LineIsSectionHeader(VAR Line      : ARRAY OF CHAR;
                              VAR Section   : CARDINAL     ): BOOLEAN;

VAR
    i                       : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;
    Found                   : BOOLEAN;

BEGIN                       (* LineIsSectionHeader *)

    Copy(Line, s);
    TrimFront(s);
    Found := FALSE;
    IF ((LengthOf(s) > 1) AND (s[1] = SectionPreambleChar)) THEN
        Remove(s, 1, 1);
        i := 1;
        Section := StoC(s, i);
        Found := TRUE;
    END;

    RETURN Found;

END LineIsSectionHeader;





    (*  StartGrafFileInput --

        Call this procedure before using any procedure declared here 
        which reads from the GrafFile.

        Preconditions:
            The file must already be opened.

        Postconditions:
            Whatever conditioning of the file for use of other input
            procedure in this module will have been done.  TRUE will
            be returned if the file is available for input, FALSE 
            otherwise.
    *)

PROCEDURE StartGrafFileInput(VAR F          : File): BOOLEAN;

BEGIN                       (* StartGrafFileInput *)

    (*<DEBUGGING*)
    ValidateFile(F);
    (*DEBUGGING>*)

    Reset(F);
    SetRead(F);

    RETURN (CheckIO(F) = done);

END StartGrafFileInput;






    (*  ReadGrafFileLine --

        Read a line from the GrafFile into the given LString.

        Preconditions:
            StartGrafFileInput must have been called and returned TRUE,
            and EndGrafFileInput must not have yet been called.

        Postconditions:
            If TRUE is returned, a line of the GrafFile has been read, 
            and the file left positioned to read the next line.  Otherwise,
            there was either a file error, or there were no more lines
            to read.
    *)

PROCEDURE ReadGrafFileLine(VAR F            : File;
                           VAR Line         : ARRAY OF CHAR): BOOLEAN;


VAR
    i                       : CARDINAL;
    ch                      : CHAR;

BEGIN                       (* ReadGrafFileLine *)

    (*<DEBUGGING*)
    ValidateFile(F);
    (*DEBUGGING>*)

    i := 0;
    SetLengthOf(Line, 0);
    REPEAT
        ReadChar(F, ch);
        IF (CheckIO(F) <> done) THEN
            SetLengthOf(Line, i);
            RETURN ((i > 0) AND (EndOfFile(F)));
        END;
        IF (ch = 0C) THEN
            SetLengthOf(Line, i);
            RETURN (i > 0);
        END;

        IF (i < HIGH(Line)) THEN
            INC(i);
            Line[i] := ch;
        END;
    UNTIL (ch = EOL);
    SetLengthOf(Line, i - 1);

    RETURN TRUE;

END ReadGrafFileLine;





    (*  ReadGrafFileSection --

        Read the indicated GrafFile section, creating and returning 
        a Text containing all the lines in that section.

        Preconditions:
            StartGrafFileInput must have been called and returned TRUE,
            and EndGrafFileInput must not have yet been called.

        Postconditions:
            If TRUE is returned, all lines of the indicated
            section will be in the returned Text, each in its own line.
            If FALSE is returned, the Text will not have been created.
    *)

PROCEDURE ReadGrafFileSection(VAR F         : File;
                                  Section   : CARDINAL;
                              VAR Text      : AText   ): BOOLEAN;

VAR
    i                       : CARDINAL;
    HPos, LPos              : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;
    FirstTime               : BOOLEAN;
    ok                      : BOOLEAN;

BEGIN                       (* ReadGrafFileSection *)

    (*<DEBUGGING*)
    ValidateFile(F);
    (*DEBUGGING>*)

    Text := AText(NIL);

    FirstTime := TRUE;
    ok := TRUE;

        (*  Look for the section preamble  *)

    LOOP
        IF (NOT ReadGrafFileLine(F, s)) THEN
            IF ((EndOfFile(F)) AND (FirstTime)) THEN
                FirstTime := FALSE;
                SetPos(F, 0, 0);
            ELSE
                ok := FALSE;
                EXIT;
            END;
        END;
        IF ((LineIsSectionHeader(s, i)) AND (i = Section)) THEN
            EXIT;
        END;
    END;

        (*  If there is no Section 0, it's implied.  *)

    IF ((NOT ok) AND (Section = 0)) THEN                      
        SetPos(F, 0, 0);
        ok := TRUE;
    END;

    IF (ok) THEN
            (*  Found the section header line, now read the section  *)

        Text := CreateText();
        IF (Text = AText(NIL)) THEN
            ok := FALSE;
        ELSE
            LOOP
                GetPos(F, HPos, LPos);
                IF (NOT ReadGrafFileLine(F, s)) THEN
                    ok := EndOfFile(F);
                    EXIT;
                END;
                IF (LineIsSectionHeader(s, i)) THEN
                    SetPos(F, HPos, LPos);
                    EXIT;
                END;
                ok := AppendLine(s, Text);
                IF (NOT ok) THEN
                    DiscardText(Text);
                    EXIT;
                END;
            END;
        END;
    END;


    RETURN ok;

END ReadGrafFileSection;







    (*  ForAllGrafFileSections --

        Interate over all GrafFile sections, calling the supplied
        processing proc for each.

        Preconditions:
            StartGrafFileInput must have been called on this file, and
            this procedure must not previously have been called on the 
            file.  The GrafFile must NOT be modified by the processing
            proc.

        Postconditions:
            For each section of the GrafFile, the processing proc will
            have been called once.
    *)

PROCEDURE ForAllGrafFileSections(VAR F       : File;
                                     Process : AGrafFileProcessingProc;
                                     Context : ADDRESS  );

VAR
    i                       : CARDINAL;
    HPos, LPos              : CARDINAL;
    HBefore, LBefore        : CARDINAL;
    Section                 : CARDINAL;
    FirstLine               : BOOLEAN;
    s                       : ARRAY [0..255] OF CHAR;

BEGIN                       (* ForAllGrafFileSections *)

    (*<DEBUGGING*)
    ValidateFile(F);
    (*DEBUGGING>*)

    Section   := 0;
    FirstLine := TRUE;

    SetPos(F, 0, 0);

    LOOP
        GetPos(F, HBefore, LBefore);
        IF (NOT ReadGrafFileLine(F, s)) THEN
            EXIT;
        END;
   
        IF ((LineIsSectionHeader(s, Section)) OR (FirstLine)) THEN
            GetPos(F, HPos, LPos);
            SetPos(F, HBefore, LBefore);
            Process(F, Section, Context);
            SetPos(F, HPos, LPos);
        END;
        FirstLine := FALSE;
    END;

END ForAllGrafFileSections;





    (*  EndGrafFileInput --

        Terminate GrafFile access to the indicated file.  Do any clean-up
        necessary.

        Preconditions:
            StartGrafFileInput must have been called on this file, and
            this procedure must not previously have been called on the 
            file.

        Postconditions:
            Whatever cleanup is necessary will have been done.
    *)

PROCEDURE EndGrafFileInput(VAR F            : File);

BEGIN                       (* EndGrafFileInput *)

    (*<DEBUGGING*)
    ValidateFile(F);
    (*DEBUGGING>*)

END EndGrafFileInput;





    (*  StartGrafFileOutput --

        Prepare the given file for later calls to procedures which write
        sections to the GrafFile.

        Preconditions:
            The file must exist at the time this call is made.

        Postconditions:
            The file will be setup for writing, and for calls to procedures
            defined here which write sections to a GrafFile.  TRUE will be
            returned iff the file is ready to be written.
    *)

PROCEDURE StartGrafFileOutput(VAR F         : File): BOOLEAN;

BEGIN                       (* StartGrafFileOutput *)

    (*<DEBUGGING*)
    ValidateFile(F);
    (*DEBUGGING>*)

    SetWrite(F);

    RETURN (CheckIO(F) = done);

END StartGrafFileOutput;





    (*  WriteGrafFileLine --

        Write the given LString to the GrafFile at whatever the current
        file position is.

        Precondtions:
            StartGrafFileOutput must have been called for this file.

        Postconditions:
            The given line will be written to the GrafFile.  TRUE will
            be returned iff the line was written successfully.
    *)

PROCEDURE WriteGrafFileLine(VAR F           : File;
                            VAR Line        : ARRAY OF CHAR): BOOLEAN;

VAR
    i                       : CARDINAL;

BEGIN                       (* WriteGrafFileLine *)

    (*<DEBUGGING*)
    ValidateFile(F);
    (*DEBUGGING>*)

    WriteNBytes(F, ADR(Line[1]), LengthOf(Line), i);
    WriteChar(F, EOL);

    RETURN ((CheckIO(F) = done) AND (i = LengthOf(Line)));

END WriteGrafFileLine;




    (*  WriteGrafFileSection --

        Write the given Text to the GrafFile, as the indicated section.

        Preconditions:
            StartGrafFileOutput must have been called for this file.

        Postconditions:
            The given Text will have each of its lines written, in order,
            to the file, after the section identifier.  TRUE will be
            returned iff the section was written successfully.
    *)

PROCEDURE WriteGrafFileSection(    Text     : AText;
                                   Section  : CARDINAL;
                               VAR F        : File    ): BOOLEAN;

VAR
    i                       : CARDINAL;
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..5] OF CHAR;

BEGIN                       (* WriteGrafFileSection *)

    (*<DEBUGGING*)
    ValidateFile(F);
    (*DEBUGGING>*)

    IF (Section > 0) THEN
        Fill(s, SectionPreambleChar, 1);
        CtoS(Section, s2);
        ConcatLS(s, s2);
        IF (NOT WriteGrafFileLine(F, s)) THEN
            RETURN FALSE;
        END;
    END;

    IF (TextExists(Text)) THEN
        i := 0;
        WHILE (LineExists(Text, i)) DO
            CopyLine(Text, i, s);
            IF (NOT WriteGrafFileLine(F, s)) THEN
                RETURN FALSE;
            END;
            INC(i);
        END;
    END;

    RETURN (CheckIO(F) = done);

END WriteGrafFileSection;





    (*  EndGrafFileOutput --

        Terminate GrafFile access to the indicated file.  Do any clean-up
        necessary.

        Preconditions:
            StartGrafFileOutput must have been called on this file, and
            this procedure must not previously have been called on the 
            file.

        Postconditions:
            Whatever cleanup is necessary will have been done.
    *)

PROCEDURE EndGrafFileOutput(VAR F           : File);

BEGIN                       (* EndGrafFileOutput *)

    (*<DEBUGGING*)
    ValidateFile(F);
    (*DEBUGGING>*)


    WriteByte(F, CtrlZ);
    Reset(F);

END EndGrafFileOutput;




BEGIN                       (* GrafFile *)

END GrafFile.
