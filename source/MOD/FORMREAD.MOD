  (* ***********************************************************

             Form  Read  -  Form file Read routines.

    MODIFICATION HISTORY
    
    11/12/86 LAA    In ReadFormFromFile, replaced the explicit use of English
                    with a reference to a phrase, and added a call to 
                    PrepareForIO.  In CloseFile, also added a PrepareForIO.
    25-Jan-88 LAA   Modified for network support.
    13-Feb-88 AJL   Use DisplayFileError.
    10-Jan-89 RSC   Split out the root-only variables and code to FormStatic.
                    Changed Storage to Space.
     8-Feb-89 RSC   Added StartFileInput just prior to all StartSubfileInput
                    calls.  This is because Subfiles needs local initialization.
                    Added a one-form cache.
     6-Mar-89 RSC   Removed one-form cache.  It took up 4KB.
    13-Jun-89 RSC   1) Find form in the TextPath, not the OverlayPath.
                    2) Eliminate the "FormsFileShared" option.
    27-Jan-91 RSC   Removed redundant "StartFileInput" call.

    ************************************************************ *)


IMPLEMENTATION MODULE FormRead;


FROM Dialog         IMPORT Error, FatalError, MessageWithPriority;

FROM FileAux        IMPORT DisplayFileError, PrepareForIO, CheckIO,
                           TextPath;

FROM FileOpen       IMPORT RequestFileOpenReadOnly;

FROM FileSystem     IMPORT File, Response, ReadWord, SetPos, GetPos,
                           ReadNBytes, Close;

FROM FormRec        IMPORT AFormRecord, AFormField, AFormRecordPointer;

FROM FormStatic     IMPORT
    (* VARS *)             FormFile, FormFileName, FormFileIsOpen;

FROM LStrings       IMPORT SetString, Fill, ConcatS, ConcatLS, CtoS, Compare,
                           SubStr;

FROM MsgFile        IMPORT GetMessage;

FROM SYSTEM         IMPORT TSIZE, SIZE, ADR, DOSCALL;

FROM Subfiles       IMPORT
     (* PROCS *)       StartFileInput, StartSubfileInput;

FROM RecordIO       IMPORT 
     (* PROCS *)       ReadRecord, ReadString;
                       



(* *************************************************************** *)



CONST
    DiskReset    = 0DH;  (* MS-DOS Disk Reset function number. *)
    ModuleNumber = 2100; (* For GetMessage *)


    FormsVersion = 7228; (* Synch with PutForms *)
    BodyType     = 1;
    TextType     = 2;
    FieldType    = 3;




PROCEDURE CheckFileError( f:File );
VAR
   s : ARRAY [0..80] OF CHAR;
BEGIN
    IF (CheckIO(f) <> done) THEN
        GetMessage(ModuleNumber+1,s);  (* "Forms file" *)
        DisplayFileError(f,s);
        Close(f);
        FormFileIsOpen := FALSE;
    END
END CheckFileError;








     (*  OPENFORMS *)

PROCEDURE OpenForms ():BOOLEAN;

VAR
    i,j                     : CARDINAL;
    Description             : ARRAY [0..255] OF CHAR;

BEGIN                       (* OpenForms *)

    CloseForms();   (* RSC 1/10/89 *)

    GetMessage(ModuleNumber+2,Description);   (*  "Time Line SYSTEM RUN disk"  *)
    FormFileIsOpen := (RequestFileOpenReadOnly(TextPath,FormFileName,Description,FormFile));

    RETURN (FormFileIsOpen AND StartFileInput(FormFile));

END OpenForms;




     (*  CLOSEFORMS *)





PROCEDURE CloseForms;
BEGIN
    IF (FormFileIsOpen) THEN
        PrepareForIO(FormFile);                                    (* 11/12/86 LAA *)
        Close(FormFile);
        CheckFileError(FormFile);
        FormFileIsOpen := FALSE;
    END
END CloseForms;










    (* GetFormRecordByNumber
               -- Get the identified form into the buffer.
                  *)

PROCEDURE GetFormRecordByNumber(FormID:CARDINAL; VAR FormRecord:AFormRecord): BOOLEAN;
CONST
    RetryLimit = 4;
VAR
    i           : CARDINAL;
    RetryCount  : CARDINAL;
    OK          : BOOLEAN;
    s           : ARRAY [0..50] OF CHAR;
BEGIN

        (* Try several times to read from the file.  This is because
           we keep this file open all the time, but if the user tries
           switching disks on us, we want to be able to recover. *)

    RetryCount := RetryLimit;
    LOOP


        FormRecord.ID := 0FFFEH;

        IF (NOT FormFileIsOpen) THEN
            IF (NOT OpenForms()) THEN
                RETURN FALSE;
            END;
        END;

        IF ReadFormFromFile( FormFile, FormID, FormRecord) THEN
            EXIT;
        ELSE
            IF (RetryCount = 0) THEN
                IF (CheckIO(FormFile) <> done) THEN
                    CheckFileError(FormFile);
                ELSE
                    GetMessage(ModuleNumber+4,s);   (*  "Bad Form File"  *)
                    Error(s);
                END; (* If a file error resulted *)
                RETURN FALSE;
            ELSE
                CloseForms;
                DOSCALL(DiskReset);   (* Attempt to force directory re-read. *)
                DEC(RetryCount);
            END;
        END; (* If there was trouble reading the form. *)
    END;

    Fill(s," ",0);
    MessageWithPriority(s,3);

    RETURN TRUE;

END GetFormRecordByNumber;







    (* Read a form from the form file.  Form.ID must be filled in. *)

PROCEDURE ReadFormFromFile( VAR FormFile   : File;
                                FormID     : CARDINAL;
                            VAR FormRecord : AFormRecord ) : BOOLEAN;
VAR
    Version,
    Type,    
    Loop,
    NumberOfFields,
    Length  : CARDINAL;
BEGIN

    IF (NOT StartSubfileInput( FormFile, FormID, Version ))  OR
       (Version <> FormsVersion)                             THEN
        RETURN FALSE;
    END;
    Length := (SIZE(FormRecord) - SIZE(FormRecord.FLine)
             - SIZE(FormRecord.Fields));
    ReadRecord( FormFile, Type, ADR(FormRecord), Length );
    IF Type <> BodyType THEN
        RETURN FALSE;
    END;
    WITH FormRecord DO

        IF MaxField <= Table.StartField THEN
            NumberOfFields := MaxField + 1; (* MaxField = 0..n-1 *)
        ELSE
            NumberOfFields := Table.StartField + 
                              Table.MinorSize;
        END;

        FOR Loop := 0 TO MaxLine DO
            ReadString( FormFile, FLine[Loop] );
        END;
        IF NumberOfFields > 0 THEN
            FOR Loop := 0 TO NumberOfFields - 1 DO
                ReadRecord( FormFile, Type, 
                            ADR(Fields[Loop]), TSIZE(AFormField) );
                IF Type <> FieldType THEN
                    RETURN FALSE;
                END;
            END;
        END;
    END;
    RETURN TRUE;
END ReadFormFromFile;


END FormRead.
