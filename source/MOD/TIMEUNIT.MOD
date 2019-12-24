IMPLEMENTATION MODULE TimeUnitsTLGS;

   (*
    Modification History:
         5-Sep-89 CMH   Moved UnitsForScaling, CharactersForScaling,
                        UnitsForGrouping and MilitaryTime to 
                        TimeUnitsTLGS.DEF from TSEDTimescale.DEF so 
                        TLNBUILD would not import from TSEDTimescale 
                        since it has 1.6k bytes of data.
    *)   
                      
FROM LStrings               IMPORT
    (* PROC *)                  LengthOf;
    
FROM TimeFormat             IMPORT
    (* TYPE *)                  ATimeFormat,
                                DefaultDateAndTimeFormat;

(*--------------------------------------------------------------------------*)
        (*  
            Get time format, standard or military 
            
         *)
         
PROCEDURE MilitaryTime(VAR TimeFormat : ATimeFormat) : BOOLEAN;

VAR
    Military                : BOOLEAN;

BEGIN

    IF (LengthOf(TimeFormat[4].FollowBy) > 0) THEN
        Military := FALSE;
    ELSE
        Military := TRUE;
    END;

    RETURN Military;
    
END MilitaryTime;


(*--------------------------------------------------------------------------*)
BEGIN                       (* TimeUnitsTLGS *)
END TimeUnitsTLGS.
