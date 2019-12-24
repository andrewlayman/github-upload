IMPLEMENTATION MODULE ColFind;

(*  =========================================================================
    Last Edit : August 5, 1991 5:17PM by PFG
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        Retrieve column information for user modification.

    MODIFICATION HISTORY:
    
    27-Aug-90 PFG   First version.
    28-Sep-90 PFG   Added generic ColumnGotoCheckProc() for use by all
                    columns.
    2-Oct-90  PFG   Removed the (short-lived) ColumnGoToCheckProc.  Now
                    handled in TLColName.
    5-Aug-91  PFG   I made GetColumnItem more forgiving when it encounters
                    a string that's too long for the array that's passed to
                    it.  Now it shortens the string if it needs to.  This 
                    way, the program won't display an unfriendly message if
                    translators make a mistake and get some strings too
                    long in the phrases file.
    =========================================================================
*)

FROM ColData                IMPORT
    (* TYPE  *)                 AColumnType,
    (* VAR   *)                 ColumnTable;


FROM ColumnSupport          IMPORT
    (* CONST *)                 FullTitle,
                                DescriptionIndex,
                                OrigNameIndex;

FROM Dialog                 IMPORT  
    (* PROC  *)                 FatalError;

FROM LStrings               IMPORT
    (* PROC  *)                 StoC, CtoS, LengthOf, Procustes, Copy;

FROM MsgFile                IMPORT
    (* PROC *)                  GetMessage;

FROM SegWords               IMPORT
    (* PROC *)                  WordNumber, UpdateWordAtWordNumber;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  CreateText, TextExists, CopyLine, AssignLine;



TYPE
    AColumnLineType = (ColInfo, ColPrompt, ColSpare1, ColSpare2, ColSpare3);



(*----------------------------------------------------------------------------
    ColumnPosition --  

    Return the position in the column Text of the requested line.            

    Preconditions:
        The column ID must be 1 or greater.

    Postconditions:
        A line number is returned.
        
----------------------------------------------------------------------------*)



PROCEDURE ColumnPosition(ID : CARDINAL; LineType : AColumnLineType) : CARDINAL;

CONST
    NLineTypeElements       =       ( ORD( MAX( AColumnLineType ) ) + 1 );

BEGIN

    IF (ID < 1) THEN
        FatalError();
    END;

    RETURN( ( ID - 1 ) * NLineTypeElements + ORD(LineType) );

END ColumnPosition;




(*----------------------------------------------------------------------------
    GetColumnFromText --

    Retrieve a line of column info from the Text if it exists.

    Preconditions:
        ColumnTable[ColumnType] must already have been created, although
        it may be empty.

    Postconditions:
        A line of column info is returned in String.  If the line is
        empty, the procedure will return FALSE.
        
----------------------------------------------------------------------------*)


PROCEDURE GetColumnFromText(    ColumnType  : AColumnType;
                                ID          : CARDINAL; 
                                LineType    : AColumnLineType;
                            VAR String      : ARRAY OF CHAR    ) : BOOLEAN;
VAR
    LinePosition : CARDINAL;

BEGIN

    LinePosition := ColumnPosition( ID, LineType );

    CopyLine( ColumnTable[ColumnType], LinePosition, String );

    RETURN (LengthOf(String) > 0);

END GetColumnFromText;
        



(*----------------------------------------------------------------------------
    PutColumnInText --

    Put a line of column info into the Text.

    Preconditions:
        None.  If a Text to place the column info in doesn't exist,
        it will be created.

    Postconditions:
        Returns FALSE if the column info couldn't be placed in the Text.
        
----------------------------------------------------------------------------*)


PROCEDURE PutColumnInText(    ColumnType    : AColumnType;
                              ID            : CARDINAL; 
                              LineType      : AColumnLineType;
                          VAR String        : ARRAY OF CHAR   ) : BOOLEAN;

VAR
    LinePosition : CARDINAL;

BEGIN

    IF (NOT(TextExists(ColumnTable[ColumnType]))) THEN
        ColumnTable[ColumnType] := CreateText();
    END;

    LinePosition := ColumnPosition( ID, LineType );

    RETURN ( AssignLine( String, LinePosition, ColumnTable[ColumnType] ) );

END PutColumnInText;
        

(*<  Not used yet...

PROCEDURE EnumerateColumns(ColumnType   : AColumnType;
                           DoThis       : AColDefProc;
                           Context      : ADDRESS
                          );
VAR
    LinePosition        :       CARDINAL;
    ID                  :       CARDINAL;

BEGIN
    ID := 1;
    LOOP
        LinePosition := ColumnPosition( ID, ColInfo );
        DoThis( ColumnType, ID, Context );
        INC( ID );
    END;
END EnumerateColumns;

>*)



(*----------------------------------------------------------------------------
    GetFromPhrasesOrText --

    Looks in memory for user-modified column info first, then in the Phrases
    file.  Retrieves any kind of column line.

    Preconditions:
        The user-defined columns must have been loaded in from the config
        file first.

    Postconditions:
        The retrieved column info is placed in Line.
----------------------------------------------------------------------------*)



PROCEDURE GetFromPhrasesOrText(    ModuleNumber : CARDINAL;
                                   ColumnType   : AColumnType;
                                   ID           : CARDINAL;
                                   LineType     : AColumnLineType;
                               VAR Line         : ARRAY OF CHAR);

BEGIN

    IF (NOT GetColumnFromText(ColumnType, ID, LineType, Line )) THEN
        GetMessage(ModuleNumber + ID, Line);
    END;
    
END GetFromPhrasesOrText;


(*----------------------------------------------------------------------------
    GetColInfoFromPhrasesOrText --

    Looks in memory for user-modified column info first, then in the Phrases
    file.  Client of this proc has no need to know about different kinds
    of column lines.  This proc retrieves column info lines only.

    Preconditions:
        The user-defined columns must have been loaded in from the config
        file first.

    Postconditions:
        The retrieved string is placed in Line.
----------------------------------------------------------------------------*)


PROCEDURE GetColInfoFromPhrasesOrText(    ModuleNumber : CARDINAL;
                                          ColumnType   : AColumnType;
                                          ID           : CARDINAL;
                                      VAR Line         : ARRAY OF CHAR);

BEGIN

    GetFromPhrasesOrText(ModuleNumber, 
                         ColumnType,
                         ID,
                         ColInfo,
                         Line);
    
END GetColInfoFromPhrasesOrText;



(*----------------------------------------------------------------------------
    GetColumnItem --

    Retrieve a particular type of column information.

    Preconditions:
        A string must be passed that's large enough to hold the 
        retrieved information.  The ColumnItem must be a valid number,
        from the list in ColumnSupport.

    Postconditions:
        The retrieved information is returned in Value or Name, 
        depending on whether it is a number.
        
----------------------------------------------------------------------------*)

PROCEDURE GetColumnItem(    ModuleNumber    : CARDINAL;   
                            ColumnType      : AColumnType;
                            ID              : CARDINAL;
                            ColumnItem      : CARDINAL;
                            ToNumber        : BOOLEAN;
                        VAR Value           : CARDINAL;
                        VAR Name            : ARRAY OF CHAR);

VAR
    i          : CARDINAL;
    TempBuffer1: ARRAY[0..255] OF CHAR;
    TempBuffer2: ARRAY[0..255] OF CHAR;



    PROCEDURE PutBufferIntoName();              (* 5-Aug-91 PFG *)
    BEGIN
        IF (ORD(TempBuffer2[1]) > HIGH(Name)) THEN
            Procustes(TempBuffer2, HIGH(Name));
        END;
        Copy(TempBuffer2, Name);
    END PutBufferIntoName;


BEGIN

    CASE ColumnItem OF

        DescriptionIndex    :   (*  Description (prompt) line  *)

            GetFromPhrasesOrText(ModuleNumber,
                                 ColumnType,
                                 ID, 
                                 ColPrompt,
                                 TempBuffer2);
            PutBufferIntoName();

    |   OrigNameIndex       :   (*  Original column name from Phrases  *)

            GetMessage(ModuleNumber + ID , TempBuffer1);
            WordNumber(TempBuffer1, FullTitle, TempBuffer2);
            PutBufferIntoName();

    ELSE
            GetFromPhrasesOrText(ModuleNumber,
                                 ColumnType,
                                 ID, 
                                 ColInfo,
                                 TempBuffer1);
            WordNumber(TempBuffer1, ColumnItem, TempBuffer2);

            IF (ToNumber) THEN
                i := 1;
                Value := StoC(TempBuffer2, i);
            ELSE
                PutBufferIntoName();
            END;

    END;

    (*  Put the contents of TempBuffer2 into the Name variable, adjusting
        the length if necessary.  *)

    PutBufferIntoName();                        (* 5-Aug-91 PFG *)

END GetColumnItem;



(*----------------------------------------------------------------------------
    SetColumnItem --

    Save a particular type of column information.

    Preconditions:
        The ColumnItem must be a valid number, from the list in 
        ColumnSupport.

    Postconditions:
        The information is saved in the Text for this ColumnType.
        
----------------------------------------------------------------------------*)

PROCEDURE SetColumnItem(    ModuleNumber: CARDINAL;
                            ColumnType  : AColumnType;
                            ID          : CARDINAL;
                            ColumnItem  : CARDINAL;
                            ToNumber    : BOOLEAN;
                            Value       : CARDINAL;
                        VAR Name        : ARRAY OF CHAR);

VAR
    TempBuffer   : ARRAY[0..255] OF CHAR;
    NumberString : ARRAY[0..10] OF CHAR;

BEGIN

    IF (ColumnItem = DescriptionIndex) THEN (*  Description (prompt) line  *)
        IF (NOT PutColumnInText(ColumnType, ID, ColPrompt, Name)) THEN
            FatalError();
        END;

    ELSE

        GetColInfoFromPhrasesOrText(ModuleNumber,
                                    ColumnType, 
                                    ID, 
                                    TempBuffer);
        IF (ToNumber) THEN
            CtoS(Value, NumberString);
            UpdateWordAtWordNumber(TempBuffer, ColumnItem, NumberString);
        ELSE
            UpdateWordAtWordNumber(TempBuffer, ColumnItem, Name);
        END;

        IF (NOT PutColumnInText(ColumnType, ID, ColInfo, TempBuffer)) THEN
            FatalError();
        END;

    END;

END SetColumnItem;


BEGIN 

END ColFind.

