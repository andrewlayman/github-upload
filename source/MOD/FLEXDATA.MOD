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
       24-Sep-91 AJL -In order to reduce fragmentation, always free up as
                      much temporary memory as possible before allocating a
                      page table, since they cannot be moved, and we
                      would like them loaded as low as possible. 

    *)

FROM FatalErr               IMPORT
    (* PROC *)                  FatalError;
    
FROM LStrings               IMPORT
                                SetString, StoC;

FROM Notices        IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          SendNotices;

FROM ParmLine               IMPORT
    (* PROC *)                  GetOption;


FROM Space                  IMPORT
    (* TYPE *)                  AMemoryRequest, APurgeRequest,
    (* PROC *)                  HeapSpaceLeft, ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM IMPORT 
    (* TYPE *)        ADDRESS,
    (* PROC *)        TSIZE;



VAR
    CurrentPageTableSize : CARDINAL;




PROCEDURE EnoughFree() : BOOLEAN;
BEGIN                       (* EnoughFree *)
    RETURN FALSE;  (* We can NEVER get enough memory! *)
END EnoughFree;



PROCEDURE AllocateForNPages( VAR N : CARDINAL;
                             VAR P : APageTablePointer;
                             VAR Size : CARDINAL) : BOOLEAN;
BEGIN

        (* In order to reduce fragmentation, always free up as
           much temporary memory as possible before allocating a
           page table, since they cannot be moved, and we
           would like them loaded as low as possible. *)

    SendNotices(LowMemory, AfterActing, ADDRESS(EnoughFree));

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
    i : CARDINAL;
BEGIN
    WHILE (ByHowMuch > 0) DO
        NewMaxPages := MaxPages + ByHowMuch;
        IF AllocateForNPages(NewMaxPages,NewPageTable,NewSize) THEN
                (* Copy the old table to the new one. *)
            FOR i := 1 TO NewMaxPages DO
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
CONST
    MinimumPageTableSize = 4;
VAR
    S,S2 : ARRAY [0..255] OF CHAR;
    i    : CARDINAL;
    Found : BOOLEAN;
BEGIN
    PageOverhead := TSIZE(APageHeader) + TSIZE(APageIndexArray)
                             + ( 3 * TSIZE(APageSet) );

        (* Select the maximum number of pages we will allow. *)

    SetString(S2,"VPAGES");            (* "VPAGES" *)
    GetOption(S2,Found,S);
    IF (Found) THEN
        i := 1;
        MaxPages := StoC(S,i);
    ELSE
        MaxPages     := 256;
    END;


        (* Allocate memory for pages.  If we cannot allocate the
           requested amount, allocate fewer. *)

        (* Step 1, create a small page table. *)

    i := MinimumPageTableSize;    
    IF NOT AllocateForNPages(i,PageTable,CurrentPageTableSize) THEN
        FatalError();
    END;

        (* Step 2, enlarge it.  *)

    IF (MaxPages > i) THEN
        IF EnlargePageTable(MaxPages-i) THEN
        END;
    END;


  
END Init;





BEGIN
    Init();
END FlexData.

