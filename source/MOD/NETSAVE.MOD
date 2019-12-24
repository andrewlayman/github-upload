IMPLEMENTATION MODULE NetSave;

(*  =========================================================================
    Last Edit : November 29, 1989 1:03PM by EGK
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        
    MODIFICATION HISTORY

        27-Nov-89 EGK   Added "ModelSave" to the list of notices that
                        purge the saved data.
        29-Nov-89 EGK   Oops.  Took it out again, because the bug that I
                        thought this would fix was elsewhere.  (See my
                        comment in NetCopy.MOD for this date.)
    =========================================================================
*)


FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle,
    (* PROC *)                  LockObject, ReleaseObject, DiscardExtObject;

FROM Notices                IMPORT
    (* TYPE *)                  AnOccasion, AStep,
    (* PROC *)                  RegisterForNotices;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  ADDRESS;

    

PROCEDURE InvalidateData();
VAR
    i               : CARDINAL;
BEGIN
    DataValid := FALSE;

    FOR i := 0 TO DataMax DO
        NetSaveData[i] := AnExtHandle(NIL);
    END;
    NetSaveArray := AnExtHandle(NIL);
END InvalidateData;



PROCEDURE DiscardData();
VAR
    i               : CARDINAL;
    NetArrayPtr     : AnArrayPtr;

BEGIN

    FOR i := 0 TO DataMax DO
        DiscardExtObject (NetSaveData[i]);
    END;

        (*  Discard each of the individual objects referenced by
            NetSaveArray.
        *)

    IF (NetSaveArray <> AnExtHandle(NIL)) THEN
        IF (LockObject (NetSaveArray, NetArrayPtr) = 0) THEN
            FatalError();
        END;
        FOR i := 0 TO ArrayMax DO
            IF (NetArrayPtr^[i] <> AnExtHandle(NIL)) THEN
                DiscardExtObject (NetArrayPtr^[i]);
            END;
        END;
        ReleaseObject (NetSaveArray);
        DiscardExtObject (NetSaveArray);
    END;

    InvalidateData();
END DiscardData;



    (*  Note: these notices are exactly the same as the ones which would
        cause the PERT view to recalculate itself.  All we do here is
        invalidate our saved data in response to any of these notices.
    *)

PROCEDURE NoticeCatcher (   Occasion    : AnOccasion;
                            Step        : AStep;
                            Context     : ADDRESS    ) : BOOLEAN;
BEGIN
    IF (NOT DataValid) THEN
        RETURN TRUE;
    END;

    CASE Occasion OF
        DeleteATask,
        MoveATask,
        OpenATask,
        CloseATask,
        ChangeAnEdge,
        ScheduleSort,
        ModelErase,
        ModelLoad,
        ProgramQuit,
        ScheduleCompute,
        DeleteAnEdge,
        AddATask,
        AddAnEdge,
        NetworkSettingChange :

            DiscardData();
    ELSE
    END;

    RETURN TRUE;
END NoticeCatcher;



PROCEDURE InitNetSave();

BEGIN
    InvalidateData();
    RegisterForNotices (AllOccasions, NoticeCatcher);
END InitNetSave;



BEGIN
END NetSave.
