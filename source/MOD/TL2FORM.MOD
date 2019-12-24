MODULE TL2Form;

    (* TL version 2 importer's form

        RSC  1/22/88 - Moved here from tlitl2.mod.
        AJL  2/19/88 - Allocate the form record off the heap.
                     - Put a shadow on the box. 
        RSC  2/22/88 - Put form into forms file.  Added 3rd line.
        LAA  2/29/88 - Changed form number to 47 to match the forms file.
        KKC  09-Aug-89 Add copyright message.
    *)


FROM Codes                  IMPORT ACode;

FROM Forms                  IMPORT
    (* TYPE *)                  AForm, AFieldValue,
    (* PROC *)                  NullCheckProc, DoForm;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol;

FROM Keys                   IMPORT DoIt, CancelKey;

FROM Layout                 IMPORT
    (* CONST *)                 GanttWEnd;
 
FROM LStrings               IMPORT
    (* PROC *)                  SetString;

FROM Overlays               IMPORT
    (* PROC *)                  OverlayContext;



PROCEDURE GetOptions();

CONST
    cThisForm               = 47;                                 (* 29-Feb-88 LAA *)
    
VAR
    Code                    : ACode;
    FormValue               : ARRAY [0..2] OF AFieldValue;
    Context                 : POINTER TO ARRAY [0..3] OF CARDINAL;
    i                       : CARDINAL;
    Copyright               : ARRAY[0..50] OF CHAR;
    
BEGIN                       (* GetFileName *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Context := OverlayContext();

    FormValue[0].CardValue := 0;
    FormValue[1].CardValue := 0;
    
    Code := DoForm(0,0,maxcol, GanttWEnd, cThisForm, TRUE, FormValue,
                   NullCheckProc );

    IF (Code <> CancelKey) THEN
        Context^[0] := 1; (* Flag that it was not the cancel key *)
        Context^[1] := FormValue[0].CardValue;
        Context^[2] := FormValue[1].CardValue;
    END;

END GetOptions;






BEGIN
    GetOptions();
END TL2Form.
