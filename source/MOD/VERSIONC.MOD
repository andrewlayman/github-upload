IMPLEMENTATION MODULE VersionConflict;

(*  =========================================================================
    Last Edit : November 29, 1989 10:25AM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        This Moudle exports just one procedure: ConflictProc.  This proc
        doesn't do anything, it's an empty procedure.  The purpose of this
        module is so that we can import this into any overlay that has the
        dreaded overlay conflict problem caused by the liner having symbol
        table boundary problems.  The theory is that importing something will
        cause the symbol table to grow and thus move us away from the
        boundary problem.  If we ever get a linker that fixes this problem,
        we should remove the import of this overlay from all it's clients
        and gas this module!!!

    MODIFICATION HISTORY:
        29-Nov-89 WKH   First version

    =========================================================================
*)

PROCEDURE ConflictProc();

BEGIN  (* module VersionConflict *)
END ConflictProc;

END VersionConflict.


