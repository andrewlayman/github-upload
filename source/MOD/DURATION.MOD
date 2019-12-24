IMPLEMENTATION MODULE Duration;

(* 
    MODIFICATION HISTORY

     8-Feb-91 TGS   FindDuration now returns 0 if "End" is before "Start".

*)

FROM CalShift               IMPORT
    (* TYPE  *)                 ATimeSheet;

FROM Timei                  IMPORT
    (* TYPE  *)                 ADate, ADuration;

PROCEDURE FindDuration( 
                        StartDate : ADate;
                          EndDate : ADate; 
                        TimeSheet : ATimeSheet
                      ) : ADuration;
BEGIN
    IF EndDate > StartDate THEN
        RETURN ( EndDate - StartDate );
    ELSE
        RETURN 0
    END;
END FindDuration;

PROCEDURE AddWorkingTime( 
                                Date : ADate; 
                            Duration : ADuration;
                           TimeSheet : ATimeSheet
                        ) : ADate;
BEGIN
    
    RETURN ( Date + Duration );
END AddWorkingTime;


PROCEDURE SubtractWorkingTime( 
                                   Date : ADate; 
                               Duration : ADuration; 
                              TimeSheet : ATimeSheet
                             ) : ADate;
BEGIN
    RETURN ( Date - Duration );
END SubtractWorkingTime;

END Duration.

