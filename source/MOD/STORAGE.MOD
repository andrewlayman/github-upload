IMPLEMENTATION MODULE Storage;

    (* MODIFICATION HISTORY
     *     8/10/88  AJL  - Added debugging versions of the code controlled
     *                     by the DEBUG version toggle.

        15-Sep-89 RSC  Removed references to BTStorage.
                       Moved AJL's checking code (which had a bug in it)
                       to TLMAGIC, removing the bug as I did so.  The bug
                       was the the check codes were written too far past
                       the end of the allocated item.
     *)

IMPORT                Space;
FROM SYSTEM    IMPORT ADDRESS;


PROCEDURE ALLOCATE (VAR a: ADDRESS; size: CARDINAL);
BEGIN
    Space.ALLOCATE(a, size);
END ALLOCATE;


PROCEDURE DEALLOCATE (VAR a: ADDRESS; size: CARDINAL);
BEGIN
    Space.DEALLOCATE(a,size);
END DEALLOCATE;


PROCEDURE Available (size: CARDINAL) : BOOLEAN;
BEGIN
    RETURN Space.Available(size);
END Available;



PROCEDURE InstallHeap;
BEGIN
    HALT;
END InstallHeap;


PROCEDURE RemoveHeap;
BEGIN
    HALT;
END RemoveHeap;


END Storage.
