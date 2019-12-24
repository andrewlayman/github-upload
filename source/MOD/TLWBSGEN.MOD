MODULE TLWBSGen;  (* RESOURCE TABLE REPORT *)


  (*    Main WBS Generator overlay. All other overlays are
        called through here.

        MODIFICATION HISTORY:

         17-Apr-89  MWP  In the beginning...
         10-Aug-89  KKC  Add copyright message.
         20-Aug-89  MWP  Nothing has really changed, this is to re-write
                         the garbage I accidentally rolled over to N.
         11-May-90  MWP  Imported ConflictProc to remove version
                         conflict.
   *)

FROM Overlays       IMPORT
                            OverlayContext, CallOverlayWithContext,
                            OverlayCallChain;

FROM SYSTEM         IMPORT
                            ADDRESS;
IMPORT WBSCommon;

FROM VersionConflict IMPORT                                       (* 11-May-90 *)
                            ConflictProc;


VAR
    OverlayList             : POINTER TO ARRAY [0..99] OF CHAR;
    ok                      : BOOLEAN;
    Context                 : ADDRESS;
    CallChain               : POINTER TO ARRAY [0..255] OF CHAR;
    Copyright               : ARRAY[0..50] OF CHAR;

BEGIN

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    Context   := OverlayContext();
    CallChain := OverlayCallChain();
    IF (CallChain^[0] = 0C) THEN (* Handle RunMenu calls too ... *)
        CallChain := Context;
        Context   := NIL;
    END;
    IF (CallChain <> NIL) AND
       (CallOverlayWithContext( CallChain^, Context )) THEN
    END;

END TLWBSGen.
