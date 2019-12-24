MODULE TLSetMouse;

    (* MODIFICATION HISTORY

    *)

FROM Forms        IMPORT AFieldValue, NullCheckProc, DoForm;

FROM Kbio         IMPORT maxcol;

FROM Keys         IMPORT ExitKey;

FROM Layout       IMPORT GanttWStart, GanttWEnd;

FROM Mouse      IMPORT
    (* TYPE *)      AMouseTime,
    (* VAR *)       RepeatRate, DoubleClickRate;


CONST
    FormNumber   = 71;


(*$S+*)

PROCEDURE SetMouse;
VAR
    FormValue                   : ARRAY [0..1] OF AFieldValue;
    Copyright                   : ARRAY[0..50] OF CHAR;
    

BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";

    FormValue[0].CardValue := (VAL(CARDINAL,DoubleClickRate) DIV 2) - 1;
    FormValue[1].CardValue := VAL(CARDINAL,RepeatRate);

    IF (DoForm(20,GanttWStart,maxcol,GanttWStart+(GanttWEnd-GanttWStart) DIV 2,
               FormNumber,TRUE,FormValue,NullCheckProc) = ExitKey) THEN
       DoubleClickRate := VAL(AMouseTime,(FormValue[0].CardValue+1) * 2);
       RepeatRate      := VAL(AMouseTime,FormValue[1].CardValue);
    END;

END SetMouse;




(*$S+*)



BEGIN
    SetMouse;
END TLSetMouse.
