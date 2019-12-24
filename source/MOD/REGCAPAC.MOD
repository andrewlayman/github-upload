IMPLEMENTATION MODULE RegCapacity;

(*  =========================================================================
    Last Edit : February 13, 1991 3:14PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        RegCapacity - Just the "QCapacity" request - smaller code than
                      is found in RegSupport.
        

    MODIFICATION HISTORY:

       28-Sep-89 RSC    Initial version from RegSupport.
       13-Feb-91 RSC    Remove Init() call and replace with GetRegistryInfo.

    =========================================================================
*)


FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Kbio                   IMPORT
    (* CONST*)                  maxcol, VersionStringLength,
    (* VAR  *)                  maxrow, VersionString;

FROM LStrings               IMPORT
    (* PROC *)                  SetString, ConcatLS, ConcatS, Copy, SubStr,
                                StoC, StringsEqual, LengthOf, TrimRear,
                                Upshift, LStringToTString;

FROM MagicNum               IMPORT
    (* CONST *)                 IsCardValue;

IMPORT Registry;

FROM Registry               IMPORT
    (* CONST *)                 QProductSerial, QProductType, QCapacity,
                                QProductEquivalence, QProductGroup,
                                QProductMajorRelease, QProductSubRelease,
                                QProductSequence, QProductCountry,
                                QProductSecretInfo, QProductPermission,
    (* TYPE *)                  ARegistryProc, ARegistryDataRecord,
    (* VAR  *)                  ProductName, UserName, UserSerialNumber;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR;





CONST
    OfsProductCapacity      = 26;
    LenProductCapacity      = 1;





PROCEDURE GetRegistryInfo( VAR UserName    : ARRAY OF CHAR;
                           VAR ProductName : ARRAY OF CHAR;
                               InfoRequest : CARDINAL;
                           VAR ReturnValue : ARegistryDataRecord
                         ) : BOOLEAN;

VAR
    BaseValue               : CARDINAL;
    UserValue               : CARDINAL;
    CurrentProductName      : ARRAY [0..8]   OF CHAR;
    NewProductName          : ARRAY [0..8]   OF CHAR;
    Registration            : BOOLEAN;


    PROCEDURE TwoToThe(n    : CARDINAL) : CARDINAL;

    VAR
        i                   : CARDINAL;
        ReturnVal           : CARDINAL;

    BEGIN
        ReturnVal := 1;
        FOR i := 1 TO n DO
            ReturnVal := ReturnVal * 2;
        END;

        RETURN(ReturnVal);
    END TwoToThe;



    PROCEDURE Min(i, j : CARDINAL) : CARDINAL;

    VAR
        k                   : CARDINAL;

    BEGIN
        k := j;
        IF (i < j) THEN
            k := i;
        END;

        RETURN (k);
    END Min;

BEGIN

    Copy(ProductName, NewProductName);
    Copy(Registry.ProductName, CurrentProductName);

    TrimRear(NewProductName);
    Upshift( NewProductName);
    TrimRear(CurrentProductName);
    Upshift( CurrentProductName);


    Registration := (StringsEqual(UserName, Registry.UserName) AND
                     StringsEqual(NewProductName, CurrentProductName));

    IF (Registration) AND (InfoRequest = QCapacity) THEN
        ReturnValue.DataType      := IsCardValue;
        BaseValue                 :=
            ORD(VersionString[OfsProductCapacity+1]) - ORD("0");
        UserValue                 :=
            ORD(UserSerialNumber[OfsProductCapacity+1]) - ORD("0");

        ReturnValue.CardinalValue := Min(BaseValue, UserValue);

        IF (ReturnValue.CardinalValue = 9) THEN (* TL thinks that 0 *)
            ReturnValue.CardinalValue := 0;     (* means unlimited  *)
        ELSE
            ReturnValue.CardinalValue := 
                TwoToThe(ReturnValue.CardinalValue + 5);
        END;

    ELSE
        FatalError();
    END;

    RETURN Registration;

END GetRegistryInfo;







END RegCapacity.
