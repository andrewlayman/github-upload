IMPLEMENTATION MODULE SubStub;

(*  =========================================================================
    Last Edit : March 5, 1991 4:14PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        This module was created to solve a problem in Subfiles.Mod.

        The problem is that Subfiles installs a file CloseProc to be
        executed when the subfile is closed.  The trouble is, the
        Subfiles.Mod code is not bound into the root in EVE, and so
        the installer of the close proc may not exist when the file
        is closed.

        This module knows very little of the internals of Subfiles,
        but it does know how to deallocate the Subfile cache.


    MODIFICATION HISTORY:

         5-Mar-91 RSC  First version.

    =========================================================================
*)



FROM FileSystem     IMPORT
    (* TYPE *)          AFilePointer;

FROM Space          IMPORT
    (* PROC *)          DEALLOCATE;




PROCEDURE InputCloseProc( P : AFilePointer );
VAR
    BufferPointer : POINTER TO CARDINAL;
BEGIN
    IF (P^.UserBuffer <> NIL) THEN
        BufferPointer := P^.UserBuffer;
        DEALLOCATE( BufferPointer, BufferPointer^ );
    END;
END InputCloseProc;




BEGIN  (* module SubStub *)
END SubStub.


