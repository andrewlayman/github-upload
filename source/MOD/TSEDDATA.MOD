IMPLEMENTATION MODULE TSEDData;

    (*  MODIFICATION HISTORY
        12-Jun-89 CMH   Eliminated scaling of base character sizes in 
                        InitCharacterSizes. 
         9-Aug-89 CMH   Changed IsEnumValue to use proportional spacing, 
                        ie., Start Status.
    *)
    
FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree, ATaskFlag,
                                ATaskFilter, ATaskFilterSet;
                                
FROM Captions               IMPORT
    (* TYPE *)                  AColumnInfoChoice,
    (* PROC *)                  GetColumnInfo;

FROM LStrings		    IMPORT
    (* PROC *)			SetString, CtoS;

FROM MagicNum               IMPORT
                                IsStringValue,
                                IsRealValue,
                                IsIntValue,
                                IsCardValue,
                                IsBoolValue,
                                IsEnumValue,
                                IsBigStart,
                                IsBigEnd,
                                IsStartDate,
                                IsEndDate,
                                IsDuration,
                                IsSlack,
                                IsCurrency,
                                IsEffort,
                                IsMilestoneEnd,
                                IsDurationUnits,
                                IsEffortUnits,
                                IsTruncatedString;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM TSEDWrite		    IMPORT
    (* PROC *)			WriteToTLGSFile;


(*--------------------------------------------------------------------------*)
        (*  
            GetDataJustification
                        
         *)
          
PROCEDURE GetDataJustification(ColumnDataType : CARDINAL) : CARDINAL;

VAR 
    DataJustification : CARDINAL;
    
BEGIN     
                 
    CASE ColumnDataType OF                       
       
         IsBigStart, IsBigEnd, IsStartDate, IsEndDate, IsMilestoneEnd:
      
         DataJustification:= DATE;
         
    |    IsRealValue, IsIntValue, IsCardValue, IsBoolValue,
         IsDuration, IsSlack, IsCurrency, IsEffort:
       
         DataJustification:= NUMERICONLY;
             
    |    IsDurationUnits, IsEffortUnits:
       
         DataJustification:= NUMERICANDTEXT;
           
    |    IsStringValue, IsTruncatedString, IsEnumValue:
       
         DataJustification:= TEXTLEFT;
          
    ELSE 
     
         DataJustification:= TEXTLEFT;
         
    END; (* case *)
   
    RETURN(DataJustification);
    
END GetDataJustification;


(*--------------------------------------------------------------------------*)
        (*  
            ShowThisTask
                        
         *)
          
PROCEDURE ShowThisTask(TaskTreeNode:ATreeNode) : BOOLEAN;

VAR 
    ParentNode,
    GrandParentNode : ATreeNode;
    task            : ATaskPtr;
    DrawTask        : BOOLEAN;
    
BEGIN     
   
 (* is this task visible ? *)
             
    DrawTask:= TRUE;
    ParentNode:= TaskTreeNode^.Methods^.Parent(TaskTreeNode);
    GrandParentNode:= ParentNode;
    IF GrandParentNode <> NIL THEN
       REPEAT
         DrawTask:= GrandParentNode^.Methods^.ChildrenVisible(GrandParentNode);
         GrandParentNode:= GrandParentNode^.Methods^.Parent(GrandParentNode);
       UNTIL (GrandParentNode = NIL) OR (DrawTask = FALSE);
    END;  

   (* be sure this task is filtered in *)
    task:=TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    IF NOT (Selected IN task^.FilterSet) THEN 
       DrawTask:= FALSE;
    END;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

    RETURN(DrawTask);
    
END ShowThisTask;


(*--------------------------------------------------------------------------*)
BEGIN                       (* TSEDData *)
   
END TSEDData.
