IMPLEMENTATION MODULE Links;


   (* MODIFICATION HISTORY:

        RSC Oct 29, 87 - First version, from inspiration by Andrew.
        11-Jan-88 LAA   Changed UnlockFlexStorDataObject to UnlockUnchanged.
        08-Feb-89 EGK   Changed InvokeTLLink to call TLLINK through
                        TLFBASE, and added GetSummaryInfoLine and
                        PutSummaryInfoLine.
   *)


FROM Allocs          IMPORT
        (* TYPE *)      ATaskPtr;

FROM LStrings        IMPORT
        (* PROCS *)     SetString, SetLengthOf;

FROM Overlays        IMPORT
        (* PROCS *)     CallOverlayWithContext;

FROM SYSTEM          IMPORT
        (* Thing *)     ADR, ADDRESS;

FROM Text            IMPORT
        (* PROCS *)     TextExists, CopyLine, AssignLine;

FROM TreeObjects     IMPORT
        (* TYPE *)      ATreeNode;




PROCEDURE GetSummaryInfoLine    (    Node       : ATreeNode;
                                     LineType   : CARDINAL;
                                 VAR s          : ARRAY OF CHAR );
VAR
    TaskPtr         : ATaskPtr;

BEGIN

    SetLengthOf(s,0);
    IF (Node = NIL) THEN
        RETURN;
    END;

    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
    IF (TextExists (TaskPtr^.summarizes)) THEN
        CopyLine (TaskPtr^.summarizes, LineType, s);
    END;
    Node^.Methods^.UnlockUnchangedDataObject (Node);
END GetSummaryInfoLine;





PROCEDURE SetSummaryInfoLine    (    Node       : ATreeNode;
                                     LineType   : CARDINAL;
                                 VAR s          : ARRAY OF CHAR );
VAR
    TaskPtr         : ATaskPtr;
    OK              : BOOLEAN;

BEGIN

    IF (Node = NIL) THEN
        RETURN;
    END;

    TaskPtr := Node^.Methods^.LockFlexStorDataObject (Node);
    IF (TextExists (TaskPtr^.summarizes)) THEN
        OK := AssignLine (s, LineType, TaskPtr^.summarizes);
    END;
    Node^.Methods^.UnlockFlexStorDataObject (Node);
END SetSummaryInfoLine;




 (* Get Displayable Link - Given a task node, return a printable string
                           suitable for columnar display on the Gantt chart.

    Preconditions  - TaskNode must be a viable task node or NIL.
    Postconditions - s contains the string to display.

  *)
PROCEDURE DefaultGetDisplayableLink( TaskNode : ATreeNode;
                                VAR  s        : ARRAY OF CHAR );
BEGIN
    GetSummaryInfoLine (TaskNode, LinkPathLine, s);
END DefaultGetDisplayableLink;




 (* Invoke TLLink - Invoke TLLink with an action code.

     Preconditions  - LinkInterface  is what to pass to TLLink.
     Postconditions - LinkInterface  has been updated as needed.
                      if the overlay can't be loaded, then CompletedOK
                      is FALSE.
 *)
PROCEDURE InvokeTLLink( VAR LinkInterface : ALinkInterface );
VAR
    OverlayName : ARRAY [0..20] OF CHAR;
    Ok          : BOOLEAN;
BEGIN
    SetString( OverlayName, "\TLFBASE(TLLINK)" );       (* 2/8/89 EGK *)
    WITH LinkInterface DO
        ChangesMade  := FALSE;
        CompletedOK  := FALSE;
    END;
    Ok := CallOverlayWithContext( OverlayName, ADR( LinkInterface ) );
END InvokeTLLink;



BEGIN

    GetDisplayableLink := DefaultGetDisplayableLink; (* Setup default *)

END Links.
