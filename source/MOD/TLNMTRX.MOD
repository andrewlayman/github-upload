(*$S+*)
MODULE TLNMTRX;

FROM MatrixPrint            IMPORT
    (* PROC *)                  PrintMatrix;
    
FROM TSEDData		    IMPORT		    (* 27-SEPTEMBER-1988 CMH *)
    (* VAR *)			BaseCharacterHeight,(* 16-MARCH-1989 CMH *) 
    			 	BaseCharacterWidth,
    			 	VerticalGap; (* 12-APRIL-1989 CMH *)    


BEGIN                           (* TLNMTRX *)
  
 (* TLGS variables used in NetUtility, 
    set them to something reasonable now,
    find a better way to do this later *)  

    BaseCharacterHeight:=  1;	(* 27-SEPTEMBER-1988 CMH *)
    BaseCharacterWidth:= 1;     (* 16-MARCH-1989 CMH *)
    VerticalGap:=0;		(* 12-APRIL-1989 CMH *)
    
    PrintMatrix();

END TLNMTRX.
