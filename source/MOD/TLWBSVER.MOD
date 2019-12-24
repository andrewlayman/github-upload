MODULE TLWBSVerify;

  (*   Verify a range of tasks for valid WBS codes.

        MODIFICATION HISTORY:

         09-Apr-89  MWP  In the beginning...
         06-Jun-89  AJL  Remove import of AFilterRecordPointer.
                         Remove use of FiltersOn.
         10-Aug-89  KKC  Add copyright message.
         27-Aug-89  MWP  Remove call to ResetFilters.
         10-May-91  RSC  Move context to the stack.
         14-Sep-91  EGK  Set ScheduleSaved to FALSE when done.
  *)

FROM Allocs         IMPORT
    (* VAR  *)              TaskTree;

FROM ChartControl           IMPORT
    (* TYPE *)                  AChartState,
    (* PROC *)                  UnSetState;

FROM Dialog         IMPORT
    (* PROC *)              ErrorPhrase;

FROM LStrings       IMPORT
    (* PROC *)              SetString;

FROM MsgFile       IMPORT
    (* PROC *)              GetMessage;

FROM Overlays       IMPORT
    (* PROC *)              CallOverlayWithContext;

FROM Schedule               IMPORT 
    (* VAR   *)                 ScheduleSaved;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADR;

FROM WBSCommon      IMPORT
                            WBSModuleNumberBase,
    (* TYPE *)              AContextRecord,
                            AWBSError,
                            AWBSErrorSet,
    (* PROC *)              SelectWBSRangeDialog;


CONST
    ModuleNumber  =   WBSModuleNumberBase + 60;



PROCEDURE DisplayVerifyRangeDialog () : BOOLEAN;
VAR
    ContextRecord           : AContextRecord;   (* 10-May-91 RSC  *)
    Choice                  : CARDINAL;
    Title                   : ARRAY [0..29] OF CHAR;
    Prefix                  : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
    Overlay                 : ARRAY [0..39] OF CHAR;
BEGIN

    GetMessage ( ModuleNumber, Title );
    (* "WBS Verify" *)
    GetMessage ( ModuleNumber + 1, Prefix);
    (* "Which tasks do you want to verify:" *)

    ContextRecord.RangeChoice := 1;

    ok := SelectWBSRangeDialog ( Prefix,
                                 Title,
                                 ContextRecord.RangeChoice );

    IF ( ok ) THEN
       SetString( Overlay, "TLVERIFY" );
       ContextRecord.ShowThese   := AWBSErrorSet {BlankError..WBSTooLarge};
       ContextRecord.ErrorsFound := AWBSErrorSet {};

       ok := CallOverlayWithContext( Overlay, ADR(ContextRecord) );
    END;

    IF ( ok ) THEN
       CheckForErrors ( ContextRecord );
       ScheduleSaved := FALSE;          (* 9/14/91 EGK *)
       UnSetState (Formatted);
    END;

    RETURN ok;

END DisplayVerifyRangeDialog;


(*=============================================================================
 * CheckForErrors
 * --------------
 * If errors have occured renumbering WBS codes, inform the user of this.
 * This proc is meant to be called after the verify and renumbering cycle
 * is complete.
 *
 * INPUT    Nothing.
 * RETURNS  Nothing.
 *============================================================================*)
PROCEDURE CheckForErrors ( VAR ContextRecord : AContextRecord );
VAR
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    IF ( ContextRecord.ErrorsFound <> AWBSErrorSet{} ) THEN
       (* "Error(s) have occured renumbering WBS codes" *)
        ErrorPhrase( ModuleNumber + 3 );
    END;

END CheckForErrors;





BEGIN
   (* Check for task tree empty before we start *)

    IF (TaskTree^.Methods^.GetFirst( TaskTree ) <> NIL) THEN
        IF ( DisplayVerifyRangeDialog () ) THEN
        END;
    ELSE
       (* "There are no tasks to verify." *)
        ErrorPhrase( ModuleNumber + 2 );
    END;

END TLWBSVerify.
