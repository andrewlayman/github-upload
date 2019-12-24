IMPLEMENTATION MODULE ChartMgr;


FROM Dialog  IMPORT FatalError;



CONST
    MaxDepth = 3;
VAR
    Stack  : ARRAY [1..MaxDepth] OF AChartDisplayProcedure;
    Count  : CARDINAL;



    (* This module keeps track of procedures for displaying the
       charts on the screen, and can push procedures on an internal
       stack. *)

    (* Sets the current procedure.  Pushes the stack. *)

PROCEDURE PushChartDisplayProcedure (  P    : AChartDisplayProcedure );
BEGIN
    IF (Count < MaxDepth) THEN
        INC(Count);
        Stack[Count] := P;
    ELSE
        FatalError;
    END;
END PushChartDisplayProcedure;




    (* Pops the stack, but never empties it. *)

PROCEDURE PopChartDisplayProcedure;
BEGIN
    IF (Count > 1) THEN
        DEC(Count);
    END;
END PopChartDisplayProcedure;




    (* Calls the current display procedure. *)

PROCEDURE DisplayCurrentChart;
VAR
    P  : AChartDisplayProcedure;
BEGIN
    IF (Count > 0) THEN
        P := Stack[Count];
        P;
    END;
END DisplayCurrentChart;




PROCEDURE ResetChartStack;
BEGIN
    IF (Count > 1) THEN
        Count := 1;       (* Save the first one. *)
    END;
END ResetChartStack;



BEGIN
    Count := 0;
END ChartMgr.
