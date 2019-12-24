IMPLEMENTATION MODULE ResCalUI;

    (* Resource Calendar Data Structure for the UI.

       This is the part of the calendar that the UI sees.  A structure
       which, among other things, contains a rate list.  The rate list
       is a series of On/Off values (Rate = 1/0) for working/nonworking.

       12-Jun-90  RSC    Split into this UI module from the ResCal module.
       10-Jul-90  EGK    Fixed bug where a RETURN was omitted.
       11-Jul-90  EGK    Made CopyCalendar copy the calendar's name along
                         with the other data.
        3-Aug-90  RSC    Allow disposing a NIL calendar.
        7-Aug-90  RSC    Add parameter to CopyDateList.
       17-Aug-90  RSC    Don't create an initial DateList in CreateCalendar.
    *)

FROM BigTimeU               IMPORT
    (* CONST *)                 MINBIGTIME,
    (* TYPE *)                  ABigTime;

FROM DateLists              IMPORT
    (* TYPE *)                  ADateList,
    (* PROC *)                  NumberOfDatesInList, GetDateListEntry,
                                CreateDateList, DisposeDateList,
                                CopyDateList;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtStoragePreference;

FROM LStrings               IMPORT
    (* PROC *)                  Copy;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable;

FROM Text                   IMPORT
    (* TYPE *)                  AText,
    (* PROC *)                  CreateText, TextExists, DiscardText, 
                                AssignText;





      (*-------------------------------------------------------------------

        CreateCalendar

        Create an empty, unnamed calendar.

        ------------------------------------------------------------------*)



PROCEDURE CreateCalendar() : AResourceCalendarPointer;
VAR
   Calendar : AResourceCalendarPointer;
BEGIN
    IF HeapAvailable() THEN
        NEW(Calendar);
        WITH Calendar^ DO
            Notes  := AText(NIL);
            Extras := AText(NIL);
            CalendarIntervals := ADateList( NIL );  (* 17-Aug-90 RSC  *)
        END;
    ELSE
        Calendar := NIL;
    END;

    RETURN Calendar;        (* 7/10/90 EGK *)

END CreateCalendar;



      (*-------------------------------------------------------------------

        DisposeCalendar


        ------------------------------------------------------------------*)



PROCEDURE DisposeCalendar( VAR Calendar : AResourceCalendarPointer );
BEGIN
    IF (Calendar <> NIL) THEN
        WITH Calendar^ DO
            DiscardText(Notes);
            DiscardText(Extras);
            DisposeDateList(CalendarIntervals);
        END;
        DISPOSE(Calendar);
        Calendar := NIL;
    END;
END DisposeCalendar;


      (*-------------------------------------------------------------------

        CopyCalendar

        Deep copy the calendar.

        ------------------------------------------------------------------*)


PROCEDURE CopyCalendar( VAR Dest   : AResourceCalendarPointer;
                            Source : AResourceCalendarPointer );
BEGIN
    IF (Source <> NIL) AND (HeapAvailable()) THEN
        NEW(Dest);
        IF AssignText(Source^.Notes,Dest^.Notes) THEN; END;
        IF AssignText(Source^.Extras,Dest^.Extras) THEN; END;
        Copy (Source^.Name, Dest^.Name);        (* 7/11/90 EGK *)
        CopyDateList(Dest^.CalendarIntervals,Source^.CalendarIntervals,ExtMedium);
    ELSE
        Dest := NIL;
    END;
END CopyCalendar;









END ResCalUI.

