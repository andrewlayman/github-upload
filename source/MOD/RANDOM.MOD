(*$R-T-F-*)
IMPLEMENTATION MODULE Random;
(******************************************************************************)
(*                                                                            *)
(*       MODULA-2    Library                                                  *)
(*                                                                            *)
(*              LOGITECH SA,   CH-1111 Romanel    (Switzerland)               *)
(*              LOGITECH Inc,  Fremont, CA 94555  (USA)                       *)
(*                                                                            *)
(*       Module  :    Random, random number generator                         *)
(*
         Andrew Layman  SYMANTEC Oct 26, 1988

         Based on essay by Pierre L'Ecuyer,
         Efficient and Portable Combined Random Number Generators
         CACM June 1988
*)

(******************************************************************************)


  FROM Calendar IMPORT 
    Date, GetMachineDate;


  VAR 
      s1, s2, s3 : INTEGER;


  PROCEDURE Uniform () : REAL;
  VAR
      Z, k : INTEGER;
  BEGIN
      k := s1 DIV 206;
      s1 := 157 * ( s1 - k * 206 ) - k * 21;
      IF (s1 < 0) THEN INC(s1,32363);  END;

      k := s2 DIV 217;
      s2 := 146 * ( s2 - k * 217 ) - k * 45;
      IF (s2 < 0) THEN INC(s2,31727);  END;

      k := s3 DIV 222;
      s3 := 142 * ( s3 - k * 222 ) - k * 133;
      IF (s3 < 0) THEN INC(s3,31657);  END;

      Z := s1 - s2;
      IF (Z > 706) THEN DEC(Z,32362); END;
      INC(Z,s3);
      IF (Z < 1) THEN INC(Z,32362); END;

      RETURN FLOAT(Z) * 0.000030899;
  END Uniform;



  PROCEDURE RandomInit (seed : CARDINAL);
    BEGIN
          (* Any mechanical formula based on the seed would be no more
             random than simple reuse of the seed.  I have not analyzed 
             whether using the same seed for all three components of
             the number generator produces a degredation of randomness.
             I suspect that it does not.    AJL   *)      
      s1 := seed;
      s2 := seed;
      s3 := seed;
    END RandomInit;



  PROCEDURE RandomCard (bound : CARDINAL): CARDINAL;
    VAR 
        R : REAL;
    BEGIN
      R := Uniform();
      IF bound = 0 THEN
          RETURN TRUNC(R * 65536.0);
      ELSE
          RETURN TRUNC (FLOAT(bound) * R); 
      END;
    END RandomCard;




  PROCEDURE RandomInt (bound : INTEGER): INTEGER;
  BEGIN
      RETURN INTEGER (RandomCard (CARDINAL (ABS (bound))));
  END RandomInt;



  PROCEDURE RandomReal () : REAL;
  BEGIN
          (* I am suspicious of the validity of generating more apparrent
             digits of precision than the Uniform() procedure actually
             produces, but I have done this for general compatibility with
             Logitech's module.    AJL    *)
  
      RETURN Uniform() * 1.0E-13 +
             Uniform() * 1.0E-9 +
             Uniform() * 1.0E-5 +
             Uniform() * 1.0E-1;
  END RandomReal;





  PROCEDURE Randomize;
    VAR
      t    : Date;
      i, j : CARDINAL;
      dummy: CARDINAL;
    BEGIN
        GetMachineDate (t);
        RandomInit (t.thousandth);
    END Randomize;



BEGIN
    Randomize;
END Random.
