IMPLEMENTATION MODULE NetKeys;

    (*  MODIFICATION HISTORY
         8-Sep-89 CMH   Removed MasterTaskWidth variable;
        15-Dec-89 EGK   For Mouse support, changed maxcol to NetXMax.
     *)
         
FROM AccessMatrix           IMPORT
    (* PROC *)                  GetCellInfo;
    
FROM Dialog                 IMPORT
    (* PROC *)                  Burp;
    
FROM NetUtility             IMPORT
    (* CONST *)                 ULX,           
    (* VAR *)                   SnetRowMin,    SnetRowMax,
                                SnetColMin,    SnetColMax,
                                BoxWidth,      BoxHeight,
                                CharWidth,     CharHeight,
                                MasterTaskHeight, NetXMax,
    (* PROC *)                  GetHorizMin,   GetHorizMax,
                                GetVertMin,    GetVertMax;
                                
FROM NetStatic              IMPORT
    (* VAR *)                   SnetHeight,    SnetWidth,
                                SnetRowOne,    SnetColOne,
                                SnetCols,      SnetRows;


(*--------------------------------------------------------------------------*)
        (*
            Scrolling

            Scroll in the given direction, begining at an input start
            point, for the given amount.  Returns the new end point.
            The Start point and End point are in terms of a matrix
            row and column.  It is calculated by the number of screen
            characters specified in the scroll amount.
         *)

PROCEDURE Scrolling(direction    : ADirection;
                    StartPoint,
                    ScrollAmount : INTEGER) : INTEGER;

VAR
   EndPoint,
   EndPosition  :  INTEGER;

BEGIN
   EndPosition:= 0;
   EndPoint:= StartPoint;

   CASE direction OF

        right:

            LOOP
                INC(EndPoint); (* keep scolling *)
                IF EndPoint > SnetCols THEN (* off the edge *)
                   DEC(EndPoint);
                   EXIT;
                END;
                EndPosition:= EndPosition + SnetWidth^[EndPoint];
                IF EndPosition > ScrollAmount THEN (* scrolled enough *)
                   DEC(EndPoint);
                   EndPosition:= EndPosition - SnetWidth^[EndPoint];
                   EXIT;
                END;
            END; (* loop *)

      | left:

            LOOP
                DEC(EndPoint); (* keep scolling *)
                IF EndPoint < SnetColOne THEN (* off the edge *)
                   INC(EndPoint);
                   EXIT;
                END;
                EndPosition:= EndPosition + SnetWidth^[EndPoint];
                IF EndPosition > ScrollAmount THEN (* scrolled enough *)
                   INC(EndPoint);
                   EndPosition:= EndPosition - SnetWidth^[EndPoint];
                   EXIT;
                END;
            END; (* loop *)

      | up:

            LOOP
                DEC(EndPoint); (* keep scolling *)
                IF EndPoint < SnetRowOne THEN (* off the edge *)
                   INC(EndPoint);
                   EXIT;
                END;
                EndPosition:= EndPosition + SnetHeight^[EndPoint];
                IF EndPosition > ScrollAmount THEN (* scrolled enough *)
                   INC(EndPoint);
                   EndPosition:= EndPosition - SnetHeight^[EndPoint];
                   EXIT;
                END;
            END; (* loop *)

      | down:

            LOOP
                INC(EndPoint); (* keep scolling *)
                IF EndPoint > SnetRows THEN (* off the edge *)
                   DEC(EndPoint);
                   EXIT;
                END;
                EndPosition:= EndPosition + SnetHeight^[EndPoint];
                IF EndPosition > ScrollAmount THEN (* scrolled enough *)
                   DEC(EndPoint);
                   EndPosition:= EndPosition - SnetHeight^[EndPoint];
                   EXIT;
                END;
            END; (* loop *)

   ELSE

   END;

   RETURN EndPoint;

END Scrolling;


(*--------------------------------------------------------------------------*)
        (*
            NetFwrdKey
         *)
            
PROCEDURE NetFwrdKey(VAR CurrentRow, CurrentCol : INTEGER) : BOOLEAN;

VAR
    NextCol,
    NextRow  : INTEGER;
    AtEdge,
    done     : BOOLEAN;
    
BEGIN

    NextCol:=0;
    NextRow:=0;
    done := FALSE;
    AtEdge:=FALSE;

    REPEAT
       INC(NextCol);
       IF (CurrentCol+NextCol) > SnetCols THEN
           Burp();  (* at right edge of plan *)
           done:= TRUE;
           IF (SnetColMax < SnetCols) THEN
            (* want to display last cols that don't contain a task *)
               AtEdge:= TRUE;
               SnetColMax:= SnetCols;
               GetHorizMin();
           END;
       ELSIF (SnetWidth^[CurrentCol+NextCol] = BoxWidth) THEN
              done:= TRUE;
              CurrentCol:= CurrentCol + NextCol;
       END;
    UNTIL done ;
             
    RETURN (AtEdge);
    
END NetFwrdKey;


(*--------------------------------------------------------------------------*)
        (*
            NetReverseKey
         *)
            
PROCEDURE NetReverseKey(VAR CurrentRow, CurrentCol : INTEGER) : BOOLEAN;

VAR
    NextCol,
    NextRow  : INTEGER;
    AtEdge,
    done     : BOOLEAN;
    
BEGIN
    NextCol:=0;
    NextRow:=0;
    done := FALSE;
    AtEdge:=FALSE;

    REPEAT
       INC(NextCol);
       IF ((CurrentCol-NextCol) < SnetColOne) THEN
            Burp();  (* at left edge of plan *)
            done:= TRUE;
            IF (SnetColMin > SnetColOne) THEN
             (* want to display first cols that don't contain a task *)
                AtEdge:= TRUE;
                SnetColMin:= SnetColOne;
                GetHorizMax(ULX,NetXMax+1);
            END;
       ELSIF (SnetWidth^[CurrentCol-NextCol] = BoxWidth) THEN
              done:= TRUE;
              CurrentCol:= CurrentCol - NextCol;
       END;
    UNTIL done ;
      
    RETURN (AtEdge);

END NetReverseKey;


(*--------------------------------------------------------------------------*)
        (*
            NetUpKey
         *)
            
PROCEDURE NetUpKey(VAR CurrentRow, CurrentCol : INTEGER) : BOOLEAN;

VAR
    NextCol,
    NextRow  : INTEGER;
    AtEdge,
    done     : BOOLEAN;
    
BEGIN

    NextCol:=0;
    NextRow:=0;
    done := FALSE;
    AtEdge:=FALSE;

    REPEAT
       INC(NextRow);
       IF ((CurrentRow-NextRow) < SnetRowOne) THEN
            Burp();  (* at top edge of plan *)
            done:= TRUE;
            IF (SnetRowMin > SnetRowOne) THEN
             (* want to display top rows that don't contain a task *)
                AtEdge:= TRUE;
                SnetRowMin:= SnetRowOne;
                GetHorizMax(ULX,NetXMax+1);
            END;
       ELSIF ((SnetHeight^[CurrentRow-NextRow] = BoxHeight+1) OR
              (SnetHeight^[CurrentRow-NextRow] = MasterTaskHeight)) THEN
               done:= TRUE;
               CurrentRow:= CurrentRow - NextRow;
       END;
    UNTIL done ;
   
    RETURN (AtEdge);

END NetUpKey;
             

(*--------------------------------------------------------------------------*)
        (*
            NetDownKey
         *)
            
PROCEDURE NetDownKey(VAR CurrentRow, CurrentCol : INTEGER) : BOOLEAN;

VAR
    NextCol,
    NextRow  : INTEGER;
    AtEdge,
    done     : BOOLEAN;
    
BEGIN

    NextCol:=0;
    NextRow:=0;
    done := FALSE;
    AtEdge:=FALSE;

    REPEAT
       INC(NextRow);
       IF ((CurrentRow+NextRow) > SnetRows) THEN
            Burp();  (* at bottom edge of plan *)
            done:= TRUE;
            IF (SnetRowMax < SnetRows) THEN
             (* want to display last rows that don't contain a task *)
                AtEdge:= TRUE;
                SnetRowMax:= SnetRows;
                GetVertMin();
            END;
       ELSIF ((SnetHeight^[CurrentRow+NextRow] = BoxHeight+1) OR
              (SnetHeight^[CurrentRow+NextRow] = MasterTaskHeight)) THEN
               done:= TRUE;
               CurrentRow:= CurrentRow + NextRow;
       END;
    UNTIL done ;
    
    RETURN (AtEdge);

END NetDownKey;
             

(*--------------------------------------------------------------------------*)
        (*
            NetPgUpKey
         *)
            
PROCEDURE NetPgUpKey(VAR CurrentRow, CurrentCol, VertScrollAmt : INTEGER) : BOOLEAN;

VAR
    i      : INTEGER;
    AtEdge : BOOLEAN;
 
BEGIN
    
    AtEdge:= FALSE;
    i:= CurrentRow;
    LOOP
       DEC(i);
       IF i < SnetRowOne THEN
          IF SnetRowMin > SnetRowOne THEN
          (* want to display top rows that don't contain a task *)
             AtEdge:= TRUE;
             SnetRowMin:= SnetRowOne;
             GetHorizMax(ULX,NetXMax+1);
           ELSE
             Burp();
           END;
           EXIT;
       ELSE
           IF SnetHeight^[i] <> CharHeight THEN
              EXIT;
           END;
       END;
    END; (* loop *)
    
    IF (NOT AtEdge) THEN
        CurrentRow:= Scrolling(up,CurrentRow,VertScrollAmt);
        IF SnetHeight^[CurrentRow] = CharHeight THEN
        (* if landed on char then back up a little *)
           LOOP
             INC(CurrentRow);
             IF CurrentRow > SnetRows THEN
                CurrentRow:= SnetRows;
                EXIT;
             END;
             IF SnetHeight^[CurrentRow] <> CharHeight THEN
                EXIT;
             END;
           END; (*loop *)
        END;
    END;    

    RETURN (AtEdge);

END NetPgUpKey;


(*--------------------------------------------------------------------------*)
        (*
            NetPgDnKey
         *)
            
PROCEDURE NetPgDnKey(VAR CurrentRow, CurrentCol, VertScrollAmt : INTEGER) : BOOLEAN;

VAR
    i      : INTEGER;
    AtEdge : BOOLEAN;
 
BEGIN
    
    AtEdge:= FALSE;
    i:= CurrentRow;
    LOOP
      INC(i);
      IF i > SnetRows THEN
         IF SnetRowMax < SnetRows THEN
         (* want to display last rows that don't contain a task *)
            AtEdge:= TRUE;
            SnetRowMax:= SnetRows;
            GetVertMin();
         ELSE
            Burp();
         END;
         EXIT;
      ELSE
         IF SnetHeight^[i] <> CharHeight THEN
            EXIT;
         END;
      END;
    END; (* loop *)
   
    IF (NOT AtEdge) THEN
        CurrentRow:= Scrolling(down,CurrentRow,VertScrollAmt);
        IF SnetHeight^[CurrentRow] = CharHeight THEN
        (* if landed on char then backup up a little *)
           LOOP
             DEC(CurrentRow);
             IF CurrentRow < SnetRowOne THEN
                CurrentRow:= SnetRowOne;
                EXIT;
             END;
             IF SnetHeight^[CurrentRow] <> CharHeight THEN
                EXIT;
             END;
           END; (*loop *)
        END;
    END;           

    RETURN (AtEdge);

END NetPgDnKey;


(*--------------------------------------------------------------------------*)
        (*
            NetRollRightKey
         *)
            
PROCEDURE NetRollRightKey(VAR CurrentRow, CurrentCol, HorizScrollAmt : INTEGER) : BOOLEAN;

VAR
    i      : INTEGER;
    AtEdge : BOOLEAN;
 
BEGIN

    
    AtEdge:= FALSE;
    i:= CurrentCol;
    LOOP
      INC(i);
      IF i > SnetCols THEN
         IF SnetColMax < SnetCols THEN
         (* want to display last cols that don't contain a task *)
            AtEdge:= TRUE;
            SnetColMax:= SnetCols;
            GetHorizMin();
         ELSE
            Burp();
         END;
         EXIT;
      ELSE
         IF SnetWidth^[i] <> CharWidth THEN
            EXIT;
         END;
      END;
    END; (* loop *)
    
    IF (NOT AtEdge) THEN
        CurrentCol:= Scrolling(right,CurrentCol,HorizScrollAmt);
        IF SnetWidth^[CurrentCol] = CharWidth THEN
        (* if landed on char then backup a little *)
           LOOP
             DEC(CurrentCol);
             IF CurrentCol < SnetColOne THEN
                CurrentCol:= SnetColOne;
                EXIT;
             END;
             IF SnetWidth^[CurrentCol] <> CharWidth THEN
                EXIT;
             END;
           END; (*loop *)
        END;
    END;

    RETURN (AtEdge);

END NetRollRightKey;


(*--------------------------------------------------------------------------*)
        (*
            NetRollLeftKey
         *)
            
PROCEDURE NetRollLeftKey(VAR CurrentRow, CurrentCol,HorizScrollAmt : INTEGER) : BOOLEAN;

VAR
    i      : INTEGER;
    AtEdge : BOOLEAN;
 
BEGIN
    
    AtEdge:= FALSE;
    i:= CurrentCol;
    LOOP
      DEC(i);
      IF i < SnetColOne THEN
         IF SnetColMin > SnetColOne THEN
         (* want to display first cols that don't contain a task *)
            AtEdge:= TRUE;
            SnetColMin:= SnetColOne;
            GetHorizMax(ULX,NetXMax+1);
         ELSE
            Burp();
         END;
         EXIT;
      ELSE
         IF SnetWidth^[i] <> CharWidth THEN
            EXIT;
         END;
      END;
    END; (* loop *)
    
    IF (NOT AtEdge) THEN
        CurrentCol:= Scrolling(left,CurrentCol,HorizScrollAmt);
        IF SnetWidth^[CurrentCol] = CharWidth THEN
        (* if landed on char then back up a little *)
           LOOP
             INC(CurrentCol);
             IF CurrentCol > SnetCols THEN
                CurrentCol:= SnetCols;
                EXIT;
             END;
             IF SnetWidth^[CurrentCol] <> CharWidth THEN
                EXIT;
             END;
           END; (*loop *)
        END;
           
    END;
 
    RETURN (AtEdge);

END NetRollLeftKey;


(*--------------------------------------------------------------------------*)
        (*
            NetTabKey
         *)
            
PROCEDURE NetTabKey(VAR CurrentRow, CurrentCol : INTEGER);

VAR
    cell,
    StartingRow,
    StartingCol    : INTEGER;
    done           : BOOLEAN;

BEGIN

    StartingRow := CurrentRow;         (* 3/9/88 EGK *)
    StartingCol := CurrentCol;
    done := FALSE;
    REPEAT
       INC(CurrentCol);
       IF (CurrentCol > SnetColMax) THEN
           CurrentCol:= SnetColMin;
           INC(CurrentRow);
           IF (CurrentRow > SnetRowMax) THEN
               CurrentRow:= SnetRowMin;
           END;
       END;
       cell:=GetCellInfo(CurrentRow,CurrentCol);
       IF (cell > 0) THEN
           done:= TRUE;
       END;
       IF (CurrentRow = StartingRow) AND (CurrentCol = StartingCol) THEN
           done := TRUE;
       END;
    UNTIL done;
             
END NetTabKey;


(*--------------------------------------------------------------------------*)
        (*
            NetRTabKey
         *)
            
PROCEDURE NetRTabKey(VAR CurrentRow, CurrentCol : INTEGER);

VAR
    cell,
    StartingRow,
    StartingCol    : INTEGER;
    done           : BOOLEAN;
    
BEGIN

    StartingRow := CurrentRow;             (* 3/9/88 EGK *)
    StartingCol := CurrentCol;
    done := FALSE;
    REPEAT
       DEC(CurrentCol);
       IF (CurrentCol < SnetColMin) THEN
           CurrentCol:= SnetColMax;
           DEC(CurrentRow);
           IF (CurrentRow < SnetRowMin) THEN
               CurrentRow:= SnetRowMax;
           END;
       END;
       cell:=GetCellInfo(CurrentRow,CurrentCol);
       IF (cell > 0) THEN
           done:= TRUE;
       END;
       IF (CurrentRow = StartingRow) AND (CurrentCol = StartingCol) THEN
           done := TRUE;
       END;
    UNTIL done;
    
END NetRTabKey;


(*--------------------------------------------------------------------------*)


BEGIN                       (* NetKeys *)


END NetKeys.
