IMPLEMENTATION MODULE CutPaste;

(*  =========================================================================
    Last Edit : February 20, 1991 5:12PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        Implement a simple Cut/Paste buffer.

    MODIFICATION HISTORY:

         9-Aug-89  RSC  First cut, as per AJL.
        20-Feb-91  RSC  Fixed some flaws while researching why Cut/Paste
                        seems not to work (as per AJL).

    =========================================================================
*)


FROM LStrings       IMPORT
    (* PROC *)          SetLengthOf, SetString;

FROM Holder         IMPORT
    (* TYPE *)          AHoldType, AHoldTypeSet,
    (* PROC *)          HoldThis, LocateHeldItem, DeleteHeldItem;

FROM Text           IMPORT
    (* TYPE *)          AText,
    (* PROC *)          CreateText, DiscardText, TextExists,
                        AssignText, LineExists, CopyLine, AssignLine;

FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS;






CONST
    CutPasteClass   = 69;
    CutPasteName    = "CUTPASTE";



    (*  =====================================================================
        
        PROCEDURE - CopyToPasteBuffer

            Preconditions :

                Time Line has initialized, and FlexStor is running.
                The StringToEdit cannot contain any chars not allowed by
                the Text module in AText.

            Postconditions :

                The global paste buffer contains ONLY the passed string.

            Parameters :
                Input:  CutPasteString  the string to copy to the cut/paste
                                        buffer.  It must fit within one line
                                        of "AText".

                Output: None

        =====================================================================
    *)
PROCEDURE CopyToPasteBuffer( VAR CutPasteString : ARRAY OF CHAR );
VAR
    LocalText : AText;
    ok        : BOOLEAN;
BEGIN
    LocalText := CreateText();
    IF (LocalText <> AText(NIL)) AND    (* 20-Feb-91 RSC  *)
       (AssignLine( CutPasteString, 0, LocalText )) THEN
        CopyToPasteText( LocalText );
        DiscardText(     LocalText );
    END;
END CopyToPasteBuffer;








    (*  =====================================================================
        
        PROCEDURE - CopyToPasteText

            Preconditions :

                Time Line has initialized, and FlexStor is running.

            Postconditions :

                The global paste buffer contains the passed text.

            Parameters :
                Input:  Text        A Valid, filled in Text record.

                Output: None.

        =====================================================================
    *)
PROCEDURE CopyToPasteText(    Text  : AText );
VAR
    HeldText : AText;
    Where    : ADDRESS;
    Size     : CARDINAL;
    Category : AHoldTypeSet;
    Name     : ARRAY [0..29] OF CHAR;
BEGIN
    SetString( Name, CutPasteName );

    IF (LocateHeldItem( Name, CutPasteClass, Category, Where, Size )) THEN
        HeldText := AText(Where);   (* 20-Feb-91 RSC  *)
        DiscardText( HeldText );    (* 20-Feb-91 RSC  *)
        DeleteHeldItem( Name, CutPasteClass );
    END;

    IF (AssignText( Text, HeldText )) THEN
        HoldThis( Name, CutPasteClass,
                  AHoldTypeSet{ErrorIfDuplicate,HoldsAddress},
                  ADDRESS(HeldText), 2 );
    END;

END CopyToPasteText;






    (*  =====================================================================
        
        PROCEDURE - PasteBuffer

            Preconditions :

                Time Line has initialized, and FlexStor is running.

            Postconditions :

                The first line of the paste buffer, if any, is copied into
                CutPasteString.  If there is no paste string, CutPasteString
                is empty.  Any needed truncation happens.

            Parameters :
                Input:  None.

                Output: CutPasteString  is the string containing whatever
                                           was in the paste buffer.

        =====================================================================
    *)
PROCEDURE PasteBuffer( VAR CutPasteString : ARRAY OF CHAR );
VAR
    Where    : ADDRESS;
    Size     : CARDINAL;
    Category : AHoldTypeSet;
    Name     : ARRAY [0..29] OF CHAR;
BEGIN
    SetString( Name, CutPasteName );

    IF (LocateHeldItem( Name, CutPasteClass, Category, Where, Size )) THEN
        CopyLine( AText(Where), 0, CutPasteString );
    ELSE
        SetLengthOf( CutPasteString, 0 );
    END;

END PasteBuffer;




    (*  =====================================================================
        
        PROCEDURE - PasteText

            Preconditions :

                Time Line has initialized, and FlexStor is running.
                Text is a valid Text, including NIL.  It cannot be
                uninitialized garbage.

            Postconditions :

                The text is returned as the entire paste buffer.  If no
                paste buffer is available, then an empty text is returned.
                It could be NIL.  The old contents of Text are destroyed.

            Parameters :
                Input:  None.

                Output: Text contains the paste buffer.

        =====================================================================
    *)
PROCEDURE PasteText( VAR Text        : AText );
VAR
    Where    : ADDRESS;
    Size     : CARDINAL;
    Category : AHoldTypeSet;
    Name     : ARRAY [0..29] OF CHAR;
BEGIN
    SetString( Name, CutPasteName );

    IF (LocateHeldItem( Name, CutPasteClass, Category, Where, Size )) AND
       (AssignText( AText(Where), Text )) THEN
    ELSE
        Text := AText(NIL);            (* 20-Feb-91 RSC  *)
    END;

END PasteText;








END CutPaste.

