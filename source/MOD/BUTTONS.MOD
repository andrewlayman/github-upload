IMPLEMENTATION MODULE Buttons;


    (* MODIFICATION HISTORY --
    
        21 Dec 89  AJL  -Original version.
         2 Jan 90  AJL  -Changed to use mouse mode videonetstarted for
                         buttons' video.   
        4-Oct-90   AJL - Change the names of the mouse video attributes.

    *)


FROM Boxes  IMPORT
    (* TYPE *)         ABoxType, ABoxAttribute,
    (* PROC *)         DrawBox, GetInnerBoxSize, GetOuterBoxSize;

FROM Correl IMPORT
    (* TYPE *)         ACorrelationList, ARegionNumber,
    (* PROC *)         CreateCorrelationList, DisposeCorrelationList,
                       SetRegion, CorrelatePoint;

FROM Fits IMPORT
    (* PROC *)         Within;

FROM Kbio IMPORT 
    (* TYPE *)         ascreenx, ascreeny, avidmode,
    (* VAR *)          maxrow, maxcol,
    (* PROC *)         PutString;

FROM LStrings IMPORT
    (* PROC *)         LengthOf, SetLengthOf, SubStr, ConcatLS, SetString;  

FROM Mouse IMPORT
    (* PROC *)         MousePresent;

FROM Rugs IMPORT
    (* TYPE *)         ARug,
    (* PROC *)         GetRug, PutRug;

FROM SegWords   IMPORT
    (* PROC *)         WordNumber;
    
FROM Space      IMPORT 
    (* PROC *)         ALLOCATE, DEALLOCATE, Available;

FROM SYSTEM     IMPORT
    (* PROC *)         TSIZE;



TYPE
    ABCRecord         = RECORD
                            Rug : ARug;
                            CorrelationList : ACorrelationList;
                        END;
    AButtonCollection = POINTER TO ABCRecord;


PROCEDURE CreateButtonCollection( ULX : ascreenx;
                                  ULY : ascreeny;
                                  LRX : ascreenx;
                                  LRY : ascreeny;
                                  BoxType : ABoxType;
                                  Orientation : AnOrientation;
                                  VAR Text       : ARRAY OF CHAR;
                                  VAR Collection : AButtonCollection ) : BOOLEAN;
VAR
    x : ascreenx;
    y : ascreeny;
    i,l : CARDINAL;
    S : ARRAY [0..99] OF CHAR;    
BEGIN
    Collection := NIL;
    IF (NOT MousePresent()) THEN
        RETURN TRUE;
    END;

    IF (Available(TSIZE(ABCRecord))) THEN
        NEW( Collection );
        Collection^.CorrelationList := CreateCorrelationList();

            (* Make the box big enough, and fit on screen. *)
        GetInnerBoxSize(ULX,ULY,LRX,LRY,BoxType);
        x := ULX;
        y := ULY;
        i := 1;
        LOOP 
            WordNumber(Text,i,S);
            IF (LengthOf(S) = 0) THEN
        EXIT;
            END;
            l := LengthOf(S);
            IF (Orientation = Horizontal) THEN
                INC(x,l+2);
            ELSE
                INC(y);
            END;
            INC(i);
        END;
        IF (x > LRX) THEN LRX := x; END;
        IF (y > LRY) THEN LRY := y; END;
        GetOuterBoxSize(ULX,ULY,LRX,LRY,BoxType);
        Within(ULX,LRX,0,maxcol);
        Within(ULY,LRY,0,maxrow);

            (* Draw the box. *)
        IF (NOT GetRug(ULX,ULY,LRX,LRY,Collection^.Rug)) THEN
            DISPOSE(Collection);
            RETURN FALSE;
        END;  
        SetLengthOf(S,0);
        IF (NOT (NoBox IN BoxType)) THEN
            DrawBox(ULX,ULY,LRX,LRY,BoxType,S,videomenuback); 
        END;
        GetInnerBoxSize(ULX,ULY,LRX,LRY,BoxType);

        i := 1;
        x := ULX;
        y := ULY;
        LOOP 
            WordNumber(Text,i,S);
            IF (LengthOf(S) = 0) THEN
        EXIT;
            END;
            l := LengthOf(S);
            PutString(S,x,y,videobutton);
            SetRegion(Collection^.CorrelationList,i,x,y,x+l-1,y);
            IF (Orientation = Horizontal) THEN
                INC(x,l+2);
            ELSE
                INC(y);
            END;
            INC(i);
        END;
        RETURN TRUE;
    END;

    RETURN FALSE;
END CreateButtonCollection;



PROCEDURE DisposeButtonCollection( VAR Collection : AButtonCollection );
BEGIN
    IF (Collection <> NIL) THEN
        WITH Collection^ DO
            PutRug(0,0,0,0,Rug);
            DisposeCorrelationList(CorrelationList);
        END;
        DISPOSE(Collection);
    END;
END DisposeButtonCollection;




PROCEDURE CorrelateMouseToButton(     Collection : AButtonCollection;
                                      X : ascreenx; 
                                      Y : ascreeny;
                                  VAR ButtonNumber : CARDINAL ) : BOOLEAN;
BEGIN
    IF (Collection = NIL) THEN
        RETURN FALSE;
    END; 
    ButtonNumber := CorrelatePoint(Collection^.CorrelationList,X,Y);
    RETURN ButtonNumber > 0;
END CorrelateMouseToButton;

END Buttons.
