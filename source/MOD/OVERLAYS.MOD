IMPLEMENTATION MODULE Overlays;

(*  =========================================================================
    Last Edit : July 1, 1991 2:23PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description: 
        

    MODIFICATION HISTORY:

            (Comment history from before 1990 removed 1-Feb-91 by RSC.)

       18-Jan-90 WKH    It's me again, and yes I'm here to change the rsrvd
                        layer again.  Due to code increases caused by mouse
                        support, we have to increase our size to 52K.  This
                        probably won't be the last you'll see of me...

       12-Nov-90 RSC    Export the Reserved Layer.
       29-Jan-91 RSC    Removed export of ReservedLayer.
        1-Feb-91 RSC    Change from 1 to two layers.  Overlays go into
                        either the heap or one of two layers.  The
                        determination of where overlays go is fixed,
                        rather than determined at run time.

                        One layer is the "Mom" layer and intermediate
                        overlays go in here.  Overlays like TLFBASE and
                        TLRPBASE.

                        The other layer is the "Kid" layer.  Overlays
                        go into here that:

                            - do not steal vectors
                            - do not register for overlays
                            - do not have kids themselves.

                        When an overlay is to be loaded, if an overlay is
                        already loaded in the layer, it is removed to
                        a swap area.

                            DEBUG IS ON

                        disables this behaviour.


       28-Mar-91 RSC    Added "Trace mode".  This is to help debug problems
                        when not in "debug mode".  Often maps are useless,
                        because they say "Map file does not correspond to
                        program dump".  at least here, you will see the flow
                        of overlay calls with trace mode on:

                            ADDIN IS TLTRACE

       16-Apr-91 RSC    When loading an overlay from cache, make sure you
                        don't flush the overlay in order to make room for
                        it.  (So, push TLCHANGE out to make room for a
                        cached overlay.  In order to do that, flush the
                        overlay you are about to load.)

                        Also, keep overlay layers in RAM, rather than
                        in the phrases file.

       26-Apr-91 RSC    Removed trace mode as explicit calls, and instead
                        rely on the notices to handle the notification for
                        me.

        8-May-91 RSC Removed use of TraverseTree, because of its unstable
                     nature when deleting essentially RANDOM NODES in the
                     tree while traversing it.
                     Improved MaybeKickOutOverlay.

       27-May-91 RSC Changed two refs to CurrentOverlayContext to
                     ThisOverlaysContext, as I think the WITH is getting
                     a little overworked when CurrentOverlayContext gets
                     changed out from under it.

                     Also, In MaybeKickOutOverlay I set CurrentOverlayContext
                     to NIL as a precaution.

       29-May-91 RSC Sometimes with DEBUG ON, the current overlay context
                     was being lost because of low memory notices or other
                     notice calls that could flush overlays.  Cleaned this
                     up.  This included removing RunTheOverlay and flattening
                     that code into CallOverlayWithDialog.

                     Also, made the Layers be an array of ALoadOption, rather
                     than always translating between LoadOption and an index.
                     LoadOffHeap has a layer of NIL, so that InstallOverlay
                     knows to allocate space for it "somewhere".

       30-May-91 RSC Another CurrentOverlayContext item.....
                     Remove my change of 27-May-91 that set CurrentOverlay
                     Context to NIL.  Only set it to NIL if we are deleting
                     the current overly.

        1-Jul-91 RSC Added a speedup into the Logitech OverlayDescriptor of
                     backpointers to our shadow data structures.  In an
                     OverlayPtr, dummy[1] is the ContextListEntry for the
                     overlay and dummy[2] is the tree node of that entry.
                     In this module, that affected just the Init proc.
                     In the init proc, I set up TimeLine's context entry
                     to point to the lotigech structure for it, and have
                     the logitech structure point back.
       10-Jul-91 AJL Take any code returned from SelectAndRunOverlay to
                     mean success except CancelKey.
       16-Jul-91 LAA In CallOverlayWithDialog, removed code which traversed
                     the tree looking for the node associated with the 
                     overlay context, in favor of using the backpointer 
                     (dummy[2]).  In InitializeOverlays, don't set up the
                     backpointer for timeline.exe, since it's now handled
                     in AddToContextList, but do transfer the dummy values
                     to overlayList.  These optimizations by Roger.
       18-Sep-91 LAA In MakeRoomToLoad, we are calling DetermineSpaceNeeded
                     to round up the space requirement to chunk sizes that
                     we'll allocate to avoid fragmentation.  BUT, if there's
                     not enough memory, we send low memory notices giving the
                     un-rounded-up amount as the amount that needs to be
                     freed.  This may have been causing problems where some
                     functions would fail the first time, but succeed if
                     retried.
       26-Sep-91 LAA In DetermineLoadOption, we now check to see if TLCAPTIO
                     is the overlay, and if it is and we have enough free
                     DOS memory, it's loaded on the heap instead of in its
                     layer.  This is an optimization, since TLCaptions is
                     called VERY frequently and there have been reports of
                     slowness in updating the Gantt chart.
       20-Jan-92 LAA In an attempt to solve continuing problems with slowness
                     due to the loading of TLCaptions, I've put in several
                     special-case checks.  In DetermineLoadOptions, we'll
                     now flush other stuff out of memory in order to load
                     TLCaptions on the heap, an in MaybeKickOutOverlay I
                     made changes to only purge it after all others have
                     be purged and memory is still needed.  There are also
                     special checks for the case where the ! flag in front
                     of an overlay name flushes memory, so we will still
                     keep TLCaptions around.
    =========================================================================
*)




FROM Dialog         IMPORT
    (* PROC *)          Error, Message, ErrorPhrase,
                        Burp, FatalError;

FROM DOSMemory      IMPORT DOSAvail;

FROM Directory      IMPORT
    (* TYPE *)          AFileNameRecord, AFileAttributeSet,
                        ASetOfFileNameParts, AFileNamePart,
                        NormalizeFileName, DOSVersion, ExtractFileNameParts,
                        GetPathEntry, StartFileNodeLookup;

FROM FileOpen       IMPORT
    (* PROC *)          RequestFileFind;

FROM FileAux        IMPORT
    (* VAR *)           OverlayPath, EXEPath;

FROM Keys           IMPORT 
     (* CONST *)        CancelKey;

FROM Lights         IMPORT
    (* PROC *)          EnableLights;

FROM LStrings       IMPORT 
                        StoC, SetString, ConcatS, ConcatLS, CtoS, Copy,
                        StringsEqual, TStringToLString, LStringToTString,
                        Insert, SubStr, Search, Fill, Remove, LengthOf,
                        SetLengthOf, TrimRear, Procustes, Upshift,
                        Compare;

FROM Menus          IMPORT
    (* PROC *)          WordNumber;

FROM MsgFile        IMPORT
    (* PROC *)          GetMessage, ConcatMessage, DisplayMessage;

FROM Notices        IMPORT
    (* TYPE *)          AnOccasion, AStep,
    (* PROC *)          RegisterForNotices, Permission, SendNotices;

FROM Overlay        IMPORT
    (* TYPE *)          LayerId, ErrorCode,
    (* PROC *)          InstallOverlayInLayer, DeInstallOverlay,
                        InstallOverlay, NewLayer;

FROM OvSize         IMPORT
    (* PROC *)          OpenOverlay, DetermineOverlaySize,
                        DetermineSpaceNeeded;

FROM OVSwap         IMPORT
    (* PROC *)          SwapIn;

FROM OvTree         IMPORT
    (* CONST *)         CallChainSize,
    (* TYPE *)          AContextListItem, AContextListEntry,
                        AVectorRecord,    AVectorRecordPointer,
                        ADeinstallProc, AnOverlayProc, AProcPointer,
                        ALoadOption, AResidence, AResidenceWhere,
                        ASwapStackMarker,
    (* VAR *)           OverlayTree,
    (* PROCS *)         FindNodeFromOvlName, CopyAndTrimName,
                        KickOutOverlayFamily, InitOvTree,
                        RemoveFromContextList, AddToContextList,
                        GetSwapStackMarker, PopSwapStack,
                        FindPusher;

FROM Paranoia       IMPORT
        (* TYPE *)      AProgramState,
        (* VAR *)       ProgramState, InitializationOK;

FROM ParmLine       IMPORT
    (* PROC *)          GetOption;

FROM RTSMain        IMPORT
    (* TYPE *)          OverlayDescriptor,
    (* VARS *)          OverlayPtr, activProcess, Status, overlayList;

FROM RunMenu        IMPORT
    (* PROC *)          SelectAndRunMenu;

FROM Space          IMPORT
    (* PROC *)            Available, ALLOCATE, DEALLOCATE, StackSpaceLeft;

FROM SpecialCharactors  IMPORT
    (* CONST *)           SpecialCharDoMenu;

FROM SYSTEM         IMPORT
    (* TYPE *)            ADDRESS, SIZE, TSIZE,
    (* CAST *)            ADR, DOSCALL;

FROM TreeObjects    IMPORT (* RSC/EGK 11/17/88 *)
    (* TYPE *)            ATreeNode, ATreeOrder, ATree,
    (* PROCS *)           CreateTree, CreateTreeNode;


FROM Words          IMPORT
        (* PROCS *)     ParseString;






CONST
    ModuleNumber      = 2700;    (* For GetMessage *)
    
    KPara             = 1024 DIV 16;  (* 1 KB in paragraphs *)
    KRound            =  512 DIV 16;  (* 1 KB roundup       *)

    MAXCARDINAL       = 65535;

    StackCushion      = 4096;     (* CallOverlayWithContext fails if this
                                     much is not available. RSC 11/1/88. *)
    StackMinimum      = 1600;     (* Don't bother with a warning message
                                     if not at least this much.  RSC 11/1/88 *)

TYPE
    AnOverlayID = AContextListEntry; (* Hide this from our customers *)



    EnoughFreeProc = PROCEDURE() : BOOLEAN;

    AKickOutContextRecord = RECORD
                                EnoughFreeCheck : EnoughFreeProc;
                                TheLoadOption   : ALoadOption;
                                KeepGoing       : BOOLEAN;
                                CheckForCaptions: BOOLEAN;  (* treat it specially *)
                            END;

    AnOverlayLoadOptionEntry = POINTER TO RECORD   (* 16-Apr-91 RSC  *)
        LoadOption           : ALoadOption;
        OverlayName          : ARRAY [0..8] OF CHAR;
    END;

    AnOverlayLoadOptionList  = ARRAY [1..180] OF AnOverlayLoadOptionEntry; (* 16-Apr-91 RSC  *)



VAR
    Layers                : ARRAY ALoadOption OF LayerId;

    OverlayLoadOptionList : AnOverlayLoadOptionList;    (* 16-Apr-91 RSC *)
    OverlayLoadOptionListEntries : CARDINAL;            (* 16-Apr-91 RSC *)

    CurrentOverlayContext : AContextListEntry;
    RootOverlayContext    : AContextListEntry;

    OverlaySpaceNeeded    : CARDINAL;

    GlobalItem            : AContextListItem; (* Was LocalItem in CallOverlayWithContext.  RSC 1/17/89 *)

    Registered,
    SpaceInterlock        : BOOLEAN;

    FullFileName          : ARRAY [0..127] OF CHAR; (* Of last loaded overlay *)
    TLCaptionsName        : ARRAY [0..8] OF CHAR;






  (* Find Entry - See if this overlay is already loaded.

        Preconditions  - FileName contains the file name, not including path.
        Postconditions - Return TRUE iff found (and therefore loaded).
                         CurrentOverlayContext is set to the found item
                                                (or NIL).
  *)
PROCEDURE FindEntry( FileName : ARRAY OF CHAR ) : BOOLEAN;
VAR
    Node      : ATreeNode;
    Entry     : AContextListEntry;
    SizeIn    : CARDINAL;
    Where     : AResidenceWhere;
    CallChain : ARRAY [0..CallChainSize] OF CHAR;
BEGIN
    SeperateFileNameFromContext( FileName, CallChain ); (* RSC 1/13/89 *)
    Node := FindNodeFromOvlName( FileName );
    IF (Node = NIL) THEN
        CurrentOverlayContext := NIL;
    ELSE
        Entry := Node^.Methods^.GetDataObject( Node );
        WITH Entry^ DO
            IF (Residence <> InMainMemory) THEN
                Where := ResidentWhere;
                IF (Where.Residence <> InMainMemory) OR
                   (FindPusher( Entry, Where ))      THEN  (* 18-Apr-91 RSC *)
                        (* Don't let MakeRoomToLoad swap THIS entry out!
                        *)
                    INC(UseCount);  (* 16-Apr-91 RSC  *)
                    MakeRoomToLoad( LoadOption, OverlaySize );
                    DEC(UseCount);  (* 16-Apr-91 RSC  *)
                    SwapIn( FALSE, Where, SizeIn, OverlayLayerAddr );
                    Residence := InMainMemory;
                ELSE
                    HALT;  (* UNEXPECTED..... *)
                END;
            END;
        END;
        CurrentOverlayContext := Entry; (* AFTER OVERLAYS COULD GET KICKED OUT! *)
    END;

    RETURN (CurrentOverlayContext <> NIL);

END FindEntry;





PROCEDURE DefaultDeinstallProc( UnsetThis : AProcPointer;
                                FromThis,
                                ToThis    : PROC );
BEGIN
    UnsetThis^ := ToThis;
END DefaultDeinstallProc;





    (* ------------------------------------------------------------

       InstallNewProcedureWithUnset

       Installs a new procedure handler into a procedure variable
       and returns the prior value.


       SetThis                  is the vector to be stolen.
       ToThis                   is the procedure to set it to.
       WhereIKeepTheOldValue    is where you keep the one and only copy
                                   of the prior value of the vector.
                                   If NIL, you do not keep an old copy.
                                   If non-NIL, it is the address of a
                                   vector to the prior value of the
                                   procedure being stolen.  This must
                                   be a global (static) variable and
                                   you must not make copies of it.

                                   The old vector's contents may be changed
                                   periodicly as overlays are removed.

       Deinstall                is the procedure that deinstalls this
                                   vector.  In this procedure, DO NOT
                                   set the vector back to your old value.
                                   instead, Overlays will do this for you.
                                   This procedure provides a way for you to
                                   do any needed cleanup.

    --------------------------------------------------------------- *)





PROCEDURE InstallNewProcedureWithUnset(     SetThis                : ADDRESS;
                                            ToThis                 : PROC;
                                            WhereIKeepTheOldValue  : ADDRESS;
                                            Deinstall              : ADeinstallProc );
VAR
    PriorEntry   : AVectorRecordPointer;
BEGIN
    IF (NOT Registered) THEN
        Registered := TRUE;
        InitializeOverlays();
    END;
    IF (CurrentOverlayContext = NIL) THEN
        CurrentOverlayContext := RootOverlayContext;
    END;

    IF (CurrentOverlayContext^.LoadOption <> LoadOffHeap) THEN
        FatalError();  (* This overlay should not have vectors stolen!! *)
    END;

    PriorEntry := CurrentOverlayContext^.VectorListHead;

    IF (NOT Available( TSIZE( AVectorRecord ) )) THEN
        InitializationOK := FALSE;
        RETURN;
    END;

    NEW( CurrentOverlayContext^.VectorListHead );

    WITH CurrentOverlayContext^.VectorListHead^ DO
        Vector      := SetThis;
        PriorValue  := Vector^;
        Vector^     := ToThis;
        NewValue    := ToThis;
        Unset       := Deinstall;
        PriorLink   := PriorEntry;
        ClientCopy  := WhereIKeepTheOldValue;
        IF (ClientCopy <> NIL) THEN
            ClientCopy^ := PriorValue;
        END;
    END;

END InstallNewProcedureWithUnset;





    (* ------------------------------------------------------------

       InstallNewProcedure

       Installs a new procedure handler into a procedure variable
       and returns the prior value.

       SetThis                  is the vector to be stolen.
       ToThis                   is the procedure to set it to.
       WhereIKeepTheOldValue    is where you keep the one and only copy
                                   of the prior value of the vector.
                                   If NIL, you do not keep an old copy.
                                   If non-NIL, it is the address of a
                                   vector to the prior value of the
                                   procedure being stolen.  This must
                                   be a global (static) variable and
                                   you must not make copies of it.

                                   The old vector's contents may be changed
                                   periodicly as overlays are removed.

       There is no need to deinstall this vector, it will be deinstalled
       automaticly.


    ---------------------------------------------------------------*)

PROCEDURE InstallNewProcedure(     SetThis                : ADDRESS;
                                   ToThis                 : PROC;
                                   WhereIKeepTheOldValue  : ADDRESS );
BEGIN
    InstallNewProcedureWithUnset( SetThis,
                                  ToThis,
                                  WhereIKeepTheOldValue,
                                  DefaultDeinstallProc);
END InstallNewProcedure;













PROCEDURE DeInstallVectors( Entry : AContextListEntry );
VAR 
    Top,
    PriorEntry : AVectorRecordPointer;
BEGIN
    Top := Entry^.VectorListHead;
    WHILE (Top <> NIL) DO

        (* Sanitize the overlay tree. *)

        OverlayTree^.Methods^.TraverseTree( OverlayTree, ParentAfterChild, 9999,
                                            SanitizeVectors, ADDRESS( Top ));

        WITH Top^ DO
            IF (Vector^ = NewValue) THEN
                (* Here, New and Prior are reversed. *)
                Unset(Vector,NewValue,PriorValue);
                IF (ClientCopy <> NIL) THEN
                    ClientCopy^ := PROC(NIL);
                END;
            END;
        END;

            (* Pop the entry *)

        PriorEntry := Top^.PriorLink;

        DISPOSE( Top );
        Top        := PriorEntry;
    END;
    Entry^.VectorListHead := NIL;

END DeInstallVectors;





(* Sanitize Vectors -

        If More than one overlay has stolen a particular vector, then we
        must be very carefull to dethread the vector properly.  That is,
        we USED to treat the vector list as a stack, but we must insted
        treat it as a LIST.

        Example:

            TLABC.OVL comes in and steals the keyboard vector.
            TLDEF.OVL comes in and steals the same vector.
            TLDEF now points to TLABC's proc, TLABC points to the original.

            TLABC.OVL exits.  What do we do with the vectors?

            We need to have TLDEF point to the original proc, not to TLABC's.

    RSC 1-Mar-89
*)
PROCEDURE SanitizeVectors( VAR Node     : ATreeNode;
                               Context  : ADDRESS   );
VAR
    OverlayEntry : AContextListEntry;
    OtherVector,
    VectorEntry  : AVectorRecordPointer;
BEGIN
    VectorEntry  := Context;
    OverlayEntry := Node^.Methods^.GetDataObject (Node);
    OtherVector  := OverlayEntry^.VectorListHead;
    WHILE (OtherVector <> NIL) DO

        (* If:

                - This is not the vector record we are deleting,
                - They share the same  target vector (they both
                  stole the same thing),
                - this record points to the proc in the code whose
                  vector we are deleting,
           Then
                Remove the entry being deleted from the chain.
        *)

        IF (OtherVector             <> VectorEntry)           AND
           (OtherVector^.Vector     =  VectorEntry^.Vector)   AND
           (OtherVector^.PriorValue =  VectorEntry^.NewValue) THEN
            OtherVector^.PriorValue := VectorEntry^.PriorValue;
            IF (OtherVector^.ClientCopy <> NIL) THEN
                OtherVector^.ClientCopy^ := OtherVector^.PriorValue;
            END;
        END;
        OtherVector := OtherVector^.PriorLink;
    END;
END SanitizeVectors;







    (*$S+*)


  (* OverlayContext   - Return the current overlay's context pointer.
     OverlayCallChain - Return the current overlay chain.

        Preconditions - You MUST be an OVERLAY, Otherwise the context area
                        will be toxic.

        Postconditions - The current context address is returned to you.
                         Remember that it could possibly be NIL, especially
                         if someone called you with "CallOverlay" and not
                         "CallOverlayWithContext".

     The CallChain is the string in parens after the overlay name in the
     call to CallOverlayWithContext.  So, if you CallOverlay with
     "TLFBASE(TLCHANGE)", "TLCHANGE" is the overlay call chain.
  *)
PROCEDURE OverlayContext() : ADDRESS;
BEGIN
    IF (CurrentOverlayContext = NIL) THEN
        FatalError(); (* not in an overlay? *)
    END;
    RETURN CurrentOverlayContext^.Context;

END OverlayContext;


PROCEDURE OverlayCallChain() : ADDRESS;
BEGIN
    IF (CurrentOverlayContext = NIL) THEN
        FatalError(); (* not in an overlay? *)
    END;
    RETURN ADR(CurrentOverlayContext^.CallChain);

END OverlayCallChain;

    (*$S=*)




  (* Get File Location And Size -

        Look through the overlay path for the file.  If found, return
        the file's size and TRUE.  And the file' path position in OverlayPath.
  *)
PROCEDURE GetFileLocationAndSize( VAR FilenameIn  : ARRAY OF CHAR;
                                  VAR PathEntry   : CARDINAL;
                                  VAR FileSize    : CARDINAL ) : BOOLEAN;
VAR
    Handle         : CARDINAL;
    s              : ARRAY [0..255] OF CHAR;
    FileNameOut    : ARRAY [0..99]  OF CHAR;
    NameAndExt     : ARRAY [0..31]  OF CHAR;
BEGIN

    (* Look for the file.  Look through the entire overlay path, trying
       to find the file we want.  This is very simular logic to FileOpen
       but we want to find the size of the file, in KB.
    *)
    PathEntry := 0;
    WHILE (GetPathEntry( OverlayPath, PathEntry, FullFileName )) DO
        NormalizeFileName( FullFileName, ASetOfFileNameParts{DevicePart,DirectoryPart} );
        ConcatLS( FullFileName, FilenameIn );
        IF (OpenOverlay( FullFileName, Handle )) THEN
            FileSize := DetermineOverlaySize();
            RETURN (FileSize > 0);
        END;
        INC( PathEntry );
    END;

    Message( FilenameIn );  (* 26-Sep-89 RSC for debugging. *)

    GetMessage( ModuleNumber+52, s ); (* "Option not installed." *)
    Error( s );

    SetLengthOf( s, 0 );    (* 26-Sep-89 RSC *)
    Message(s);

    RETURN FALSE;  (* Not found! *)

END GetFileLocationAndSize;






PROCEDURE SeperateFileNameFromContext( VAR FileName,
                                           Context   : ARRAY OF CHAR );
VAR
    Len : CARDINAL;
    s   : ARRAY [0..99] OF CHAR;
BEGIN
    Copy( FileName, s );
    Len := 1;
    ParseString( s, Len, FileName );
    ParseString( s, Len, Context  );
END SeperateFileNameFromContext;




(* Determine the load option.  Look up the overlay's name in the overlay
   index and from that determine where to load it.
*)
PROCEDURE DetermineLoadOption( FileName : ARRAY OF CHAR;
                               Size     : CARDINAL       ) : ALoadOption;
VAR
    DOSSize     : CARDINAL;
    LoadOption  : ALoadOption;
    s           : ARRAY [0..255] OF CHAR;
    Device      : ARRAY [0..5]   OF CHAR;
    Path        : ARRAY [0..127] OF CHAR;
    Extension   : ARRAY [0..5]   OF CHAR;


    PROCEDURE SearchList( Last   : CARDINAL ) : ALoadOption;
    VAR
        i        : INTEGER;
        LowBound,
        Target   : CARDINAL;
    BEGIN
        LowBound := 1;

        REPEAT
            Target := (LowBound + Last) DIV 2;

(*$O-*)
            i := Compare( FileName, OverlayLoadOptionList[Target]^.OverlayName );
(*$O=*)

            IF (i < 0) THEN
                Last     := Target - 1;
            ELSIF (i > 0) THEN
                LowBound := Target + 1;
            ELSE
(*$O-*)
                RETURN OverlayLoadOptionList[Target]^.LoadOption; (* Found! *)
(*$O=*)
            END;
        UNTIL (LowBound > Last);

        RETURN LoadOffHeap;

    END SearchList;

BEGIN
    IF (OverlayLoadOptionListEntries = 0) THEN  (* Not setup? *)
        SetupLoadOptionList( OverlayLoadOptionList,
                             OverlayLoadOptionListEntries );
    END;

    IF (OverlayLoadOptionListEntries > 0) THEN  (* Not in debug mode? *)
        Upshift(FileName);
        Copy(FileName,s);
        ExtractFileNameParts( s, Device, Path, FileName, Extension );

        LoadOption := SearchList( OverlayLoadOptionListEntries );

        IF (StringsEqual( FileName, TLCaptionsName )) THEN
            DOSSize := DetermineSpaceNeeded( Size );
            MakeRoomOnHeap( DOSSize );                         (* 20-Jan-92 *)
            IF (DOSSize <= DOSAvail()) THEN
                LoadOption := LoadOffHeap;
            END;
        END;
    ELSE
        LoadOption := LoadOffHeap;
    END;

    RETURN LoadOption;

END DetermineLoadOption;






(* Setup the list of where overlays are to go.

    This goes on the heap rather than global memory to try to get it into
    one of the many special areas we can squirrel memory (HMA/VIDEO/UMB).
*)
PROCEDURE SetupLoadOptionList( VAR LoadOptionList        : AnOverlayLoadOptionList;
                               VAR LoadOptionListEntries : CARDINAL );
VAR
    i, j               : CARDINAL;
    CurrentLoadOption  : ALoadOption;
    s                  : ARRAY [0..255] OF CHAR;
    NewOverlayName     : ARRAY [0..9] OF CHAR;

    (*  This subprocedure:

        Implements the CombSort11 algorithm discussed in the
        "Hands On" April 1991 BYTE magazine article, pp 315-320.

        CombSort is a much, much faster version of the bubblesort.
        Its run times are closer to a HeapSort or QuickSort, but without
        the complexity.

        Read the article for complete information, but the basic idea is
        to implement a bubble sort.  Where a bubble sort always compares
        and swaps adjacent items, this sort will compare items that are
        not nescessarily adjacent.  That is, where a bubble sort compares
        item N with item N+1, this sort compares N with N+<gap>.  The
        gap size starts large and decreases with each pass, untill the
        gap eventually is 1.  After a pass with a gap size of 1 where
        there were no swaps, the sort terminates.

        The advantage to this strategy of using gaps is to help move
        items quickly from one end of the list to the other.  For example,
        in a bubble sort, if the last item in the list to be sorted should
        be at the top of the list, it gets moved once for every pass,
        insuring that the bubble sort takes as long as it ever could.
        By having a larger gap, once the item to be moved up is found,
        it tends to move up faster.

        This is the variation called "CombSort 11", which favors a gap
        size of 11 at one point, rather than 10 or 9.
    *)
    PROCEDURE DoCombSort(     ItemCount : CARDINAL;
                          VAR Array     : AnOverlayLoadOptionList );
    VAR
        A           : AnOverlayLoadOptionEntry;
        Top,
        i, j,
        Gap         : CARDINAL;
        SwapDone    : BOOLEAN;
    BEGIN
        Gap := ItemCount;

        SwapDone := TRUE; (* Not really needed, but this is tidy *)

        WHILE ((Gap > 1) OR SwapDone) DO

            IF (Gap > 1) THEN
                Gap := (Gap * 10) DIV 13;  (* Same as Gap / 1.3 *)

                IF (Gap = 9) OR (Gap = 10) THEN
                    Gap := 11; (* This is the CombSort 11 variation *)
                END;

            END;

            SwapDone := FALSE;   (* Called "Switches" in the article *)

            FOR i := 1 TO (ItemCount - Gap) DO
                j := i + Gap;
(*$O-*)
                IF (Compare(Array[i]^.OverlayName,Array[j]^.OverlayName) > 0) THEN
(*$O=*)

                        (* SWAP:
                        *)
                    A        := Array[i];
                    Array[i] := Array[j];
                    Array[j] := A;
                    SwapDone := TRUE;
                END;
            END;
        END;

    END DoCombSort;

BEGIN

    IF (LoadOptionListEntries = 0)             AND  (* Not done this yet *)
       (Layers[LoadInMomArea] <> LayerId(NIL)) THEN (* Not in debug mode *)

        CurrentLoadOption := LoadInMomArea;
        i                 := ModuleNumber + 80;
        GetMessage( i, s );
        WHILE (i < (ModuleNumber + 99)) AND (LengthOf(s) > 0) DO
            Upshift(s);

            j := 1;
            WordNumber( s, j, NewOverlayName );
            WHILE (LengthOf(NewOverlayName) > 0) DO
                IF (LoadOptionListEntries > HIGH(LoadOptionList)) THEN
                    HALT;  (* Raise the limit! *)
                END;
                INC(LoadOptionListEntries);
                NEW(LoadOptionList[ LoadOptionListEntries ]);
                WITH LoadOptionList[ LoadOptionListEntries ]^ DO
                    LoadOption := CurrentLoadOption;
                    Copy( NewOverlayName, OverlayName );
                END;
                INC(j);
                WordNumber( s, j, NewOverlayName );
            END;

            CurrentLoadOption := LoadInKidArea;
            INC(i);
            GetMessage( i, s );
        END;

              (* Sort the list if > 1 item (which it SHOULD be).
                 We cannot call the standard sort, because that is
                 in an overlay.

                 Here we use the Combsort routine.
              *)
        IF (LoadOptionListEntries > 1) THEN
            DoCombSort( LoadOptionListEntries, LoadOptionList );
        END;
    END;

END SetupLoadOptionList;




    (*  These procedure are for the private use of CallOverlayWithContext,
        and have been seperated out in order to minimize stack usage.
    *)

PROCEDURE BuildEntryAndFilename(VAR TheirFilename : ARRAY OF CHAR;
                                    LContext      : ADDRESS;
                                VAR TheLoadOption : ALoadOption;
                                VAR Item          : AContextListItem )
                                                                 : BOOLEAN;
VAR
    SizeFound           : CARDINAL;
    LocalCallChain      : ARRAY [0..CallChainSize] OF CHAR;
    Filename            : ARRAY [0..79] OF CHAR;
BEGIN
    SeperateFileNameFromContext( TheirFilename, LocalCallChain );
    Copy( TheirFilename, Filename );
    ConcatS( Filename, ".OVL" );

    IF (Filename[1] = "|") OR (Filename[1] = "\") THEN
        Remove( Filename, 1, 1 );
    END;

    IF (Filename[1] = "!") THEN
        KickOutResidents( LoadOffHeap, NIL ); (* Kick out all residents *)
        OverlaySpaceNeeded := MAXCARDINAL;
        SendNotices(LowMemory, AfterActing, ADDRESS(EnoughFree)); (* And all other space *)
        Remove( Filename, 1, 1 );
    END;

    IF (NOT GetFileLocationAndSize( Filename,
                                    Item.WhichPathEntry,
                                    SizeFound )) THEN
        RETURN FALSE;
    END;

    TheLoadOption       := DetermineLoadOption(Filename, SizeFound);

    WITH Item DO
        Context         := LContext;
        VectorListHead  := NIL;
        UseCount        := 0;
        MainProcedure   := AnOverlayProc(NIL);
        DeInstallProc   := AnOverlayProc(NIL);
        TheOverlayPtr   := OverlayPtr(NIL);
        OverlaySize     := SizeFound;
        WantsResidence  := FALSE;
        IsLocked        := FALSE;
        LoadOption      := TheLoadOption;
        Residence       := InMainMemory;
        ResidentWhere.Residence := InMainMemory;
        Copy( TheirFilename,  OverlayName );
        Copy( LocalCallChain, CallChain   );

        OverlayLayerAddr := ADDRESS(Layers[LoadOption]);

    END;

    RETURN TRUE;

END BuildEntryAndFilename;






PROCEDURE DisplayTheError(VAR OverlayName : ARRAY OF CHAR;
                              st          : Status;
                              errorcode   : ErrorCode;
                              Context     : ADDRESS  );

VAR
    s                   : ARRAY [0..255] OF CHAR;
    s2                  : ARRAY [0..101] OF CHAR;

BEGIN                   (* DisplayTheError *)

    IF (errorcode <> Done) THEN                                   (* 24-Dec-87 LAA *)
        IF (errorcode = InsufMemory) THEN                         (* 18-Feb-88 LAA *)
            GetMessage(ModuleNumber + 55, s);
            Error(s);
            RETURN;
        END;
        GetMessage(ModuleNumber+30+ORD(errorcode),s);         (* 16-Dec-87 LAA *)
    ELSE
        IF ((st <> Normal) AND (st <= NoCoprocessor87)) THEN           (* V3 *)
            GetMessage(ModuleNumber+ORD(st),s);
        ELSE
            GetMessage(ModuleNumber+53,s);   (* " Overlay error: " *)
            CtoS(ORD(st),s2);
            ConcatLS(s,s2);
        END;
    END;

    ConcatMessage(s,ModuleNumber+54);  (* " with " *)
    ConcatLS(s,OverlayName);
    Error(s);

END DisplayTheError;







    (*  For use by SwapF via notices call.... *)

PROCEDURE EnoughFree() : BOOLEAN;

BEGIN                       (* EnoughFree *)

    IF (DOSAvail() >= OverlaySpaceNeeded) THEN
        RETURN TRUE; (* We have enough to attempt a liftoff! *)
    END;
    RETURN FALSE;

END EnoughFree;





PROCEDURE MaybeKickOutOverlay (  VAR Node       : ATreeNode;
                                 VAR Context    : AKickOutContextRecord );
VAR
    Entry               : AContextListEntry;
    SwapTrouble         : BOOLEAN;
    ok                  : BOOLEAN;

BEGIN
    WITH Context DO

    (* 8-May-91 RSC 2 improvements:

            1) Only try to kick out those that are in memory.  If they are
               in a cache, don't bother kicking them out.
            2) If we do try to kick something out, then if the node is
               NIL or the item is now not in memory, things have changed
               and we are done if we were not dumping heap.
    *)

        IF (KeepGoing) THEN
            Entry := Node^.Methods^.GetDataObject (Node);
            IF (Entry <> NIL) THEN
                WITH Entry^ DO
                    ok := (TheLoadOption = LoadOption) AND (Residence = InMainMemory);
                    IF (ok) THEN
                        IF (LoadOption = LoadOffHeap) THEN
                            ok := (UseCount = 0) AND (NOT IsLocked);
                            IF (ok AND (CheckForCaptions)) THEN
                                ok := (NOT StringsEqual(OverlayName, TLCaptionsName));
                            END;
                        END;
                    END;

                    IF (ok) THEN
                        IF (Entry = CurrentOverlayContext) THEN (* 30-May-91 RSC  *)
                            CurrentOverlayContext := NIL;   (* 27-May-91 RSC  *)
                        END;
                        KickOutOverlayFamily (Node, DeInstallVectors, SwapTrouble );
                        IF (SwapTrouble) THEN
                            ErrorPhrase( ModuleNumber + 40 );  (* 8-May-91 RSC AAAAHHHHHHH!!!! *)
                            FatalError();
                        END;

                        IF (ADDRESS(EnoughFreeCheck) <> NIL) AND
                           (EnoughFreeCheck())               THEN
                            KeepGoing := FALSE;
                        ELSIF (TheLoadOption <> LoadOffHeap) THEN
                            IF (Node = NIL) OR (Residence <> InMainMemory) THEN
                                KeepGoing := FALSE; (* 8-May-91 RSC we're done. *)
                            END;
                        END;
                    END;
                END;
            END;
        END;
    END;

END MaybeKickOutOverlay;







  (* Kick Out Residents - remove any resident overlays in the specified
                          area whose use counts are 0.

        Preconditions  - ResidentsWithReservations is TRUE iff you want to
                                search the reserved layer.  FALSE if you
                                want to search the Heap.
                         FreeProc is for use with Notices() and is the
                                  procedure to call to see if we need to
                                  keep going.   It is ignored iff NIL.

        Postconditions - overlays may be found and removed.
  *)
PROCEDURE KickOutResidents( LoadOption    : ALoadOption;
                            FreeProc      : ADDRESS );
VAR
    ContextRecord       : AKickOutContextRecord;


        (* 8-May-91 RSC Added.  See note below.  Code is from
                        TreeObjects.Traverse
        *)
    PROCEDURE LocalTraverse( Tree : ATree );
    VAR
        CurrentNode,
        NextNode    : ATreeNode;
        Subtree     : ATree;
    BEGIN

        CurrentNode := Tree^.Methods^.GetFirst (Tree);
        WHILE (CurrentNode <> NIL) AND (ContextRecord.KeepGoing) DO

            NextNode := CurrentNode^.Methods^.GetNext( CurrentNode );
            Subtree := CurrentNode^.Methods^.GetSubtree( CurrentNode );
            IF (Subtree <> NIL) THEN
                LocalTraverse( Subtree );
            END;
            MaybeKickOutOverlay( CurrentNode, ContextRecord );

            CurrentNode := NextNode;
        END;

    END LocalTraverse;


BEGIN
    IF (SpaceInterlock) THEN
        RETURN;
    END;
    SpaceInterlock := TRUE;

    WITH ContextRecord DO
        EnoughFreeCheck  := EnoughFreeProc(FreeProc);
        TheLoadOption    := LoadOption;
        KeepGoing        := TRUE;
        CheckForCaptions := (LoadOption = LoadOffHeap);        (* 20-Jan-92 *)
    END;

        (* 8-May-91 RSC Don't use TraverseTree anymore, as
                        MaybeKickOutOverlay doesn't like nodes in the
                        tree to be deleted other than the current target
                        of TraverseTree.  As part of flushing overlays,
                        the tree can be massively shaken (ha ha), and
                        TraverseTree tries to deal with nodes which
                        have been delisted (and so loops forever, or
                        halts because of calling the processing proc
                        on the kid)

            OLD CODE:
                    OverlayTree^.Methods^.TraverseTree
                            (OverlayTree, ParentAfterChild, 9999,
                             MaybeKickOutOverlay, ADR(ContextRecord));
            NEW CODE:
        *)

    LocalTraverse( OverlayTree );

    IF (ContextRecord.KeepGoing AND (LoadOption = LoadOffHeap)) THEN          (* 20-Jan-92 *)
            (*  If we still need more heap memory, then check that this isn't 
                a general memory flush (use of ! before overlay name).  
                If we ARE just generally flushing memory, keep TLCaptions
                around.
            *)
        IF (FreeProc <> NIL) THEN
            ContextRecord.CheckForCaptions := FALSE;
            LocalTraverse( OverlayTree );
        END;
    END;

    SpaceInterlock := FALSE;

END KickOutResidents;


  (*  MakeRoomOnHeap --

      Free up the amount of heap space requested in the Size parameter,
      which is in paragraphs.  No guarantee this will work, so check
      DOSAvail afterwards if you care.
  *)

PROCEDURE MakeRoomOnHeap(    Size           : CARDINAL );      (* 20-Jan-92 *)

BEGIN                       (* MakeRoomOnHeap *)

    IF (Size > DOSAvail()) THEN
        OverlaySpaceNeeded := Size;
        KickOutResidents( LoadOffHeap, ADDRESS(EnoughFree) );
        IF (Size > DOSAvail()) THEN
            SendNotices(LowMemory, AfterActing, ADDRESS(EnoughFree));
        END;
    END;

END MakeRoomOnHeap;



  (* Make Room To Load -

      Try to make enough room to load the overlay where it should go.
      Return a suggested place to start trying to load the overlay, before
      resorting to the 'oh, shit' strategy.
  *)
PROCEDURE MakeRoomToLoad( LoadOption    : ALoadOption;
                          OverlaySize   : CARDINAL     );

BEGIN
    CASE LoadOption OF

        LoadInKidArea,
        LoadInMomArea :

            KickOutResidents( LoadOption, NIL );

      | LoadOffHeap        :

            MakeRoomOnHeap( DetermineSpaceNeeded(OverlaySize) );
    ELSE
        FatalError();
    END;

END MakeRoomToLoad;








PROCEDURE MaybeSendLowMemory( VAR FileName : ARRAY OF CHAR );
BEGIN
    IF (FileName[1] = "!") OR (FileName[2] = "!") THEN
        OverlaySpaceNeeded := MAXCARDINAL;
        KickOutResidents( LoadOffHeap, NIL ); (* Kick out residents *)
        SendNotices(LowMemory, AfterActing, ADDRESS(EnoughFree)); (* And all other space *)
    END;
END MaybeSendLowMemory;




PROCEDURE LowStackWarning ();
BEGIN
        (* Use FullFileName rather than a local var because
           we are low on stack!
        *)
    GetMessage (ModuleNumber+56, FullFileName);   (* "Stack space exceeded" *)
    Error (FullFileName);
END LowStackWarning;







    (*  =====================================================================
        
        PROCEDURE - CallOverlayWithDialog

            Preconditions :

                TimeLine's root is running

            Postconditions :

                The named overlay is called if possible.

            Parameters :
                Input:

                    FileName        The name of the overlay file, no
                                    path or extension.  An LString.

                    OverlayContext  The context address made available
                                    to the overlay via OverlayContext();

                    CouldntLoadProc The procedure to call to report errors
                                    like "Insufficient Memory" or "Version
                                    Conflict".

                    CouldntLoadCntxt the context to be passed to the
                                    CouldntLoadProc.

                Output:

                    RETURN is TRUE if the overlay ran.

        =====================================================================
    *)
PROCEDURE CallOverlayWithDialog( VAR FileName        : ARRAY OF CHAR;
                                     OverlayContext  : ADDRESS;
                                     CouldntLoadProc : ACouldntLoadProc;
                                     CouldntLoadCntxt: ADDRESS ) : BOOLEAN;
VAR
    Node                : ATreeNode;
    ThisOverlaysContext : AContextListEntry;
    SwapStackMarker     : ASwapStackMarker;
    st                  : Status;
    errorcode           : ErrorCode;
    LoadingOption       : ALoadOption;
    SwapTrouble         : BOOLEAN;

    PROCEDURE MakeFullOverlayName(     Context : AContextListEntry;
                                   VAR Name    : ARRAY OF CHAR    );
    VAR
        i   : CARDINAL;
        s1  : ARRAY [0..19]  OF CHAR;
    BEGIN
        Copy( Context^.OverlayName, s1 );
        FOR i := 1 TO 2 DO
            IF (s1[1] = "|") OR     (* Don't use "i" here *)
               (s1[1] = "!") OR
               (s1[1] = "\") THEN
                Remove( s1, 1, 1 );
            END;
        END;

        IF (NOT GetPathEntry( OverlayPath, Context^.WhichPathEntry, Name)) THEN
            FatalError(); (* It worked before, in "GetFileLocationAndSize", *)
                          (* why not now? *)
        END;
        NormalizeFileName( Name, ASetOfFileNameParts{DevicePart,DirectoryPart} );
        IF (Name[ORD(Name[0])] <> "\") THEN
            ConcatS(Name,"\");
        END;
        ConcatLS( Name, s1 );

        LStringToTString( Name, Name );

    END MakeFullOverlayName;


BEGIN
    (* Some prior error? *)
    IF ((NOT InitializationOK) AND (ProgramState < TLMainStarting)) THEN
        RETURN FALSE;
    END;

  (* We cannot register for notices in the module init because notices
     has not been initted yet, so we wait until we are invoked the first
     time.
  *)

    IF (NOT Registered) THEN
        Registered := TRUE;
        InitializeOverlays();
    END;

    IF (NOT StackSpaceLeft (StackCushion)) THEN             (* 10/28/88 EGK *)
        IF (StackSpaceLeft (StackMinimum)) THEN             (* 11/01/88 RSC *)
            LowStackWarning();
        ELSE
            Burp();
        END;
        RETURN FALSE;
    END;

    SwapStackMarker := GetSwapStackMarker();    (* 1-Feb-91 RSC *)

    st        := Normal;
    errorcode := Done;

    IF (FindEntry( FileName )) THEN (* Allready loaded/swapped in *)
        ThisOverlaysContext := CurrentOverlayContext;
(*$O-*)
        WITH ThisOverlaysContext^ DO    (* 27-May-91 RSC was current overlay context. *)
            SendNotices(OverlayCall,BeforeActing,ThisOverlaysContext); (* RSC 1/30/89 *)
            INC( UseCount );
            Context   := OverlayContext;
            SeperateFileNameFromContext( FileName, CallChain );
            IF (ADDRESS(MainProcedure) <> NIL) THEN
                MaybeSendLowMemory( FileName );
                CurrentOverlayContext := ThisOverlaysContext;  (* 29-May-91 RSC *)
                MainProcedure();     (* Call MAIN procedure *)
            END;
            DEC( UseCount );
            SendNotices(OverlayCall,AfterActing,ThisOverlaysContext); (* RSC 1/30/89 *)
        END;
(*$O=*)
        CurrentOverlayContext := NIL;  (* No longer valid.  RSC 1/30/89 *)
    ELSE
        IF (NOT BuildEntryAndFilename(FileName, OverlayContext,
                                      LoadingOption, GlobalItem )) THEN
            RETURN FALSE;
        END;

        SendNotices(OverlayCall,BeforeActing,ADR(GlobalItem)); (* RSC 1/30/89 *)

        (* Now we run the overlay.  At this point, "GlobalItem" has
           been set up for this particular overlay.  As soon as we
           enter the overlay, however, we can no longer trust "GlobalItem"
           because it will be changed/used by the next overlay to load.
           So, once the overlay is running,

            > CurrentOverlayContext points to the MOST RECENTLY
              LOADED overlay
            > The overlay is in the tree of overlays, and could be
              found by name.

           Upon return from RunTheOverlay, "GlobalItem" cannot be trusted.

           Also note that the passed parameter, "FileName" is now
           potentially invalid.

           RSC 1/17/89
        *)
        MakeRoomToLoad( LoadingOption, GlobalItem.OverlaySize );

        (* NOW add the item to the heap, AFTER we have freed up memory space
           via low mem notices!  RSC 2/18/88
        *)
        AddToContextList( GlobalItem, ThisOverlaysContext );

        IF (ThisOverlaysContext = NIL) THEN     (* Really out of memory! *)
            errorcode := InsufMemory;
            st        := HeapOvf;
        ELSE
            CurrentOverlayContext := ThisOverlaysContext; (* Set it. *)

            MakeFullOverlayName( ThisOverlaysContext, FullFileName );

            INC( CurrentOverlayContext^.UseCount );

            InstallOverlayInLayer( FullFileName,
                                   ThisOverlaysContext^.TheOverlayPtr,
                                   Layers[LoadingOption],
                                   errorcode, st );

            CurrentOverlayContext := ThisOverlaysContext; (* Reset it *)
            DEC( CurrentOverlayContext^.UseCount );
        END;

        IF ((st = Normal) AND (errorcode = Done)) THEN
            SendNotices(OverlayCall,AfterActing,ADDRESS(ThisOverlaysContext)); (* RSC 1/30/89 *)
        ELSE
            SendNotices(OverlayCall,FailureToAct,ADDRESS(ThisOverlaysContext)); (* RSC 1/30/89 *)
            IF (ThisOverlaysContext <> NIL) THEN  (* RSC 2-Aug-89 *)
                CouldntLoadProc( ThisOverlaysContext^.OverlayName, st,
                                 errorcode,
                                 CouldntLoadCntxt );
            ELSE
                CouldntLoadProc( RootOverlayContext^.OverlayName, st,
                                 errorcode,
                                 CouldntLoadCntxt );
            END;
        END;

        CurrentOverlayContext := ThisOverlaysContext; (* Reset it *)

        (* Remember that "GlobalItem" is no longer valid here .... *)

            (* 27-May-91 RSC CurrentOverlayContext --> ThisOverlaysContext
            *)
        IF (ThisOverlaysContext <> NIL) THEN                     (* 2/7/89 EGK *)
            WITH ThisOverlaysContext^ DO (* But this is .... *)
                IF (UseCount = 0) AND (NOT (WantsResidence OR IsLocked)) THEN
                    IF (TheOverlayPtr = NIL) THEN 
                        FatalError(); 
                    END;
                    Node := TheOverlayPtr^.dummy[2];           (* 16-Jul-91 *)
                    IF (Node = NIL) THEN
                        FatalError();
                    END;
                       (* the following INVALIDATES CurrentOverlayContext *)
                    KickOutOverlayFamily (Node, DeInstallVectors, SwapTrouble );
                       (* We don't expect swap trouble, as we shouldn't
                          even try to swap.
                       *)
                END;
            END;
        END;
        CurrentOverlayContext := NIL;  (* No longer valid.  RSC 1/30/89 *)
    END;

          (* Swap in any swapped-out items.  1-Feb-91 RSC
          *)
    PopSwapStack(SwapStackMarker, MakeRoomToLoad);


        (* Fix any changes to the status lights line.
        *)
    EnableLights(TRUE);


    RETURN ((st = Normal) AND (errorcode = Done));

END CallOverlayWithDialog;




    (*  CallOverlayWithContext
                -- Call the program indicated by the string "FileName".
                   (This is an L-string.)
                   Also pass a context address to the caller if he wishes it.
                   If all goes ok, return TRUE;
                   Otherwise, report the error on the screen, and
                   return FALSE.
    *)


PROCEDURE CallOverlayWithContext( VAR FileName : ARRAY OF CHAR;
                                      Context  : ADDRESS       ) : BOOLEAN;
BEGIN
    RETURN CallOverlayWithDialog( FileName, Context, DisplayTheError, NIL );
END CallOverlayWithContext;






    (*  CallOverlay  -- Call the program indicated by the string "FileName".
                        (This is an L-string.)
                        If all goes ok, return TRUE;
                        Otherwise, report the error on the screen, and
                        return FALSE.
    *)


PROCEDURE CallOverlay( VAR FileName : ARRAY OF CHAR ) : BOOLEAN;

BEGIN
    RETURN CallOverlayWithDialog( FileName, NIL, DisplayTheError, NIL );
END CallOverlay;



    (*  OverlayPackage -- Call the series of programs indicated by the
                          Package LString.  Its format is

                          NAME[(params)] ....

                          as in

                          "TLPUTIT(xyz) TLFBASE(TLXFORM) TLXPORTS"

                          Processing continues from left to right until the
                          entire package has been processed, or until there
                          is an error.

                          The items in parens are REQUIRED for overlays
                          except for the last overlay on the line.

                          Besides overlays, you can specify

                            @MenuName           Calls the menu with that name
                            #Message number     Calls DisplayMessage with that #.

                          Neither of these parameters get parameters in parens.
                          
                          RETURN is TRUE iff all overlays completed.

                          ERROR communication is handled by "PackageOK",
                                a BOOLEAN exported from Overlays.Def.
                                Client overlays SET this flag if they have
                                an error.

                                A Side effect of this procedure is that it
                                RESETS "PackageOK" to TRUE when it starts.
    *)
PROCEDURE XOverlayPackage( VAR Package : ARRAY OF CHAR ) : BOOLEAN;
VAR
    i           : CARDINAL;
    CallThis    : ARRAY [0..11]  OF CHAR;
    WithThis    : ARRAY [0..100] OF CHAR;
    OverlayOK   : BOOLEAN;
BEGIN

    PackageOK := TRUE;
    i         := 1;

    WHILE (i <= LengthOf(Package)) AND (PackageOK) DO
        ParseString( Package, i, CallThis );
        IF (LengthOf( CallThis ) > 0) THEN
            IF (CallThis[1] = SpecialCharDoMenu) THEN
                Remove( CallThis, 1, 1 );

                OverlayOK := (SelectAndRunMenu( CallThis, CallThis ) <> CancelKey);

            ELSE
                ParseString( Package, i, WithThis );
                OverlayOK := CallOverlayWithContext( CallThis, ADR( WithThis ) );
            END;
            PackageOK := (PackageOK AND OverlayOK);
        END;
    END;

    RETURN PackageOK;

END XOverlayPackage;


 


    (* ------------------------------------------------------------

       ImAnInstallableOverlay -

       This procedure is called from an overlay in its main body to
       identify it as a 'resident' overlay.  The overlay will remain
       resident as long as it can, until this module decides to remove
       it.  MainProcedure is the main procedure to call in the overlay
       on second and subsequent requests for the overlay.  NIL is
       acceptable.  DeInstallProc is a proc called just before the
       overlay is unloaded.  NIL is acceptable.  The RETURN value
       of AnOverlayID is used by EnteringOverlay and ExitingOverlay, below.

       Please note that procedure vectors stolen with InstallNewProcedure
       or InstallNewProcedureWithUnset should not be put back in the
       DeInstallProc, but in the way they would normally be put back.
       This allows the cleanup of the vector stack.

       Implementation note:

                AnOverlayID is REALLY AContextListEntry, and, when
                returned to the caller, points to the caller's entry
                in the list.
    --------------------------------------------------------------- *)

PROCEDURE ImAnInstallableOverlay( LMainProcedure : AnOverlayProc;
                                  LDeInstallProc : AnOverlayProc
                                ) : AnOverlayID;
BEGIN
    IF (CurrentOverlayContext = NIL) THEN
        FatalError();  (* Not in an overlay? *)
    END;

    WITH CurrentOverlayContext^ DO
        WantsResidence := TRUE;
        MainProcedure  := LMainProcedure;
        DeInstallProc  := LDeInstallProc;
    END;

    RETURN CurrentOverlayContext;

END ImAnInstallableOverlay;





    (* ------------------------------------------------------------

       ImALockedOverlay -

       This procedure is called from an overlay in its main body to
       identify it as a 'locked' overlay.  The overlay will remain
       resident as long as Time Line is running.

       DeInstallProc is a proc called just before the
       overlay is unloaded.  NIL is acceptable.  The RETURN value
       of AnOverlayID is used by EnteringOverlay and ExitingOverlay, below.

       Please note that procedure vectors stolen with InstallNewProcedure
       or InstallNewProcedureWithUnset should not be put back in the
       DeInstallProc, but in the way they would normally be put back.
       This allows the cleanup of the vector stack.

    --------------------------------------------------------------- *)

PROCEDURE ImALockedOverlay( LMainProcedure : AnOverlayProc;
                            LDeInstallProc : AnOverlayProc ) : AnOverlayID;
BEGIN
    IF (CurrentOverlayContext = NIL) THEN
        FatalError();  (* Not in an overlay? *)
    END;

    WITH CurrentOverlayContext^ DO
        IsLocked       := TRUE;
        MainProcedure  := LMainProcedure;
        DeInstallProc  := LDeInstallProc;
        IF (LoadOption <> LoadOffHeap) THEN
            FatalError();
        END;
    END;

    RETURN CurrentOverlayContext;

END ImALockedOverlay;




    (* ------------------------------------------------------------

      UnlockOverlay -

        Given an overlay ID, change the status of the overlay from
        "locked" to "resident", so that it could be removed if need
        be.

    --------------------------------------------------------------- *)

PROCEDURE UnlockOverlay( ID : AnOverlayID );
BEGIN
    IF (ID = NIL) THEN
        FatalError();  (* Not an overlay? *)
    END;

    WITH ID^ DO
        IF (IsLocked) THEN
            IsLocked       := FALSE;
            WantsResidence := TRUE;
        END;
    END;
END UnlockOverlay;



    (* ------------------------------------------------------------

      RemoveLockedOverlays -


        Remove ALL locked and resident overlays from memory.
        This should only be used at shutdown of Time Line.

        Alas, this snips off the term procs for any resident overlays.
        This should be concidered for overlays that MUST have
        their term procs run.

    --------------------------------------------------------------- *)

PROCEDURE RemoveLockedOverlays();
VAR
    Entry             : AContextListEntry;
    Node              : ATreeNode;
BEGIN
    Node := OverlayTree^.Methods^.GetFirst (OverlayTree);
    WHILE (Node <> NIL) DO
        Entry := Node^.Methods^.GetDataObject (Node);
        UnlockOverlay( Entry );
        IF (Entry^.Residence <> InMainMemory) THEN
            Entry^.TheOverlayPtr^.termProc := NIL; (* Snip off the term proc! *)
        END;
        Node  := Node^.Methods^.NextPreOrder (Node);
    END;
    KickOutResidents( LoadOffHeap,    NIL );
END RemoveLockedOverlays;






    (* ------------------------------------------------------------

       EnteringOverlay
       ExitingOverlay

       Tell this module that your stolen procedure is executing.

       When a stolen procedure is entered in your overlay, call
       'EnteringOverlay'.  When the procedure exits (for ANY reason),
       call 'ExitingOverlay'.  Resident overlays are only unloaded
       when their use count is 0, and these procedures manage that count.
       'MyID' is the ID returned by ImAnInstallableOverlay.

       For overlays that have not stolen procedure vectors, and so ALWAYS
       enter the overlay via calls to CallOverlay or CallOverlayWithContext,
       do not need to call these procedures.

    --------------------------------------------------------------- *)

PROCEDURE EnteringOverlay( MyID : AnOverlayID );
BEGIN
    (*$R+*)
    (*$T+*)
    INC( MyID^.UseCount ); (* MyID could be nil or UseCount = 65535 *)
    (*$T=*)
    (*$R=*)
END EnteringOverlay;


PROCEDURE ExitingOverlay( MyID : AnOverlayID );
BEGIN
    (*$R+*)
    (*$T+*)
    DEC( MyID^.UseCount ); (* MyID could be nil or UseCount = 0 *)
    (*$T=*)
    (*$R=*)
END ExitingOverlay;





  (* Low Memory Receiver -

        Whenever a low memory notice is sent out,
          IF BeforeActing,
              count the number of K avail in resident unused overlays.
          ELSE
              free up any Heap-based resident overlays.
          END;
  *)
PROCEDURE LowMemoryReceiver( Occasion : AnOccasion;
                             Step     : AStep;
                             Context  : ADDRESS ) : BOOLEAN;
VAR
    Entry             : AContextListEntry;
    Node              : ATreeNode;
    ContextAsCardinal : POINTER TO CARDINAL;
    ParagraphsFound   : CARDINAL;

BEGIN

    IF (Step = BeforeActing) THEN
        ParagraphsFound   := 0;
        ContextAsCardinal := Context;

        Node := OverlayTree^.Methods^.GetFirst (OverlayTree);
        WHILE (Node <> NIL) DO
            Entry := Node^.Methods^.GetDataObject (Node);
            WITH Entry^ DO
                IF (LoadOption = LoadOffHeap) AND
                   (NOT IsLocked)             AND
                   (UseCount = 0)             THEN
                    INC( ParagraphsFound, OverlaySize );
                END;
            END;
            Node := Node^.Methods^.NextPreOrder (Node);
        END;
        ContextAsCardinal^ := (ParagraphsFound + KRound) DIV KPara;
    ELSE
        KickOutResidents( LoadOffHeap, Context ); (* FALSE = "Those on the heap" *)
    END;

    RETURN TRUE;

END LowMemoryReceiver;










(* Read in the layer index.  Return the size of those indexes,
   in PARAGRAPHS.
*)
PROCEDURE BuildLayerIndex( VAR MomSize, KidSize : CARDINAL );
VAR
    i       : CARDINAL;
    s       : ARRAY [0..255] OF CHAR;
    s1      : ARRAY [0..19]  OF CHAR;
    Found   : BOOLEAN;
BEGIN
    SetString( s, "DEBUG" );
    GetOption( s, Found, s );
    IF (Found) THEN
        MomSize := 0;
        KidSize := 0;
    ELSE
        GetMessage( ModuleNumber + 99, s );
        i       := 1;
        MomSize := StoC(s,i);
        INC(i);
        KidSize := StoC(s,i);
    END;

END BuildLayerIndex;







PROCEDURE InitializeOverlays();
VAR
    Item      : AContextListItem;
    MomSize,
    KidSize   : CARDINAL;
    OK        : BOOLEAN;
    s         : ARRAY [0..255] OF CHAR;
    Option    : ALoadOption;
BEGIN
    CurrentOverlayContext := NIL;
    SpaceInterlock        := FALSE;

    FOR Option := MIN(ALoadOption) TO MAX(ALoadOption) DO
        Layers[Option] := LayerId(NIL);
    END;

    BuildLayerIndex( MomSize, KidSize );

    IF (MomSize > 0) AND (KidSize > 0) THEN
        NewLayer( Layers[LoadInMomArea], MomSize+1, OK );
        IF (OK) THEN
            NewLayer( Layers[LoadInKidArea], KidSize+1, OK );
        END;
        IF (NOT OK) THEN
            GetMessage( ModuleNumber + 0, s ); (* "No room to start." *)
            Error(s);
            FatalError();
        END;
    END;

    InitOvTree();   (* RSC 1/5/89 *)

    WITH Item DO
        Context         := NIL;
        VectorListHead  := NIL;
        UseCount        := 1;   (* Always in use *)
        MainProcedure   := AnOverlayProc(NIL);
        DeInstallProc   := AnOverlayProc(NIL);
        LoadOption      := LoadOffHeap;
        WhichPathEntry  := 0;
        Residence       := InMainMemory;
        TheOverlayPtr   := OverlayPtr(NIL);
        OverlaySize     := 20000;  (* Silly number for now. *)
        WantsResidence  := TRUE;
        IsLocked        := TRUE;
        Residence       := InMainMemory;
        ResidentWhere.Residence := InMainMemory;
        SetString( OverlayName, "\TIMELINE" );
        SetString( CallChain,   "This space for rent." );
    END;
    AddToContextList( Item, CurrentOverlayContext );
    IF (CurrentOverlayContext = NIL) THEN
        FatalError();
    END;
        (* 1-Jul-91 RSC Make sure we are the current overlay.
        *)
    IF (overlayList^.overlayName[0] <> "T") OR
       (overlayList^.overlayName[1] <> "i") THEN
        HALT;
    END;
        (* Make our context list entry be referenced by the current
           overlay.  Do this AFTER the call to AddToContextList.
        *)
    WITH CurrentOverlayContext^ DO
        IF (TheOverlayPtr <> NIL) THEN                         (* 16-Jul-91 *)
            (*  Special case for Timeline.exe.  AddToContextList (above) has
                allocated a Logitech overlay structure and filled in important
                values.  These values must be transfered to overlayList, and
                the structure deallocated.
            *)
            overlayList^.dummy[1] := TheOverlayPtr^.dummy[1];
            overlayList^.dummy[2] := TheOverlayPtr^.dummy[2];
            DEALLOCATE( TheOverlayPtr, TSIZE(OverlayDescriptor) );
        END;
        TheOverlayPtr   := overlayList; (* 1-Jul-91 RSC  *)
    END;
    RootOverlayContext  := CurrentOverlayContext;  (* Always TimeLine's. *)

    (* Trap low memory notices so that we can free up space as needed.

        Do This LAST!!  This is because registering for notices calls
        routines in THIS MODULE, potentially needing the things we just
        initialized.
    *)
    RegisterForNotices( LowMemory, LowMemoryReceiver );

    SetString( TLCaptionsName, "TLCAPTIO" );

END InitializeOverlays;




BEGIN
    Registered     := FALSE;
    OverlayTree    := NIL;
    OverlayPackage := XOverlayPackage; (* Set this proc vector to its initial value *)
    OverlayLoadOptionListEntries := 0;
    SetLengthOf( TLCaptionsName, 0 );
END Overlays.
