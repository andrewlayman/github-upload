(*----------------------------------------------------------------------------
    MODIFICATION HISTORY

    12/03/86 LAA    Fixed ShowLights so that the Break light would not
                    decrease in size when it's off.
                    Fixed ShowLights for the case where the last light fits
                    exactly on the screen, with no trailing blank seperator.
    07/03/87 AJL  - DisposeLight redisplays the region.
                  - Export ShowLights.
    07/10/87 AJL  - Remove import of Video and use of PutStringWithAttribute.
    02/24/88 AJL  - Check the program state before displaying installing the
                    initial light region.
    11/21/88 RSC  - In ShowLights, don't write to column 80, even if
                    the write count = 0.
   10-Jan-89 RSC    Changed Storage to Space    .
   13-Jun-89 WKH    Added MoveLightRegion routine to move a lights region
   15-Sep-89 RSC    Added calls to Available.  Allow failure gracefully.
                    Also, lights used to have the behavior that they could
                    grow, but never shrink.  Now they shrink back to MINSIZE.
   18-Dec-89 LAA    Added procedure QueryLightXY to return the coordinates of
                    a specific light (for mouse support).
   22-Dec-89 LAA    Added procedures to validate lights and light regions.
----------------------------------------------------------------------------*)

IMPLEMENTATION MODULE Lights;

FROM Dialog                 IMPORT
    (* PROC *)                  FatalError;

FROM Kbio                   IMPORT
    (* TYPE *)                  ascreenx, ascreeny, avidmode,
    (* CONST *)                 maxcol, maxrow,
    (* PROC *)                  PutString;

FROM LStrings               IMPORT
    (* PROC *)                  Fill, SubStr, TrimFront, Procustes;

FROM Paranoia               IMPORT
    (* TYPE *)                  AProgramState,
    (* VAR *)                   ProgramState;
    
FROM Rugs                   IMPORT
    (* TYPE *)                  ARug, GetRug, PutRug;

FROM Space                  IMPORT
    (* PROC *)                  Available, ALLOCATE, DEALLOCATE;

FROM SYSTEM                 IMPORT
    (* PROC *)                  ADR, TSIZE;




TYPE
    ALight                  = POINTER TO ALightRecord;

    ALightRegion            = POINTER TO ALightRegionRecord;
    
    ALightRecord            = RECORD
                                tag         : CHAR;
                                attribute   : avidmode;
                                value       : ARRAY [0..maxcol + 1] OF CHAR;
                                priority    : CARDINAL;
                                min         : CARDINAL;
                                max         : CARDINAL;
                                displaysize : CARDINAL;
                                region      : ALightRegion;
                                nextlight   : ALight;
                              END;

    ALightRegionRecord      = RECORD
                                tag         : CHAR;
                                RugTaken    : BOOLEAN;
                                ulx         : ascreenx;
                                uly         : ascreeny;
                                lrx         : ascreenx;
                                lry         : ascreeny;
                                rug         : ARug;
                                lightlist   : ALightRecord;
                                prevregion  : ALightRegion;
                              END;


CONST
    LightTag                = 22C;
    LightRegionTag          = 55C;

VAR
    LightsOn                : BOOLEAN;


PROCEDURE ValidateLight(     Light          : ALight );

BEGIN                       (* ValidateLight *)

    IF (Light^.tag <> LightTag) THEN
        FatalError();
    END;

END ValidateLight;


PROCEDURE ValidateLightRegion(     LightRegion : ALightRegion );

BEGIN                       (* ValidateLightRegion *)

    IF (LightRegion^.tag <> LightRegionTag) THEN
        FatalError();
    END;

END ValidateLightRegion;



(*----------------------------------------------------------------------------
    CreateLightRegion --
    
    Create a new light region at the specified screen coordinates.  Takes a
    rug of the current screen contents, and then erases the light region in
    preparation for new lights being installed and displayed.
----------------------------------------------------------------------------*)

PROCEDURE CreateLightRegion(    ULX         : ascreenx;
                                ULY         : ascreeny;
                                LRX         : ascreenx;
                                LRY         : ascreeny;
                            VAR LightRegion : ALightRegion);

VAR
    Y                       : ascreeny;
    s                       : ARRAY [0..maxcol + 1] OF CHAR;

BEGIN                       (* CreateLightRegion *)

    IF (Available(TSIZE(ALightRegionRecord))) THEN
        NEW(LightRegion);
        WITH LightRegion^ DO
            RugTaken := (ProgramState >= RootRunning) AND
                        GetRug(ULX, ULY, LRX, LRY, rug);
        
                (*  Save the screen coordinates of the rug  *)
            ulx := ULX;
            uly := ULY;
            lrx := LRX;
            lry := LRY;
        
            IF (ProgramState >= RootRunning) THEN
                    (*  Erase the light region of the screen  *)
                Fill(s, " ", LRX - ULX + 1);
                FOR Y := ULY TO LRY DO
                    PutString(s, ULX, Y, videonormal);
                END;
            END;

            lightlist.nextlight := ALight(NIL);
            lightlist.region := LightRegion;
            tag := LightRegionTag;
        
                (*  Maintain a stack of light regions  *)
            prevregion := ActiveLightRegion;
        END;
        ActiveLightRegion := LightRegion;
    ELSE
        LightRegion := NIL;
    END;
    
END CreateLightRegion;                                    










(*----------------------------------------------------------------------------
    DisposeLightRegion --
    
    Release the specified light region, and restore the previous screen 
    contents of the space this screen had occupied.
----------------------------------------------------------------------------*)

PROCEDURE DisposeLightRegion(VAR LightRegion : ALightRegion);

BEGIN                       (* DisposeLightRegion *)

    IF (LightRegion <> NIL) THEN
        WITH LightRegion^ DO
            IF (tag <> LightRegionTag) OR
               (lightlist.nextlight <> ALight(NIL)) THEN
                FatalError();
            END;
            ActiveLightRegion := prevregion;
            IF (RugTaken) THEN
                PutRug(ulx, uly, lrx, lry, rug);
            END;
            tag := 0C;
        END;
        DISPOSE(LightRegion);
    END;
    
END DisposeLightRegion;





(*----------------------------------------------------------------------------
    LightBefore --
    
    Find the Light record which should be before this one, i.e. whose priority
    is greater than this light.  Lower numbers indicate higher priority.
----------------------------------------------------------------------------*)

PROCEDURE LightBefore(    LightRegion       : ALightRegion;
                          Light             : ALight)
                                                     : ALight;

VAR
    Predecessor             : ALight;
    
BEGIN                       (* LightBefore *)

    Predecessor := ADR(LightRegion^.lightlist);
    LOOP
        WITH Predecessor^ DO
            IF (nextlight = ALight(NIL)) OR
               (nextlight^.priority >= Light^.priority) THEN
    EXIT;
            END;
            Predecessor := nextlight;
        END;
    END;
    
    RETURN Predecessor;
    
END LightBefore;







(*----------------------------------------------------------------------------
    InstallLight --
    
    Install a light of the specified priority (determining display position)
    in the given light region.  A handle is returned by which this light is
    refered to.  The minsize determines initial display size, the maxsize
    indicates where to truncate a displayed value, rather than expand the
    size of the light.  Allocation of the light is done here.  Return FALSE
    if a light couldn't be allocated.
----------------------------------------------------------------------------*)

PROCEDURE InstallLight(    LightRegion      : ALightRegion;
                           Priority         : CARDINAL;
                           MinSize          : CARDINAL;
                           MaxSize          : CARDINAL;
                       VAR Light            : ALight);

VAR
    Predecessor             : ALight;
          
BEGIN                       (* InstallLight *)
    Light := NIL;

    IF (LightRegion <> NIL) THEN
        WITH LightRegion^ DO
            ValidateLightRegion( LightRegion );
        
            IF (Available(TSIZE(ALightRecord))) THEN
                NEW(Light);
                WITH Light^ DO
                    tag := LightTag;
                    min := MinSize;
                    max := MaxSize;
                    priority := Priority;
                    Fill(value, " ", min);
                    attribute := videonormal;
                    displaysize := 0;
                
                        (*  Link this light in priority order into the region  *)
                    Predecessor := LightBefore(LightRegion, Light);
                    nextlight := Predecessor^.nextlight;
                    Predecessor^.nextlight := Light;

                        (*  This light must point to it's region  *)
                    region := LightRegion;
                END;
            END;
        END;
    END;
        
END InstallLight;





(*----------------------------------------------------------------------------
    RemoveLight --
    
    Remove the light from the specified light region, and release it's 
    storage.                  
----------------------------------------------------------------------------*)

PROCEDURE RemoveLight(VAR Light             : ALight);

VAR
    Predecessor             : ALight;
    
BEGIN                       (* RemoveLight *)

    IF (Light <> NIL) THEN
        WITH Light^ DO
            ValidateLight( Light );
        
                (*  Remove the light from the linked list  *)
            Predecessor := ADR(region^.lightlist);
            WHILE (Predecessor^.nextlight <> ALight(NIL)) AND 
                  (Predecessor^.nextlight <> Light) DO
                Predecessor := Predecessor^.nextlight;
            END;

            IF Predecessor^.nextlight = Light THEN
                Predecessor^.nextlight := Light^.nextlight;
            END;

            ShowLights(region);    (* Redisplay owning region. *)

            Light^.tag := 0C;
            DISPOSE(Light);

        END;    
    END;    
        
END RemoveLight;





(*----------------------------------------------------------------------------
    ShowLights --
    
    Display the light region specified in its screen coordinates.
----------------------------------------------------------------------------*)

PROCEDURE ShowLights(    LightRegion        : ALightRegion);

VAR
    Remaining               : CARDINAL;
    Size                    : CARDINAL;
    X                       : ascreenx;
    i                       : CARDINAL;
    Light                   : ALight;
    s                       : ARRAY [0..maxcol + 1] OF CHAR;

BEGIN                       (* ShowLights *)
    IF (LightRegion = NIL) THEN
        RETURN;
    END;

    WITH LightRegion^ DO
        Remaining := lrx - ulx + 1;
        Light := lightlist.nextlight;
        X := ulx;
    END;
    
    LOOP
        IF Light = ALight(NIL) THEN
    EXIT;
        END;
            
        WITH Light^ DO
            Size := ORD(value[0]);
            i :=min;

 (* *** RSC 15-Sep-89 *****
            IF displaysize > i THEN
                i := displaysize;
            END;
  *** *)

            IF Size >= i THEN
                i := Size;
            END;
            IF i > Remaining THEN
    EXIT;
            END;

            DEC(Remaining, i);
            PutString(value, X, LightRegion^.uly, attribute);
            INC(X, Size);
            IF Size < i THEN
                Fill(s, " ", i - Size);
                PutString(s, X, LightRegion^.uly, videonormal);
                INC(X, ORD(s[0]));
            END;
            Fill(s, " ", 1);
            IF X <= maxcol THEN
                PutString(s, X, LightRegion^.uly, videonormal);
                INC(X);
                DEC(Remaining);
            END;
            displaysize := i;
        END;
        Light := Light^.nextlight;
    END;

    IF (Remaining > 0) THEN     (* RSC 11/22/88 *)
        Fill(s, " ", Remaining);
        PutString(s, X, LightRegion^.uly, videonormal);
    END;

END ShowLights;





(*----------------------------------------------------------------------------
    DisplayLight --
    
    Give the light a new value, and cause it to be displayed on the screen if
    it has sufficiently high priority, relative to other lights.  If it isn't 
    displayed, it value is still retained, and could be displayed at a later
    time.
----------------------------------------------------------------------------*)

PROCEDURE DisplayLight(    Light            : ALight;
                       VAR Value            : ARRAY OF CHAR;
                           Attribute        : avidmode);

BEGIN                       (* DisplayLight *)

    IF (Light <> NIL) THEN
        WITH Light^ DO
            ValidateLight( Light );
        
                (*  Store the new value, and size it if necessary  *)
            SubStr(Value, value, 1, HIGH(value));
            TrimFront(value);
            IF ORD(value[0]) > max THEN
                Procustes(value, max);
            END;
            attribute := Attribute;
        
            IF (region = ActiveLightRegion) AND (LightsOn) THEN
                ShowLights(ActiveLightRegion);
            END;
        END;
    END;
        
END DisplayLight;





(*----------------------------------------------------------------------------
    EnableLights --

    Turn on (if TRUE) the currently active light region, or turn it off in
    the On parameter is FALSE.
----------------------------------------------------------------------------*)

PROCEDURE EnableLights(    On               : BOOLEAN);

BEGIN                       (* EnableLights *)

    LightsOn := On;

END EnableLights;






(*----------------------------------------------------------------------------
    MoveLightRegion --
    
    Move an existing light region to the specified screen coordinates. 
----------------------------------------------------------------------------*)

PROCEDURE MoveLightRegion(    ULX         : ascreenx;
                              ULY         : ascreeny;
                              LRX         : ascreenx;
                              LRY         : ascreeny;
                          VAR LightRegion : ALightRegion);
BEGIN
    IF (LightRegion <> NIL) THEN
        WITH LightRegion^ DO
            IF RugTaken THEN
                PutRug(ulx, uly, lrx, lry, rug);
            END;
            RugTaken := (ProgramState >= RootRunning) AND GetRug(ULX, ULY, LRX, LRY, rug);
            ulx := ULX;
            uly := ULY;
            lrx := LRX;
            lry := LRY;
        END;
    END;
END MoveLightRegion;



(*  QueryLightXY --
        Determine the four coordinate values for a specific light.  Returns
        FALSE if the light does not exist in the specified light region.
    Preconditions:
        The region for this light must have been created and not yet disposed.
    Postconditions:
        XY coordinates of the light are returned.
*)

PROCEDURE QueryLightXY(     Light           : ALight;
                        VAR Ulx             : ascreenx;
                        VAR Uly             : ascreeny;
                        VAR Lrx             : ascreenx;
                        VAR Lry             : ascreeny ): BOOLEAN;

VAR
    LightRegion             : ALightRegion;
    TLight                  : ALight;

BEGIN                       (* QueryLightXY *)

    IF (Light <> NIL) THEN
        ValidateLight( Light );
        LightRegion := Light^.region;
        ValidateLightRegion( LightRegion );
        TLight := LightRegion^.lightlist.nextlight;
        Uly := LightRegion^.uly;
        Lry := LightRegion^.lry;
        Ulx := LightRegion^.ulx;
        LOOP
            IF (TLight = NIL) THEN
                EXIT;
            END;
            Lrx := Ulx + TLight^.displaysize;
            IF (Light = TLight) THEN
                RETURN TRUE;
            END;
            Ulx := Lrx + 1;
            TLight := TLight^.nextlight;
        END;
    END;

    RETURN FALSE;

END QueryLightXY;



BEGIN                       (* Lights *)
    ActiveLightRegion := ALightRegion(NIL);
    CreateLightRegion(0, maxrow, maxcol, maxrow, ActiveLightRegion);
    EnableLights(FALSE);
END Lights.
