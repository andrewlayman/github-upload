IMPLEMENTATION MODULE DataTree;

    (*  MODIFICATION HISTORY

        25-Sep-89 EGK   Import FindNetLayoutByName from NetLUtility instead
                        of defining it here.
    *)


FROM FontTLGS		    IMPORT 
    (* CONST *) 		HELVETICALIGHT,
    (* VAR *)			ActiveFont,
    (* PROC *)			GetASedonaFontNumber;
        
FROM DataNetwork	    IMPORT
     				ShowDependencyLines,
     				TimeScaleNetwork,
     				NetworkDiagramLayout,
    				NormalPipeWidth,
    				MasterPipeWidth,
    				CrateInteriorPipeStyle,
    				NormalPipeHighlight,
    				NormalPipeRadius,
    				NormalPipeStyle,
    				MasterPipeStyle, CompressAxis;

FROM IlsaStatic             IMPORT
    (* TYPE *)			ATLGSGridStyle,   
    				ATLGSCorner,     
    				AnOrientation,      
    				ATLGSTreeRecord,       
    				ATLGSTreeRecordPtr,
    (* PROC *)   		TLGSTreeRecord;
    				   
FROM LStrings               IMPORT
    (* PROC *)                  SetString, Copy, Compare, SetLengthOf,
                                LengthOf, TrimRear, ConcatLS;

FROM NetLayouts	 	        IMPORT
    (* TYPE *)		            ANetworkLayout,
    (* VAR *)			        NetLayoutTree,
    (* PROC *)			        GetNormalNetLayout;

FROM NetLUtility            IMPORT
    (* PROC *)                  FindNetLayoutByName;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATreeNode;

FROM TSEDData		    IMPORT 
    (* CONST *)			NORMAL,
    				THINLINE, 		
    				NORMALLINE, 		
    				FLOWLINE, 
    				THICKTUBE,
   				FLOWTUBE, 
    				INCHESPERPOINT,
    				SEDONAUNITPERINCH,
        
    (* VAR *)			SpacePointSize,
          			CharPointSize,
          			VerticalGap,
          			BaseCharacterHeight,
          			BaseCharacterWidth,
          			RealCharacterHeight,
          			RealCharacterWidth;


(*--------------------------------------------------------------------------*)
         (*  
          InitializeTreeData          
          *)
         
PROCEDURE InitializeTreeData();

VAR 
    FontFamily,
    FontMember   : CARDINAL;
    TLGSTreeInfo : ATLGSTreeRecordPtr;
    Node         : ATreeNode;

BEGIN

    TLGSTreeInfo:=TLGSTreeRecord();
    SpacePointSize:= (TLGSTreeInfo^.Leading) DIV 16;		(* vertical spacing *)       
    CharPointSize:= (TLGSTreeInfo^.DefaultSpec.PointSize) DIV 16;	(* character size in points *)
     
 (* vertical gap in Sedona Units *)
    VerticalGap:= SpacePointSize-CharPointSize;
    VerticalGap:=  TRUNC(FLOAT(VerticalGap)*INCHESPERPOINT*SEDONAUNITPERINCH);
     
 (* character size in Sedona units *)  
    RealCharacterHeight:= TRUNC(FLOAT(CharPointSize)*INCHESPERPOINT*SEDONAUNITPERINCH);
    RealCharacterWidth:= RealCharacterHeight;
      
 (* character size for scaling *)  
    BaseCharacterHeight:= RealCharacterHeight;
    BaseCharacterWidth:= 1;
      
 (* line style *)  
    NormalPipeWidth := BaseCharacterWidth;
    CASE TLGSTreeInfo^.GridStyle OF
         Thin:
          NormalPipeStyle:= THINLINE;	
       | Hollow :
          NormalPipeWidth := NormalPipeWidth + BaseCharacterWidth ;
          NormalPipeStyle:= THICKTUBE;	
    ELSE
       (* thick *)
          NormalPipeWidth := NormalPipeWidth + BaseCharacterWidth ;
          NormalPipeStyle:= NORMALLINE;	
    END;
    MasterPipeStyle:= THINLINE;	
    MasterPipeWidth := NormalPipeWidth;
    CrateInteriorPipeStyle:= THINLINE;	
          
 (* drop shadows *)    
    IF (TLGSTreeInfo^.Shadows) THEN
        NormalPipeHighlight:= 1;  (* use drop shadows *)
        NormalPipeWidth := NormalPipeWidth + BaseCharacterWidth ;
    ELSE
        NormalPipeHighlight:= 0;  (* no drop shadows *)
    END;
 
 (* frame corners style *)
    IF ( TLGSTreeInfo^.Corners = Round) THEN
         NormalPipeRadius:= (BaseCharacterHeight + VerticalGap) DIV 5 (* 20% of box text height *);
    ELSE (* Square *)
         NormalPipeRadius:= 0;
    END;
      
    Node := FindNetLayoutByName(TLGSTreeInfo^.Layout);
    IF (Node = NIL) THEN
        NetworkDiagramLayout := GetNormalNetLayout();
    ELSE
        NetworkDiagramLayout := Node^.Methods^.GetDataObject (Node);
    END;
    FontFamily:=TLGSTreeInfo^.DefaultSpec.FontFamily;
    FontMember:=TLGSTreeInfo^.DefaultSpec.FontMember;
    ActiveFont:= GetASedonaFontNumber(FontFamily,FontMember);

    TimeScaleNetwork:= FALSE;
    CompressAxis:= FALSE;
    ShowDependencyLines:= TRUE;

END InitializeTreeData;



BEGIN                       (* DataTree *)

END DataTree.
