IMPLEMENTATION MODULE Indentation;

    (* Indentation  - outline indentations.

        12/16/88  RSC  Cloned from Captions.

    *)





FROM LStrings       IMPORT
    (* PROCS *)         Fill, SetString;

FROM TreeObjects    IMPORT
    (* TYPE *)          ATreeNode;







(*----------------------------------------------------------------------------
    FormatIndentation --

    Create a string according to the level of the node, indicate if this
    task is a summary task or not, and limit the resulting LString to the
    indicated width.  

    Preconditions:
        The given task node must not be NIL.

    Postconditions:
        An LString of the indicated width will be generated, containing blanks
        according to the indentation required, with the indicator of whether 
        this is a summary or detail task.  The length of the LString will 
        always be of the requested width, as long as the string variable is 
        big enough. Therefore, it may have to be padded with trailing blanks.
----------------------------------------------------------------------------*)

PROCEDURE FormatIndentation(    TaskNode       : ATreeNode;
                                Length         : CARDINAL;
                            VAR String         : ARRAY OF CHAR);

VAR
    i                       : CARDINAL;

BEGIN                       (* FormatIndentation *)

    IF (Length > HIGH(String)) THEN
        Length := HIGH(String);
    END;

    i := TaskNode^.Methods^.IndentationLevel(TaskNode) * SpacesPerLevel + 1;
    IF (i > Length) THEN
        i := Length;
    END;

    Fill(String, " ", i);
    IF (i > 0) THEN
        IF (TaskNode^.Methods^.GetSubtree(TaskNode) <> NIL) AND
           (NOT TaskNode^.Methods^.ChildrenVisible(TaskNode)) THEN
            String[i] := "+";
        END;
    END;

END FormatIndentation;




BEGIN
    SpacesPerLevel := 3;  (* Default.  Nothing in the root is for sure. *)
END Indentation.

