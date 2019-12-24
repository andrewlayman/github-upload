IMPLEMENTATION MODULE FormalName;

  (* Formal Name

        Modification History:

        19-Jun-89 MWP In the beginning...
        26-Jul-89 MWP Added this section.
        27-Aug-89 MWP 'Cache' all formal names for rapid access by importers.
        29-Aug-89 MWP Allow retrieval of formal name based on ID.
        30-Aug-89 MWP Code cleanup.
  *)

FROM AllFormalName  IMPORT
    (* CONST *)             TaskFile,
                            ResourceFile,
                            AssFile,
                            EdgesFile,
                            MaxCardinal,
    (* TYPE *)              AFormalName,
    (* VAR *)               Cache,
                            CacheContents,
    (* PROC *)              PurgeCache,
                            InitCache;



FROM Allocs         IMPORT
    (* TYPE *)              ATaskPtr;

FROM Captions       IMPORT
    (* TYPE *)              AColumnInfoChoice, AColumnDataRecord;

FROM FormalTaskName  IMPORT
                            SetupTaskCache,
                            FindTaskName,
                            CheckTaskName;

FROM FormalRsrcName  IMPORT
                            SetupResourceCache,
                            FindResourceName,
                            CheckResourceName;

FROM FormalAssName   IMPORT
                            SetupAssCache,
                            FindAssName,
                            CheckAssName;

FROM FormalEdgeName  IMPORT
                            SetupEdgeCache,
                            FindEdgeName,
                            CheckEdgeName;

FROM ImPorTable      IMPORT
      (* VAR *)             FileType;

FROM IntFileIO      IMPORT
                           ExportDataType;

FROM LStrings       IMPORT
    (* PROC *)              Upshift, TrimFront, TrimRear, Copy, Fill,
                            LJust, SetLengthOf, StringsEqual, LengthOf,
                            TStringToLString;


PROCEDURE GetFormalNameInfo (  VAR FormalName : ARRAY OF CHAR;
                                   ReportType : CARDINAL;
                               VAR DataType   : CARDINAL;
                               VAR ColumnID   : CARDINAL ) : BOOLEAN;
VAR
    ok                      : BOOLEAN;
BEGIN

    CASE ReportType OF
         TaskFile     :
                      ok := CheckTaskName ( FormalName, DataType, ColumnID );
      |  ResourceFile :
                      ok := CheckResourceName ( FormalName, DataType, ColumnID );
      |  AssFile      :
                      ok := CheckAssName ( FormalName, DataType, ColumnID );
      |  EdgesFile    :
                      ok := CheckEdgeName ( FormalName, DataType, ColumnID );
    ELSE
       ok := FALSE;
    END;

    RETURN ok;

END GetFormalNameInfo;


PROCEDURE  IsFormalNameOurs ( VAR FormalName : ARRAY OF CHAR;
                              VAR DataType   : CARDINAL;
                                  ReportType : CARDINAL     ) : BOOLEAN;
VAR
    ok                      : BOOLEAN;
    ColumnID                : CARDINAL;
BEGIN

    LJust ( FormalName );
    TrimRear ( FormalName );
    Upshift ( FormalName );

    CASE ReportType OF
         TaskFile     :
                      ok := CheckTaskName ( FormalName, DataType, ColumnID );
      |  ResourceFile :
                      ok := CheckResourceName ( FormalName, DataType, ColumnID );
      |  AssFile      :
                      ok := CheckAssName ( FormalName, DataType, ColumnID );
      |  EdgesFile    :
                      ok := CheckEdgeName ( FormalName, DataType, ColumnID );
      ELSE
         ok := FALSE;
      END;

      RETURN ok;

END IsFormalNameOurs;


PROCEDURE SetupFormalNameCache ( ReportType : CARDINAL ) : BOOLEAN;
VAR
    ok                      : BOOLEAN;
BEGIN
    ok := TRUE;

    CASE ReportType OF
         TaskFile     :
                      ok := SetupTaskCache ();
      |  ResourceFile :
                      ok := SetupResourceCache ();
      |  AssFile      :
                      ok := SetupAssCache ();
      |  EdgesFile     :
                      ok := SetupEdgeCache ();
    ELSE
       ok := FALSE;
    END;

    RETURN ( ok );

END SetupFormalNameCache;

PROCEDURE FindFormalName (     ID         : CARDINAL;               (* 29-Aug-89 MWP *)
                               ReportType : CARDINAL;
                           VAR ColumnName : ARRAY OF CHAR ) : BOOLEAN;
VAR
    ok                      : BOOLEAN;
    T                       : ATaskPtr;
    DataRecord              : AColumnDataRecord;
BEGIN

    ok := TRUE;
    SetLengthOf ( ColumnName, 0 );

    CASE ReportType OF
         TaskFile     :
                      ok := FindTaskName ( ID, ColumnName );

      |  ResourceFile :
                      ok := FindResourceName ( ID, ColumnName );

      |  AssFile      :
                      ok := FindAssName ( ID, ColumnName );

      |  EdgesFile    :
                      ok := FindEdgeName ( ID, ColumnName );

    ELSE
       ok := FALSE;
    END;

    IF ( ok ) THEN
        LJust ( DataRecord.StringValue );
        TrimRear ( DataRecord.StringValue );
        Copy ( DataRecord.StringValue, ColumnName );
        IF ( LengthOf ( ColumnName ) = 0 ) THEN
          ok := FALSE;
        END;
    END;


    RETURN ( ok );

END FindFormalName;


BEGIN
    CacheContents := MaxCardinal;

END FormalName.
