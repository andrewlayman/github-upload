IMPLEMENTATION MODULE FontTLGS;
       
PROCEDURE GetASedonaFontNumber(FontFamily,FontMember : CARDINAL) : CARDINAL;

VAR
   font : CARDINAL;

BEGIN
    
    font:= HELVETICALIGHT; 
    CASE FontFamily OF
         HELVETICA :
            CASE FontMember OF
                 LIGHT  : font:= HELVETICALIGHT;
               | MEDIUM : font:= HELVETICAMEDIUM;
               | BOLD   : font:= HELVETICABOLD;
               | ITALIC : font:= HELVETICAITALIC;
             ELSE
             END;
       | TIMESROMAN :
            CASE FontMember OF
                 LIGHT  : font:= TIMESROMANLIGHT;
               | MEDIUM : font:= TIMESROMANMEDIUM;
               | BOLD   : font:= TIMESROMANBOLD;
               | ITALIC : font:= TIMESROMANITALIC;
             ELSE
             END;
       | SPECIAL :
             CASE FontMember OF
                  LIGHT  : font:= SPECIALLIGHT;
                | MEDIUM : font:= SPECIALMEDIUM;
                | BOLD   : font:= SPECIALBOLD;
                | ITALIC : font:= SPECIALITALIC;
             ELSE
             END;
    ELSE
    END;
    
    RETURN (font);
    
END GetASedonaFontNumber;


(*--------------------------------------------------------------------------*)
BEGIN                       (* FontTLGS *)

END FontTLGS.
