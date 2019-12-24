IMPLEMENTATION MODULE TSEDUtility;

FROM Allocs                 IMPORT
    (* TYPE *)                  ATaskPtr, TaskTree, ATaskFlag,
                                ATaskFilter, ATaskFilterSet;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;
    				
(*--------------------------------------------------------------------------*)
   
        (*  
            GetFilterSetting
            
            Returns the filter setting for the input task;
            
         *)
  
PROCEDURE GetFilterSetting(TaskTreeNode : ATreeNode) : CARDINAL; 

CONST
 (* filters *) 
    NONE = 0;
    HL1  = 1;
    HL2  = 2;
    HL3  = 3;
    HL4  = 4;
    HL5  = 5;
    SEL  = 6;
                                
VAR
    FilterSetting  : CARDINAL;
    filter : ATaskFilterSet;
    task   : ATaskPtr; 

BEGIN
 
 (* get the filter set for this task *)
   
    task:=TaskTreeNode^.Methods^.LockFlexStorDataObject(TaskTreeNode);
    filter:= task^.FilterSet;
    TaskTreeNode^.Methods^.UnlockUnchangedDataObject(TaskTreeNode);

 (* determine the FilterSetting *)
    FilterSetting:= NONE;
    IF Highlight1 IN filter THEN
      FilterSetting:= HL1;
    ELSIF Highlight2 IN filter THEN 
      FilterSetting:= HL2;
    ELSIF Highlight3 IN filter THEN 
      FilterSetting:= HL3;
    ELSIF Highlight4 IN filter THEN 
       FilterSetting:= HL4;
    ELSIF Highlight5 IN filter THEN 
       FilterSetting:= HL5;
    END; 
    IF NOT (Selected IN filter) THEN 
       FilterSetting:= SEL;
    END;
      
    RETURN (FilterSetting);
    
END GetFilterSetting;


(*--------------------------------------------------------------------------*)

BEGIN                       (* TSEDUtility *)

    

END TSEDUtility.
