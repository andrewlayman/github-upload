(*----------------------------------------------------------------------------
    MODIFICATION HISTORY 

    06/10/88 RSC    Created from DIRECT411.

----------------------------------------------------------------------------*)

    (*****************************************************************)
    (*                                                               *)
    (*    Pick Dirs.                                                 *)
    (*                                                               *)
    (*    Pick a directory from a picklist.                          *)
    (*                                                               *)
    (*    This module was added after Time Line 3.0 was released,    *)
    (*    and it should be a part of DIRECT411.  But isn't.          *)
    (*    Keep this in mind, as the interface to TLDIR411 is a real  *)
    (*    Kluge.  But that is what you have come to expect from me.  *)
    (*                                                               *)
    (*****************************************************************)

IMPLEMENTATION MODULE PickDirs;


FROM Direct411              IMPORT
        (* TYPES *)             AQualificationProcedure,
                                AnAssistanceFunction,
                                ATLDir411Interface,
        (* PROCS *)             AlwaysApprove;

FROM Directory              IMPORT
        (* TYPE *)              AFileNameRecord,
        (* PROCS *)             ExtractFileNameParts;

FROM SYSTEM                 IMPORT
        (* TYPE *)              ADR;

FROM LStrings               IMPORT
        (* PROCS *)             Insert, Copy, SetString, ConcatS, ConcatLS;

FROM Overlays               IMPORT
        (* PROCS *)             CallOverlayWithContext;

FROM Kbio                   IMPORT
        (* TYPE *)              ascreeny;




PROCEDURE FileNameToRecord( VAR PathIn : ARRAY OF CHAR;
                            VAR Record : AFileNameRecord );
VAR 
    s : ARRAY [0..99] OF CHAR;
BEGIN
    Copy(PathIn, s);
    IF (s[ORD(s[0])] <> "\") THEN
        ConcatS(s,"\");
    END;
    ConcatS(s,"*.*");
    WITH Record DO
        ExtractFileNameParts( s, Device, Path, FileName, Extension );
    END;
END FileNameToRecord;





PROCEDURE RecordToFileName( VAR Record  : AFileNameRecord;
                            VAR PathOut : ARRAY OF CHAR    );
BEGIN
    WITH Record DO
        Copy(     Device,   PathOut );
        ConcatLS( PathOut,  Path );
    END;
END RecordToFileName;



    (*  Input: FirstRow, LastRow : Rows to use for display.
               Title             : Caption for box, and for Help.
               Template          : Device:\Directory\ mask.

        Output:Template          : The actual device and directory.

         Returns TRUE iff a dir was chosen.

    *)

PROCEDURE PickDirectory( FirstRow,
                         LastRow       : ascreeny;
                     VAR TitleIn,
                         Template      : ARRAY OF CHAR ):BOOLEAN;
VAR
    i                 : CARDINAL;
    TLDir411Interface : ATLDir411Interface;
    s                 : ARRAY [0..29] OF CHAR;
BEGIN
    WITH TLDir411Interface DO
         IF (Template[ORD(Template[0])] <> "\") THEN
             ConcatS( Template, "\" );
         END;
         FileNameToRecord( Template, FileNameIn );

         Qualification   := AlwaysApprove;
         FirstY          := FirstRow;
         LastY           := LastRow;

         Copy( TitleIn,  Title );

         (* Make the cursor name the last directory path entry.  If any. *)

         CursorName[0] := 0C;
         i := ORD(FileNameIn.Path[0]);
         IF (FileNameIn.Path[i] = "\") THEN DEC(i); END;
         s[0] := 1C;  (* One char string *)

         WHILE (i > 0)                                 AND
               (FileNameIn.Path[i] <> "\")             AND
               (ORD(CursorName[0]) < HIGH(CursorName)) DO
             s[1] := FileNameIn.Path[i];
             Insert( CursorName, s, 1 );
             DEC(i);
         END;

         AllowWildcards  := TRUE;
         GiveAssistance  := FALSE; (* not for dirs *)

         WhichFunction   := DirectoryAssistance;

         ProcedureReturn := TRUE; (* !!!! THIS IS WHAT MAKES THIS A DIR ONLY
                                     SEARCH!!!!! *)
    END;

    SetString(s,"\TLFBASE(TLDIR411)");
    IF (NOT CallOverlayWithContext( s, ADR( TLDir411Interface ) ) ) THEN
        RETURN FALSE;
    END;

    WITH TLDir411Interface DO
        IF (NOT ProcedureReturn) THEN
            RecordToFileName( FileNameOut, Template );
        END;
        RETURN (NOT ProcedureReturn); (* FALSE <--> TRUE *)
    END;

END PickDirectory;


BEGIN
END PickDirs.
