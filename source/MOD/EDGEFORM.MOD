IMPLEMENTATION MODULE EdgeFormat;

(*  =========================================================================
    Last Edit : September 26, 1990 5:47PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 

    Edge Format - Format Edge Information

        This module is intended to do for Edges what Captions does for
        tasks.  That is, given a column ID, return information about an
        edge.

        MODIFICATION History -

        17-Feb-89 RSC First version - information only.
        17-Mar-89 RSC Added support for better reports.
        21-Mar-89 RSC Added MORE support for better reports.
        27-Mar-89 RSC Added MORE support for better reports.
        24-Apr-89 AJL Hard coded several of the (no longer internally kept)
                      edge fields: EdgeToPlus, EdgeToDuration, EdgeToTime and
                      EdgeToScale.
        05-May-89 EGK Changed to support new WBS storage scheme.
        17-May-89 WKH Someone ^ forgot to import WBSLine from Allocs
         1-May-89 MWP Adjusted offsets into Phrases file for calculating
                      edge fields for export.
        20-May-89 RSC Changed ManHours to WorkHours.
        13-Jul-89 MWP Removed importing of FromID and ToID.
        13-Jul-89 LAA Commented out use of EdgeFromTaskID and EdgeToTaskID,
                      so this would compile.  Matt, is this right????
        24-Aug-89 MWP Trim trailing spaces from valus retrieved from
                      GetCodingField.
         1-Sep-89 EGK Added FormatType parameter to FormatEdgeValue.
        30-Mar-90 RSC Removed unused Timeu imports.
        26-Sep-90 PFG Added ColumnType parameter to ColumnInfo for 
                      user-defined column headings.

    =========================================================================
  *)


FROM Allocs                 IMPORT
    (* CONST *)                 WBSLine,      (* 5/17/89 WKH *)
    (* TYPE *)                  ATaskPtr,
    (* PROC *)                  GetCodingField;

FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice, AColumnDataRecord,
    (* PROC *)                  FormatColumnValue;

FROM ColData                IMPORT
    (* TYPE  *)                 AColumnType;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Edges                  IMPORT
    (* TYPE *)                  AnEdgePtr,
    (* PROC *)                  FindEdge;

FROM FormatCommon           IMPORT
    (* PROC *)                  ColumnInfo, GetFormattingInfo, GetValueInfo,
                                GetMessageWord, ConcatMessageWord,
                                FormatDataValue;

FROM Gantt                  IMPORT
    (* TYPE *)                  AGanttLineType;

FROM LStrings               IMPORT
    (* PROC *)                  Copy, ConcatLS, TrimFront, TrimRear,
                                SetLengthOf;

FROM MagicNum               IMPORT
    (* CONST *)                 EdgeModuleNumber, EdgeLastColumn,
                                EdgeFromTaskName,
                                EdgeFromTaskWBS,
                                EdgeToTaskName,
                                EdgeToTaskWBS,
                                EdgeFromStart,
                                EdgeFromPlus,
                                EdgeFromDuration,
                                EdgeFromTime,
                                EdgeFromScale,
                                EdgeToStart,
                                EdgeToPlus,
                                EdgeToDuration,
                                EdgeToTime,
                                EdgeToScale;

FROM Timei                  IMPORT
    (* TYPE *)                  ADurationUnit,
    (* PROC *)                  DurationToReal;

FROM Timeu                  IMPORT
    (* VAR *)                   SMUPH;

FROM WorkHours               IMPORT
    (* PROC *)                  WorkHoursToRealTime;


CONST
    Zero = 0.0;







(*
    Get Edge Info

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
PROCEDURE XGetEdgeInfo(     ColumnID      : CARDINAL;
                            InfoChoice    : AColumnInfoChoice;
                            Length        : CARDINAL;
                        VAR InfoValue     : AColumnDataRecord) : BOOLEAN;
BEGIN
    IF (ColumnID > EdgeLastColumn) THEN
        RETURN FALSE;
    ELSE
        ColumnInfo( EdgeModuleNumber,
                    ColumnID,
                    EdgeLastColumn,
                    InfoChoice, 
                    Length, 
                    NotEditableColumn,          (* 26-Sep-90 PFG *)
                    InfoValue );
        RETURN TRUE;
    END;
END XGetEdgeInfo;








(*
    Get Edge Value

        Preconditions
                        > Edge is the actual edge record.

                        > Predecessor and Successor are the two sides of
                          the edge.

                        > ColumnID  is the column to return information about.

        Postconditions
                        > If TRUE, Value contains the desired information.

                        > If FALSE, The column data is not applicable.
*)
PROCEDURE XGetEdgeValue(    Edge         : AnEdgePtr;
                            Predecessor,
                            Successor    : ATaskPtr;
                            ColumnID     : CARDINAL;
                        VAR Value        : AColumnDataRecord)
                                                              : BOOLEAN;
VAR
    ok                  : BOOLEAN;
BEGIN

    ok  := TRUE;

    WITH Edge^ DO
        WITH Value DO
            GetValueInfo( EdgeModuleNumber + ColumnID, DataType, DataFields );
            CASE ColumnID OF
               EdgeFromTaskName    :
                    Copy( Predecessor^.taskname, StringValue );
(*                                                                (* 13-Jul-89 LAA *)
            | EdgeFromTaskID      :
                    CardinalValue := Predecessor^.TaskID;
*)
            | EdgeFromTaskWBS     :
                    GetCodingField (Predecessor^, WBSLine, StringValue); (* 24-Aug-89 MWP *)
                    TrimRear ( StringValue );

            | EdgeToTaskName      :
                    Copy( Successor^.taskname, StringValue );
(*                                                                (* 13-Jul-89 LAA *)
            | EdgeToTaskID        :
                    CardinalValue := Successor^.TaskID;
*)
            | EdgeToTaskWBS       :
                    GetCodingField (Successor^, WBSLine, StringValue);
                    TrimRear ( StringValue );                     (* 24-Aug-89 MWP *)
            | EdgeFromStart       :
                    BooleanValue := FromOffset.Start;
(* 17-May-89 MWP
                    GetMessageWord( EdgeModuleNumber + 2, ORD(BooleanValue), StringValue );
*)
                    GetMessageWord( EdgeModuleNumber - 4, ORD(BooleanValue), StringValue );
                    (* "End,Start" *)

            | EdgeFromPlus        :
                    BooleanValue := FromOffset.Plus;
(* 17-May-89 MWP
                    GetMessageWord( EdgeModuleNumber + 3, ORD(BooleanValue), StringValue );
*)
                    GetMessageWord( EdgeModuleNumber - 5, ORD(BooleanValue), StringValue );
                    (* "Minus,Plus" *)

            | EdgeFromDuration    :
                    RealValue := DurationToReal(FromOffset.Dur) 
                                 / 
                                 DurationToReal(SMUPH);  (* WORK HOURS *)

            | EdgeFromTime        :
                    RealValue := DurationToReal(FromOffset.Dur) 
                                 / 
                                 DurationToReal(SMUPH);  (* WORK HOURS *)
                    RealValue := WorkHoursToRealTime(RealValue, FromOffset.Scale);

            | EdgeFromScale       :
                    CardinalValue := ORD( FromOffset.Scale );
(* 17-May-89 MWP
                    GetMessageWord( EdgeModuleNumber + 1, CardinalValue, StringValue);
*)
                    GetMessageWord( EdgeModuleNumber - 8, CardinalValue, StringValue);
                        (* Minutes/Hours/Days... *)

            | EdgeToStart         :
                    BooleanValue := ToOffset.Start;
(* 17-May-89 MWP
                    GetMessageWord( EdgeModuleNumber + 2, ORD(BooleanValue), StringValue );
*)
                    GetMessageWord( EdgeModuleNumber - 4, ORD(BooleanValue), StringValue );
                    (* "End,Start" *)

            | EdgeToPlus          :
                    BooleanValue := FALSE;
(* 17-May-89 MWP
                    GetMessageWord( EdgeModuleNumber + 3, ORD(BooleanValue), StringValue );
*)
                    GetMessageWord( EdgeModuleNumber - 5, ORD(BooleanValue), StringValue );
                    (* "Minus,Plus" *)

            | EdgeToDuration      :
                    RealValue := Zero; (* WORK HOURS *)

            | EdgeToTime          :
                    RealValue := Zero; (* Elapsed time *)

            | EdgeToScale         :
                    CardinalValue := ORD( Days );
(* 17-May-89 MWP
                    GetMessageWord( EdgeModuleNumber + 1, CardinalValue, StringValue);
*)
                    GetMessageWord( EdgeModuleNumber - 8, CardinalValue, StringValue);
                            (* Minutes/Hours/Days... *)

            ELSE
                FatalError();  (* New column added? *)
            END;
        END;
    END;

    RETURN ok;

END XGetEdgeValue;









(*
    Format Edge Value

        Preconditions
                        > ColumnID     is the column to return information about.

                        > Width        is how wide the data is.

                        > MinDecimals  is the min decimals to use for REALs.

                        > MaxDecimals  is the max decimals to use for REALs.

                        > RightJust    is wether to right justify the string.

        Postconditions
                        > Value contains the desired string.

*)
PROCEDURE XFormatEdgeValue(    ColumnID     : CARDINAL;
                               Width        : CARDINAL;
                               MinDecimals  : CARDINAL;
                               MaxDecimals  : CARDINAL;
                               RightJust    : BOOLEAN;
                               FormatType   : CARDINAL;
                           VAR Value        : AColumnDataRecord);
BEGIN
    FormatDataValue( Width, MinDecimals, MaxDecimals,
                     RightJust, FormatType, Value    );
END XFormatEdgeValue;










(*
    Get Edge String

        Preconditions
                        > Edge is the actual edge record.

                        > Predecessor and Successor are the two sides of
                          the edge.

                        > ColumnID  is the column to return information about.

                        > Width     is how wide the data is.

        Postconditions
                        > If TRUE, Value contains the desired string.

                        > If FALSE, The column data is not applicable.
*)
PROCEDURE XGetEdgeString(    Edge           : AnEdgePtr;
                             Predecessor,
                             Successor      : ATaskPtr;
                             ColumnID       : CARDINAL;
                             Width          : CARDINAL;
                         VAR Value          : ARRAY OF CHAR )
                                                              : BOOLEAN;
VAR
    MinDecimals,
    MaxDecimals   : CARDINAL;
    RightJustify  : BOOLEAN;
    FormatType    : CARDINAL;
    ValueRecord   : AColumnDataRecord;
BEGIN

    IF (GetEdgeValue( Edge,
                      Predecessor, Successor,
                      ColumnID,
                      ValueRecord ))    THEN
        GetFormattingInfo( EdgeModuleNumber + ColumnID,
                           MinDecimals,
                           MaxDecimals,
                           RightJustify,
                           FormatType   );
        FormatEdgeValue( ColumnID,
                         Width,
                         MinDecimals,
                         MaxDecimals,
                         RightJustify,
                         FormatType,
                         ValueRecord );
    ELSE
        SetLengthOf(Value, 0);
        RETURN FALSE;
    END;

    Copy( ValueRecord.StringValue, Value );

    RETURN TRUE;

END XGetEdgeString;





BEGIN
    GetEdgeInfo     := XGetEdgeInfo;
    GetEdgeValue    := XGetEdgeValue;
    FormatEdgeValue := XFormatEdgeValue;
    GetEdgeString   := XGetEdgeString;
END EdgeFormat.
