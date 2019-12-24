MODULE TLEndImport;

    (*
        After Import has completed, sanitize the entire task tree.

        Modification History:


         27-Jul-89  MWP  In the beginning...
          8-Aug-89  MWP  Renumber all tasks, resources etc. after import is complete.
         10-Aug-89  KKC  Add copyright message.
          3-Oct-89  MWP  Fixed a bug with formatting of import journal
                         messages. During sanitize, we have to check for,
                         and possibly set, the schedule start and end dates
                         otherwise the data imported is really messed up.
          9-Oct-89  MWP  Removed text literals.
         19-Oct-89  MWP  During schedule verification, display taskname
                         message to indicate somnething is occuring.
         23-Oct-89  EGK  Put back call to RenumberEverything, which was
                         accidentally removed.
         28-Nov-89  MWP  Removed naming the schedule to 'IMPORT' if
                         we imported into a blank schedule.
         30-Mar-90  RSC  Made Timeu to Timei/TimeForm conversions.
    *)


FROM Allocs         IMPORT
    (* TYPE *)              ATaskPtr,
    (* VAR  *)              TaskTree;

FROM ChartControl   IMPORT
    (* TYPE *)              AChartState,
    (* PROC *)              UnSetState;

FROM Dialog         IMPORT
    (* PROC *)              Message, Burp, Error;

FROM EditError      IMPORT
    (* TYPE *)              AnErrorSeverity, AKindOfError;

FROM ImportCommon   IMPORT
    (* PROC *)              CleanUp;

FROM ImPorTable     IMPORT
    (* TYPE *)              AImportTable,
    (* PROC *)              LogAMessage,
                            LogAnError,
                            AskAlterBaseline;

FROM LStrings       IMPORT
    (* PROC *)              SetString, LengthOf, SetLengthOf, Fill, Copy;

FROM MsgFile        IMPORT
    (* PROC *)              GetMessage;

FROM Planner   IMPORT
    (* VAR *)               ScheduleStartDate, ScheduleEndDate;

FROM Renumber       IMPORT
                            RenumberEverything;

FROM Schedule       IMPORT
    (* VAR  *)              ProjectName,
    (* PROC *)              DisplayScheduleLight;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR;

FROM TaskChange     IMPORT
    (* PROC *)              SanitizeTask;

FROM Timei          IMPORT
                            ADate, MinDate, MaxDate;


FROM TreeObjects    IMPORT
    (* TYPE *)              ATreeNode, ATreeOrder;


    (* I am temporarily stealing this from TLSpread.mod  *)
CONST
    ModuleNumber            = 29500;


VAR
    LocalImportTable        : AImportTable;


PROCEDURE SanitizeImport ();
CONST
    ImportModNumber = 29300;
VAR
    s                       : ARRAY [ 0..255] OF CHAR;
    Len                     : CARDINAL;
BEGIN

    RenumberEverything ();                                         (* 8-Aug-89 MWP *)

    ScheduleEndDate := MinDate;
    ScheduleStartDate := MaxDate;

    LocalImportTable.Counter := 0;

    TaskTree^.Methods^.TraverseTree (TaskTree, ParentBeforeChild, 9999,
                                     CheckTask, NIL);

    SetLengthOf ( s, 0 );
    Message ( s );

    UnSetState( Scheduled );

    CleanUp ();
(*
    IF ( LengthOf ( ProjectName ) = 0 ) THEN
       GetMessage ( ImportModNumber + 72, ProjectName );
       (* "IMPORT" *)
       DisplayScheduleLight();   (* We may have changed the project name. *)
    END;
*)

END SanitizeImport;


PROCEDURE CheckTask    ( VAR TaskNode  : ATreeNode;
                             Context   : ADDRESS   );
VAR
    TaskPtr                 : ATaskPtr;
    LocalEarlyEnd,
    LocalEarlyStart         : ADate;
    s                       : ARRAY [0..255] OF CHAR;
BEGIN
    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    WITH TaskPtr^ DO                                              (* 19-Oct-89 MWP *)
      Copy ( taskname, s );
      Message ( s );
    END;

    TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

    SanitizeTask( TaskNode, ErrorHandler, NIL,
                  AskAlterBaseline,
                  ADR(LocalImportTable) );


    TaskPtr := TaskNode^.Methods^.LockFlexStorDataObject( TaskNode );

    WITH TaskPtr^ DO

        LocalEarlyEnd   := Plan.Dates.EarlyEnd;
        LocalEarlyStart := Plan.Dates.EarlyStart;

    END;

    TaskNode^.Methods^.UnlockFlexStorDataObject( TaskNode );

    IF (LocalEarlyEnd > ScheduleEndDate) THEN
        ScheduleEndDate := LocalEarlyEnd;
    END;

    IF (LocalEarlyStart < ScheduleStartDate) THEN
        ScheduleStartDate := LocalEarlyStart;
    END;

END CheckTask;


PROCEDURE ErrorHandler( Severity        : AnErrorSeverity;
                        ErrorKind       : AKindOfError;
                        ColumnID        : CARDINAL;
                    VAR ErrorText       : ARRAY OF CHAR;
                        MyContext       : ADDRESS
                       ) : BOOLEAN;         (* Continue?         *)
CONST
    ErrModuleNumber = 29300;
VAR
    s           : ARRAY [0..255] OF CHAR;
    Copyright   : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    GetMessage ( ErrModuleNumber + 10 + ORD(ErrorKind) + 1, s );

    IF (LengthOf(s) > 0) THEN
        LogAnError ( s );
    END;

    RETURN TRUE;

END ErrorHandler;


BEGIN
    SanitizeImport ();
END TLEndImport.
