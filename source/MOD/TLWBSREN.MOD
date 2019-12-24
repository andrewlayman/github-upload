MODULE TLWBSRenumber;

  (*    Renumber a range of WBS codes.

        MODIFICATION HISTORY:

         09-Apr-89  MWP  In the beginning...
         06-Jun-89  AJL  Remove import of AFilterRecordPointer.
         10-Aug-89  KKC  Add copyright message.
         15-Aug-89  MWP  Removed initialization of WBS form values, as this is
                         done in TLRENUMB.
         27-Aug-89  MWP  Remove call to ResetFilters.
         10-May-91  RSC  Moved context to the stack.
         12-Jul-91 PFG   Set ScheduleSaved to FALSE and added a call to 
                         DisplayScheduleLight when renumber happens.
  *)


FROM Allocs         IMPORT
    (* VAR  *)              TaskTree;

FROM Dialog         IMPORT
    (* PROC *)              Error;

FROM LStrings       IMPORT
    (* PROC *)              SetString;

FROM MsgFile       IMPORT
    (* PROC *)              GetMessage;

FROM Overlays       IMPORT
    (* PROC *)              CallOverlayWithContext;

FROM Schedule               IMPORT 
    (* VAR   *)                 ScheduleSaved,
    (* PROC  *)                 DisplayScheduleLight;

FROM WBSCommon      IMPORT
                            WBSModuleNumberBase,
    (* TYPE *)              AContextRecord,
                            AWBSErrorSet,
                            AWBSError,
                            AnWBSFormsValue,
                            AWBSPtr,                                (* 15-Aug-89 MWP *)
    (* PROC *)              SelectWBSRangeDialog,
                            PerformConfirmationDialog,
                            SetWBSValues;

FROM SYSTEM         IMPORT
    (* TYPE *)              ADDRESS, ADR;


CONST
    ModuleNumber  =   WBSModuleNumberBase + 40;





PROCEDURE DisplayConfirmationDialog () : BOOLEAN;
VAR
    Choice                  : CARDINAL;
    Prefix                  : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
BEGIN

(*
    Renumbering all tasks may change existingü
    WBS numbers. If you are using WBS numbersü
    as part of an import or export process, youü
    may be erasing numbers other systems depend upon.
*)
    GetMessage ( ModuleNumber, Prefix );

    Choice := 1; (* Default is Proceed *)

    ok := PerformConfirmationDialog ( Prefix, Choice );

    IF ( ok ) THEN
       ok := Choice = 1;
    END;

    RETURN ok;

END DisplayConfirmationDialog;


PROCEDURE DisplayRenumberRangeDialog ();
VAR
    ContextRecord           : AContextRecord;
    Title                   : ARRAY [0..29] OF CHAR;
    Prefix                  : ARRAY [0..255] OF CHAR;
    ok                      : BOOLEAN;
    Overlay                 : ARRAY [0..39] OF CHAR;
    Copyright               : ARRAY[0..50] OF CHAR;

BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    GetMessage ( ModuleNumber + 1, Title );
    (* "WBS Renumber Tasks" *)

    GetMessage ( ModuleNumber + 2, Prefix );
    (* Prefix, "Which tasks do you want to renumber:" *)

    ContextRecord.RangeChoice := 1; (* Default is Cancel *)

    ok := SelectWBSRangeDialog ( Prefix,
                                 Title,
                                 ContextRecord.RangeChoice );

    IF ( NOT ok ) THEN
       RETURN;
    END;

    SetString( Overlay, "TLRENUMB" );
    ContextRecord.ShowThese   := AWBSErrorSet {BlankError..WBSTooLarge};
    ContextRecord.ErrorsFound := AWBSErrorSet {};

    ok := CallOverlayWithContext( Overlay, ADR(ContextRecord) );

    ScheduleSaved := FALSE;     (* 17-Jul-91 PFG *)
    DisplayScheduleLight();     (* 17-Jul-91 PFG *)

END DisplayRenumberRangeDialog;


VAR
    ok                      : BOOLEAN;
    WBSRecordP              : AWBSPtr;                              (* 15-Aug-89 MWP *)
    ErrorMessage            : ARRAY [0..255] OF CHAR;
    FormName                : ARRAY[0..10] OF CHAR;

BEGIN
   (* Check for task tree empty before we start *)

   IF (TaskTree^.Methods^.GetFirst( TaskTree ) <> NIL) THEN

       IF ( DisplayConfirmationDialog () ) THEN
          DisplayRenumberRangeDialog ();
       END;
    ELSE
       GetMessage ( ModuleNumber + 4, ErrorMessage );
       (* "There are no tasks to renumber." *)
       Error ( ErrorMessage );
    END;

END TLWBSRenumber.
