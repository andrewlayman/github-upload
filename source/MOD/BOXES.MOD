IMPLEMENTATION MODULE Boxes;

(*  MODIFICATION HISTORY:

    3/17/87     EGK - Modified DrawBox to handle shadowing.
                      Added GetOuterBoxSize and GetInnerBoxSize (see below).
    07/11/87    AJL - Modified the shadow boxes to use PutAttribute.
    02/22/88    AJL - Modified the shadow boxes to uses TransparentShadow.
     2/23/88    AJL - Changed the shadow character to 261C;
    12-Dec-89   AJL - Mouse support!
    14-Dec-89   AJL - Draw arrows only if output enabled.
    14-Dec-89   AJL - Draw shadows only if output enabled.
     2-Jan-90   AJL - Draw buttons and borders in new mouse attributes,
                      videonetstarted and videonetdone.
     8-Jan-90   AJL - Made the scroll buttons larger. 
    10-Jan-90   AJL - Corrected the correlation region for the down scroll button.
                    - Changed the scroll bar style.   
     4-Oct-90   AJL - Change the names of the mouse video attributes.
                    - When boxes have shadows, put the buttons below the box.
     6-Oct-90   AJL - Activate the Edit, Ins, Del, Menu and Help button
                      attributes.
                    - Allow buttons at left end of box.
    23-Jan-91   AJL - Correct placement of buttons indented from right.
     6-May-91   AJL - Box titles are always at the top of the box.
    17-Jun-91   AJL - Put the scroll bar over the box border, even if
                      there is a shadow.  See bug 4596.

*)

FROM Codes     IMPORT 
    (* TYPE *)       ACode;

FROM Correl    IMPORT
    (* TYPE *)       ACorrelationList, ARegionNumber,
    (* PROC *)       CreateCorrelationList, DisposeCorrelationList, 
                     SetRegion, CorrelatePoint; 

FROM GaGa      IMPORT
    (* PROC *)        GetGaGaMessage;

FROM Keys      IMPORT
    (* CONST *)       CancelKey, ExitKey, DeleteKey, InsertKey, EditKey, 
                      OnMenu, HelpKey;  

FROM Kbio      IMPORT 
    (* TYPE *)        ascreenx, ascreeny, avidmode, 
    (* VAR  *)        maxcol,
    (* PROC *)        PutString, PutAttribute;

FROM LStrings  IMPORT 
    (* PROC *)        Fill, SubStr, LengthOf, ConcatS, Remove, StoC;

FROM Words     IMPORT 
    (* PROC *)        ParseBal;


CONST
    ButtonsPhrase = 4;




(*----------------------------------------------------------------------------
DrawBox:

Puts a box on the screen at the given coordinates, which define the total screen
area used by the box, including borders and/or shadowing.

Returns a CorrelationList which must be disposed of by caller.

-----------------------------------------------------------------------------*)

PROCEDURE DrawBoxCorrelate(    OutputEnable : BOOLEAN;
                               ULX : ascreenx;
                               ULY : ascreeny;
                               LRX : ascreenx;
                               LRY : ascreeny;
                               BoxType : ABoxType;
                           VAR Title : ARRAY OF CHAR;
                               VidMode : avidmode;
                           VAR CorrelationList : ACorrelationList);

CONST
    HBar2      = 315C;
    VBar2      = 272C;
    ULC2       = 311C;
    URC2       = 273C;
    LLC2       = 310C;
    LRC2       = 274C;

    HBar1      = 304C;
    VBar1      = 263C;
    ULC1       = 332C;
    URC1       = 277C;
    LLC1       = 300C;
    LRC1       = 331C;

    Shading    = 261C;

VAR
    s  : ARRAY [0..121] OF CHAR;
    s2 : ARRAY [0..maxcol+1] OF CHAR;
    HBar,VBar,ULC,URC,LLC,LRC : CHAR;
    x     : ascreenx;
    xleft : ascreenx;
    y     : ascreeny;
    i,j,k : CARDINAL;
    Width : CARDINAL;
    CurrentWidth : CARDINAL;
    CurrentLRY   : ascreeny;
    BoxAttr      : ABoxAttribute;
BEGIN
    CorrelationList := CreateCorrelationList();

    IF (DoubleBox IN BoxType) THEN
        HBar := HBar2;
        VBar := VBar2;
        ULC  := ULC2;
        URC  := URC2;
        LLC  := LLC2;
        LRC  := LRC2;
    ELSIF (SingleBox IN BoxType) THEN
        HBar := HBar1;
        VBar := VBar1;
        ULC  := ULC1;
        URC  := URC1;
        LLC  := LLC1;
        LRC  := LRC1;
    ELSE
        HBar := " ";
        VBar := " ";
        ULC  := " ";
        URC  := " ";
        LLC  := " ";
        LRC  := " ";
    END;

    IF (ShadowBox IN BoxType) THEN
        LRX := LRX - 2;
        LRY := LRY - 1;
    END;

    Width := LRX-ULX+1;

    IF (GrowBox IN BoxType) THEN
        CurrentWidth := 2;
        CurrentLRY   := ULY + 1;
    ELSE
        CurrentWidth := Width;
        CurrentLRY   := LRY;
    END;

    LOOP
        Fill(s,HBar,CurrentWidth);
        s[1] := ULC;
        s[CurrentWidth] := URC;
        IF (OutputEnable) THEN 
            PutString(s,ULX,ULY,VidMode);
        END;

        IF (CurrentLRY > 0) THEN
            Fill(s," ",CurrentWidth);
            s[1] := VBar;
            s[CurrentWidth] := VBar;
            FOR y := ULY+1 TO CurrentLRY-1 DO
                IF (OutputEnable) THEN 
                    PutString(s,ULX,y,VidMode);
                END;
            END;

            Fill(s,HBar,CurrentWidth);
            s[1] := LLC;
            s[CurrentWidth] := LRC;
            IF (OutputEnable) THEN 
                PutString(s,ULX,CurrentLRY,VidMode);
            END;
        END;

        IF (CurrentWidth >= Width) AND (CurrentLRY >= LRY) THEN
            EXIT;
        END;

        IF (CurrentWidth < Width-1) THEN
            INC(CurrentWidth,2);
        END;
        IF (CurrentWidth < Width) THEN
            INC(CurrentWidth);
        END;
        IF (CurrentLRY < LRY) THEN
            INC(CurrentLRY);
        END;
    END; (* Loop  *)

        (* Draw the shadow. *)

    IF (ShadowBox IN BoxType) THEN
        IF (OutputEnable) THEN
            IF (TransparentShadow) THEN
                FOR y := ULY+1 TO LRY DO
                    PutAttribute(LRX+1,y,2,videoshadow);
                END;
                PutAttribute(ULX+2,LRY+1,CurrentWidth,videoshadow);
            ELSE 
                Fill(s,Shading,2);
                FOR y := ULY+1 TO LRY DO
                    PutString(s,LRX+1,y,VidMode);
                END;
                Fill(s,Shading,CurrentWidth);
                PutString(s,ULX+2,LRY+1,VidMode);
            END;
        END;
    END;


        (* Record the the border regions.   The order of setting these is
           important, since the last one defined overrides, sort-of, the
           earlier ones. *)
    SetRegion(CorrelationList,ORD(OnBorder),ULX,ULY,LRX,LRY);
    SetRegion(CorrelationList,ORD(OnInside),ULX+1,ULY+1,LRX-1,LRY-1);
    (*---------------------  Short, fat scroll buttons
    IF (HasVScroll IN BoxType) THEN
        Fill(s,30C,1);   (* Up arrow. *)
        IF (ShadowBox IN BoxType) THEN     (* Widen the scroll bar. *)
            ConcatS(s," ");
        END;
        j := ORD(s[0])-1;  (* Width of scroll-sensitive region. *)

        IF (OutputEnable) THEN 
            PutString(s,LRX,ULY+1,videoscrollbar);

            s[1] := 31C;     (* Down arrow. *)
            PutString(s,LRX,LRY-1,videoscrollbar);
            s[1] := " ";                            (* Make bars longer. *)
            PutString(s,LRX,ULY+2,videoscrollbar);
            PutString(s,LRX,ULY+3,videoscrollbar);
            PutString(s,LRX,LRY-2,videoscrollbar);
            PutString(s,LRX,LRY-3,videoscrollbar);
        END;
        
            (* Set the mouse-sensitive areas. *)
        SetRegion(CorrelationList,ORD(OnVScrollUp),LRX,ULY+1,LRX+j,ULY+3);
        SetRegion(CorrelationList,ORD(OnVScrollDown),LRX,LRY-3,LRX+j,LRY-1);
    END;
    ------------------------*)

    
    IF (HasVScroll IN BoxType) THEN
        x := LRX;
        i := ((LRY-ULY) DIV 2)-1;             (* Length of each scroll item. *)
        IF (OutputEnable) THEN 
            Fill(s," ",1);
            FOR k := ULY+2 TO LRY-2 DO
                PutString(s,x,k,videoscrollbar);
            END;
            Fill(s,30C,1);   (* Up arrow. *)
            PutString(s,x,ULY+1,videoscrollbar);
            s[1] := 31C;     (* Down arrow. *)
            PutString(s,x,LRY-1,videoscrollbar);
            s[1] := HBar1;   (* Horizontal tick. *)
            PutString(s,x,ULY+i+1,videoscrollbar);
        END;

        
            (* Set the mouse-sensitive areas. *)
        IF (ShadowBox IN BoxType) THEN             (* spill over width. *)
            j := 1;
        ELSE
            j := 0;
        END;                                  
        SetRegion(CorrelationList,ORD(OnVScrollUp),LRX,ULY+1,LRX+j,ULY+i);
        SetRegion(CorrelationList,ORD(OnVScrollDown),LRX,ULY+i+2,LRX+j,LRY-1);
    END;

    (* -- Currently unused
    IF (HasHScroll IN BoxType) THEN
    END;
    *) 



        (* Draw the title. *)
    IF NOT(NoBox IN BoxType) THEN
            (* Put the Title on the top to 
               make room for the Ok and Cancel buttons. *)
        SubStr(Title,s,1,CurrentWidth-2);
        x := ULX + ((LRX-ULX+1-ORD(s[0])) DIV 2);
        IF (OutputEnable) THEN 
            PutString(s,x,ULY,VidMode);
        END;
    END;

         (* Draw the buttons.  These are drawn right to left, and 
            proper operation rests on the assumptions that the button 
            attributes and mouse click points are both consecutive
            and in the same order.  Furthermore, the string containing
            the names of the buttons has those names in the exact
            same order.  The last (rightmost) button is "Cancel". *)

    xleft  := ULX;
    y := LRY;

    (*-- Activate this to put the buttons below the box. 
    IF (ShadowBox IN BoxType) THEN     (* Lower the button. *)
        INC(y);
    END;
    -- *)

        (* Put the buttons on *)

    GetGaGaMessage(ButtonsPhrase, s);                   (* (Cancel)(Ok) etc. *)
    i := 1;                                             (* index of button name *)
    FOR BoxAttr := MAX(ABoxAttribute) TO HasCancel BY -1 DO
        ParseBal(s,i,s2);                               (* button name *)
        IF BoxAttr IN BoxType THEN
            j := LengthOf(s2);                          (* button size *)
                (* If the button name begins with a "-", indent from the right *)
            IF (j > 0) AND (s2[1] = "-") THEN
                k := 2;
                x := LRX - StoC(s2,k);
                Remove(s2,1,k-1);
                j := LengthOf(s2);                      (* button size *)
                   (* Avoid run off left edge. *) 
                IF (x < xleft) THEN
                    x := LRX - j;
                    INC(y);
                END;
            ELSE 
                INC(xleft, 2);  (* Space after last button. *)
                x := xleft;
                INC(xleft,j);
                   (* Avoid run off right edge. *) 
                IF (x > LRX-j) THEN
                    x := ULX+2;
                    INC(y);
                END;
            END;
               (* Draw the button? *)
            IF (OutputEnable) THEN 
                PutString(s2,x,y,videobutton);
            END;
               (* Determine the location. *)
            SetRegion(CorrelationList, 
                      ORD(BoxAttr)-ORD(HasCancel)+ORD(OnCancel),
                      x,y,x+j-1,y);
        END;
    END;


END DrawBoxCorrelate;


(*----------------------------------------------------------------------------
DrawBox:

Puts a box on the screen at the given coordinates, which define the total screen
area used by the box, including borders and/or shadowing.

-----------------------------------------------------------------------------*)

PROCEDURE DrawBox(ULX : ascreenx;
                  ULY : ascreeny;
                  LRX : ascreenx;
                  LRY : ascreeny;
                  BoxType : ABoxType;
                  VAR Title : ARRAY OF CHAR;
                  VidMode : avidmode);
VAR
    CorrelationList : ACorrelationList;
BEGIN
    DrawBoxCorrelate(TRUE,ULX,ULY,LRX,LRY,BoxType,Title,VidMode,CorrelationList);
    DisposeCorrelationList(CorrelationList);
END DrawBox;


(*--------------------------------------------------------------------------
GetOuterBoxSize:

Changes the coordinates from "inner" coordinates, which define only the actual
usable box area, and "outer" coordinates, which include borders and/or
shadowing, if present.

-----------------------------------------------------------------------------*)

PROCEDURE GetOuterBoxSize  (  VAR ULX: ascreenx;
                              VAR ULY: ascreeny;
                              VAR LRX: ascreenx;
                              VAR LRY: ascreeny;
                              BoxType: ABoxType);
BEGIN
    IF (ShadowBox IN BoxType) THEN
        LRX := LRX + 2;
        LRY := LRY + 1;
    END;
    IF NOT (NoBox IN BoxType) THEN
        ULX := ULX - 1;
        ULY := ULY - 1;
        LRX := LRX + 1;
        LRY := LRY + 1;
    END;
END GetOuterBoxSize;


(*--------------------------------------------------------------------------
GetInnerBoxSize:

Complement of GetOuterBoxSize; converts from "outer" to "inner" dimensions.

-----------------------------------------------------------------------------*)

PROCEDURE GetInnerBoxSize  (  VAR ULX: ascreenx;
                              VAR ULY: ascreeny;
                              VAR LRX: ascreenx;
                              VAR LRY: ascreeny;
                              BoxType: ABoxType);
BEGIN
    IF (ShadowBox IN BoxType) THEN
        LRX := LRX - 2;
        LRY := LRY - 1;
    END;
    IF NOT (NoBox IN BoxType) THEN
        ULX := ULX + 1;
        ULY := ULY + 1;
        LRX := LRX - 1;
        LRY := LRY - 1;
    END;
END GetInnerBoxSize;



    (* ------------------------------------------------------------------
        CorrelateMousePoint

        Returns an indication of where on the box the mouse was clicked.



    ---------------------------------------------------------------------- *)

PROCEDURE CorrelateMousePoint(ULX: ascreenx;
                              ULY: ascreeny;
                              LRX: ascreenx;
                              LRY: ascreeny;
                              BoxType: ABoxType;
                              X  : ascreenx;
                              Y  : ascreeny ) : AMouseClickPoint;
VAR
    CorrelationList : ACorrelationList;
    Region          : AMouseClickPoint; 
    Title           : ARRAY [0..0] OF CHAR;
    i               : ARegionNumber;
BEGIN
    Title[0] := 0C;   (* Empty *)
    DrawBoxCorrelate(FALSE,ULX,ULY,LRX,LRY,BoxType,Title,videovanish,CorrelationList);
    i := CorrelatePoint(CorrelationList,X,Y); 
    Region := VAL(AMouseClickPoint,i); 
    DisposeCorrelationList(CorrelationList);
    RETURN Region;
END CorrelateMousePoint;




PROCEDURE CorrelateMouseToCode(ULX: ascreenx;
                               ULY: ascreeny;
                               LRX: ascreenx;
                               LRY: ascreeny;
                               BoxType: ABoxType;
                               X  : ascreenx;
                               Y  : ascreeny ) : ACode;
VAR
    Code : ACode;
BEGIN
    CASE CorrelateMousePoint(ULX,ULY,LRX,LRY,BoxType,X,Y) OF
        OnCancel     : Code := CancelKey;
      | OnOk         : Code := ExitKey;
      | OnDelete     : Code := DeleteKey;
      | OnInsert     : Code := InsertKey;
      | OnEdit       : Code := EditKey;
      | OnMenuButton : Code := OnMenu;
      | OnHelp       : Code := HelpKey;  
      ELSE
        Code := 0;
    END;
    RETURN Code;
END CorrelateMouseToCode;



BEGIN
    TransparentShadow := TRUE;
END Boxes.
