IMPLEMENTATION MODULE EmsStorage;

(*  =========================================================================
    Last Edit : October 9, 1990 3:44PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        
        This module manages allocation of EMS memory pages

    MODIFICATION HISTORY:

        3-Aug-89 RSC First version, based on ideas from Larry and Andrew.
                     This is a skeleton module.  Steal my vectors, PLEASE!

        9-Oct-90 RSC Added two new procedres, EMSWriteRecordToPage and
                     EMSReadRecordFromPage.

    =========================================================================
*)


FROM Dialog         IMPORT
    (* PROC *)          FatalError;

FROM SYSTEM         IMPORT
    (* TYPE *)          ADDRESS;





PROCEDURE XEMSAllocate( VAR EmsHandle   : AnEmsHandle;
                            EmsPriority : AnEmsPriority ) : BOOLEAN;
BEGIN

    EmsHandle := NilEMSHandle;

    RETURN FALSE;   (* This is not fatal, there is just NO EMS.  Yet. *)

END XEMSAllocate;





PROCEDURE XEMSUnLock(    EmsHandle     : AnEmsHandle;
                         FrameHandle   : CARDINAL    );
BEGIN
    FatalError();   (* Should never get this far. *)
END XEMSUnLock;







PROCEDURE XEMSDeAllocate( VAR EmsHandle     : AnEmsHandle );
BEGIN

    (* A no-op, in case its called after TLEMS shuts down. *)

    EmsHandle := NilEMSHandle;

END XEMSDeAllocate;








PROCEDURE XEMSLock(     EmsHandle     : AnEmsHandle;
                    VAR PageFrame     : ADDRESS;
                    VAR FrameHandle   : CARDINAL ) : BOOLEAN;
BEGIN

    PageFrame := NIL;

    RETURN FALSE; (* This is not fatal, there is just NO EMS.  Anymore. *)

END XEMSLock;





PROCEDURE XEMSFrameRequest( RequestType : AnEmsPageFrameRequest
                          ) : BOOLEAN;
BEGIN
    RETURN TRUE;
END XEMSFrameRequest;




PROCEDURE XEMSStatistics( VAR TotalPages,
                              FreePages,
                              HighPriFree    : CARDINAL );
BEGIN
    TotalPages  := 0;
    FreePages   := 0;
    HighPriFree := 0;
END XEMSStatistics;





PROCEDURE EMSReadOrWriteRecordFromPage(    EmsHandle  : AnEmsHandle;
                                           Offset     : CARDINAL;
                                           Length     : CARDINAL;
                                           TargetAddr : ADDRESS
                                       ) : BOOLEAN;
BEGIN
    RETURN FALSE;
END EMSReadOrWriteRecordFromPage;




BEGIN 
    EMSAllocate             := XEMSAllocate;
    EMSDeAllocate           := XEMSDeAllocate;
    EMSLock                 := XEMSLock;
    EMSUnLock               := XEMSUnLock;
    EMSFrameRequest         := XEMSFrameRequest;
    EMSStatistics           := XEMSStatistics;
    EMSReadRecordFromPage   := EMSReadOrWriteRecordFromPage;
    EMSWriteRecordToPage    := EMSReadOrWriteRecordFromPage;
END EmsStorage.

