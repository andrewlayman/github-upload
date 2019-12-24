IMPLEMENTATION MODULE TaskAssForms;

(*  =========================================================================
    Last Edit : February 8, 1991 11:35AM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Task Assignment Forms.  Run the (up to 6) assignment form(s).

    MODIFICATION HISTORY:

        8-Feb-91 RSC  Moved code to TLTAFORM.MOD.

========================================================================= *)



FROM Assignments    IMPORT
    (* TYPE *)          AnAssignmentPointer;

FROM LStrings       IMPORT
    (* PROC *)          SetString;

FROM Overlays       IMPORT
    (* PROC *)          CallOverlayWithContext;

FROM SYSTEM         IMPORT
    (* PROC *)          ADR;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATreeNode;




(* Do Assignment Form - Do an assignment form and any subforms.

    Preconditions
                    TaskTreeNode    is the node of the task this assignment
                                    belongs to.
                    Assignment      The Assignment record's pointer.

    Postconditions
                    The assignment record may have been changed.  The task
                    may have been recalc'd.

                    IF FALSE, ESC was pressed on the form.
*)
PROCEDURE DoAssignmentForm(     TaskTreeNode    : ATreeNode;
                            VAR Assignment      : AnAssignmentPointer
                          ) : BOOLEAN;
VAR
    Context : AnOverlayContext;
    s       : ARRAY [0..19] OF CHAR;
BEGIN
    SetString( s, "TLFBASE(TLTAFORM)" );
    Context.TaskTreeNode := TaskTreeNode;
    Context.Assignment   := Assignment;

    Context.ReturnValue  := CallOverlayWithContext( s, ADR(Context) ) AND
                            Context.ReturnValue;

    Assignment           := Context.Assignment;

    RETURN Context.ReturnValue;

END DoAssignmentForm;



END TaskAssForms.
