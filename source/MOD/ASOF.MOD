IMPLEMENTATION MODULE AsOf;
(*----------------------------------------------------------------------------
MODIFICATION HISTORY:

    3/20/87   EGK - Added SetAsOfDate procedure.  Sets the As-of date value
                    according to the setting of the As-of setting option.
    30-Mar-90 RSC   Made Timeu to Timei/TimeForm conversions.

----------------------------------------------------------------------------*)

FROM Timei       IMPORT   FindToday, ADurationUnit, Today;

FROM TimeJump    IMPORT   FindStartDateOf;

FROM Dialog      IMPORT   FatalError; 



PROCEDURE SetAsOfDate();

BEGIN

    CASE AsOfSettingOption OF
        AsOfNow:         AsOfDate := FindToday();
      | AsOfToday:       AsOfDate := FindStartDateOf(FindToday(),Days);
      | AsOfStartOfWeek: AsOfDate := FindStartDateOf(FindToday(),Weeks);
      | AsOfWhenISay: ;         (* Schedule form handles this *)
      ELSE FatalError;
    END;

END SetAsOfDate;


BEGIN
    AsOfSettingOption := AsOfToday;
    AsOfDate := Today;
END AsOf.
