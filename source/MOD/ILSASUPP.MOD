IMPLEMENTATION MODULE IlsaSupport;

(*  =========================================================================
    Last Edit : October 23, 1990 3:25PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Support routines for IlsaStatic

    MODIFICATION HISTORY:
        23-Aug-89 WKH   Initial Version
        24-Aug-89 WKH   Added module number
         3-Oct-90 DSL   Changed $ to % in filename for Unix
        24-Oct-90 RSC   Changed % to 4 in filename for Dos batch files.
    =========================================================================
*)

FROM Directory              IMPORT
    (* TYPE *)                  AFileAttribute, AFileAttributeSet,
    (* PROC *)                  FileLookupStart;

FROM IlsaStatic             IMPORT
    (* TYPE *)                  ATLGSConfigRecordPtr,
    (* PROC *)                  TLGSConfigRecord;

FROM LStrings               IMPORT
    (* PROC *)                  ConcatLS, LengthOf;

FROM Schedule               IMPORT
    (* VAR *)                   CurrentFileExtension;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  TextExists, LineExists, CopyLine;

CONST
    ModuleNumber            = 8600;

    (*  =====================================================================
        
        TLGSConfigIsCool - Determine if a graphics device has been configured

            Preconditions :
                None

            Postconditions :
                None

            Parameters :
                Input:

                Output:

        =====================================================================
    *)
PROCEDURE TLGSConfigIsCool() : BOOLEAN;
    
VAR
    i                       : CARDINAL;
    ConfigRecord            : ATLGSConfigRecordPtr;
    Attributes              : AFileAttributeSet;
    ParmFileName            : ARRAY[0..13] OF CHAR;
    s                       : ARRAY[0..79] OF CHAR;
    WeBeHappy               : BOOLEAN;

BEGIN (* Procedure TLGSConfigIsCool *)

    ConfigRecord := TLGSConfigRecord();
    WeBeHappy    := TRUE;   (* So I'm an optimist... *)

    WITH ConfigRecord^ DO
        IF (NOT TextExists(ConfigDescription)) THEN
            WeBeHappy := FALSE;
        ELSIF (NOT LineExists(ConfigDescription, 1)) THEN
            WeBeHappy:= FALSE;
        ELSE
            CopyLine(ConfigDescription, 1, ParmFileName);
            IF (LengthOf(ParmFileName) = 0) THEN
                WeBeHappy := FALSE;
            END;
        END;
    END;

    IF (WeBeHappy) THEN

            (* 23-Oct-90 RSC
            *)
        ConcatLS( ParmFileName, CurrentFileExtension );
        i := LengthOf( ParmFileName );

        ParmFileName[ i - 1 ] := "G";
        ParmFileName[ i     ] := "V";  (* ".4GV" *)

        Attributes := AFileAttributeSet{ReadOnlyAttribute, ArchiveAttribute};
        IF (NOT FileLookupStart(ParmFileName, 
                                s, 
                                Attributes)) THEN
            WeBeHappy := FALSE;
        END;
    END;

    RETURN WeBeHappy;

END TLGSConfigIsCool;


END IlsaSupport.


