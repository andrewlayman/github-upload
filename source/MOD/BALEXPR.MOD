IMPLEMENTATION MODULE BalExpr;

(*

     Bal Expr - Balanced Expression manager

        This module deals with LStrings that are "balanced".  That is, each
        expression or subexpression has parens around it, like:

            (1) ( ((1)(6)(1)) ((2)(2)(5.0)) )

        Which is two expressions, the second with two subexpressions, each of
        those with three subexpressions.

        More formally:

            Atom       :== <Any text string, NOT bounded by parens>
            Expression :== Atom | "(" Expression ")"


        Modification History:

        31-Mar-89   RSC   First Version.
        09-May-89   LAA   Changed calls to ParseBal because the length
                          parameter had been removed.
*)




FROM LStrings       IMPORT
    (* PROC *)          SetString, Insert, ConcatS, ConcatLS, StoC,
                        SubStr,    LengthOf, Copy;

FROM Words          IMPORT
    (* PROC *)          ParseBal;






(* LString To Expression - Add parens to an LString.

    Preconditions:
                    LString    is the string to make into an expression.
                               It can be empty.

    Postconditions:
                    Expression is equivelent to LString, but with parens
                                  around it.
*)
PROCEDURE LStringToExpression(  VAR LString     : ARRAY OF CHAR;
                                VAR Expression  : ARRAY OF CHAR );
VAR
    s   : ARRAY [0..1] OF CHAR;
BEGIN
    SetString( s, "(" );
    Copy( LString, Expression );
    Insert(  Expression, s, 1 );
    ConcatS( Expression,  ")" );
END LStringToExpression;




PROCEDURE Atomizer( VAR StartBal   : CARDINAL;
                    VAR Expression : ARRAY OF CHAR;
                    VAR TooFar     : BOOLEAN       ) : BOOLEAN;
VAR
    L,
    EndBal     : CARDINAL;
BEGIN
    L := LengthOf(Expression);
    WHILE (StartBal <= L) AND
          (Expression[StartBal] = " ")  DO
        INC(StartBal);
    END;
    TooFar := (StartBal > L);                  (* Empty string is an atom *)
    IF (TooFar)                         OR
       (Expression[StartBal] <> "(")    THEN   (* Or no starting parens   *)
        RETURN TRUE;
    END;


    EndBal := L;
    WHILE (EndBal > 0)                  AND
          (Expression[EndBal] = " ")    DO
        DEC(EndBal);
    END;

    RETURN (Expression[EndBal] <> ")");

END Atomizer;





(* This Is An Atom


    Preconditions:
                    Expression is the expression to test.  It can be empty.

    Postconditions:
                    RETURN     is TRUE  if the string is an atom.
                                  FALSE if the string could be further parsed.

                    If the string was empty, TRUE is returned.
*)
PROCEDURE ThisIsAnAtom( VAR Expression : ARRAY OF CHAR ) : BOOLEAN;
VAR
    StartBal  : CARDINAL;
    TooFar    : BOOLEAN;
BEGIN
    StartBal := 1;
    RETURN (Atomizer(StartBal, Expression, TooFar));
END ThisIsAnAtom;









(* Parse Expression

    Preconditions
                    Expression        is the expression to be parsed.

                    ExpressionNumber  is which expression you want.
                                         Expressions start with 1, not 0.
                                         ("Get me the Nth Expression")

    Postconditions
                    SubExpression     is the result.  It may be another
                                         Expression.  If it is an atom,
                                         it may have leading, trailing, or
                                         imbedded blanks.  It may be empty.

                    RETURN            is TRUE iff an expression was found,
                                         even if the expression was empty.
                                         FALSE means no expression found.
*)
PROCEDURE ParseExpression( VAR Expression        : ARRAY OF CHAR;
                               ExpressionNumber  : CARDINAL;
                           VAR SubExpression     : ARRAY OF CHAR
                          ) : BOOLEAN;
VAR
    i,
    Len,
    AtomStart,
    StartBal           : CARDINAL;
    TempSubExpression  : ARRAY [0..255] OF CHAR;
    ok,
    TooFar             : BOOLEAN;
BEGIN
    StartBal := 1;
    FOR i := 1 TO (ExpressionNumber - 1) DO
        IF (Atomizer( StartBal, Expression, TooFar ) OR TooFar) THEN
            RETURN FALSE;
        ELSE
            ParseBal( Expression, StartBal, TempSubExpression );  (* 09-May-89 LAA *)
        END;
    END;

    AtomStart := StartBal;
    ok        := (Atomizer( StartBal, Expression, TooFar ));

    IF (TooFar) THEN
        RETURN FALSE;  (* No expression here. *)
    END;

    IF (ok) THEN
        SubStr( Expression, SubExpression,
                AtomStart, (LengthOf(Expression) - AtomStart) + 1 );
    ELSE
        ParseBal( Expression, StartBal, SubExpression );          (* 09-May-89 LAA *)
    END;

    RETURN TRUE;

END ParseExpression;







(* Parse Cardinal

    Preconditions
                    Expression        is the expression to be parsed.

                    ExpressionNumber  is which expression you want.
                                         Expressions start with 1, not 0.
                                         ("Get me the Nth Expression")

    Postconditions
                    CardinalValue     is the returned cardinal, if TRUE.

                    RETURN            is TRUE iff a cardinal was found.
*)
PROCEDURE ParseCardinal( VAR Expression        : ARRAY OF CHAR;
                             ExpressionNumber  : CARDINAL;
                         VAR CardinalValue     : CARDINAL
                       ) : BOOLEAN;
VAR
    i                 : CARDINAL;
    SubExpression     : ARRAY [0..9] OF CHAR;
BEGIN
    IF (ParseExpression( Expression, ExpressionNumber, SubExpression )) THEN
        i             := 1;
        CardinalValue := StoC( SubExpression, i );
        RETURN (i > 1);
    END;

    RETURN FALSE;

END ParseCardinal;





END BalExpr.

