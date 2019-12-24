(*--------------------------------------------------------------------------*)
        (*
            LookForAParent
         *)

PROCEDURE LookForAParent(StartingRow, StartingCol : CARDINAL) : ATreeNode;

VAR
    row, col : CARDINAL;
    TaskNode : ATreeNode;
    Found : BOOLEAN;
    message : ARRAY [0..255] OF CHAR;
    task : ATaskPtr;
    
BEGIN

    TaskNode:= NIL;
    
    IF (LayoutType = CONVENTIONAL) THEN 
        RETURN(TaskNode); 
    END;
    
    row:= StartingRow;
    col:= StartingCol;
    Found:= FALSE;
    
 (* look left for a left master task outline character *)
    WHILE ((col > ORD(SnetColOne)) AND (NOT CellIsOutline(GetCellInfo(row,col)))) DO
      DEC(col);
    END;
 
    IF (StartingCol = col) THEN (* started out on an edge *)
        Found:= TRUE;
    ELSE  (* see if moved to left edge from inside an outline *)      
        IF ((GetCellInfo(row,col) = pDPlus) OR
            (GetCellInfo(row,col) = pVDash) OR
            (GetCellInfo(row,col) = pDRightTee)) THEN
             WHILE ((row > ORD(SnetRowOne)) AND 
                    (GetCellInfo(row,col) <> pastrUL) AND
                    (GetCellInfo(row,col) <> pastrUR)) DO
                  DEC(row);
             END;
             IF (GetCellInfo(row,col) = pastrUL) THEN
                  Found:= TRUE;
             ELSE
                  row:= StartingRow;
                  col:= StartingCol;   
               (* look right for a right master task outline character *)
                   WHILE ((col < ORD(SnetCols)) AND (NOT CellIsOutline(GetCellInfo(row,col)))) DO
                     INC(col);
                   END;
                   IF ((GetCellInfo(row,col) = pDPlus) OR
                       (GetCellInfo(row,col) = pVDash) OR
                       (GetCellInfo(row,col) = pDLeftTee)) THEN
                        WHILE ((row > ORD(SnetRowOne)) AND 
                               (GetCellInfo(row,col) <> pastrUL) AND
                               (GetCellInfo(row,col) <> pastrUR)) DO
                                DEC(row);
                        END;
                        IF (GetCellInfo(row,col) = pastrUR) THEN
                            Found:= TRUE;
                        ELSE
                            row:= StartingRow;
                            col:= StartingCol;   
                         (* look up for a top master task outline character *)
                            WHILE ((row > ORD(SnetRowOne)) AND (NOT CellIsOutline(GetCellInfo(row,col)))) DO
                                    DEC(row);
                            END;
                            IF (GetCellInfo(row,col) = pdash) THEN
                                WHILE ((col > ORD(SnetColOne)) AND 
                                       (GetCellInfo(row,col) <> pastrUL) AND
                                       (GetCellInfo(row,col) <> pastrLL)) DO
                                     DEC(col);
                                END;
                            END;
                            IF (GetCellInfo(row,col) = pastrUL) THEN
                                Found:= TRUE;
                            ELSE
                                row:= StartingRow;
                                col:= StartingCol;   
                             (* look down for a bottom master task outline character *)
                                WHILE ((row < ORD(SnetRows)) AND (NOT CellIsOutline(GetCellInfo(row,col)))) DO
                                       INC(row);
                                END;
                                IF (GetCellInfo(row,col) = pdash) THEN
                                    WHILE ((col > ORD(SnetColOne)) AND 
                                         (GetCellInfo(row,col) <> pastrUL) AND
                                         (GetCellInfo(row,col) <> pastrLL)) DO
                                      DEC(col);
                                    END;
                                END;    
                                IF (GetCellInfo(row,col) = pastrLL) THEN
                                    Found:= TRUE;
                                END;
                            END;
                        END;
                  END;      
             END;
        END;
    END;
        
    IF (Found) THEN      
        IF ((GetCellInfo(row,col) = pDPlus) OR
            (GetCellInfo(row,col) = pVDash) OR
            (GetCellInfo(row,col) = pastrLL) OR
            (GetCellInfo(row,col) = pastrLR) OR
            (GetCellInfo(row,col) = pDLeftTee) OR
            (GetCellInfo(row,col) = pDRightTee)) THEN (* on left or right edge *) 
            WHILE ((row > ORD(SnetRowOne)) AND 
                    (GetCellInfo(row,col) <> pastrUL) AND
                    (GetCellInfo(row,col) <> pastrUR)) DO
                DEC(row);
             END;         
        ELSE (* else on upper or lower edge *) 
             WHILE ((col > ORD(SnetColOne)) AND 
                    (GetCellInfo(row,col) <> pastrLL) AND
                    (GetCellInfo(row,col) <> pastrUL)) DO
                DEC(col);
             END; 
             IF ((GetCellInfo(row,col) = pastrLL)) THEN
                 WHILE ((row>ORD(SnetRowOne)) AND 
                        (GetCellInfo(row,col)<>pastrUL)) DO
                   DEC(row);
                 END;             
             END;
        END;
    
     (* look for master task cell *)    
        IF ((GetCellInfo(row,col) = pastrUL)) THEN
             WHILE ((col<ORD(SnetCols)) AND 
                    (GetCellInfo(row,col)<0)) DO
               INC(col);
             END;
        ELSIF ((GetCellInfo(row,col) = pastrUR)) THEN
             WHILE ((col>ORD(SnetColOne)) AND 
                    (GetCellInfo(row,col)<0)) DO
               DEC(col);
             END;
        END;
    
        IF (GetCellInfo(row,col) > 0) THEN   
            TaskNode:= loopnode^[GetCellInfo(row,col)];
        END;
    
    END;(* if found *)    
    
    RETURN TaskNode;
   
END LookForAParent;


