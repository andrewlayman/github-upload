MODULE TLRenum;

    (*  MODIFICATION HISTORY --
        28-Sep-89 LAA   Pulled this out of TLITL4 to try and make it fit
                        within the reserved layer.
    *)

FROM Renumber               IMPORT
    (* PROC *)                  RenumberEverything;


BEGIN                       (* TLRenum *)

    RenumberEverything();

END TLRenum.
