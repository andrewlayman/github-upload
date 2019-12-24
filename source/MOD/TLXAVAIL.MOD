MODULE TLXAvail;  (* Export Availabilities *)

(*V1=TRACE*)


  (* TL X Avail - Export Resource Availabilities

                  Link to TLRPBase (as of Feb-91).

                  There is fairly similar code to this in TLXAvail,
                  TLXCALND, TLXRates and TLXVaryA; so if you change one, you 
                  may need to apply similar changes to these other
                  exporters.

        MODIFICATION HISTORY:

        AJL 17-Feb-91  First version.
        AJL  8-Apr-91  Get error message 24613 from phrases file.
   *)


FROM Allocs        IMPORT
    (* TYPE *)          ATaskFilter, ATaskFilterSet;


FROM BigTimeU      IMPORT
    (* TYPE *)          ABigTime,
    (* VAR  *)          MINBIGTIME, MAXBIGTIME;

FROM Captions      IMPORT
    (* TYPE *)         AColumnInfoChoice, AColumnDataRecord;

FROM ColData       IMPORT
    (* TYPE *)         AColumnType;            (* 26-Sep-90 PFG  *)

FROM DateLists     IMPORT
    (* TYPE *)         ADateList,
    (* PROC *)         NumberOfDatesInList, GetDateListEntry;

FROM Dialog        IMPORT
    (* PROC *)         FatalError;

FROM ExportLinkage  IMPORT
    (* VAR *)           InterFile, InterFileOpen;

FROM FileSystem    IMPORT
        (* TYPE *)      Response;

FROM FileAux       IMPORT
        (* PROCS *)     CheckIO, DisplayFileError;

FROM Filter1       IMPORT
        (* PROC *)      ResourceFiltersPassed;

FROM FlexStor      IMPORT
        (* TYPE *)      AnExtHandle,
        (* PROC *)      ReleaseUnchangedObject, LockObjectArray;

FROM FormatCommon  IMPORT
    (* PROC *)         ColumnInfo, GetValueInfo;

FROM IntFileIO     IMPORT
    (* CONST *)         OverallSubfileNumber, PredicateSubfileNumber,
                        TextType, RealNumberType, IntegerType,
                        CardinalType, BooleanType,
                        HeadingRecordType, SkipRecordType,
    (* TYPE *)          AHeadingRecord, AnIntDataRecord,
    (* PROC *)          WriteIntData,
                        ConvertCaptionsToIntermediate;

FROM LStrings      IMPORT
        (* PROCS *)     CtoS, SetString, LJust, Copy, TrimRear, Procustes,
                        LStringToTString, SetLengthOf, LengthOf, ConcatLS,
                        StoC, ConcatS, TrimFront, Compare;

FROM MsgFile       IMPORT
        (* PROCS *)     GetMessage;

FROM Overlays      IMPORT
        (* VARS  *)     PackageOK,
        (* PROCS *)     OverlayContext;

FROM Progress      IMPORT
        (* TYPE *)      AThermometer,
        (* PROCS *)     CreateThermometer, UpdateThermometer,
                        DiscardThermometer;

FROM RecordIO      IMPORT
        (* PROCS *)     WriteRecord;

FROM ResCalUI      IMPORT
    (* TYPE *)         AnAvailabilityRate;

FROM RptCommon     IMPORT
        (* TYPES *)     AColumn, AGetInfoProc,
        (* PROCS *)     GenerateFileTrailers, ReleaseDialog,
                        GenerateFileHeaders,  DoDialog,
                        CreateTheFile, 
                        CommonCleanup;

FROM RsrcMod       IMPORT
    (* CONST *)         DefaultAvailabilityAmount,
                        DefaultAvailabilityPercent,
    (* TYPE *)          AResourcePointer, AResourceType,
    (* VAR *)           ResourceTree,
    (* PROC *)          CheckResourceValid;

FROM Subfiles      IMPORT
        (* PROCS *)     StartSubfileOutput, EndSubfileOutput;

FROM SYSTEM        IMPORT
        (* THINGS *)    SIZE, TSIZE, ADDRESS, ADR;

FROM TempFile      IMPORT
    (* PROC *)         DeleteTempFile;

FROM TimeFormat    IMPORT
    (* TYPE *)         ADateDisplayOption,
    (* VAR *)          DefaultDateOption, DefaultDateFormat,
                       DefaultTimeFormat, DefaultDateAndTimeFormat,
    (* PROC *)         TimeStringLength;

FROM TreeObjects   IMPORT
        (* TYPE *)      ATreeNode, ATreeOrder,
        (* PROCS *)     ValidateTree, ValidateTreeNode;

FROM Words          IMPORT
        (* PROC *)      ParseString;


(*<TRACE
FROM Tracer IMPORT PrintString, EndTrace;
VAR
    TraceS, TraceS2 : ARRAY [0..255] OF CHAR;
TRACE>*)




CONST   ModuleNumber     = 30000;  (* For GetMessage *)
        OverallPhrase    = ModuleNumber +  9;      (* Phrase describing the table. *)
        ColumnBaseMessage= ModuleNumber + 10 - 1;  (* Phrases that define columns. *)
        DomainBaseMessage= ModuleNumber + 30;      (* Phrase defining table type. *)

        OneHundred       = 100.0;



        (* Subfile IO version number:   *)

        VersionNumber  = 1; (* For subfiles *)

            (* Identifying numbers for each availability column. *)

        ResourceNameColumn = 1;
        StartDateColumn    = 2;
        EndDateColumn      = 3;
        AvailabilityColumn = 4;
        PercentColumn      = 5;

        MaxReportColumns   = 5;

        (* Font constants for printing *)

        NormalFont = 0C;
        BoldFont   = 1C;



VAR
    Columns                 : ARRAY [1..MaxReportColumns] OF AColumn;
    CallerIsExporter        : BOOLEAN;

    Thermometer  : AThermometer;








(*
    Get Avail Info

        Preconditions
                        > ColumnID  is the column to return information about.

                        > InfoChoice is the kind of information you are
                          interested in.  See Captions.Def for the choices.

                        > Length is the length of the string to return,
                          important mostly for Right Justified strings.

        Postconditions
                        > If TRUE, InfoValue contains the desired information.
                          If a string value is being returned, it may be right
                          justified, and is always exactly "Length" bytes long.

                        > If FALSE, The column does not exist.  This allows
                          looking for information on ALL columns.
*)
PROCEDURE GetAvailInfo(     ColumnID      : CARDINAL;
                            InfoChoice    : AColumnInfoChoice;
                            Length        : CARDINAL;
                        VAR InfoValue     : AColumnDataRecord) : BOOLEAN;
BEGIN
    IF (ColumnID > MaxReportColumns) THEN
        RETURN FALSE;
    ELSE
        ColumnInfo( ColumnBaseMessage,
                    ColumnID,
                    MaxReportColumns,
                    InfoChoice, 
                    Length, 
                    NotEditableColumn,          (* 26-Sep-90 PFG *)
                    InfoValue );
        RETURN TRUE;
    END;
END GetAvailInfo;








(*
    Get Avail Value

        Preconditions
                        > Resource is a pointer to a resource record.

                        > EndDate and StartDate are dates, with
                          StartDate < EndDate, and StartDate = the
                          EndDate the last time this procedure was 
                          called for this resource.

                        > ColumnID  is the column to return information about.

        Postconditions
                        > If TRUE, Value contains the desired information.

                        > If FALSE, The column data is not applicable.
*)
PROCEDURE GetAvailValue(    Resource     : AResourcePointer;
                            StartDate,
                            EndDate      : ABigTime;
                            Rate         : AnAvailabilityRate;
                            ColumnID     : CARDINAL;
                        VAR Value        : AColumnDataRecord)
                                                              : BOOLEAN;
VAR
    ok                  : BOOLEAN;
BEGIN

    ok  := TRUE;

    WITH Value DO
        GetValueInfo( ColumnBaseMessage + ColumnID, DataType, DataFields );
        CASE ColumnID OF
          ResourceNameColumn :
                Copy( Resource^.Name, StringValue );
        | StartDateColumn :
                BigTimeValue  := StartDate;
        | EndDateColumn :
                BigTimeValue  := EndDate;
        | AvailabilityColumn :
                CardinalValue := Rate.Amount;
        | PercentColumn :
                RealValue := FLOAT(Rate.Percent)/OneHundred;

        ELSE
            FatalError();  (* New column added? *)
        END;
    END;

    RETURN ok;

END GetAvailValue;



















 (* Column Data - Given a resource, date range and rate,
                  return a single data item.

        Preconditions  - 
                        > Resource is a pointer to a resource record.

                        > EndDate and StartDate are dates, with
                          StartDate < EndDate, and StartDate = the
                          EndDate the last time this procedure was 
                          called for this resource.

                        > Column is the column number, one of the constants
                                   defined above.
                        > Width  is the maximum width of the resulting
                                   (string) field.
        Postconditions - DataType is the returned data type.
                         TheData  is a record containing the returned item.
 *)
PROCEDURE ColumnData (     Resource     : AResourcePointer;
                           StartDate,
                           EndDate      : ABigTime;
                           Rate         : AnAvailabilityRate;
                           Column   : CARDINAL;
                           Width    : CARDINAL; (* for strings only. *)
                       VAR DataType : CARDINAL;
                       VAR TheData  : AnIntDataRecord;
                           Font     : CHAR);
VAR
    Value   : AColumnDataRecord;
BEGIN

    DataType := MAX(CARDINAL);        (* 1-May-89 MWP *)

    IF (GetAvailValue( Resource, StartDate, EndDate, Rate, Column, Value)) THEN
        TheData.Font := Font;           (* 5/30/89 EGK *)
        ConvertCaptionsToIntermediate( Value, Width, DataType, TheData );
    END;

END ColumnData;









 (* GenerateOneAvailData - create the data records for availability entry.

        Preconditions  - 
                        > Resource is a pointer to a resource record.

                        > EndDate and StartDate are dates, with
                          StartDate < EndDate, and StartDate = the
                          EndDate the last time this procedure was 
                          called for this resource.

        Postconditions - one or more data records have been written to the file.
 *)
PROCEDURE GenerateOneAvailData( Resource     : AResourcePointer;
                                StartDate,
                                EndDate      : ABigTime;
                                Rate         : AnAvailabilityRate;
                                OutputFont   : CHAR);
VAR
    DataType,
    Loop           : CARDINAL;
    DataRecord     : AnIntDataRecord;
BEGIN
    FOR Loop := 1 TO MaxReportColumns DO
        ColumnData( Resource, StartDate, EndDate, Rate,
                    Columns[ Loop ].ColumnNumber,
                    Columns[ Loop ].Width,
                    DataType,
                    DataRecord,
                    OutputFont);
        IF (DataType = MAX(CARDINAL)) THEN
            WriteIntData( SkipRecordType, DataRecord );
        ELSE
            WriteIntData( DataType, DataRecord );
        END;
    END;
END GenerateOneAvailData;



    (* GenerateOneAvailabilityList --

       Preconditions -- The subfile is correctly positioned and written
                        so that it is at the start of a data row.

                        Context is the address of a CARDINAL number.

       Postconditions --

                        For each entry in the availability list of the
                        resource, a row of data records is written to the
                        output file.

                        The CARDINAL addressed by Context^ is incremented
                        for each row.

                        The global thermometer is updated.

    *)


PROCEDURE GenerateOneAvailabilityList( VAR ResourceNode : ATreeNode;
                                           Context : ADDRESS );
VAR
    Resource        : AResourcePointer;
    FilterSet       : ATaskFilterSet;
    HighlightFilters: ATaskFilterSet;
    Counter         : POINTER TO CARDINAL;
    StartDate,
    EndDate         : ABigTime;
    Rate            : AnAvailabilityRate;
    i               : CARDINAL;
    Font            : CHAR;
BEGIN
    FilterSet := ResourceFiltersPassed(ResourceNode);
    IF (NOT ( Selected IN  FilterSet)) THEN
        RETURN;
    END;


    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );

    IF (Resource^.Type <> Employable) THEN
        RETURN;
    END;

    HighlightFilters := (FilterSet * ATaskFilterSet{Highlight1..Highlight5});
    IF (HighlightFilters <> ATaskFilterSet{}) THEN
        Font     := BoldFont;
    ELSE
        Font     := NormalFont;
    END;
         (*<TRACE
         SetString(TraceS,"Now in GenerateOneAvailList, Resource =");
         ConcatLS(TraceS,Resource^.Name);
         ConcatS(TraceS,", Font = ");
         CtoS(ORD(Font),TraceS2);  ConcatLS(TraceS,TraceS2);
         PrintString(TraceS);
         TRACE>*)

        (* Update the progress counter showing how many resources we
           have output. *)
    Counter  := Context;
    INC(Counter^);
    UpdateThermometer( Thermometer, Counter^ );

        (* Write out the availability records for this resource. *)

    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );
    IF (Resource^.Availability = ADateList(NIL)) THEN
        Rate.Amount  := DefaultAvailabilityAmount;
        Rate.Percent := DefaultAvailabilityPercent;
        GenerateOneAvailData( Resource, 
                              MINBIGTIME, MAXBIGTIME, Rate, Font);
    ELSE
        i := 1;
        WHILE (GetDateListEntry( Resource^.Availability, i,
                                 StartDate, EndDate, Rate )) DO
            GenerateOneAvailData( Resource, StartDate, EndDate, Rate, Font);
            INC(i);
        END;
    END;
END GenerateOneAvailabilityList;








PROCEDURE FileComplaint();
VAR
    s : ARRAY [0..51] OF CHAR;
BEGIN
    GetMessage(24613,s);               (* "Export Interpass File" *)
    DisplayFileError(InterFile,s);
END FileComplaint;



  (* Generate the headers for the availability list attached to this resource. *)

PROCEDURE DoAvailHeader( VAR ResourceNode : ATreeNode;
                                IDContext    : ADDRESS    );
VAR
    DataRecord     : AnIntDataRecord;
    HeadingRecord  : AHeadingRecord;
    Resource       : AResourcePointer;
    s              : ARRAY [0..255] OF CHAR;
    s5             : ARRAY [0..5] OF CHAR;
    StartDate,
    EndDate        : ABigTime;
    Rate            : AnAvailabilityRate;
    i              : CARDINAL;
    ID             : POINTER TO CARDINAL;

    PROCEDURE WriteHeadRecord( i : CARDINAL);
    BEGIN
        INC( ID^ );
        WITH HeadingRecord DO
            UniqueID        := ID^;
            HeadingDepth    := 1;  (* just the name *)
            DataIndentation := 0;  (* levels indented.  0 for all resources *)
            Summary         := FALSE; (* resources are never summaries. *)
        END;
        WriteRecord( InterFile, HeadingRecordType,
                     ADR(HeadingRecord), SIZE(HeadingRecord) );
            (* Identify this row. *)
        WITH DataRecord DO
            Font := NormalFont;
            Copy( Resource^.Name, s );
            TrimRear(s);
            (*
            ConcatS( s, "/" );
            CtoS(i,s5);
            ConcatLS(s, s5 );
            *)
            Copy( s, LString );
        END;
        WriteIntData( TextType, DataRecord );
    END WriteHeadRecord;

BEGIN
    ID := IDContext;

  (* Here we act paranoid about the resource tree node.  By the time we are
     outputting data, we won't have to worry.
  *)
    ValidateTreeNode( ResourceNode );

    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );
    CheckResourceValid( Resource );
    IF (Resource^.Type <> Employable) THEN
        RETURN;
    END;

    IF (NOT ( Selected IN  ResourceFiltersPassed(ResourceNode))) THEN
        RETURN;
    END;

    Resource := ResourceNode^.Methods^.GetDataObject( ResourceNode );

    (* For each availability cell. *)

    IF (Resource^.Availability = ADateList(NIL)) THEN
        WriteHeadRecord(1);
    ELSE
        i := 1;
        WHILE (GetDateListEntry( Resource^.Availability, i,
                                 StartDate, EndDate, Rate )) DO
            WriteHeadRecord(i);
            INC(i);
        END;
    END;

END DoAvailHeader;





    (* Generate the headers for the AVAILABILITY dimension. *)

PROCEDURE AvailHeaders( HeaderNumber : CARDINAL ) : CARDINAL;
VAR
    ID          : CARDINAL;
    ResourceNode: ATreeNode;
BEGIN
    StartSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber, VersionNumber );
    IF (CheckIO( InterFile ) <> done) THEN
        FileComplaint();
        RETURN 0;
    END;
    ID := 0;
    ResourceTree^.Methods^.TraverseTree(ResourceTree,ParentBeforeChild,
                                        9999, DoAvailHeader,
                                        ADR(ID));
    EndSubfileOutput( InterFile, PredicateSubfileNumber + HeaderNumber );
    RETURN ID;
END AvailHeaders;





 (* Main *)

PROCEDURE DoTLXAvail();
VAR
    P                   : POINTER TO ARRAY [0..255] OF CHAR; (* Overlay Context *)
    s                   : ARRAY [0..51] OF CHAR;


    PROCEDURE Setup() : BOOLEAN;
    VAR
        s1         : ARRAY [0..19] OF CHAR;
        s2         : ARRAY [0..19] OF CHAR;
        j          : CARDINAL;
    BEGIN
        P := OverlayContext();                                        (* 1-May-89 MWP *)

        IF (P = NIL) THEN
            FatalError();
        END;

        (* Validate the resource tree.  Insure that there ARE some resources. *)

        ValidateTree( ResourceTree );

        IF (ResourceTree^.Methods^.GetFirst( ResourceTree ) = NIL) THEN
            DoDialog( ModuleNumber + 6, TRUE );
            (* There are no resources on which to report. *)
            RETURN FALSE;
        END;


            (* Get the parameters passed to us.  The first parameter
               indicates whether or not this is generated for export. *)

        j := 1;

        ParseString( P^, j, s1 );

        GetMessage( 13807, s2 );        (* "EXPORT" *)

        CallerIsExporter := ( Compare ( s1, s2 ) = 0 );

        SetLengthOf ( s, 0 );

        RETURN ( CreateTheFile( s ) );

    END Setup;




    PROCEDURE GenerateData();
    VAR
        ResourceNode : ATreeNode;
        Rows         : CARDINAL;
        Count        : CARDINAL;
        s            : ARRAY [0..69] OF CHAR;
        ok           : BOOLEAN;
    BEGIN
         (*<TRACE
         SetString(TraceS,"Now in GenerateData");
         PrintString(TraceS);
         TRACE>*)

        Rows := AvailHeaders( 1 );
        IF (CheckIO( InterFile ) <> done) THEN
            RETURN;
        END;

         (*<TRACE
         SetString(TraceS,"Rows = "); CtoS(Rows,TraceS2); ConcatLS(TraceS,TraceS2);
         PrintString(TraceS);
         TRACE>*)


        GetMessage( ModuleNumber + 7, s ); (* "Joins' data generated" *)
        ok := CreateThermometer( Thermometer, 0, 0, s, Rows );

        (* Generate the data section of the file. *)

        StartSubfileOutput( InterFile, PredicateSubfileNumber + 2, VersionNumber );

        IF (CheckIO( InterFile ) = done) THEN
            Count := 0; (* # of rows output *)
            ResourceTree^.Methods^.TraverseTree(ResourceTree,
                                        ParentBeforeChild, 9999,
                                        GenerateOneAvailabilityList,
                                        ADR(Count));
        ELSE
            FileComplaint();
        END;

        IF (CheckIO( InterFile ) = done) THEN
            EndSubfileOutput( InterFile, PredicateSubfileNumber + 2 );
        END;

        DiscardThermometer ( Thermometer );

    END GenerateData;



    PROCEDURE SetUpColumns();
    VAR
        i          : CARDINAL;
        DateWidth  : CARDINAL;   (* How wide should date columns be? *)
        DataRecord : AColumnDataRecord;
        ok         : BOOLEAN;
    BEGIN
            (* How wide should date columns be? *)
        CASE DefaultDateOption OF
            ShowDate :
                        DateWidth := TimeStringLength(DefaultDateFormat);
          | ShowTime :
                        DateWidth := TimeStringLength(DefaultTimeFormat);
            ELSE
                        DateWidth := TimeStringLength(DefaultDateAndTimeFormat);
        END;

        FOR i := 1 TO MaxReportColumns DO
            WITH Columns[i] DO
                    (* Column widths differ for exporting vs. printing. *)
                IF ( CallerIsExporter ) THEN
                    ok := GetAvailInfo( i, ColumnExportWidth, 0, DataRecord );
                    Width        := DataRecord.CardinalValue;
                ELSE
                    ok := GetAvailInfo( i, ColumnWidth, 0, DataRecord );
                        (* Date columns may have adjustable widths. *)
                    IF (i IN {StartDateColumn, EndDateColumn}) THEN
                        Width    := DateWidth;
                    ELSE
                        Width    := DataRecord.CardinalValue;
                    END;
                END;

                IF (NOT ok) THEN FatalError(); END;  (* too few? *)

                ColumnNumber := i;
                    
                    (* Determine the number of decimals for this column. *)
                ok := GetAvailInfo( i, ColumnMaxDecimals, 0, DataRecord );
                Decimals     := DataRecord.CardinalValue;
            END;
        END;
    END SetUpColumns;

BEGIN
    s         := "Program Copyright (c) 1991 Symantec Corporation.";
    PackageOK := FALSE;  (* In case we terminate early. *)

    SetLengthOf (s,0);

    IF ( NOT Setup () ) THEN
        RETURN;
    END;

    SetUpColumns();

    (* Create the first part of the file (the non-data part) *)


    IF (GenerateFileHeaders( AGetInfoProc(GetAvailInfo),
                             OverallPhrase,      (* OverallPhrase         *)
                             2,                  (* PredicateHeadingDepth *)
                             DomainBaseMessage,  (* DomainBase            *)
                             Columns,
                             s
                                )) THEN
        GenerateData();

        (* Clean up the file and exit.  Do not close the file! *)

        IF (CheckIO( InterFile ) <> done) THEN
            FileComplaint();
        ELSIF (GenerateFileTrailers()) THEN
            PackageOK := TRUE;  (* Tell mom that we're OK down here. *)
        END;
    ELSE
        FileComplaint();
    END;

    CommonCleanup();

    IF (NOT PackageOK) AND (InterFileOpen) THEN     (* 3/17/89 EGK *)
        DeleteTempFile (InterFile);
        InterFileOpen := FALSE;
    END;

END DoTLXAvail;




BEGIN

    DoTLXAvail();
         (*<TRACE
         SetString(TraceS,"Ready to exit TLXAvail.");
         PrintString(TraceS);
         TRACE>*)


END TLXAvail.
