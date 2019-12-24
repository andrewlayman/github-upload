IMPLEMENTATION MODULE OvTree;


  (*    Ov Tree  - Overlay Tree Maintainer

    This module exists to seperate out the overlay tree structure from either
    Overlays.Mod or Overlay.Mod

    One of the motives for this is so that this DEF can change and the only modules
    that MUST be recompiled are Overlay.Mod (Logitek), Overlays.Mod (ours) and
    TLMagic.Mod (testing only).  In other words, we can change this DEF and still
    use our "Field Linking" strategy.



     MODIFICATION HISTORY:

        5-Jan-89    RSC     New module, built from Overlays.Mod
        7-Feb-89    EGK     Set Fudge to 0.  Why the overhead?
       20-Jun-89    RSC     Rearranged the order of space checks when
                            allocating space.
        6-Aug-89    WKH     Initial OS/2 edits.
        7-Feb-91    RSC     Overlay swapping support.

       28-Mar-91 RSC Added "Trace mode".  This is to help debug problems
                     when not in "debug mode".  Often maps are useless,
                     because they say "Map file does not correspond to
                     program dump".  at least here, you will see the flow
                     of overlay calls with trace mode on:

                         ADDIN IS TLTRACE

       17-Apr-91 RSC Added ability to find pushed residents.
       18-Apr-91 RSC Added ability to count pushed overlays.
       26-Apr-91 RSC Removed tracing, instead see OvSwap's stealable
                     vectors.
        8-May-91 RSC Removed use of TraverseTree, because of its unstable
                     nature when deleting essentially RANDOM NODES in the
                     tree while traversing it.
       15-May-91 RSC Two recursion problems:
                     1) If an overlay is called recursively, its use count
                        is incremented, but it may not be on the swap stack
                        that number of times.  So, with the swap stack,
                        keep the use count at the time of the swap, so that
                        we don't underestimate the "accounted for" use count.

                     2) When kicking out an overlay that is SWAPPED OUT,
                        but is not CACHED, do not discard the overlay.
       27-May-91 RSC Added FindOvlNodeFromEntry to speed up deletions of
                     overlay entries.

        1-Jul-91 RSC Put into the overlay descriptor maintained by the
                     RTSMain module the address of the corresponding
                     OvTree record and treenode as dummy[1] and dummy[2],
                     respectively.  This is set up in the SetBaseLayer
                     procedure called by Overlay.Mod.

                     Use these pointers rather than FindNodeFromOvlName
                     and FindNodeFromEntry as even faster methods of
                     finding the various records involved.

       11-Jul-91 RSC Use BTStorage, not Space for ALLOCATE, so that the
                     records do not go into the HMA or video memory.
                     This confuses the PMD program.
       11-Jul-91 LAA Set up the pointers from the Logitech overlay record
                     to our Context in AddToContextList.  This is intended
                     to keep the machine from crashing when an overlay gets
                     a version conflict.  Credit Roger with this fix.
       16-Jul-91 LAA In SetBaseLayer, make use of the back pointers that are
                     now set up in the Logitech overlay record, instead of
                     searching the overlay tree for a matching entry.  Roger
                     defined this optimization also.  Also added some extra
                     error checking in various places.
       22-Jul-91 LAA Added the FindWhere procedure to assist looking through
                     the SwapStack.
       13-Aug-91 LAA Bug #4805 and general speed-up.  I've added a small
                     static array and a procedure which allows us to specify
                     by name overlays which it is critical to cache for
                     performance reasons.  This means that such overlays
                     will be put into FlexStor if there's no room in Xms.
                     This was a cheap fix for problems caused by massive
                     reloading of TLCAPTIO, which is currently the only such
                     designated critical overlay.
       18-Sep-91 LAA To improve speed, I fixed up InitOvTree to take the
                     CriticalToCacheOverlays from a phrase, and allow at least
                     5 of them.  This is mainly for TLUNDO, which, in addition
                     to TLCAPTIO, seems to be causing substantial slowdowns.
       27-Jan-92 LAA Removed the above two changes having to do with 
                     CriticalToCacheOverlays.  This wasn't doing much for
                     TLCaptions, and I found a better way to provide the
                     desired effect by forcing it to load on the heap if at
                     all possible.
  *)

FROM Dialog         IMPORT
    (* PROCS *)         FatalError, Error;

FROM LStrings       IMPORT
    (* PROCS *)         SetString, ConcatS, ConcatLS, CtoS, Copy,
                        StringsEqual, TStringToLString, LStringToTString,
                        Insert, SubStr, Search, Fill, Remove, LengthOf,
                        TrimRear, Procustes, Upshift;

FROM Menus          IMPORT
    (* PROC *)          WordNumber;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage;

FROM Overlay        IMPORT
    (* PROC *)          DeInstallOverlay;

FROM OVSwap         IMPORT
    (* PROC *)          SwapIn, SwapOut;

FROM Paranoia       IMPORT
    (* VAR *)           InitializationOK;

FROM RTSMain        IMPORT
    (* TYPE *)          OverlayPtr, Status, OverlayDescriptor,
    (* VAR  *)          activProcess;

FROM BTStorage      IMPORT      (* 11-Jul-91 RSC not Space *)
    (* PROCS *)         ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM         IMPORT
    (* TYPE *)          SIZE, ADDRESS, TSIZE;

FROM TreeObjects    IMPORT (* RSC/EGK 11/17/88 *)
    (* TYPE *)            ATreeNode, ATreeOrder, ATree,
    (* PROCS *)           CreateTree, CreateTreeNode;

CONST
    ModuleNumber            = 2700;         (*  Shared with Overlays *)

TYPE
    AnOverlayName           = ARRAY [0..13] OF CHAR;



    (* Make a copy of the given overlay file name without the decorations. *)

PROCEDURE CopyAndTrimName( VAR OurName, s1 : ARRAY OF CHAR );

TYPE
    ASetOfCharacters        = SET OF CHAR;

CONST
    SpecialCharacters       = ASetOfCharacters{"\", "|", "!"};    (* 04-Mar-88 LAA *)

    FileNameLength          = 8;  (* On DOS, anyway. *)

BEGIN                       (* CopyAndTrimName *)

    Copy( OurName, s1 );       (* Like "\!TLNet" *)
    WHILE ((LengthOf(s1) > 0) AND (s1[1] IN SpecialCharacters)) DO
        Remove( s1, 1, 1 );
    END;
    Upshift(   s1 );
    Procustes( s1, FileNameLength );
    TrimRear(  s1 );

END CopyAndTrimName;






    (* Find Node From Ovl Name -

        Given the name of an overlay, find the tree node associated with that
        overlay name.
    *)
PROCEDURE FindNodeFromOvlName ( VAR OverlayName : ARRAY OF CHAR ) : ATreeNode;
VAR
    Node                    : ATreeNode;
    Context                 : AContextListEntry;
    s                       : ARRAY [0..15] OF CHAR;
    s2                      : ARRAY [0..15] OF CHAR;
BEGIN
    IF (OverlayTree = NIL) THEN
        FatalError();  (* Overlays not initialized! *)
    END;

    Node := OverlayTree^.Methods^.GetFirst (OverlayTree);
    CopyAndTrimName(OverlayName, s);                                 (* 04-Mar-88 LAA *)

    WHILE (Node <> NIL) DO
        Context := Node^.Methods^.GetDataObject (Node);
        CopyAndTrimName(Context^.OverlayName, s2);
        IF (StringsEqual(s2, s)) THEN   (* RSC 1/2/88 *)
            RETURN Node;
        END;
        Node := Node^.Methods^.NextPreOrder (Node);
    END;

    RETURN ATreeNode(NIL);

END FindNodeFromOvlName;








  (* SetBaseLayer - Set up the base layer given the base layer's overlay
                    pointer and the current overlay's pointer.

      Preconditions  - CurrentLayer and BaseLayer are the OverlayPtr's of the
                       layers.

                       The Overlay Tree must have been initialized.

      Postconditions - The overlay identified by the "CurrentLayer" is
                       made a child of the overlay identified by the
                       "BaseLayer".

            1-Jul-91 RSC Changed from using names to using the OverlayPtr.
  *)
PROCEDURE SetBaseLayer( CurrentLayer, BaseLayer : OverlayPtr );
VAR
    BaseNode,
    CurrentNode : ATreeNode;

BEGIN

    (* 1-Jul-91 RSC I now use the previously-unused "dummy" addresses
                    from the OverlayPtr to reference back to the
                    tree node and record in our overlay tree.

                    dummy[1] is the address of the overlay record
                                (AContextListEntry)

                    dummy[2] is the address of the tree node associated
                                with the overlay record.

                On entry to this call, BaseLayer has been set up by a
                prior invocation of this procedure (or by Overlays.Mod
                for Timeline.Exe)
    *)

    IF ((BaseLayer = NIL) OR (CurrentLayer = NIL)) THEN        (* 16-Jul-91 *)
        FatalError();
    END;

    BaseNode    := BaseLayer^.dummy[2];             (* Allready set up *)
    CurrentNode := CurrentLayer^.dummy[2];                     (* 16-Jul-91 *)

    IF (BaseNode = NIL) OR (CurrentNode = NIL) THEN
        FatalError();
    END;

    (* Make the defined base layer have the current overlay as a kid.
       We originally link the Current Overlay to the root of the tree,
       at the same level as Time Line.
    *)
    CurrentNode^.Methods^.DeList( CurrentNode );
    BaseNode^.Methods^.AddAsFirstChild( BaseNode, CurrentNode );

END SetBaseLayer;







  (* AddToContextList - Add the overlay's context area into the list of
                         such areas.

       Preconditions   - Item is filled in (except for PriorEntry)

       Postconditions  - The context list is one entry bigger.
                         'GetOverlayContext' call returns the new context.

                         'WhereItWent' is set to the just-added item.
  *)

PROCEDURE AddToContextList( VAR Item            : AContextListItem;
                            VAR WhereItWent     : AContextListEntry );
VAR
    NewEntry    : AContextListEntry;
    Node        : ATreeNode;

BEGIN

    IF (CreateTreeNode(Node)) THEN
        IF (Available(SIZE(Item)+TSIZE(OverlayDescriptor)+8)) THEN (* RSC 20-Jun-89 *)
            NEW(NewEntry);
            Node^.Methods^.SetDataObject (Node, NewEntry);
            OverlayTree^.Methods^.AddLast (OverlayTree, Node);

            NewEntry^                         := Item;
            ALLOCATE(NewEntry^.TheOverlayPtr,TSIZE(OverlayDescriptor));
            NewEntry^.TheOverlayPtr^.dummy[1] := NewEntry;     (* 11-Jul-91 *)
            NewEntry^.TheOverlayPtr^.dummy[2] := Node;
            WhereItWent                       := NewEntry;
        ELSE
            Node^.Methods^.Discard( Node );
            InitializationOK      := FALSE;
            WhereItWent           := NIL;
        END;
    ELSE
        InitializationOK      := FALSE;
        WhereItWent           := NIL;
    END;

END AddToContextList;





  (* RemoveFromContextList - Remove an item from the context tree.

       Preconditions  - A prior 'AddToContextList' call was made
                        sometime in the past for this entry.

       Postconditions - The context list is one entry smaller.
  *)
PROCEDURE RemoveFromContextList( VAR Entry : AContextListEntry );
VAR 
    Node        : ATreeNode;
BEGIN
    IF ((Entry = NIL) OR (Entry^.TheOverlayPtr = NIL)) THEN    (* 16-Jul-91 *)
        InitializationOK  := FALSE; (* In case we are in an overlay *)
        FatalError();
    END;

    Node := Entry^.TheOverlayPtr^.dummy[2];  (* 1-Jul-91 RSC  *)

    IF (Node <> NIL) THEN
        Node^.Methods^.Discard (Node);
        DEALLOCATE(Entry^.TheOverlayPtr,TSIZE(OverlayDescriptor));
        DISPOSE (Entry);
    ELSE
        InitializationOK  := FALSE; (* In case we are in an overlay *)
        FatalError();
    END;

    Entry := NIL;

END RemoveFromContextList;





    
(* 8-May-91 RSC Returns TRUE iff we did a swap, which could possibly
                        cause other nodes to be deleted.  Else returns
                        a FALSE.

                        TRUE means "restart tree search".
                           but, the error flag could be set.

                        Returning TRUE implies that this procedure
                        guarentees that we will not loop forever, because
                        the conditions have changed.
*)
PROCEDURE KickOutOverlay ( VAR Node             : ATreeNode;
                               DeInstallVectors : AnEntryProc;
                           VAR ErrorFlag        : BOOLEAN ) : BOOLEAN;
VAR
    Entry            : AContextListEntry;
    Where            : AResidenceWhere;

    PROCEDURE SwapIt( Critical : BOOLEAN ) : BOOLEAN;
    BEGIN
        WITH Entry^ DO
            IF (SwapOut( Critical,
                         Where,
                         OverlaySize+2,
                         OverlayLayerAddr )) THEN
                Residence := Where.Residence; (* Not in main mem *)
                RETURN TRUE;
            END;
        END;

        RETURN FALSE;

    END SwapIt;

BEGIN
    IF (ErrorFlag) THEN
        RETURN FALSE;
    END;

    Entry := Node^.Methods^.GetDataObject (Node);
    WITH Entry^ DO
        IF (Residence <> InMainMemory) THEN (* 11-Feb-91 RSC not IN. *)
            RETURN FALSE;       (* 8-May-91 RSC prevent looping forever *)
        END;

            (* SWAPPING/CACHEING:

                    We can swap or cache overlays IF they are not on
                    the heap.

                    We only want to attempt swapping and/or caching
                    if the overlay is currently in main memory.

                    IF the use count is greater than 0, we need to
                        SWAP this entry, and push the entry onto the
                        swap stack.

                    ELSE we can cache the entry.  If it is already
                        cached, just mark it as again being in the cache.
                        otherwise swap it.
            *)
        IF (LoadOption <> LoadOffHeap) THEN
            IF (UseCount > StackOccurances(Entry)) THEN (* 18-Apr-91 RSC  *)
                IF (SwapIt(TRUE)) THEN
                    PushSwapStack( Entry, Where );
                ELSE
                    ErrorFlag := TRUE;
                END;
                RETURN TRUE; (* EXIT IF SWAPPED/CACHED *)
            ELSIF (WantsResidence) THEN
                IF (ResidentWhere.Residence = InMainMemory) THEN
                    IF (SwapIt( FALSE )) THEN                  (* 27-Jan-92 *)
                        ResidentWhere := Where;
                        RETURN TRUE; (* EXIT IF SWAPPED/CACHED *)

                        (* It may not be cached, but perhaps it is already
                           on the swap stack.  If so, mark it as not present,
                           but do NOT fill in the ResidentWhere, as that
                           would indicate that it is cached, which it is not.
                        *)
                    ELSIF (FindPusher(Entry, Where)) THEN (* 15-May-91 RSC *)
                        Residence     := Where.Residence;
                        RETURN TRUE; (* EXIT IF SWAPPED/CACHED *)
                    END;
                ELSE
                        (* Just mark it as "allready cached"
                        *)
                    Residence := ResidentWhere.Residence;
                    RETURN FALSE; (* EXIT IF SWAPPED/CACHED *)
                END;
            END;

        END;

        IF (ADDRESS(DeInstallProc) <> NIL) THEN
            DeInstallProc();    (* This could cause overlays to be removed! *)
        END;
        DeInstallVectors( Entry );
        DeInstallOverlay( TheOverlayPtr );
    END;
    RemoveFromContextList( Entry ); (* Entry is returned as NIL *)

        (* We have deleted THIS entry, but not others.
        *)
    RETURN FALSE;

END KickOutOverlay;




    (* KickOutOverlayFamily -

            Kick out the given overlay and all its kids.

            Context is a procedure to deinstall vectors, of type
            AnEntryProc.

    *)
PROCEDURE KickOutOverlayFamily (  VAR Node              : ATreeNode;
                                      Context           : AnEntryProc;
                                  VAR SwapFailure       : BOOLEAN );
VAR
    Subtree         : ATree;


        (* 8-May-91 RSC Added.  See note below.  Code is from
                        TreeObjects.Traverse
        *)
    PROCEDURE LocalTraverse( Tree : ATree );
    VAR
        CurrentNode,
        NextNode    : ATreeNode;
        Subtree     : ATree;
        Restart     : BOOLEAN;
    BEGIN

        Restart     := FALSE;
        CurrentNode := Tree^.Methods^.GetFirst (Tree);
        WHILE (CurrentNode <> NIL) AND (NOT SwapFailure) DO

            IF (Restart) THEN
                CurrentNode := Tree^.Methods^.GetFirst (Tree);
            END;

            NextNode := CurrentNode^.Methods^.GetNext( CurrentNode );
            Subtree  := CurrentNode^.Methods^.GetSubtree( CurrentNode );
            IF (Subtree <> NIL) THEN
                LocalTraverse( Subtree );
            END;
            Restart  := KickOutOverlay( CurrentNode, Context, SwapFailure );
            CurrentNode := NextNode;
        END;

    END LocalTraverse;


BEGIN

    IF (Node = NIL) THEN
        HALT;
    END;

    SwapFailure := FALSE;
    Subtree     := Node^.Methods^.GetSubtree (Node);

    IF (Subtree <> NIL) THEN
        LocalTraverse( Subtree );
            (* 8-May-91 RSC was:
            *)
(*        Subtree^.Methods^.TraverseTree (Subtree, ParentAfterChild, 9999,*)
(*                                        KickOutOverlay, ADDRESS(Context));*)
    END;

    IF (KickOutOverlay(Node, Context, SwapFailure )) THEN END;

END KickOutOverlayFamily;





(* *********************  OVERLAY SWAP STACK  *********************** *)

(* When an overlay is in use and needs to be removed from an overlay
   area, it must be swapped out in its entirety.  As soon as the replacing
   overlay exits, the overlay is swapped back in.  Here we maintain a
   stack of such swaps.
*)

VAR
    SwapStack : ARRAY [1..20] OF RECORD
        Entry    : AContextListEntry;
        Where    : AResidenceWhere;
        UseCount : CARDINAL;    (* 15-May-91 RSC use count when PUSHED. *)
    END;
    StackPointer : ASwapStackMarker;


(* 17-Apr-91 RSC Find the most "recent" pushed entry of this overlay.
                 RETURN TRUE iff found, and where it is.
*)
PROCEDURE FindPusher(     Entry  : AContextListEntry;
                      VAR Where  : AResidenceWhere   ) : BOOLEAN;
VAR
    i   : CARDINAL;
BEGIN
    i := 1;
    WHILE (i <= StackPointer)           AND
          (Entry <> SwapStack[i].Entry) DO
        INC(i);
    END;

    IF (i <= StackPointer) THEN
        Where := SwapStack[i].Where;
    END;

    RETURN (i <= StackPointer);

END FindPusher;



    (*  Look through the swap stack for an entry which matches the Where
        parameter.  Return TRUE iff found.  This will probably be mostly
        used for statistics and debugging.
    *)

PROCEDURE FindWhere(     Where   : AResidenceWhere;
                     VAR Entry   : AContextListEntry ) : BOOLEAN;

VAR
    i                       : CARDINAL;

        PROCEDURE ItMatches(     WhereA     : AResidenceWhere;
                                 WhereB     : AResidenceWhere    ) : BOOLEAN;

        VAR
            Match               : BOOLEAN;

        BEGIN                   (* ItMatches *)

            Match := FALSE;
            IF (WhereA.Residence = WhereB.Residence) THEN
                CASE WhereA.Residence OF
                    InMainMemory :
                        Match := (WhereA.Address = WhereB.Address);
                |   InEms :
                        Match := (WhereA.EMSHandle = WhereB.EMSHandle);
                |   InXms :
                        Match := (WhereA.XMSStartingByte = WhereB.XMSStartingByte);
                |   InFlexStor :
                        Match := (WhereA.FlexStorHandle = WhereB.FlexStorHandle);
                ELSE
                    FatalError();
                END;
            END;

            RETURN Match;

        END ItMatches;

BEGIN                       (* FindWhere *)

    FOR i := 1 TO StackPointer DO
        IF (ItMatches( SwapStack[i].Where, Where )) THEN
            Entry := SwapStack[i].Entry;
            RETURN TRUE;
        END;
    END;

    RETURN FALSE;

END FindWhere;



(* 18-Apr-91 RSC Count the number of times this overlay is
                 already "pushed".

   15-May-91 RSC Well, return the highest UseCount found in the list.
                 I am now tracking UseCounts because an overlay could
                 call itself and then be pushed out, so the use count
                 is 2 but the times on the stack are 1.
*)
PROCEDURE StackOccurances(  FindThisEntry  : AContextListEntry ) : CARDINAL;
VAR
    i,
    HighestUseCount : CARDINAL;
BEGIN
    HighestUseCount := 0;
    FOR i := 1 TO StackPointer DO
        WITH SwapStack[i] DO
            IF (Entry = FindThisEntry) THEN
                IF (UseCount > HighestUseCount) THEN
                    HighestUseCount := UseCount;
                END;
            END;
        END;
    END;

    RETURN HighestUseCount;

END StackOccurances;



(* Get the current top-of-stack, so that you can return to it when
   you are ready to.

   This is used just before loading an overlay, so that when the
   overlay exits, we can "PopSwapStack".

*)
PROCEDURE GetSwapStackMarker() : ASwapStackMarker;
BEGIN
    RETURN StackPointer;
END GetSwapStackMarker;



(* Pop the swap stack back to the marker given.  In order to make room
   for the overlay to be swapped back in, use the passed "MakeRoom"
   procedure.

   THIS ACTUALLY SWAPS THE CODE BACK INTO THE LAYER IT CAME FROM.
*)
PROCEDURE PopSwapStack( SwapStackMarker : ASwapStackMarker;
                        MakeRoom        : AMakeRoomProc   );
VAR
    Entry  : AContextListEntry;
    Where  : AResidenceWhere;
    Size   : CARDINAL;
    s      : ARRAY [0..39] OF CHAR;
BEGIN
    WHILE (SwapStackMarker < StackPointer) DO
        Entry := SwapStack[StackPointer].Entry;
        Where := SwapStack[StackPointer].Where;
        MakeRoom( Entry^.LoadOption, Entry^.OverlaySize );
(*        SwapIn( (Entry^.UseCount > 0), Where, Size, Entry^.OverlayLayerAddr );*)
        SwapIn( TRUE, Where, Size, Entry^.OverlayLayerAddr );
        Entry^.Residence := InMainMemory;
        DEC(StackPointer);
    END;
END PopSwapStack;




(* Push the swap stack.  THIS DOES NOT MOVE THE CODE.
   A HALT here means "stack full".
*)
PROCEDURE PushSwapStack(     PushEntry  : AContextListEntry;
                         VAR PushWhere  : AResidenceWhere   );
BEGIN
    INC(StackPointer);
    IF (StackPointer > HIGH(SwapStack)) THEN
        HALT;
    END;

    WITH SwapStack[StackPointer] DO
        Entry    := PushEntry;
        Where    := PushWhere;
        UseCount := PushEntry^.UseCount;  (* 15-May-91 RSC *)
    END;

END PushSwapStack;




PROCEDURE InitOvTree();

VAR
    s                       : ARRAY [0..255] OF CHAR;
    s2                      : ARRAY [0..9] OF CHAR;
    i                       : CARDINAL;

BEGIN
    IF (NOT CreateTree( OverlayTree )) THEN
        FatalError();
    END;

END InitOvTree;




BEGIN
    StackPointer := 0;
    OverlayTree  := NIL;
END OvTree.
