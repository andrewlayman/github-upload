IMPLEMENTATION MODULE MacLights;

(*--------------------------------------------------------------------------

            (c) Copyright 1988 Lawrence V. Koepke & Cybersoft
                           All Rights Reserved  
            Developed with LOGITECH MODULA-2/86, version 3.03 
                  Many thanks to Breakthrough Software

    MODIFICATION HISTORY:

        26-Oct-89 RSC  Set Lights to NIL so they can be tested against
                       NIL to see if they are on.  Bug # 1634.
        30-Nov-89 MWP  Added procedure DisplayMacLight.
---------------------------------------------------------------------------*)


FROM Kbio           IMPORT
                            avidmode;
 
FROM Lights         IMPORT
                            ALight,                     (*TYPE*)
                            InstallLight, DisplayLight,
                            ActiveLightRegion;
                     
FROM LStrings        IMPORT
                            SetString;                     



CONST
       MaxLightSize = 40;
       MinLightSize = 2;

(*------------------------------------------------------------------------

Puts light on screen.

-------------------------------------------------------------------------*)

PROCEDURE DoOurLight (VAR Light : ALight;
                          phrase : ARRAY OF CHAR);
                          
BEGIN
    IF (Light = ALight(NIL)) THEN   (* 26-Oct-89 RSC *)
        InstallLight (ActiveLightRegion, 1, MinLightSize, MaxLightSize, Light);
    END;                            (* 26-Oct-89 RSC *)
    DisplayLight (Light, phrase, videolights);
END DoOurLight;


    (*  DisplayMacLight

            Display a light on the screen with the indicated phrase
            using Attribute for the video display..

        Preconditions:
            Light should be initialized to ALight(NIL) initially before
            the first time this light is to be displayed. This allows
            us to test if the light is on/off and needs to be installed
            or not.

        Postconditions:
            None.

        Note:
            This routine is a virtual clone of DoOurLight with the exception
            that it allows the video attribute to be passed to it. It is 
            the intention that DoOurLight should be so parameterised in the
            near future. This proc is included for the sole purpose of allowing
            the input pause light to be displayed with a video mode of
            ' videowarning'.
    *)

PROCEDURE DisplayMacLight (VAR Light  : ALight;
                               phrase : ARRAY OF CHAR;
                           Attribute  : avidmode );
BEGIN

    IF (Light = ALight(NIL)) THEN
        InstallLight ( ActiveLightRegion, 1, MinLightSize, MaxLightSize, Light);
    END;

    DisplayLight ( Light, phrase, Attribute );

END DisplayMacLight;


BEGIN
  (* 26-Oct-89 RSC se we can test for this *)
    InputLight      := ALight(NIL);
    RecordLight     := ALight(NIL);
    PauseLight      := ALight(NIL);
    PlaybackLight   := ALight(NIL);
    StepModeLight   := ALight(NIL);

END MacLights.
