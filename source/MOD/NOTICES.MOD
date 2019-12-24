    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE Notices;

    (* This module allows one part of the program to send notices to
       other parts of the program, bound at run time, that need to
       be kept informed of changes to the program status.

       Note that the existence of this module does not guarantee that
       is will be called for all the defined Occasions.

        MODIFICATION HISTORY --

        22-Feb-88 LAA   Took out NotYetImplemented calls.
        24-Jan-88 AJL  -Check Notice records quite carefully for validity.
                       -Removed a bug from RegisterForNotices that had 
                        unregistered that procedure for any other notices.
                       -Moved most of the code from ListInit into NodeInit
                        and the rest into the main proc.
                       -Check bytes at start of procedures to ensure that 
                        our procedure variables actually point to procedures
                        before calling them. 

         2-Mar-88 RSC  -Changed to reflect new "InstallNewProcedure" call from
                        Overlays.Mod.  Also improved Andrew's checking: the
                        default notice proc was set to FatalError(), but as
                        that has no parameters, I created a LocalFatalError()
                        that takes the appropriate parameters, so we have a
                        safe stack upon dump.
        4-Jun-89 EGK    Disabled Permission's automatic sending of
                        "BeforeActing" notices if all registering procedures
                        return TRUE.
        5-Aug-89 WKH    Initial OS/2 edits.
        7-Aug-89 WKH    Comment out the "super procedure validator" for OS/2.
                        Also, call HALT instead of FatalError if not valid.
                        What was happening was we were recursively chewing
                        up the stack and causing an overflow.
    *)

FROM Dialog IMPORT
    (* PROC *)       FatalError, Error;

FROM MsgFile  IMPORT
    (* PROC *)       GetMessage;

FROM Overlays   IMPORT
    (* PROC *)      InstallNewProcedureWithUnset;

FROM OvTree     IMPORT
    (* TYPE *)      AProcPointer;

FROM Space IMPORT
    (* PROC *)       Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM IMPORT
    (* TYPE *)       ADDRESS,
    (* PROC *)       ADR, SIZE;


CONST
    NoticeTag       = 13131;
    ModuleNumber    = 23100;

TYPE
    ANoticePointer = POINTER TO ANoticeRecord;
    ANoticeRecord    = RECORD
                           Tag       : CARDINAL;
                           Occasion   : AnOccasion;
                           NoticeProc : ANoticeProc;
                           NextLink,
                           PriorLink : ANoticePointer;
                       END;
VAR
    NoticeList  : ANoticePointer;



PROCEDURE CheckNoticeRecordValid( NoticeRecord : ANoticePointer );
BEGIN
    WITH NoticeRecord^ DO 
        IF (Tag <> NoticeTag) OR (NextLink^.Tag <> NoticeTag) THEN
            FatalError();
        END;
    END;
END CheckNoticeRecordValid;







(* Can't be too careful.  RSC 2-Mar-89  *)

PROCEDURE NoticeFatalError( Occasion : AnOccasion;
                            Step     : AStep;
                            Context  : ADDRESS ) : BOOLEAN;
BEGIN
    FatalError();  (* Item deinstalled? *)
END NoticeFatalError;






PROCEDURE NodeInit( VAR Node : ANoticePointer );
BEGIN
    IF Node <> NIL THEN
        WITH Node^ DO
            Tag := NoticeTag;
            Occasion := VAL(AnOccasion,0);       (* Can't be too careful. *)
            NoticeProc := NoticeFatalError;      (* Can't be too careful. *)
            NextLink := Node;                    (* Make it a proper (1-node!) list *)
            PriorLink := Node;
        END;
    ELSE
        FatalError();
    END;
END NodeInit;



    (* AddBefore -- Add a new resource to the list before the BeforeNode. *)

PROCEDURE AddBefore (BeforeNode, NewNode : ANoticePointer);
BEGIN
    CheckNoticeRecordValid(BeforeNode);
    CheckNoticeRecordValid(NewNode);
    NewNode^.PriorLink := BeforeNode^.PriorLink;
    NewNode^.NextLink := BeforeNode;
    NewNode^.PriorLink^.NextLink := NewNode;
    BeforeNode^.PriorLink := NewNode;
END AddBefore;



    (* DeList -- Remove the Notice from whichever circular list it is on. *)

PROCEDURE DeList ( Notice: ANoticePointer);
VAR
    P, N : ANoticePointer;
BEGIN
    IF (Notice = NoticeList) THEN FatalError; END;
    CheckNoticeRecordValid(Notice);

    Notice^.PriorLink^.NextLink := Notice^.NextLink;
    Notice^.NextLink^.PriorLink := Notice^.PriorLink;

    Notice^.NextLink := Notice;
    Notice^.PriorLink := Notice;
END DeList;



    (* --------------------------------------------------------

       UnRegisterForNotices

       Preconditions:      none.

       Postconditions:     Any registrations of the procedure
                           obtained with RegisterForNotices will
                           be cancelled.

    ------------------------------------------------------------*)


PROCEDURE UnRegisterForNotices(     Notify   : ANoticeProc ); 
VAR
    Node, NextNode : ANoticePointer;
BEGIN
    Node := NoticeList^.NextLink;
    WHILE (Node <> NoticeList) DO
        NextNode := Node^.NextLink;
        CheckNoticeRecordValid(NextNode);
        IF (Node^.NoticeProc = Notify) THEN
            DeList(Node);
            Node^.Tag := 0BAD0H;
            DISPOSE(Node);
        END;
        Node := NextNode;
    END;
END UnRegisterForNotices;








PROCEDURE DeinstallNotice( UnsetThis : AProcPointer;
                           FromThis,
                           ToThis    : PROC );
BEGIN
    UnRegisterForNotices(ANoticeProc(FromThis));
END DeinstallNotice;




    (* --------------------------------------------------------

       RegisterForNotices

       Installs a notice proc that will be called by this module whenever
       SendNotices or Permission is called for the registered Occasion.

       Preconditions:      none.

       Postconditions:     The Notify procedure will become eligible
                           to receive notices.

    ------------------------------------------------------------*)



PROCEDURE RegisterForNotices(     Occasion : AnOccasion;
                                  Notify   : ANoticeProc );
VAR
    Node : ANoticePointer;
    s    : ARRAY [0..255] OF CHAR;

BEGIN
    IF (Available(SIZE(Node^))) THEN                              (* 22-Feb-88 LAA *)
        NEW(Node);
        NodeInit(Node);
        Node^.Occasion := Occasion;
(*<OS2
	    (*
	     * Set noticeproc to a KNOWN value, so when it is referenced within
	     * InstallNew.... it will not load garbage into selector and generate
	     * a protection fault.
	     *)
	    Node^.NoticeProc := ANoticeProc(NIL);
OS2>*)

            (* Use this so it will be backed out when overlay ends. *)
        InstallNewProcedureWithUnset(ADR(Node^.NoticeProc),
                                     PROC(Notify),
                                     NIL,     (* RSC 2-Mar-89 *)
                                     DeinstallNotice );
        AddBefore(NoticeList,Node);
    ELSE
        GetMessage(ModuleNumber + 1, s);   (* No space to register for notices.  *)
        Error(s);
    END;
END RegisterForNotices;



PROCEDURE SendNotice (     Node     : ANoticePointer;
                           Occasion : AnOccasion;
                           Step     : AStep;
                           Context  : ADDRESS ) : BOOLEAN;
TYPE
    ABytePointer  = POINTER TO CHAR; 
CONST
    PushBP        = 125C;        (* Procedure code begins with this, PUSH BP. *)
    MovAX         = 273C;        (* or this if stack checking is on. *)
VAR
    X : RECORD
            CASE BOOLEAN OF
                TRUE  :  TheProc : ANoticeProc;
              | FALSE :  TheByte : ABytePointer;
            END;
        END;  
BEGIN
    X.TheProc := Node^.NoticeProc; 
(*<DOS*)
    IF (X.TheByte^ <> PushBP) AND (X.TheByte^ <> MovAX) THEN
        HALT;  (* 7-Aug-89 WKH *)
    END;
(*DOS>*)
    RETURN X.TheProc(Occasion,Step,Context);
END SendNotice;






    (* --------------------------------------------------------

       SendNotices

       Send the notice to all callers who registered for the notice.
       Ignore the BOOLEAN return value.

       Preconditions:      none.

       Postconditions:     All procedures that were registered via
                           RegisterForNotices for this Occasion or
                           AllOccasions (and have not been subsequently
                           UnRegistered) will be called with the
                           passed parameters.

    ------------------------------------------------------------*)


PROCEDURE SendNotices(     Occasion : AnOccasion;
                           Step     : AStep;
                           Context  : ADDRESS );
VAR
    Node : ANoticePointer;
    ok   : BOOLEAN;
BEGIN
    ok := TRUE;
    Node := NoticeList^.NextLink;
    WHILE (Node <> NoticeList) DO
        IF (Node^.Tag <> NoticeTag) THEN
            FatalError();
        END;
        IF (Node^.Occasion = Occasion) OR (Node^.Occasion = AllOccasions) THEN
            ok := ok AND SendNotice(Node,Occasion,Step,Context);
        END;
        Node := Node^.NextLink;
    END;
END SendNotices;





    (* --------------------------------------------------------

       Permission

       Send the notice to some or all callers who registered for it.
       Return FALSE if any NoticeProc returns FALSE, else TRUE.
       If any NoticeProc returns FALSE, then other NoticeProcs may
       or may not be called.

       Preconditions:      none.

       Postconditions:     Some procedures that were registered via
                           RegisterForNotices for this Occasion or
                           AllOccasions (and have not been subsequently
                           UnRegistered) will be called with the
                           passed parameters, and a Step of
                           RequestPermission.

                           If all procedures return a TRUE value, then
                           all procedures will be called, and a TRUE
                           value is returned.  Prior to return, however,
                           all procedures will be called again with
                           a Step of BeforeActing.

                           If any procedure returns a FALSE, then
                           subsequent procedures may or may not be called,
                           and a FALSE is returned.

    ------------------------------------------------------------*)


PROCEDURE Permission(     Occasion : AnOccasion;
                          Context  : ADDRESS ) : BOOLEAN;
VAR
    Node : ANoticePointer;
    ok   : BOOLEAN;
BEGIN
    ok := TRUE;
    Node := NoticeList^.NextLink;
    WHILE (ok) AND (Node <> NoticeList) DO
        IF (Node^.Tag <> NoticeTag) THEN
            FatalError();
        END;
        IF (Node^.Occasion = Occasion) OR (Node^.Occasion = AllOccasions) THEN
            ok := SendNotice(Node,Occasion,RequestPermission,Context);
        END;
        Node := Node^.NextLink;
    END;

(*                      Removed by EGK 6/4/89
    IF (ok) THEN
        SendNotices(Occasion,BeforeActing,Context);
    END;
*)

    RETURN ok;
END Permission;




BEGIN
        (* Init the list. *)
    NEW(NoticeList);
    NodeInit(NoticeList);
END Notices.
