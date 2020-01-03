IMPLEMENTATION MODULE FlexData;

    (* MODIFICATION HISTORY

       23-Feb-89 AJL -Made MaxPages a variable and allocate the PageTable
                      from the Heap. 
                     -Read the parmline to get the maximum number of pages
                      to allow.  (The keyword for this should come from 
                      GAGA, but doesn't, yet.)
       12-Jun-90 AJL -Add the EnlargePageTable procedure.
                     -During startup, if the requested number of pages 
                      cannot be allocated, try to allocate fewer, rather
                      than halting.
       17-Jan-91 AJL -Add a limit of the MaxPageNumber.
                     -Correct calculation of PageOverhead.

    *)

FROM FatalErr               IMPORT
    (* PROC *)                  FatalError;
    
FROM LStrings               IMPORT
                                SetString, StoC;

FROM ParmLine               IMPORT
    (* PROC *)                  GetOption;


FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM IMPORT 
    (* PROC *)        ADR, ADDRESS, TSIZE;



CONST
    MaxPageNumber = 255;


VAR
    CurrentPageTableSize : CARDINAL;


PROCEDURE AllocateForNPages( VAR N : CARDINAL;
                             VAR P : APageTablePointer;
                             VAR Size : CARDINAL) : BOOLEAN;
BEGIN
        (* Allocate enough room to manage that many pages.   
           The odd construct in this equation rounds the size up to the next
           even number of bytes. *)
    Size := CARDINAL(BITSET( TSIZE(APageInfo) + 1 ) * BITSET( 0FFFEH )) * N;
    IF (Available(Size)) THEN
        ALLOCATE( P, Size );
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END AllocateForNPages;



PROCEDURE EnlargePageTable( ByHowMuch : CARDINAL ) : BOOLEAN;
VAR
    NewPageTable : APageTablePointer;
    NewMaxPages, NewSize  : CARDINAL;
    i : APageNo;
BEGIN
    WHILE (ByHowMuch > 0) DO
        NewMaxPages := MaxPages + ByHowMuch;
            (* Don't try to allocate more than we can count. *)
        IF (NewMaxPages > MaxPageNumber) THEN
            NewMaxPages := MaxPageNumber;
        END;

        IF (NewMaxPages <= MaxPages) THEN
            RETURN FALSE;
        ELSIF AllocateForNPages(NewMaxPages,NewPageTable,NewSize) THEN
                (* Copy the old table to the new one. *)
            FOR i := 0 TO MaxPages DO
                IF i <= MaxPages THEN
                    NewPageTable^[i] := PageTable^[i];
                ELSE
                    NewPageTable^[i].Valid := FALSE;
                END;
            END;
                (* Deallocate the old page table. *)
            DEALLOCATE( PageTable, CurrentPageTableSize );
                (* Switch pointers. *)
            PageTable := NewPageTable;
            MaxPages := NewMaxPages;
            CurrentPageTableSize := NewSize;
            RETURN TRUE;
        ELSE
            ByHowMuch := ByHowMuch DIV 2;
        END;
    END;

    RETURN FALSE;

END EnlargePageTable;


PROCEDURE Init();
VAR
    S,S2 : ARRAY [0..255] OF CHAR;
    PageData : ADDRESS;
    i    : CARDINAL;
    Found : BOOLEAN;
    Page[0H:0H] : APagePointer;
BEGIN
    (*
    PageOverhead := TSIZE(APageHeader)
                             + TSIZE(APageIndexArray)
                             + TSIZE(APageSet)
                             + SIZE(Page^.Generation);
    *)
        (* The above formula looks good, but it doesn't necessarily account
           for alignment and padding that may be generated by the compiler.

           The following is a total trick, in that we never need to
           allocate the Page, just pretend it has been.  Since this messes
           around with addresses' internals, it is not portable to protected
           mode, only to real mode Intel architecture. *)
    PageData := ADR( Page^.Data );
    PageOverhead := PageData.OFFSET;

        (* Select the maximum number of pages we will allow. *)

    SetString(S2,"VPAGES");            (* "VPAGES" *)
    GetOption(S2,Found,S);
    IF (Found) THEN
        i := 1;
        MaxPages := StoC(S,i);
    ELSE
        MaxPages     := 128;
    END;


        (* Allocate memory for pages. *)

    IF NOT AllocateForNPages(MaxPages,PageTable,CurrentPageTableSize) THEN
        FatalError();
    END;
  
END Init;





BEGIN
    Init();
END FlexData.
