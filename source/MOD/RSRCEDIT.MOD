IMPLEMENTATION MODULE RsrcEdit;

    (*V3= Real Time Line *)
    (*V4= Plot Line *)

    (* MODIFICATION HISTORY --

       Dec 4, 1985,  AJL - Moved the text for cost type abbreviations
                           R, FC, UC and VC to the phrases file.
                         - Expanded some text buffer sizes.
        11/04/86 LAA    Used UnSetState to make the ChartState an empty set.
        11/28/86 LAA    Added support for a notes field in the resource, which
                        is a Text.
        12/16/86 LAA    Incorporated new version of Edit.
        12/31/86 LAA    Changed screen coordinates of edit window.
        30-Mar-87 LAA   Incorporated second version of editor, using object
                        oriented ideas.
        5/21/87   EGK   SelectResource and EditResources rewritten to
                        support new resource implementation.
        7/8/87    EGK   Make a copy of ResourceBeingEditted^.Notes, so we can
                        <ESC> without keeping the changes.
        7/29/87   RSC   New resource form layout for SPIKE.
        9/28/87   EGK   Now export ResourceOutline for use by undo.
       10/13/87   RSC   Added Keyword field to form.                
       10/15/87   RSC   Added shadows to boxes.  Added parameter to EditText.
       10/19/87   RSC   Moved resource list over to the left 3 positions to
                        make room for the histogram rsrc form (so you can see
                        it UNDER the resource list).
       10/20/87   EGK   Call ResetMatching when the resource list is put up.
       10/27/87   RSC   notify Forms when text is changed.
       11/06/87   RSC   Preserve top 3 lines when resource list is active.
       20-Nov-87  LAA   Added LevelThisResource field to the rsrc form.
        1-Jan-88  RSC   Broke off resource form into TLRsrc.
       16-Feb-88  RSC   Improve the no memory check to display a message
                        AFTER putting back the rug, not before.
        02-Mar-88 LAA   TLFBASE is not allowed in the reserve layer.
       05-Mar-88  LAA   Added ModuleNumber into call to CreateResourceOutline.
       12-Mar-88  RSC   SelectResource would not return NIL if ESC pressed.
                        as a result, pressing ESC always accepts the item
                        the cursor was on.  Affects assignment lists/histogram
                        menu/filters.
       16-Jun-89  RSC   Moved the resource list to TLRsrcEdit, removing the
                        outline code from the root.
       29-May-90  AJL   Removed some unused imports of stuff from RsrcMod.
    *)


FROM   Codes     IMPORT ACode;

FROM   Dialog    IMPORT  Message, Burp, FatalError, Error;

FROM   Keys      IMPORT  CancelKey;

FROM   LStrings  IMPORT  SetString, SubStr, ConcatLS, Fill,
                         LJust, TrimRear, StoC, CtoS, ConcatS,
                         TrimFront, Insert, Procustes, Upshift,
                         Remove, Search, Compare, Copy;

FROM   Overlays   IMPORT CallOverlayWithContext;

FROM   RsrcMod    IMPORT 
                         AResourcePointer;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM SYSTEM                 IMPORT
    (* THINGS *)                ADR, ADDRESS;



CONST
    ModuleNumber = 3000;   (* For GetMessage, SAME AS TLRsrc!! *)

CONST
    Height    = 13;
    Width     = 49;
    ULX       = 13;

    OneHundred = 100.0;





PROCEDURE DoResourceForm( LResource : AResourcePointer) : ACode;
VAR
    ResourceFormLink : AResourceFormLink;
    s                : ARRAY [0..29] OF CHAR;
    ok               : BOOLEAN;
BEGIN
    WITH ResourceFormLink DO
        Resource := LResource;
        Code     := CancelKey;  (* In case we fail ... *)
    END;

    SetString(s,"\TLFBASE(TLRSRC)");                              (* 02-Mar-88 LAA *)
    ok := CallOverlayWithContext( s, ADR( ResourceFormLink ) );

    RETURN ResourceFormLink.Code;

END DoResourceForm;






(* RSC 16-Jun-89  Made the code be in an overlay. *)

PROCEDURE DoResourceList (VAR TheNode            : ATreeNode;
                              DoWeAllowSelection : BOOLEAN   )
                                                             : BOOLEAN;
VAR
    ResourceListLink : AResourceListLink;
    s                : ARRAY [0..29] OF CHAR;
    ok               : BOOLEAN;
BEGIN

    WITH ResourceListLink DO
        Node            := TheNode;
        AllowSelection  := DoWeAllowSelection;
        ReturnValue     := FALSE;
    END;

    SetString(s,"TLRSRCED");
    ok := CallOverlayWithContext( s, ADR( ResourceListLink ) );

    TheNode := ResourceListLink.Node;

    RETURN (ok AND ResourceListLink.ReturnValue);

END DoResourceList;









PROCEDURE SelectResource (VAR Node      : ATreeNode)
                                                    : BOOLEAN;
BEGIN
    RETURN DoResourceList (Node, TRUE);
END SelectResource;




PROCEDURE EditResources ();
VAR
    Dummy           : ATreeNode;
BEGIN
    Dummy := ATreeNode (NIL);
    IF (DoResourceList (Dummy, FALSE)) THEN END;
END EditResources;




END RsrcEdit.

