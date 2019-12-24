IMPLEMENTATION MODULE Transfer;

    (* MODIFICATION HISTORY:

       Dec. 3, 1985   AJL - Expanded the size of some text buffers.
       Oct. 27, 1986  AJL - Added procedure CheckForRecompute to the
                            saving and exporting process. 
       10/07/86 LAA         Brought back in the code for RecomputeAfterLoad
                            and RollupAnySummaries from vers. 2.2.
       10/31/86 LAA     Imported NeedsRecompute from ChartControl, for use in
                        RecomputeAfterLoad.  Imported lots of other stuff so
                        it will compile.
        11/04/86 LAA    Initialized RetrieveType in this module initialization.
        11/10/86 LAA    Exported RecomputeAfterLoad so that importers can use
                        it, same as retrieving a schedule.  Moved the
                        RetrieveDammit line from DoTransferFunction into it.
        11/26/86 LAA    Removed usage of NeedsRecompute, whose function is
                        now handled by ChartState.
         9/30/87 RSC    Moved most procedures to overlays.
    *)

FROM LStrings     IMPORT  SetString;

FROM RunMenu      IMPORT  ExecuteMenu;


CONST
    ModuleNumber  = 3400;     (* For GetMessage *)










PROCEDURE RollupAnySummaries;
VAR 
    s : ARRAY [0..8] OF CHAR; 
BEGIN 
    SetString(s,"TLROLLEM");             (* LAA 10/07/86 *)
    ExecuteMenu(s,s);
END RollupAnySummaries;


BEGIN
    RetrieveDammit := FALSE;
    RetrieveType   := RetrieveAll;    (* 11/04/86 LAA *)
END Transfer.
