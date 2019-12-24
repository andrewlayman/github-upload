MODULE TLSetCSV;

    (*  Modification History:

        RSC  6-Feb-89  Change "ExportersOK" to "PackageOK"
        EGK 12-Jun-89  Oops.  I thought an attribute of "HoldsNumber"
                       meant you could just use the held item's size as
                       the number you're holding, and use NIL as the
                       item's location.  Not true, so I fixed
                       SetLengthSelection appropriately.
        KKC 09-Aug-89  Add copyright message.

        This overlay puts up the initial dialog allowing the user to change
        the CSV line length, before any exporting happens.
    *)


FROM Dialog                 IMPORT
    (* TYPE *)                  ADialogOption,
    (* PROC *)                  Message, Error, FatalError,
                                NotYetImplemented, MultipleChoiceBox;

FROM Holder                 IMPORT
    (* TYPE *)                  AHoldType, AHoldTypeSet,
    (* PROC *)                  HoldThis, LocateHeldItem, DeleteHeldItem;

FROM LStrings               IMPORT
    (* PROC *)                  SetLengthOf, SetString, StoC, LengthOf, Copy;

FROM Menus                  IMPORT
    (* PROC *)                  WordNumber;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage, ConcatMessage;

FROM Overlays               IMPORT
    (* VAR *)                   PackageOK;

FROM Space                  IMPORT
    (* PROC *)                  Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS,
    (* PROC *)                  TSIZE;



CONST
    LengthName      = "CSVLength";
    LengthClass     = 64;               (* A very good year *)

    ModuleNumber    = 24400;            (* Same as TLXCSV! *)

VAR
    MenuString      : ARRAY [0..50] OF CHAR;
    Prefix          : ARRAY [0..1] OF CHAR;
    Selection       : CARDINAL;
    i               : CARDINAL;
    s               : ARRAY [0..40] OF CHAR;
    Title           : ARRAY [0..40] OF CHAR;
    LineLength      : CARDINAL;
    HoldName        : ARRAY [0..20] OF CHAR;
    Category        : AHoldTypeSet;
    Where           : POINTER TO CARDINAL;
    Size            : CARDINAL;
    TotalSelections : CARDINAL;


PROCEDURE NumberOfWords ( VAR s     : ARRAY OF CHAR ) : CARDINAL;
VAR
    i           : CARDINAL;
    s2          : ARRAY [0..20] OF CHAR;
BEGIN
    i := 0;
    LOOP
        WordNumber (s, i+1, s2);
        IF (LengthOf(s2) = 0) THEN
            EXIT;
        END;
        INC (i);
    END;
    RETURN i;
END NumberOfWords;




PROCEDURE GetLengthSelection () : CARDINAL;
VAR
    Copyright                      : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    SetString (HoldName, LengthName);
    IF (LocateHeldItem (HoldName, LengthClass, Category,
                        Where, Size))                      THEN
        RETURN Where^;
    ELSE
        RETURN 0;
    END;
END GetLengthSelection;


PROCEDURE SetLengthSelection ( Length   : CARDINAL );
BEGIN
    SetString (HoldName, LengthName);
    IF (LocateHeldItem (HoldName, LengthClass, Category,
                        Where, Size))                      THEN
        Where^ := Length;
    ELSE
        Size := TSIZE(CARDINAL);
        IF (Available (Size)) THEN        (* You've got to be kidding *)
            NEW (Where);
            Where^ := Length;
            HoldThis (HoldName, LengthClass,
                      AHoldTypeSet{HeapNoOwner,HoldInConfig}, Where, Size);
        END;
    END;
END SetLengthSelection;


BEGIN

        (* Get the previous selection.  0 means "unlimited".    *)

    Selection := GetLengthSelection();

    GetMessage (ModuleNumber+1, Title);             (* "CSV Exporter" *)
    SetLengthOf (Prefix, 0);
    GetMessage (ModuleNumber+2, s);                 (* "Maximum Line Length" *)
    GetMessage (ModuleNumber+3, MenuString);        (* "80,120,250" *)
    TotalSelections := NumberOfWords (MenuString);
    IF (Selection = 0) THEN
        Selection := TotalSelections + 1;
    END;
    ConcatMessage (MenuString, ModuleNumber+4);     (* ",Unlimited" *)
    IF (MultipleChoiceBox (s, Title, NoHelp, Prefix, MenuString,
                               Selection)) THEN
        IF (Selection > TotalSelections) THEN
            Selection := 0;
        END;
        SetLengthSelection (Selection);
    ELSE
        PackageOK := FALSE;
    END;

END TLSetCSV.
