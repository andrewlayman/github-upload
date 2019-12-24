(*$S+*)
MODULE TLNPrint;

    (* MODIFICATION HISTORY:

     10-Aug-89  KKC - Add copyright message.
    
    *)

FROM NetPrint               IMPORT
    (* PROC *)                  PrintNetwork;

FROM TSEDData		    IMPORT		(* 27-SEPTEMBER-1988 CMH *)
    (* VAR *)			BaseCharacterHeight, (* 16-MARCH-1989 CMH *)
    			 	BaseCharacterWidth, 
    			 	VerticalGap; (* 12-APRIL-1989 CMH *)    

VAR
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN                           (* TLNPrint *)
    
    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
  
 (* TLGS variables used in NetUtility, 
    set them to something reasonable now,
    find a better way to do this later *)  

    BaseCharacterHeight:=  1;	(* 27-SEPTEMBER-1988 CMH *)
    BaseCharacterWidth:= 1;	(* 16-MARCH-1989 CMH *)
    VerticalGap:=0;		(* 12-APRIL-1989 CMH *)

    PrintNetwork();
      
END TLNPrint.
