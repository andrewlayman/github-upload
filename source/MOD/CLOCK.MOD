    (*V1=OS2 OS2 code changes.	  *)
    (*V2=DOS Regular DOS TL code. *)

IMPLEMENTATION MODULE Clock;

    (*  MODIFICATION HISTORY
        16-Dec-87 LAA  -Created local variables for use by SETREG and GETREG.
                        This is required by the Logitech compiler, ver. 3.0.
         1-Mar-88 AJL  -Changed the Delay procedure to take into account that
                        the clocks on some computers skip several ticks
                        between counts.
         7-Aug-89 WKH  -Initial OS/2 edits.
        19-Apr-90 KKC  -Grouped year, month, day, hour, minute into the
                        date structure, SystemTime.
                       -Removed date structure Trick.
                       -Support seconds in System time.
         7-Aug-91 EGK  -Switched order of two statements in SetDateAndTime.
                        The compiler was clobbering our registers in order
                        to do its own optimization.  (See Eve bug #4902.)
    *)

(*<DOS*)
FROM SYSTEM     IMPORT WORD, BYTE, TSIZE, SIZE, ADR, GETREG, SETREG,
                       SWI, DOSCALL, AX, CX, DX;
(*DOS>*)

(*<OS2
FROM SYSTEM                 IMPORT
                                BYTE, ADR, ADDRESS;

FROM Misc                   IMPORT
                                DosGetDateTime,
                                DosSetDateTime,
                                DateTime;

OS2>*)

    (*  Set the current date and time.  Sets the system clock. *)
    (*   This routine is written for MS-DOS.                   *)

(*<DOS*)
PROCEDURE SetDateAndTime( VAR SystemTime : ASystemTime );
CONST
    SetDate = 02B00H;
    SetTime = 02D00H;
    DOSInterrupt = 21H;

VAR
    PrivateYear             : CARDINAL;
    PrivateMonth            : CARDINAL;
    PrivateHour             : CARDINAL;
    PrivateSecond           : CARDINAL;

BEGIN
    WITH SystemTime DO
        PrivateHour := (SysHour * 100H) + SysMinute;
        PrivateSecond := (SysSecond * 100H);
        SETREG(CX,PrivateHour);
        SETREG(DX,PrivateSecond);
        SETREG(AX,SetTime);
        SWI(DOSInterrupt);

        PrivateMonth := ((SysMonth+1) * 100H) + SysDay;
        PrivateYear := SysYear;
        SETREG(DX,PrivateMonth);
        SETREG(CX, PrivateYear);
        SETREG(AX,SetDate);
        SWI(DOSInterrupt);
    END;
END SetDateAndTime;
(*DOS>*)


(*<OS2

PROCEDURE SetDateAndTime( VAR SystemTime : ASystemTime );

VAR
    dateTime : DateTime;
    err      : CARDINAL;

BEGIN

    err := DosGetDateTime ( dateTime );
    dateTime.seconds := VAL( CHAR, SystemTime.SysSecond );
    dateTime.minutes := VAL( CHAR, SystemTime.SysMinute );
    dateTime.hours := VAL( CHAR, SystemTime.SysHour );
    dateTime.day := VAL( CHAR, SystemTime.SysDay );
    dateTime.month := VAL( CHAR, SystemTime.SysMonth + 1 );
    dateTime.year := SystemTime.SysYear;
    err := DosSetDateTime ( dateTime );

END SetDateAndTime;

OS2>*)



    (*  Return the current date and time *)

(*<DOS*)
PROCEDURE GetDateAndTime(VAR SystemTime : ASystemTime );
CONST
    GetDate = 02A00H;
    GetTime = 02C00H;
    DOSInterrupt = 21H;
VAR
    OldHour, OldMonth : CARDINAL;
    PrivateSecond           : CARDINAL;
    PrivateHour             : CARDINAL;
    PrivateMonth            : CARDINAL;
    PrivateYear             : CARDINAL;

BEGIN
    WITH SystemTime DO
        SysMonth := 0FFFFH;
        SysHour := 0FFFFH;
        REPEAT
            OldHour := SysHour;
            OldMonth := SysMonth;

            SETREG(AX,GetTime);
            SWI(DOSInterrupt);
            GETREG(CX,PrivateHour);                                   (* 16-Dec-87 LAA *)
            SysHour := PrivateHour;
            GETREG(DX,PrivateSecond);

            SETREG(AX,GetDate);
            SWI(DOSInterrupt);
            GETREG(DX,PrivateMonth);
            GETREG(CX,PrivateYear);
            SysMonth := PrivateMonth;
            SysYear  := PrivateYear;
        UNTIL (SysMonth = OldMonth) AND (SysHour = OldHour);

        SysSecond := PrivateSecond DIV 0FFH;
        SysMinute := CARDINAL( BITSET(SysHour) * BITSET(00FFH) );
        SysHour := SysHour DIV 0FFH;
        SysDay := CARDINAL( BITSET(SysMonth) * BITSET(00FFH) );
        SysMonth := (SysMonth DIV 0FFH) - 1;
    END;
END GetDateAndTime;
(*DOS>*)



(*<OS2
PROCEDURE GetDateAndTime(VAR SystemTime : ASystemTime );

VAR
    dateTime	    : DateTime;
    err             : CARDINAL;

BEGIN

    err := DosGetDateTime ( dateTime );
    SystemTime.SysSecond	:=  ORD( dateTime.seconds );
    SystemTime.SysMinute	:=  ORD( dateTime.minutes );
    SystemTime.SysHour	    :=  ORD( dateTime.hours );
    SystemTime.SysDay 	    :=  ORD( dateTime.day ) ;
    SystemTime.SysMonth	    :=  ORD(dateTime.month) - 1;
    SystemTime.SysYear      :=  dateTime.year;
END GetDateAndTime;

OS2>*)


(*<DOS*)
PROCEDURE Delay(Centiseconds:CARDINAL; EarlyExit : ATestProcedure );
CONST
    GetTime = 2CH;
VAR
    Ch : CHAR;
    HourMinute,SecondCentisecond, OldSecondCentisecond  : CARDINAL;
    i : CARDINAL;
    j : CARDINAL;
BEGIN
                (*  Delay  *)
    DOSCALL(GetTime,HourMinute,OldSecondCentisecond);
    OldSecondCentisecond := OldSecondCentisecond MOD 100H;
    WHILE (Centiseconds > 0) AND (NOT EarlyExit()) DO
        REPEAT
            DOSCALL(GetTime,HourMinute,SecondCentisecond);
            SecondCentisecond := SecondCentisecond MOD 100H;
        UNTIL (SecondCentisecond <> OldSecondCentisecond);
        j := (100 + SecondCentisecond - OldSecondCentisecond) MOD 100;
        IF (j < Centiseconds) THEN 
            DEC(Centiseconds,j);
        ELSE
            Centiseconds := 0;
        END;
        OldSecondCentisecond := SecondCentisecond;
    END;
END Delay;
(*DOS>*)



(*<OS2
PROCEDURE Delay(Centiseconds:CARDINAL; EarlyExit : ATestProcedure );

VAR
    Ch                      : CHAR;
    HourMinute,
    SecondCentisecond, 
    OldSecondCentisecond	: CARDINAL;
    i                       : CARDINAL;
    j                       : CARDINAL;
    dateTime                : DateTime;
    err                     : CARDINAL;

BEGIN
		(*  Delay  *)

    err := DosGetDateTime ( dateTime );

    trick.Card	         := 0;
    trick.AByte          := dateTime.hundredths;
    OldSecondCentisecond := trick.Card;

    OldSecondCentisecond := OldSecondCentisecond MOD 100H;
    WHILE (Centiseconds > 0) AND (NOT EarlyExit()) DO
	    REPEAT
	        err := DosGetDateTime ( dateTime );

	        trick.Card	      := 0;
	        trick.AByte       := dateTime.hundredths;
	        SecondCentisecond := trick.Card;
	        SecondCentisecond := SecondCentisecond MOD 100H;
	    UNTIL (SecondCentisecond <> OldSecondCentisecond);

    	j := (100 + SecondCentisecond - OldSecondCentisecond) MOD 100;

	    IF (j < Centiseconds) THEN
	        DEC(Centiseconds,j);
	    ELSE
	        Centiseconds := 0;
	    END;

	    OldSecondCentisecond := SecondCentisecond;
    END;
END Delay;
OS2>*)


PROCEDURE NoEarlyExit():BOOLEAN;
BEGIN
    RETURN FALSE;
END NoEarlyExit;



END Clock.
