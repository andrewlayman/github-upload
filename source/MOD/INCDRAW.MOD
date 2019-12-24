IMPLEMENTATION MODULE IncDraw;

    (* MODIFICATION HISTORY: 
        29-Aug-89 CMH   Modified return value from GetCellInfo and GetCell 
                        to take into account the COLORBIAS used to color 
                        critical path lines.
        30-Aug-89 CMH   Added code to update corners of master task outline
                        for incremental redraw. 
        11-Sep-89 EGK   Put checks into MakeRow and MakeCol to prevent
                        SnetRows and SnetCols from becoming too big.
        19-Sep-89 CMH   Fixed expansion of master task outlines for new
                        rows from a double vertical bar to a blank.
        28-Sep-89 EGK   If HaveInfLoop is set, act as if NetworkType was
                        Conventional.
        20-Oct-89 EGK   If HaveInfLoop is set, IRDeleteDep and IRAddDep
                        should fail, since loops can change dramatically
                        (or go away) for single changes such as these.
        21-Nov-89 KWC   Fixed adding a dependency
        21-Nov-89 KWC   Fixed removing a dependency to be more selective                
    *)
    
FROM AccessMatrix           IMPORT
    (* CONST *)                 COLORBIAS,
    (* PROC *)                  GetCell, GetCellInfo, SetCell,
                                MoveMatrixRows, MoveMatrixCols;

FROM ErrorUtil              IMPORT
    (* PROC *)                  PrintSMsg, PrintSCard;
    
FROM NetCharacters          IMPORT
    (* CONST *)                 pblank, pVBar,pHBar,pVDash,pdash,pRightTee,
                                pURC,pLLC,pBotTee,pTopTeeUp,pTopTeeDown,
                                pLeftTee,pplus,pLRC,pULC,pDPlus,pDHPlus,
                                pastrLL,pastrLR,pastrUR,pastrUL,pMTaskHBar,
                                pMTaskVBar, pDLeftTee,pDRightTee;

FROM NetStatic              IMPORT 
    (* CONST *)                 DimHeight,
    (* VAR *)                   Xpos,Ypos,
                                Xmaxpos, Ymaxpos,
                                Utility, HaveInfLoop,
                                SnetCols,SnetRows,maxtask,
                                SnetWidth,SnetHeight;

FROM NetUtility             IMPORT
    (* VAR *)                   CharHeight,CharWidth,BoxHeight,BoxWidth;                     
    
FROM NetworkData            IMPORT
    (* TYPE *)                  ANetworkType,
    (* VAR  *)                  CurrentActiveView,
                                AnnealingChoice, NetworkType;


(*--------------------------------------------------------------------------*)
        (*  
             IRAddTask
         *)
         
PROCEDURE IRAddTask(TaskId :INTEGER;
                    xpos   :INTEGER;
                    ypos   :INTEGER);
BEGIN

   MakeCol(xpos);
   SnetWidth^[xpos] := BoxWidth;
   SnetHeight^[ypos] := BoxHeight;
   SetCell(ypos,xpos,TaskId);

END IRAddTask;


(*--------------------------------------------------------------------------*)
        (*  
             IRDeleteTask
         *)
         
PROCEDURE IRDeleteTask(TaskId :INTEGER);

BEGIN
 
     SetCell(Ypos[TaskId],Xpos[TaskId],0);

END IRDeleteTask;


(*--------------------------------------------------------------------------*)
        (*  
             IRAddDep
         *)

PROCEDURE IRAddDep(ptask,stask :INTEGER) : BOOLEAN;

VAR
   x1, y1,
   x2, y2    : INTEGER;

BEGIN
   
   x1 := Xpos[ptask];
   y1 := Ypos[ptask];
   x2 := Xpos[stask];
   y2 := Ypos[stask];
    
(* DEBUG  
   PrintSCard(ORD(x1),"ptask x1 ");
   PrintSCard(ORD(y1),"ptask y1 ");
   PrintSCard(ORD(x2),"stask x1 ");
   PrintSCard(ORD(y2),"stask y1 "); 
   DEBUG *)
   
   IF (x2 <= x1) OR (HaveInfLoop) THEN          (* 10/20/89 EGK *)
       RETURN (FALSE);
   END;
   
   MakeCol(x1+1);
   SnetWidth^[x1+1] := CharWidth;
   INC(x2);
   MakeCol(x2);
   INC(x2);
   SnetWidth^[x2-1] := CharWidth;
   IF (y2 < y1) THEN (* y2 above *)
       MakeRow(y2+1);
       SnetHeight^[y2+1] := CharHeight;
       INC(y1);
       IRDrawVert(x1+1,y2+1,y1);
       IRDrawHorz(x1+1,y2+1,x2-1);
       SetCell(y1,x1+1,pLRC);
       SetCell(y2+1,x1+1,pULC);
       SetCell(y2+1,x2-1,pLRC);
       SetCell(y2,x2-1,pULC);
     
   ELSIF (y2 > y1) THEN  (* y2 below *)
       MakeRow(y2);
       SnetHeight^[y2] := CharHeight;
       INC(y2);
       IRDrawVert(x1+1,y1,y2-1);
       IRDrawHorz(x1+1,y2-1,x2-1);
       SetCell(y1,x1+1,pURC);
       SetCell(y2-1,x1+1,pLLC);
       SetCell(y2-1,x2-1,pURC);
       SetCell(y2,x2-1,pLLC);

   ELSE  (* y2=y1 *)
       MakeRow(y2+1);
       SnetHeight^[y2+1] := CharHeight;
       IRDrawHorz(x1+1,y2+1,x2-1);
       SetCell(y1,x1+1,pURC);
       SetCell(y2+1,x1+1,pLLC);
       SetCell(y2+1,x2-1,pLRC);
       SetCell(y2,x2-1,pULC);
   END;
   
   RETURN(TRUE);
     
END IRAddDep;  


(*--------------------------------------------------------------------------*)
        (*  
             IRDeleteDep
         *)

PROCEDURE IRDeleteDep(ptask,stask :INTEGER):BOOLEAN;

VAR
   x1, y1, x2, y2, 
   char,
   nextpos, i         : INTEGER;
   pathfound          : BOOLEAN;

BEGIN

   IF (HaveInfLoop) THEN                (* 10/20/89 EGK *)
       RETURN FALSE;
   END;

   x1        := Xpos[ptask];
   y1        := Ypos[ptask];
   x2        := Xpos[stask];
   y2        := Ypos[stask];
   nextpos   := x1;
   pathfound := FALSE;
   
   IF (y2 < y1) THEN (* y2 above *)
       REPEAT
         INC(nextpos);  
         IF (nextpos > SnetCols) THEN 
             RETURN(FALSE); 
         END;
         char := GetCell(y1,nextpos);
      (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
         IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
              char := char + COLORBIAS;
         END;  
         IF (char = pLRC) THEN
             pathfound := UPPath(nextpos,y1,stask,FALSE);
         END;
       UNTIL (pathfound=TRUE);
       pathfound := UPPath(nextpos,y1,stask,TRUE); 
   
   ELSIF (y2 > y1) THEN  (* y2 below *)
       REPEAT
         INC(nextpos);  
         IF (nextpos > SnetCols) THEN 
             RETURN(FALSE); 
         END;
         char := GetCell(y1,nextpos);
      (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
         IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
              char := char + COLORBIAS;
         END;  
         IF (char = pURC) THEN
             pathfound := DownPath(nextpos,y1,stask,FALSE);
         END;
       UNTIL (pathfound=TRUE);
       pathfound := DownPath(nextpos,y1,stask,TRUE); 
  
   ELSE  (* y2=y1 *)
       REPEAT
         INC(nextpos);  
         IF (nextpos > SnetCols) THEN RETURN(FALSE); END;
         pathfound := EqualPath(nextpos,y1,stask,FALSE);
         char := GetCellInfo(y1,nextpos);
      (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
         IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
              char := char + COLORBIAS;
         END;  
         IF (char = stask) THEN
             FOR i := x1+1 TO nextpos-1 DO
                 char := GetCell(y1,i);
              (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
                 IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
                      char := char + COLORBIAS;
                 END;  
                 IF (char = pHBar) THEN
                     SetCell(y1,i,0);
                 END;
             END;
             RETURN(TRUE);
         END;
       UNTIL (pathfound=TRUE);
       pathfound := EqualPath(nextpos,y1,stask,TRUE); 
   END;
    
   RETURN(pathfound);
   
END IRDeleteDep;  


(*--------------------------------------------------------------------------*)
        (*  
             UPPath
         *)

PROCEDURE UPPath(x1,y1,stask:INTEGER; Blastit:BOOLEAN):BOOLEAN;

VAR
    char,
    pad      : INTEGER;

BEGIN

 (* Look up *)
    IF (Blastit = TRUE) THEN 
        SetCell(y1,x1,0); 
    END;
    REPEAT
      DEC(y1);
      IF (y1 <= 0) THEN 
          RETURN(FALSE); 
      END;
      char:=GetCell(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;  
      IF (Blastit=TRUE) THEN
         IF (char = pULC) THEN 
             FixRowCell(y1,x1); 
         END;
         IF (char = pVBar) THEN 
             FixColCell(y1,x1); 
         END;
      END;
    UNTIL (char=pULC);
    
 (* Look Across *)
    REPEAT
      INC(x1);
      IF(x1>SnetCols) THEN RETURN(FALSE); END;
      char:=GetCellInfo(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;
      IF (char = stask) THEN 
          RETURN(TRUE);
      END;
      IF (char > 0) THEN 
          RETURN(FALSE); 
      END;
      IF (Blastit = TRUE) THEN
         IF (char = pLRC) THEN 
             FixColCell(y1,x1); 
         END;
         IF (char =pHBar) THEN 
             FixRowCell(y1,x1); 
         END;
      END;
    UNTIL (char = pLRC);
    
 (* Look Up *)
    REPEAT
      DEC(y1);
      IF (y1 <= 0) THEN 
          RETURN(FALSE); 
      END;
      char := GetCell(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;  
      IF (Blastit = TRUE) THEN
          IF (char = pULC )THEN 
              FixRowCell(y1,x1);
          END;
          IF (char = pVBar) THEN 
              FixColCell(y1,x1); 
          END;
      END;
    UNTIL (char = pULC);
 
 (* Look Across *)
    LOOP
      INC(x1);
      IF (x1 > SnetCols) THEN 
          RETURN(FALSE);
      END;
      char := GetCellInfo(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;
      IF (char = stask) THEN
          RETURN(TRUE); 
      END;
      IF (char > 0) THEN 
          RETURN(FALSE); 
      END;
      IF (Blastit = TRUE) THEN
         IF (char = pHBar) THEN 
             FixRowCell(y1,x1); 
         END;
      END;
    END;
    
END UPPath; 
 
 
(*--------------------------------------------------------------------------*)
        (*  
             DownPath
         *)
         
PROCEDURE DownPath(x1,y1,stask:INTEGER; Blastit:BOOLEAN):BOOLEAN;

VAR
    char : INTEGER;
 
BEGIN

    IF (Blastit = TRUE) THEN 
        SetCell(y1,x1,0); 
    END;
 (* Look Down *)
    REPEAT
      INC(y1);
      IF (y1 > SnetRows) THEN 
          RETURN(FALSE); 
      END;
      char := GetCell(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;  
      IF (Blastit = TRUE) THEN
         IF (char=pLLC) THEN 
             FixRowCell(y1,x1);
         END;
         IF (char = pVBar) THEN 
             FixColCell(y1,x1); 
         END;
      END;
    UNTIL (char=pLLC);
    
 (* Look Across *)
    REPEAT
      INC(x1);
      IF (x1 > SnetCols) THEN 
          RETURN(FALSE); 
      END;
      char := GetCellInfo(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;
      IF (char = stask) THEN 
         RETURN(TRUE);
      END;
      IF (char > 0) THEN 
          RETURN(FALSE); 
      END;
      IF (Blastit = TRUE) THEN
          IF (char = pURC) THEN 
          FixColCell(y1,x1); 
          END;
          IF (char = pHBar) THEN 
              FixRowCell(y1,x1); 
          END;
      END;
    UNTIL (char = pURC);
    
 (* Look Down *)
    REPEAT
      INC(y1);
      IF (y1 > SnetRows) THEN 
          RETURN(FALSE); 
      END;
      char := GetCell(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;  
      IF (Blastit = TRUE) THEN
         IF (char = pLLC) THEN 
             FixRowCell(y1,x1); 
         END;
         IF (char = pVBar) THEN 
             FixColCell(y1,x1); 
         END;
      END;
    UNTIL (char=pLLC);
    
 (* Look Across *)
    LOOP
      INC(x1);
      IF (x1 > SnetCols) THEN 
          RETURN(FALSE); 
      END;
      char := GetCellInfo(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;
      IF (char = stask) THEN 
        RETURN(TRUE);
      END;
      IF (char > 0) THEN 
          RETURN(FALSE); 
      END;
      IF (Blastit = TRUE) THEN
         IF (char = pHBar) THEN 
             FixRowCell(y1,x1); 
         END;
      END;
    END;
    
END DownPath;  


(*--------------------------------------------------------------------------*)
        (*  
             EqualPath
         *)

PROCEDURE EqualPath(x1,y1,stask:INTEGER; Blastit:BOOLEAN):BOOLEAN;

VAR
    char :INTEGER;

BEGIN

    IF (Blastit = TRUE) THEN 
        SetCell(y1,x1,0); 
    END;
 
 (* Look Down *)
    REPEAT
      INC(y1);
      IF (y1 > SnetRows) THEN 
          RETURN(FALSE); 
      END;
      char := GetCell(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;  
      IF (Blastit = TRUE) THEN
          IF (char = pLLC) THEN 
              FixRowCell(y1,x1); 
         END;
         IF (char = pVBar) THEN 
             FixColCell(y1,x1); 
         END;
      END;
    UNTIL (char = pLLC);
    
 (* Look Across *)
    REPEAT
      INC(x1);
      IF (x1 > SnetCols) THEN 
          RETURN(FALSE); 
      END;
      char := GetCellInfo(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;
      IF (char > 0) THEN 
          RETURN(FALSE); 
      END;
      IF (char = pURC) THEN 
          RETURN(FALSE); 
      END;
      IF (Blastit = TRUE) THEN
          IF (char = pLRC)  THEN 
              FixColCell(y1,x1); 
          END;
          IF (char = pHBar) THEN 
              FixRowCell(y1,x1); 
          END;
      END;
    UNTIL (char=pLRC);
    
 (* Look Up *)
    REPEAT
      DEC(y1);
      IF (y1 <= 0) THEN 
          RETURN(FALSE);
      END;
      char := GetCell(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;  
      IF (Blastit = TRUE) THEN
          IF (char = pULC) THEN 
              FixRowCell(y1,x1); 
          END;
          IF (char = pVBar) THEN
              FixColCell(y1,x1); 
          END;
      END; 
    UNTIL (char = pULC);
    
    (* Look Across *)
    LOOP
      INC(x1);
      IF (x1 > SnetCols) THEN 
          RETURN(FALSE);
      END;
      char := GetCellInfo(y1,x1);
   (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
      IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
           char := char + COLORBIAS;
      END;
      IF (char = stask) THEN 
          RETURN(TRUE); 
      END;
      IF (char > 0) THEN 
          RETURN(FALSE); 
      END;
      IF (Blastit = TRUE) THEN
          IF (char = pHBar) THEN 
              FixRowCell(y1,x1); 
          END;
      END;
    END;
    
END EqualPath;  
  
  
(*--------------------------------------------------------------------------*)
        (*  
             MakeCol
         *)
         
PROCEDURE MakeCol(col:INTEGER);

VAR
    icol, irow, j :  INTEGER;
    
BEGIN

    IF (SnetCols < DimHeight) THEN          (* 9/11/89 EGK *)
        INC(SnetCols);
    END;
    MoveMatrixCols(col,SnetCols,SnetRows);
    FOR irow := 0 TO SnetRows DO
        FixColCell(irow,col);
    END;
    FOR j := 1 TO maxtask  DO
        IF (NetworkType = Outline) AND (NOT HaveInfLoop) THEN   (* 9/28/89 EGK *)
            IF (Utility[j] >= col) THEN
                INC(Utility[j]);
            END;
            IF (Xmaxpos[j] >= col) THEN
                INC(Xmaxpos[j]);
            END;
        END;
        IF (Xpos[j] >= col) THEN
            INC(Xpos[j]);
        END;
    END;         
    FOR icol := SnetCols TO col BY -1 DO
        SnetWidth^[icol] := SnetWidth^[icol-1];
    END;
    
END MakeCol;


(*--------------------------------------------------------------------------*)
        (*  
             FixColCell
         *)

PROCEDURE FixColCell(irow,col:INTEGER);

VAR
    top, bottom,
    left, right,
    char, j,
    icol,tcol     :  INTEGER;
    
BEGIN
        SetCell(irow,col,0);
        left  := 0;
        right := 0;
     (* See Whats in the  matrix already *)
        tcol := col-1;
        TestChar2(irow,tcol,left,right,top,bottom);      
        char := GetCell(irow,tcol);
     (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
        IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
             char := char + COLORBIAS;
        END;  
        IF ((right <> 0) AND (char < 0))   THEN
             SetCell(irow,col,pHBar);
        END;
        IF (char = pdash) THEN
            SetCell(irow,col,pdash);
        END;
        IF ((char = pastrUL) OR (char = pastrLL)) THEN
             SetCell(irow,col,pdash);
        END;
        
        tcol := col+1;
        TestChar2(irow,tcol,left,right,top,bottom);      
        IF ((left <> 0) AND (char < 0)) THEN
             SetCell(irow,col,pHBar);
        END;
        IF (char = pdash) THEN
            SetCell(irow,col,pdash);
        END;
        IF ((char = pastrUR) OR (char = pastrLR)) THEN
            SetCell(irow,col,pdash);
        END;
        
END FixColCell;


(*--------------------------------------------------------------------------*)
        (*  
             MakeRow
         *)

PROCEDURE MakeRow(row:INTEGER);

VAR
    top, bottom,
    left, right,
    icol, irow,
    trow,j          : INTEGER;

BEGIN

    IF (SnetRows < DimHeight) THEN          (* 9/11/89 EGK *)
        INC(SnetRows);
    END;
    MoveMatrixRows(row,SnetRows);
    FOR icol := 0 TO SnetCols DO
        FixRowCell(row,icol);
    END;
    FOR j := 1 TO maxtask  DO
        IF (Ypos[j] >= row) THEN
            INC(Ypos[j]);
        END;
        IF (NetworkType = Outline) AND (NOT HaveInfLoop) THEN   (* 9/28/89 EGK *)
            IF (Ymaxpos[j] >= row) THEN
                INC(Ymaxpos[j]);
            END;
        END;
    END;         
    FOR irow := SnetRows TO row BY -1 DO
        SnetHeight^[irow]:=SnetHeight^[irow-1];
    END;
    
END MakeRow;


(*--------------------------------------------------------------------------*)
        (*  
             FixRowCell
         *)

PROCEDURE FixRowCell(row,icol:INTEGER);

VAR
    top,bottom,
    left,right,
    char, j,
    irow,trow       :  INTEGER;

BEGIN
        SetCell(row,icol,0);
        trow := row+1;
        TestChar2(trow,icol,left,right,top,bottom);      
        IF (top <> 0) THEN
            SetCell(row,icol,pVBar);
        END;   
        char := GetCell(trow,icol);
     (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
        IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
             char := char + COLORBIAS;
        END;  
         
        IF ((char = pVDash) OR (char = pMTaskVBar)) THEN
             SetCell(row,icol,pVDash);   
        END; 
        IF ((char = pastrLL) OR (char = pastrLR)) THEN
            SetCell(row,icol,pVDash);
        END;
         IF (char = pDPlus) THEN
            SetCell(row,icol,pVDash);
        END;
        IF (char = pDRightTee) THEN
              SetCell(row,icol,pVDash);
        END;
        IF (char = pDLeftTee) THEN
            SetCell(row,icol,pVDash);   
        END;  
        trow := row-1;  
        TestChar2(trow,icol,left,right,top,bottom);      
        IF (bottom <> 0) THEN
            SetCell(row,icol,pVBar);
        END; 
        IF ((char = pDPlus) OR (char = pDRightTee)) THEN
            SetCell(row,icol,pVDash);   
        END;
        IF ((char = pastrUR) OR (char = pastrUL)) THEN
             SetCell(row,icol,pblank); (* 19-Sep-89 CMH *)
        END;
         IF (char = pDLeftTee) THEN
            SetCell(row,icol,pVDash);   
        END;  
 
        IF ((char = pVDash) OR (char = pMTaskHBar)) THEN
            SetCell(row,icol,pVDash);   
        END;   
        
END FixRowCell;


(*--------------------------------------------------------------------------*)
        (*  
             TestChar2
         *)
         
PROCEDURE TestChar2(row,icol: INTEGER; VAR left,right,top,bottom: INTEGER);
VAR
    char : INTEGER;
    
BEGIN
    left   := 0;
    right  := 0;
    top    := 0;
    bottom := 0;
    
    char := GetCell(row,icol);
  (* remove color bias to get actual character *)  (* 29-Aug-89 CMH *)  
     IF ((ABS(char) > COLORBIAS) AND (char < 0)) THEN
          char := char + COLORBIAS;
     END;  
         
    IF (char = 0) THEN 
        RETURN; 
    END;
    
    CASE char OF
    
         pMTaskVBar : top    := 1;
                      bottom := 4;
                      
    |    pMTaskHBar : left  := 8;
                      right := 2;
                                
    |    pHBar:       left  := 8;
                      right := 2;
                      
    |    pVBar:       top    := 1;
                      bottom := 4;
                      
    |    pRightTee:   top    := 1;
                      left   := 8;
                      bottom := 4; 
                      
    |    pDRightTee:  top    := 1;
                      left   := 8;
                      bottom := 4; 
                      

    |    pURC:        left   := 8;
                      bottom := 4; 
                      
    |    pLLC:        top   := 1;
                      right :=2 ; 
                      
    |    pBotTee:     top   := 1;
                      left  := 8;
                      right := 2; 
                      
    |    pTopTeeUp:   right  := 2;
                      left   := 8;
                      bottom := 4;
                      
    |    pTopTeeDown: right  := 2;
                      left   := 8;
                      bottom := 4;
                      
    |    pLeftTee:    right  := 2;
                      bottom := 4;
                      top    := 1; 
                      
    |    pDLeftTee:   right  := 2;
                      bottom := 4;
                      top    := 1; 

    |    pplus:       top    := 1;
                      right  := 2;
                      bottom := 4;
                      left   := 8; 
                      
    |    pDHPlus:     top    := 1;
                      right  := 2;
                      bottom := 4;
                      left   := 8; 
                      
    |    pDPlus:      top    := 1;
                      right  := 2;
                      bottom := 4;
                      left   := 8; 
                      
    |    pLRC:        top  := 1;
                      left := 8; 
                      
    |    pULC:        right  := 2;
                      bottom := 4;
                       
    ELSE  (* task found *)
         IF (GetCell(row,icol) > 0) THEN
             left  := 8;  
             right := 2;
         END;    
    
    END; (* End of case *)                      

END TestChar2;


(*--------------------------------------------------------------------------*)
        (*  
             IRDrawVert
         *)

PROCEDURE IRDrawVert(col1,row1,row2: INTEGER);

VAR
    irow :  INTEGER;

BEGIN

      FOR irow := row1 TO row2 DO
          SetCell(irow,col1,pVBar);
      END; 

END IRDrawVert;


(*--------------------------------------------------------------------------*)
        (*  
             IRDrawHorz
         *)

PROCEDURE IRDrawHorz(col1,row1,col2:INTEGER);

VAR
    icol : INTEGER;
    
BEGIN

     FOR icol := col1 TO col2 DO
          SetCell(row1,icol,pHBar);
     END; 

END IRDrawHorz;

    
(*--------------------------------------------------------------------------*)

BEGIN

END IncDraw.

