IMPLEMENTATION MODULE EvalReal;

(* Modification History:

    13-Apr-89  RSC  Fixed bugs to make this work.  (Blew off the cobwebs).
    26-May-89  RSC  Numbers beginning with a decimal point did not get
                    accepted.
    11-Jul-89  AJL  Allow the comma (or the local significance symbol) to
                    occur within numbers.
*)


FROM LStrings       IMPORT
    (* PROC *)          SubStr, SetString, Fill, Search;

FROM ParseReal      IMPORT
    (* PROC *)          AmountToReal;

FROM RealFormat     IMPORT
    (* TYPE *)          AnAmountFormat;




    (* EvaluateRealExpression -- Four-function, parenthesized,
                                 operator priority evaluation.
                                 Reference "Compilers: Principles,
                                 Techniques and Tools" by Aho,
                                 Sethi and Ullman, 1986, algorithm
                                 4.5.

                                 Any expression found in the Expression
                                 string beginning at position ScanPosition
                                 will be evaluated.

                                 Evaluation will continue to match the
                                 longest valid numeric expression possible.

                                 On return:

                                 ScanPosition will point to just past the
                                 expression (if any) matched and evaluated.

                                 Either Value will contain the evaluation
                                 of the expression, or ErrorFlag will be
                                 TRUE.

                                 Mismatched parenthesis or invalid syntax
                                 will cause the ErrorFlag value to be
                                 returned as TRUE.

                                 *)


PROCEDURE EvaluateRealExpression( VAR Expression    : ARRAY OF CHAR;
                                  VAR ScanPosition  : CARDINAL;
                                  VAR Value         : REAL;
                                  VAR AmountFormat  : AnAmountFormat;
                                  VAR ErrorFlag     : BOOLEAN
                                 );

CONST
    Zero               = 0.0;
    OperatorStackSize  = 40;
    OperandStackSize   = 40;
    EndOfScan          = "~";
    IsAnOperand        = "#";
    OpListConstant     = "+-*/()~";      (* Operators *)
    FArray             = "03355170";     (* F Precedence *)
    GArray             = "02244610";     (* G Precedence *)
TYPE
    AnOperatorStackIndex = [0..OperatorStackSize];
    AnOperandStackIndex  = [0..OperandStackSize];
VAR
    OperatorStack      : ARRAY AnOperatorStackIndex OF CHAR;
    OperatorStackIndex : AnOperatorStackIndex;
    OperandStack       : ARRAY AnOperandStackIndex OF REAL;
    OperandStackIndex  : AnOperandStackIndex;
    StackTop,
    Operator,
    PoppedOperator     : CHAR;
    Operand            : REAL;
    SymbolLength       : CARDINAL;
    OperatorList       : ARRAY [0..10] OF CHAR;   (* Symbol to Number *)
    FList, GList       : ARRAY [0..10] OF CHAR;


        (* OperatorNumber -- 1 indicates not an operator. *)

    PROCEDURE OperatorNumber( Operator : CHAR ) : CARDINAL;
    VAR
        S1 : ARRAY [0..1] OF CHAR;
    BEGIN
        Fill(S1,Operator,1);
        RETURN (Search(OperatorList,S1,1)) + 1;
    END OperatorNumber;




        (* The Lex module returns successive tokens from the
           Expression string.  Each is either an operator, or
           a real number (an operand).  GetCurrentSymbol will
           return the same item again and again, unless AdvanceSymbol
           is called inbetween. *)


    MODULE Lex;

        IMPORT Expression, EndOfScan, IsAnOperand,
               AmountToReal, SubStr, AmountFormat,
               OperatorNumber, ScanPosition;

        EXPORT GetCurrentSymbol, AdvanceSymbol;

        VAR
            Index             : CARDINAL;   (* Current position in Expression. *)
            LastOperator      : CHAR;
            LastOperand       : REAL;
            LastPosition      : CARDINAL;
            LastSaved         : BOOLEAN;

        PROCEDURE AdvanceSymbol;
        BEGIN
            LastSaved := FALSE;
        END AdvanceSymbol;

            (* Determine if we are positioned at the start of a
               number.  The only problem is recognizing the difference
               between a unary minus and the minus operator.
               *)

        PROCEDURE Numeric( VAR S : ARRAY OF CHAR;
                               I : CARDINAL ) : BOOLEAN;
        VAR
            X : CHAR;
        BEGIN
            X := S[I];
            IF (X >= "0") AND (X <= "9") THEN
                RETURN TRUE;
            ELSIF (X = "-") THEN
                IF (I > 1) THEN
                    CASE S[I-1] OF
                        "+", "-", "*", "/", "("  : RETURN TRUE;
                        ELSE RETURN FALSE;
                    END;
                ELSE
                    RETURN TRUE;
                END;
            ELSIF (X = AmountFormat.RadixSymbol) THEN   (* 26-May-89 RSC *)
                RETURN TRUE;
            ELSE
                RETURN FALSE;
            END;
        END Numeric;


            (* GetReal -- Evaluate the real number in string S
                          beginning at position i.  Return the
                          number, and move i to point just past
                          it. *)

        PROCEDURE GetReal( VAR  S : ARRAY OF CHAR;
                           VAR  i : CARDINAL;
                           VAR  R : REAL;
                           VAR  ErrorFlag : BOOLEAN   );
        VAR
            j : CARDINAL;
            C : CHAR;
            S2 : ARRAY [0..80] OF CHAR;
            OK : BOOLEAN;
        BEGIN
            j := i;
                (* We are not checking here that j is in bounds.
                   In the context of our use, this is unnecessary. *)
            IF ( S[j] = "-" ) THEN
                INC(j);
            END;
                (* Note, it may be possible to crash the program if
                   you feed it a number with more characters in it
                   than S2.  We don't check for this. *)
            LOOP
                IF (j > ORD(S[0])) THEN
                    EXIT;
                END;
                C := S[j];
                IF ( ( C >= "0" ) AND ( C <= "9" ) )
                      OR 
                      (C = AmountFormat.SymbolForSignificance) 
                      OR
                      ( C = AmountFormat.RadixSymbol ) THEN
                    INC(j);
                ELSE
                    EXIT;
                END;
            END;

            SubStr(S,S2,i,j-i);
            AmountToReal( S2, R, OK );
            i := j;
            ErrorFlag := NOT OK;
        END GetReal;


        PROCEDURE GetCurrentSymbol( VAR Operator    : CHAR;
                                    VAR Operand     : REAL;
                                    VAR Position    : CARDINAL;
                                    VAR Length      : CARDINAL );
        VAR
            OK      : BOOLEAN;
            j       : CARDINAL;
        BEGIN
            IF (LastSaved) THEN
                Operator := LastOperator;
                Operand  := LastOperand;
                Position := LastPosition;
            ELSE
                LOOP
                    Position := Index;
                    IF (Position > ORD(Expression[0]) ) THEN
                        Operator := EndOfScan;
                        EXIT;
                    ELSE
                        Operator := Expression[Position];
                        IF (Operator = " ") THEN
                            INC(Index);                       (* Skip Blanks *)
                        ELSIF (Numeric(Expression,Position)) THEN
                            j := Index;
                            GetReal(Expression,j,Operand,OK);
                            Index := j;
                            Operator := IsAnOperand;
                            EXIT;
                        ELSIF (OperatorNumber(Operator) > 1 ) THEN
                            INC(Index);
                            EXIT;
                        ELSE
                            Operator := EndOfScan;    (* Not an operator *)
                            EXIT;
                        END;
                    END;
                END;    (* End of scanning for token loop. *)
                LastOperator := Operator;
                LastOperand := Operand;
                LastPosition := Position;
                LastSaved := TRUE;
            END;
            Length := Index - Position;
        END GetCurrentSymbol;

    BEGIN
        Index := ScanPosition;
        LastSaved := FALSE;
    END Lex;







        (* Pop the OperandStack. *)

    PROCEDURE Pop(): REAL;
    BEGIN
        IF (OperandStackIndex > 0) THEN
            DEC(OperandStackIndex);
            RETURN (OperandStack[OperandStackIndex+1]);
        ELSE
            ErrorFlag := TRUE;
            RETURN Zero;
        END;
    END Pop;



        (* Operate -- Apply the Operator to the operand stack.
                      Leaves any result on top of the stack.  *)


    PROCEDURE Operate(   Operator : CHAR  );
    VAR
        A, B : REAL;
    BEGIN
        IF (Operator = "(") OR (Operator = ")") THEN
            RETURN;
        ELSE
            B := Pop();
            A := Pop();
            IF (NOT ErrorFlag) THEN
                CASE Operator OF
                    "+"  : A := A + B;
                  | "-"  : A := A - B;
                  | "*"  : A := A * B;
                  | "/"  : IF ( B <> Zero ) THEN
                               A := A / B;
                           ELSE
                               ErrorFlag := TRUE;
                               A := Zero;
                           END;
                  ELSE
                      ErrorFlag := TRUE;
                      A := Zero;
                END;
                    (* Push result *)
                INC(OperandStackIndex);
                OperandStack[OperandStackIndex] := A;
            END;
        END;
    END Operate;


        (* F and G compare the precedences of two operators *)

    PROCEDURE F ( Operator : CHAR ) : CARDINAL;
    BEGIN
        RETURN ORD(FList[OperatorNumber(Operator)]) - ORD("0");
    END F;


    PROCEDURE G ( Operator : CHAR ) : CARDINAL;
    BEGIN
        RETURN ORD(GList[OperatorNumber(Operator)]) - ORD("0");
    END G;


BEGIN
    SetString(OperatorList,OpListConstant);
    SetString(FList,FArray);
    SetString(GList,GArray);

    ErrorFlag := FALSE;
    Value     := Zero;
    ScanPosition := 0;

    OperatorStack[0] := EndOfScan;
    OperatorStackIndex := 0;

    OperandStackIndex := 0;

    LOOP
        StackTop := OperatorStack[OperatorStackIndex];
        GetCurrentSymbol( Operator, Operand, ScanPosition, SymbolLength );
        IF (StackTop = EndOfScan) AND (Operator = EndOfScan) THEN
            IF (OperandStackIndex = 1) THEN
                Value := OperandStack[1];
                INC(ScanPosition,SymbolLength);
                AdvanceSymbol;
            ELSE
                ErrorFlag := TRUE;
            END;
            RETURN;
        ELSE
            IF (Operator = IsAnOperand) THEN
                INC(OperandStackIndex);
                OperandStack[OperandStackIndex] := Operand;
                AdvanceSymbol;
            ELSIF ( F(StackTop) <= G(Operator) ) THEN
                INC( OperatorStackIndex );
                OperatorStack[OperatorStackIndex] := Operator;
                AdvanceSymbol;
            ELSE
                REPEAT
                    PoppedOperator := OperatorStack[OperatorStackIndex];
                    DEC(OperatorStackIndex);
                    Operate(PoppedOperator);
                    IF (ErrorFlag) THEN
                        RETURN;
                    END;
                UNTIL ( F(OperatorStack[OperatorStackIndex]) < G(PoppedOperator) );
            END;
        END;
    END;
END EvaluateRealExpression;


END EvalReal.

