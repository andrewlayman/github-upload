(*----------------------------------------------------------------------------
    MODIFICATION HISTORY
    
    11/14/86 LAA    Brought this over from international.  Changed parameters 
                    of Menu call to conform with this version.
    12/24/87 RSC    Take a rug to help out TLNewPrj.
    09-Aug-89  KKC  Add copyright message.
    12-Dec-89  RSC  Added MODAL parameter to Menus.
     9-Jan-90  MWP  Made calender menu 'non-modal'.

----------------------------------------------------------------------------*)
MODULE TLCALNDR;

FROM CalControl     IMPORT CalendarDays, CalendarHours, CalendarForm;

FROM Codes          IMPORT ACode;

FROM CodeSets       IMPORT MenuCodeSet;

FROM Dialog         IMPORT FatalError;

FROM Kbio           IMPORT maxrow, maxcol;

FROM Keys           IMPORT DoIt;

FROM Layout         IMPORT MenuStart, MenuEnd;

FROM Menus          IMPORT Menu;

FROM MsgFile        IMPORT GetMessage;

FROM Rugs           IMPORT GetRug, PutRug, ARug;

FROM Space          IMPORT SetHeapLevels, HeapAvailable;



CONST
    ModuleNumber = 11500;    (* For GetMessage *)


VAR
    Choice                  : CARDINAL;
    Code                    : ACode;
    ScreenRug               : ARug;
    RugTaken                : BOOLEAN;
    s                       : ARRAY [0..81] OF CHAR;
    Prefix, Name            : ARRAY [0..21] OF CHAR;
    Copyright               : ARRAY[0..50] OF CHAR;


   
BEGIN

(*$S+*)
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
     SetHeapLevels(4,2);
    IF (NOT HeapAvailable()) THEN RETURN; END;
    RugTaken := GetRug( 0, 0, maxcol, maxrow, ScreenRug );

    Choice := 1;
    GetMessage(ModuleNumber+1,Prefix);   (*  "CALENDAR"  *)
    GetMessage(ModuleNumber+2,s);   (*  "Hours,Days,Form,Quit calendar"  *)
    LOOP
        Code := Menu(Prefix,s,0,MenuStart,maxcol,MenuEnd,MenuCodeSet,
                     FALSE,  (* 9-Jan-90 MWP *)
                     Choice);
        IF (Code=0) OR (Code=DoIt) THEN
            CASE Choice OF
                1: CalendarHours;
              | 2: CalendarDays;
              | 3: CalendarForm;
              | 4: EXIT;
              ELSE FatalError;
            END;
            Choice := 3;
        ELSE
            EXIT;
        END;
    END;

    IF (RugTaken) THEN
        PutRug( 0, 0, maxcol, maxrow, ScreenRug );
    END;

(*$S=*)

END TLCALNDR.

