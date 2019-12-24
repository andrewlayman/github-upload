IMPLEMENTATION MODULE FormalTaskName;

  (* Formal Task Name - Routines to manage a cache of task information.

        Modification History:

        30-Aug-89 MWP Creation.
        22-Sep-89 MWP Removed unnecessary call to GetTaskColumnID.
        25-Jun-91 RSC Speed up accessing by avoiding captions for the
                      formal name.  Use ColFind instead.
  *)


FROM AllFormalName  IMPORT
    (* CONST *)             TaskFile,
                            MaxCardinal,
    (* TYPE *)              AFormalName,
    (* VAR *)               Cache,
                            CacheContents,
                            CharTable,
    (* PROC *)              PurgeCache,
                            InitCache;

FROM Allocs         IMPORT
    (* TYPE *)              ATaskPtr;

FROM Captions       IMPORT
    (* TYPE *)              AColumnInfoChoice, AColumnDataRecord,
    (* VAR *)               GetColumnInfo;

FROM ColData        IMPORT
    (* TYPE *)          AColumnType;

FROM ColFind        IMPORT
    (* PROC *)          GetColumnItem;

FROM ColumnSupport  IMPORT
    (* CONST *)         FormalName;

FROM Foreign        IMPORT
    (* TYPE *)          ACharacterConversionTable,
    (* PROC *)          ConvertString;

FROM ImPorTable      IMPORT
      (* VAR *)             FileType;

FROM IntFileIO      IMPORT
                           ExportDataType;

FROM LStrings       IMPORT
    (* PROC *)              Upshift, TrimFront, TrimRear, Copy, Fill,
                            LJust, SetLengthOf, StringsEqual, LengthOf,
                            TStringToLString;



CONST
    ModuleNumber            = 19200;    (* List of TASK columns *)




    (* 25-Jun-91 RSC Speed up formal name searches by avoiding captions
                     for this data (which calls TLCAPTIONS)
    *)
PROCEDURE GetFormalName(     ColumnID         : CARDINAL;
                         VAR FormalNameString : ARRAY OF CHAR );
VAR
    CardinalValue : CARDINAL;
BEGIN

    GetColumnItem( ModuleNumber,
                   TaskColumnInfo,
                   ColumnID,
                   FormalName,
                   FALSE,
                   CardinalValue,
                   FormalNameString);

END GetFormalName;







PROCEDURE SetupTaskCache () : BOOLEAN;
VAR
    T                       : ATaskPtr;
    DataRecord              : AColumnDataRecord;
    i                       : CARDINAL;

BEGIN

    InitCache ();

    i := 1;
    T := NIL;

    REPEAT

        WITH Cache[i] DO
           ColumnID := i;

           WITH DataRecord DO

              GetFormalName( i, StringValue );

              (* For dBase records. Maximum formal name size will be 10 chars. *)
              IF ( LengthOf ( StringValue ) > 10 ) THEN
                 SetLengthOf ( StringValue, 10 );
              END;

              ConvertString ( StringValue, CharTable);            (* 4-Sep-89 MWP *)

              Copy ( StringValue, Name );
           END;

           GetColumnInfo ( NIL, T, i, ColumnDataType, 255, DataRecord );
           DataType    := ExportDataType ( DataRecord.CardinalValue );
        END;

        GetColumnInfo ( NIL, T, i, ColumnNext, 1, DataRecord );
        i := DataRecord.CardinalValue;
    UNTIL ( i = 0 );

    CacheContents := TaskFile;

    RETURN TRUE;

END SetupTaskCache;



PROCEDURE  CheckTaskName ( VAR RangeName  : ARRAY OF CHAR;
                           VAR DataFormat : CARDINAL;
                           VAR ID         : CARDINAL      ) : BOOLEAN;
VAR
    i     :  CARDINAL;
    Local :  ARRAY [0..255] OF CHAR;
BEGIN

    Copy ( RangeName, Local );
    LJust ( Local );
    TrimRear ( Local );
    Upshift ( Local );

    (* For dBase records. Maximum formal name size will be 10 chars. *)
    IF ( LengthOf ( Local ) > 10 ) THEN
       SetLengthOf ( Local, 10 );
    END;

    ConvertString ( Local, CharTable);            (* 4-Sep-89 MWP *)

    IF ( CacheContents = TaskFile ) THEN
       FOR i := 1 TO HIGH(Cache) DO
          WITH Cache[i] DO
             IF ( StringsEqual ( Local, Name ) ) THEN
                 ID := ColumnID;
                 DataFormat := DataType;
                 RETURN TRUE;
             END;
          END;
       END;
    END;

    RETURN FALSE;

END CheckTaskName;





PROCEDURE FindTaskName (     ID         : CARDINAL;               (* 29-Aug-89 MWP *)
                         VAR ColumnName : ARRAY OF CHAR ) : BOOLEAN;
BEGIN

    GetFormalName( ID, ColumnName );

    RETURN TRUE;

END FindTaskName;



END FormalTaskName.
