    (*  ---------------- Module TextStack ------------ *)

IMPLEMENTATION MODULE TextStack;

FROM Space IMPORT ALLOCATE, DEALLOCATE;

FROM LStrings IMPORT SubStr;


TYPE
    AStackNodePointer = POINTER TO AStackNode;
    AStackNode = RECORD
                     Name : ARRAY [0..255] OF CHAR;
                     Level: CARDINAL;
                     Link : AStackNodePointer;
                 END;

VAR
    Stack : AStackNodePointer;


PROCEDURE PushText(    Name : ARRAY OF CHAR;
                       Level   : CARDINAL );
VAR
    Node : AStackNodePointer;
BEGIN
    NEW(Node);
    SubStr(Name,Node^.Name,1,HIGH(Node^.Name));
    Node^.Level := Level;
    Node^.Link := Stack;
    Stack := Node;
END PushText;




PROCEDURE PopText( VAR Name : ARRAY OF CHAR;
                   VAR Level : CARDINAL ) : BOOLEAN;
VAR
    Node : AStackNodePointer;
BEGIN
    IF (Stack = NIL) THEN
        RETURN FALSE;
    ELSE
        SubStr(Stack^.Name,Name,1,HIGH(Name));
        Level := Stack^.Level;
        Node  := Stack^.Link;
        DISPOSE(Stack);
        Stack := Node;
        RETURN TRUE;
    END;
END PopText;


PROCEDURE FlushTextStack;
VAR
    Name        : ARRAY [0..10] OF CHAR;
    Level         : CARDINAL;
BEGIN
    WHILE (PopText(Name,Level)) DO; END;
END FlushTextStack;



BEGIN
    Stack := NIL;
END TextStack.
