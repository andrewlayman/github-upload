(*$S+*)
MODULE TLNSHOW;

    (* MODIFICATION HISTORY:

     10-Aug-89  KKC - Add copyright message.
    
    *)

FROM Layout                 IMPORT 
    (* VAR *)			GanttWStart;

FROM NetDraw                IMPORT
    (* PROC *)                  NetDrawMain;
    
FROM TSEDData		    IMPORT		    (* 27-SEPTEMBER-1988 CMH *)
    (* VAR *)			BaseCharacterHeight,(* 16-MARCH-1989 CMH *) 
    			 	BaseCharacterWidth,
    			 	VerticalGap; (* 12-APRIL-1989 CMH *)    

CONST
    ModuleNumber            = 20300;  (* For GetMessage *)

VAR
    Copyright               : ARRAY[0..50] OF CHAR;
BEGIN                           (* TLNSHOW *)

    Copyright := "Program Copyright (c) 1989 Symantec Corporation.";
  
 (* TLGS variables used in NetUtility, 
    set them to something reasonable now,
    find a better way to do this later *)  

    BaseCharacterHeight:=  1;	(* 27-SEPTEMBER-1988 CMH *)
    BaseCharacterWidth:= 1;     (* 16-MARCH-1989 CMH *)
    VerticalGap:=0;		(* 12-APRIL-1989 CMH *)
    
    GanttWStart:= GanttWStart+1;
    NetDrawMain();
    GanttWStart:= GanttWStart-1;

END TLNSHOW.
