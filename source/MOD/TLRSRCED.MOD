MODULE TLRsrcEdit;

(*  =========================================================================
    Last Edit : September 21, 1989 1:57PM by WKH
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

        16-Jun-89 RSC First cut, from RsrcEdit.
        09-Aug-89 KKC Add copyright message.
        14-Sep-89 WKH Made resource list box bigger in 50 line mode
        21-Sep-89 WKH Don't "grow" resource list anymore, too slow
        14-Dec-89 MWP Added checking for existence of rodents.
        27-Dec-89  LAA  Removed the Ok button, since double-clicking now does
                        the same thing.
         5-Jan-90 MWP   Put the Ok button back in.
        04-Jun-90 AJL   Removed the cost rate information, for now.
         6-Oct-90 AJL   Added Insert and Delete mouse buttons.
    =========================================================================
*)


FROM   Codes     IMPORT ACode;

FROM   Kbio      IMPORT avidmode, maxcol, ascreeny, EraseLn;

FROM   Dialog    IMPORT  Message, Burp, FatalError, Error, NotYetImplemented;

FROM   Layout    IMPORT  GanttWEnd, GanttWStart;

FROM   Keys      IMPORT  ExitKey, UndoKey, ChngTskKey, DeleteKey,
                         BackSpace, CancelKey, DoIt,
                         InsertKey, EditKey;

FROM   LStrings  IMPORT  SetString, SubStr, ConcatLS, Fill,
                         LJust, TrimRear, StoC, CtoS, ConcatS,
                         TrimFront, Insert, Procustes, Upshift,
                         Remove, Search, Compare, Copy;

FROM   Mouse        IMPORT
    (* PROC *)          MousePresent;                               (* 14-Dec-89 MWP *)

FROM   Notices      IMPORT
    (* TYPE *)          AStep, AnOccasion,
    (* PROC *)          RegisterForNotices;

FROM   Overlays     IMPORT
    (* TYPE *)          AnOverlayID,
    (* PROC *)          OverlayContext, ImAnInstallableOverlay;

FROM OvTree         IMPORT
    (* TYPE *)          AnOverlayProc;

FROM   Rugs       IMPORT ARug, GetRug, PutRug;

FROM   RsrcMod    IMPORT CheckResourceValid,
                          ACostStyle, AResourceType,
                          AResourcePointer, ResourceNameLength, ResourceTree,
                          FindResourceByName;

FROM RsrcEdit       IMPORT
    (* TYPE *)          AResourceListLink;

FROM   Boxes      IMPORT ABoxType, ABoxAttribute;

FROM   MsgFile    IMPORT GetMessage, DisplayMessage, ConcatMessage;

FROM Events                 IMPORT
    (* TYPE *)                  AnEvent,
    (* PROC *)                  GetNextEvent;

FROM RsrcOutlines           IMPORT
    (* TYPE *)                  AResourceOutline,
    (* PROC *)                  CreateResourceOutline;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM SYSTEM                 IMPORT
    (* THINGS *)                ADR, ADDRESS;



CONST
    ModuleNumber = 3000;   (* For GetMessage, SAME AS TLRsrc!! *)

CONST
    Width     = 49;
    ULX       = 13;

    OneHundred = 100.0;


VAR
    ResourceOutline     : AResourceOutline;
    OverlayID           : AnOverlayID;









PROCEDURE DoResourceList (VAR Node              : ATreeNode;
                              AllowSelection    : BOOLEAN   )
                                                             : BOOLEAN;

VAR
    FirstNode           : ATreeNode;
    Event               : AnEvent;
    Rug                 : ARug;
    LocalBoxType        : ABoxType;
    Title               : ARRAY [0..81] OF CHAR;
    RugTaken,
    Ok                  : BOOLEAN;      (* RSC 12-May-89 *)
BEGIN
    RugTaken := GetRug( 0, 0, maxcol, 2, Rug ); (* Preserve top 3 lines.  RSC 11/6/87 *)

    DisplayMessage(ModuleNumber+1);
    IF (AllowSelection) THEN
        EraseLn(1);     (* Erase any instructions for form. *)
        EraseLn(2);
        GetMessage (ModuleNumber+8, Title);
    ELSE
        GetMessage (ModuleNumber+9, Title);
    END;
       (*  " Resource/Cost List"         Has leading space, for Helper. *)

    Event.EventCode := 0;

    Ok := TRUE;     (* RSC 12-May-89 *)

    IF ( MousePresent () ) THEN                                  (* 14-Dec-89 MWP *)
      LocalBoxType := ABoxType{ShadowBox,DoubleBox,HasOk,HasCancel,HasVScroll,
                               HasInsert, HasDelete }; (* 5-Jan-89 MWP *)
    ELSE
      LocalBoxType := ABoxType{ShadowBox,DoubleBox};
    END;

    IF (CreateResourceOutline (ResourceOutline, NIL, ULX, GanttWStart+4,
            ULX+Width+1, GanttWEnd-2, LocalBoxType,
            videonormal, Title, ModuleNumber, TRUE)) THEN         (* 05-Mar-88 LAA *)

        ResourceOutline^.Methods^.SetObject (ResourceOutline, ResourceTree);
        ResourceOutline^.Methods^.ResetMatching (ResourceOutline);
        FirstNode := ResourceTree^.Methods^.GetFirst (ResourceTree);
        ResourceOutline^.Methods^.SetFirst (ResourceOutline, FirstNode);
        IF (Node = NIL) THEN
            ResourceOutline^.Methods^.SetCursorNode (ResourceOutline, FirstNode);
        ELSE
            ResourceOutline^.Methods^.SetCursorNode (ResourceOutline, Node);
        END;
        ResourceOutline^.Methods^.SetCursor (ResourceOutline, TRUE);

        LOOP
            ResourceOutline^.Methods^.Display (ResourceOutline);
            GetNextEvent (Event);
            IF (NOT AllowSelection) AND (Event.EventCode = DoIt) THEN
                Event.EventCode := EditKey;
            END;
            ResourceOutline^.Methods^.ActOnEvent (ResourceOutline, Event, Event);
            CASE Event.EventCode OF
                0 :;

            |   CancelKey:
                    Ok := FALSE;    (* RSC 12-May-89 *)
                    EXIT;
            |   DoIt:
                    IF (AllowSelection) THEN
                        Node := ResourceOutline^.Methods^.GetCursorNode (ResourceOutline);
                        EXIT;
                    END;
            |   ExitKey:
                    IF (AllowSelection) THEN
                        Node := ResourceOutline^.Methods^.GetCursorNode (ResourceOutline);
                    END;
                    EXIT;
            ELSE
                Burp();
            END;
        END;
        ResourceOutline^.Methods^.Discard (ResourceOutline);
    ELSE
        DisplayMessage (ModuleNumber);     (* "Not enough memory for the view" *)
        Burp();
        Ok := FALSE;    (* RSC 12-May-89 *)
    END;

    IF (RugTaken) THEN
        PutRug( 0, 0, maxcol, 2, Rug ); (* Preserve top 3 lines.  RSC 11/6/87 *)
    END;

    RETURN (Ok AND (Node <> NIL));  (* RSC 12-May-89 *)

END DoResourceList;





PROCEDURE NoticeResourceDeletion(    Occasion   : AnOccasion;
                                     Step       : AStep;
                                     Context    : ADDRESS ) : BOOLEAN;
BEGIN

    IF (Step = BeforeActing) AND (ResourceOutline <> NIL) THEN
        ResourceOutline^.Methods^.NotifyNodeDeleted(ResourceOutline, ATreeNode(Context));
    END;

    RETURN TRUE;

END NoticeResourceDeletion;





PROCEDURE RsrcInit();
BEGIN

    ResourceOutline := NIL;
    RegisterForNotices( DeleteAResource, NoticeResourceDeletion );

END RsrcInit;






PROCEDURE DoTLRsrc();
VAR
    ResourceListLinkPtr : POINTER TO AResourceListLink;
    Copyright           : ARRAY[0..50] OF CHAR;
BEGIN
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
    ResourceListLinkPtr := OverlayContext();

    WITH ResourceListLinkPtr^ DO
        ReturnValue := DoResourceList( Node, AllowSelection );
    END;

END DoTLRsrc;







BEGIN

    RsrcInit();
    OverlayID := ImAnInstallableOverlay(DoTLRsrc, AnOverlayProc(NIL));
    DoTLRsrc();

END TLRsrcEdit.


