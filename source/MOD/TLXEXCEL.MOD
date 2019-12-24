MODULE TLXExcel;

(* 

    MODIFICATION HISTORY

    10-Aug-89 KKC   Add copyright message.
*)


FROM ExportLinkage          IMPORT
    (* VAR *)                   InterFile;

FROM FileAux                IMPORT
    (* PROC *)                  CheckIO;

FROM FileSystem             IMPORT
    (* TYPE *)                  File, Response;

FROM IntFileIO              IMPORT
    (* CONST *)                 OverallSubfileNumber,
    (* TYPE *)                  AnOverallRecord;

IMPORT ExcelExport;             (* Force this into this layer. *)

FROM LStrings               IMPORT
    (* PROC *)                  SetString;

FROM Overlays               IMPORT
    (* PROC *)                  CallOverlay;

FROM RecordIO               IMPORT
    (* PROC *)                  ReadRecordPreface, ReadRecordBody;

FROM Subfiles               IMPORT
    (* PROC *)                  StartFileInput, StartSubfileInput;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, SIZE;


VAR
    n           : CARDINAL;
    s           : ARRAY [0..10] OF CHAR;


PROCEDURE SkipRecordBody(VAR F      : File;
                             Length : CARDINAL );
VAR
    i : CARDINAL;
BEGIN
    ReadRecordBody(F,Length,ADR(i),0);
END SkipRecordBody;




PROCEDURE GetOverallInfo();

VAR
    Version         : CARDINAL;
    Type            : CARDINAL;
    Length          : CARDINAL;
    OverallRecord   : AnOverallRecord;
    Copyright       : ARRAY[0..50] OF CHAR;

BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    n := 0;

    IF (NOT StartFileInput (InterFile)) THEN
        RETURN;
    END;

    IF (NOT StartSubfileInput (InterFile, OverallSubfileNumber, Version)) THEN
        RETURN;
    END;

    LOOP
        ReadRecordPreface (InterFile, Type, Length);
        IF (CheckIO(InterFile) <> done) THEN EXIT; END;
        CASE Type OF
            1 :
                ReadRecordBody (InterFile, Length,
                                ADR(OverallRecord), SIZE(OverallRecord));
                n := OverallRecord.Dimensions;
        |   0FFH :
                EXIT;
        ELSE
            SkipRecordBody(InterFile,Length);
        END;
    END;

END GetOverallInfo;





BEGIN

    GetOverallInfo();

    CASE n OF
        1 :
            SetString (s, "TL1DXCEL");
    |   2 :
            SetString (s, "TL2DXCEL");
    ELSE
        RETURN;
    END;

    IF (CallOverlay(s)) THEN
    END;

END TLXExcel.
