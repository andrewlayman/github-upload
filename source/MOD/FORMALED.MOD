IMPLEMENTATION MODULE FormalEdgeName;

  (* Formal Edges Name - Routines to manage a cache of edges information.

        Modification History:

        30-Aug-89 MWP Creation.
        22-Sep-89 MWP Removed unnecessary call to GetEdgeColumnID.
  *)


FROM AllFormalName  IMPORT
    (* CONST *)             EdgesFile,
                            MaxCardinal,
    (* TYPE *)              AFormalName,
    (* VAR *)               Cache,
                            CacheContents,
                            CharTable,
    (* PROC *)              PurgeCache,
                            InitCache;

FROM Captions       IMPORT
    (* TYPE *)              AColumnInfoChoice, AColumnDataRecord;

FROM EdgeFormat      IMPORT
                            GetEdgeInfo;

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


PROCEDURE SetupEdgeCache () : BOOLEAN;
VAR
    DataRecord              : AColumnDataRecord;
    i                       : CARDINAL;
    ok                      : BOOLEAN;
BEGIN

    InitCache ();

    i := 1;

    REPEAT
        WITH Cache[i] DO
           ColumnID := i;

           ok := GetEdgeInfo( i, ColumnFormalName, 255, DataRecord);    (* 17-May-89 RSC *)

           WITH DataRecord DO
              LJust ( StringValue );
              TrimRear ( StringValue );

              (* For dBase records. Maximum formal name size will be 10 chars. *)
              IF ( LengthOf ( StringValue ) > 10 ) THEN
                 SetLengthOf ( StringValue, 10 );
              END;

              ConvertString ( StringValue, CharTable);            (* 4-Sep-89 MWP *)

              Copy ( StringValue, Name );
           END;

           ok := GetEdgeInfo( i, ColumnDataType, 255, DataRecord);    (* 17-May-89 RSC *)
           DataType    := ExportDataType ( DataRecord.CardinalValue );

        END;

        ok := GetEdgeInfo( i, ColumnNext, 1, DataRecord);      (* 22-Dec-88 LAA *)
        i := DataRecord.CardinalValue;

    UNTIL ( i = 0 );

    CacheContents := EdgesFile;

    RETURN TRUE;

END SetupEdgeCache;


PROCEDURE  CheckEdgeName ( VAR RangeName : ARRAY OF CHAR;
                           VAR DataFormat : CARDINAL;
                           VAR ID        : CARDINAL      ) : BOOLEAN;
VAR
    i  :  CARDINAL;
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

    IF ( CacheContents = EdgesFile ) THEN
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

END CheckEdgeName;


PROCEDURE FindEdgeName (     ID         : CARDINAL;               (* 29-Aug-89 MWP *)
                         VAR ColumnName : ARRAY OF CHAR ) : BOOLEAN;
VAR
    ok                      : BOOLEAN;
    DataRecord              : AColumnDataRecord;
BEGIN

    ok := TRUE;

    SetLengthOf ( ColumnName, 0 );

    ok := GetEdgeInfo( ID,
                       ColumnFormalName,
                       255,
                       DataRecord);

    IF ( ok ) THEN
        LJust ( DataRecord.StringValue );
        TrimRear ( DataRecord.StringValue );
        Copy ( DataRecord.StringValue, ColumnName );
        IF ( LengthOf ( ColumnName ) = 0 ) THEN
          ok := FALSE;
        END;
    END;

    RETURN ( ok );

END FindEdgeName;



BEGIN
END FormalEdgeName.
