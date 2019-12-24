IMPLEMENTATION MODULE LongDuration;

(*  =========================================================================
    Last Edit : January 22, 1991 9:15PM by RSC
    Language  : Logitech Modula-2/86 Version 3

    Description:

        LongDurationToString



    MODIFICATION HISTORY:

    22-Jan-91 RSC First version from TimeFormat to get it out of the root.
     3-Apr-92 TGS Add parameter to LongDurationToString to help align.

    =========================================================================
*)



FROM LStrings           IMPORT
    (* PROC *)              TrimRear, LengthOf, SetLengthOf, ConcatS, Overlay;

FROM MsgFile            IMPORT
        (* PROCS *)        GetMessage;

FROM RealFormat         IMPORT
        (* VAR  *)         DefaultAmountFormat,
        (* PROC *)         FormatAsAmount;

FROM Timei              IMPORT
    (* TYPES *)            ADuration, ADurationUnit,
    (* PROCS *)            DurationToReal;

FROM Timeu              IMPORT
    (* VAR *)              FSMUPH;

FROM WorkHours          IMPORT
        (* PROCS *)        WorkHoursToRealTime;



CONST
    CaptionsModuleNumber    = 19100;  (* FROM CAPTIONS *)







PROCEDURE AppendDurationUnit(VAR String         : ARRAY OF CHAR;
                             Units          : ADurationUnit;
                             Plural         : BOOLEAN      );

VAR
    i                       : CARDINAL;
    s                       : ARRAY [0..81] OF CHAR;

BEGIN                       (* AppendDurationUnit *)

    ConcatS(String,"  "); (* RSC 1/23/89.  Also took away "+1" below *)
    i := 1;
    IF (Plural) THEN
        INC(i,10);
    END;
    GetMessage(CaptionsModuleNumber+i+ORD(Units), s);
    Overlay(String, s, LengthOf(String), LengthOf(s));            (* 25-Feb-88 LAA *)

END AppendDurationUnit;








(*----------------------------------------------------------------------------
    AdjustForAppropriateScale --

    Adjust the long duration and the scale so the duration will be within
    the range LowerLimit..UpperLimit, when converted into a string.

    Preconditions:
        The calendar must have been initialized.

    Postconditions:
        The duration and time scale will be adjusted so that the duration
        amount falls within the range LowerLimit to UpperLimit, exclusive.

    This is the REAL equivelent of "FindCorrectScale" from Timeu.

----------------------------------------------------------------------------*)


PROCEDURE AdjustForAppropriateScale(VAR WorkHours    : REAL;
                                    VAR DurationUnit     : ADurationUnit;
                                        LowerLimit   : REAL;
                                        UpperLimit   : REAL     );
VAR
    Quantity                : REAL;

BEGIN                       (* AdjustForAppropriateScale *)

   (* Make the number fit. *)

    LOOP
        Quantity := WorkHoursToRealTime(WorkHours, DurationUnit );
        IF (DurationUnit = Minutes)  OR  (ABS(Quantity) > LowerLimit)  THEN
            EXIT;
        END;
        DEC(DurationUnit);
    END;
    LOOP
        IF (DurationUnit = Years)  OR  (ABS(Quantity) < UpperLimit)  THEN
            EXIT;
        END;
        INC(DurationUnit);
        Quantity := WorkHoursToRealTime(WorkHours, DurationUnit );
    END;

    WorkHours := Quantity;

END AdjustForAppropriateScale;




   (* LongDurationToString  -  Convert a REAL number into a printable string.

          Preconditions  - WorkHours is a REAL number which can be huge.
                           It is a number of Man Hours.

                           SuggestedDurationUnit is the desired minimum time unit.
                           If it seems appropriate, I may scale this up.

                           MinDecimalPlaces is the minimum number of decimal
                           places to include.  It may be zero.

                           MaxDecimalPlaces is the maximum number of decimal
                           places to include.  It may be zero.

                           MaxLength is the maximum length to fill the string
                           with.  This allows FormValues, which are 80 bytes,
                           to be filled in for, say, 25 bytes.

          Postconditions - The string "s" is filled in up to MaxLength.
                           Internally, the string may be filled a little
                           longer than MaxLength (say, around 10 bytes).

                           SuggestedDurationUnit may have been changed to reflect
                                         a better fit into the number scales.
    *)

PROCEDURE LongDurationToString( WorkHours         : REAL;
                            VAR SuggestedDurationUnit : ADurationUnit;
                                MinDecimalPlaces,
                                MaxDecimalPlaces  : CARDINAL;
                                MaxLength         : CARDINAL;
                            VAR s                 : ARRAY OF CHAR;
                            VAR EndOfNumber       : CARDINAL);
VAR
    MinSize  : REAL;
BEGIN

  (* Make the number fit. *)

    IF (MaxDecimalPlaces = 0) THEN
        MinSize := 1.0;
    ELSE
        MinSize := 0.1;
    END;

    AdjustForAppropriateScale(WorkHours, SuggestedDurationUnit, MinSize, 10000.0);

    FormatAsAmount( WorkHours, DefaultAmountFormat, s, HIGH(s)-1,
                    MinDecimalPlaces, MaxDecimalPlaces, FALSE );

    TrimRear(s);
    EndOfNumber := LengthOf(s);

    IF (EndOfNumber > MaxLength) THEN       (* 10/30/89 EGK *)
        SetLengthOf(s, MaxLength);
        EndOfNumber := MaxLength;
    END;

    IF (WorkHours <> 0.0) THEN           (* 2/27/89 EGK *)
        AppendDurationUnit(s, SuggestedDurationUnit, WorkHours <> 1.0);
    END;

    IF (LengthOf(s) > MaxLength) THEN
        SetLengthOf(s, MaxLength);
    END;

END LongDurationToString;






    (*  NameScale -- Given a duration and a unit of measure, return
                     a printable description of the duration.

                     RSC 1/23/89 converted to this more compact form.
    *)
PROCEDURE NameScale(    N        : ADuration;
                        DurationUnit : ADurationUnit;
                    VAR S        : ARRAY OF CHAR );
VAR
    i : CARDINAL;
BEGIN
    LongDurationToString( DurationToReal(N) / FSMUPH,
                          DurationUnit,
                          0, 0,
                          HIGH(S), S, i );
END NameScale;






END LongDuration.



