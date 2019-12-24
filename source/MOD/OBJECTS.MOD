IMPLEMENTATION MODULE Objects;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;


CONST
    ModuleNumber            = 14800;

VAR
    ObjectMethodsRecord      : AnObjectMethodsRecord;





PROCEDURE ObjectClone(    OldObject         : AnObject;
                      VAR NewObject         : AnObject)
                                                       : BOOLEAN;

BEGIN                       (* ObjectClone *)

    FatalError();

END ObjectClone;







PROCEDURE ObjectStoreOn(    Object          : AnObject;
                            StoreOnFile     : AnObject);

BEGIN                       (* ObjectStoreOn *)

    FatalError();

END ObjectStoreOn;








PROCEDURE ObjectDiscard(VAR Object          : AnObject);

BEGIN                       (* ObjectDiscard *)

    FatalError();

END ObjectDiscard;








(*----------------------------------------------------------------------------
    InitAsObject --

    Initialize the area of memory referenced as an object, so that it is a
    valid object.  This procedure does not allocate storage for an object, 
    but initializes that storage after it is allocated (from either the heap
    or the stack).

    Preconditions:
        None.

    Postconditions:
        The object will be initialized as a valid object.
----------------------------------------------------------------------------*)

PROCEDURE InitAsObject(    Object           : AnObject);

BEGIN                       (* InitAsObject *)

    WITH Object^ DO
        Methods := AnObjectMethods(ADR(ObjectMethodsRecord));
    END;

END InitAsObject;







(*----------------------------------------------------------------------------
    UnInitAsObject --

    UnInitialize the indicated object.

    Preconditions:
        The object must be a valid object.

    Postconditions:
        Whatever was done by InitAsObject will be un-done.
----------------------------------------------------------------------------*)

PROCEDURE UnInitAsObject(    Object         : AnObject);

BEGIN                       (* UnInitAsObject *)

    Object^.Methods := NIL;

END UnInitAsObject;







(*----------------------------------------------------------------------------
    ValidateObject --

    Check the given object and determine if it is a valid object.

    Preconditions:
        None.

    Postconditions:
        FatalError will be called if the object is not valid.
----------------------------------------------------------------------------*)

PROCEDURE ValidateObject(    Object         : AnObject);
                                                       
BEGIN                       (* ValidateObject *)

    IF (Object^.Methods^.ObjectMethodsTag <> ModuleNumber) THEN
        FatalError();
    END;

END ValidateObject;






(*----------------------------------------------------------------------------
    CloneObjectMethods --

    Make a copy of this class' methods into the indicated method object.

    Preconditions:
        None.

    Postconditions:
        The object methods will be copied into the indicated method object.
----------------------------------------------------------------------------*)

PROCEDURE CloneObjectMethods(    ObjectMethods : AnObjectMethods);

BEGIN                       (* CloneObjectMethods *)

    ObjectMethods^ := ObjectMethodsRecord;
    ObjectMethods^.SuperclassMethods 
                                 := AnObjectMethods(ADR(ObjectMethodsRecord));

END CloneObjectMethods;





BEGIN                       (* Objects *)

    WITH ObjectMethodsRecord DO
        Methods := NIL;
        Clone := ObjectClone;
        StoreOn := ObjectStoreOn;
        Discard := ObjectDiscard;
        SuperclassMethods := NIL;
        MethodSize := TSIZE(AnObjectMethodsRecord);
        ObjectMethodsTag := ModuleNumber;
    END;

END Objects.
