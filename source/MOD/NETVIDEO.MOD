IMPLEMENTATION MODULE NetVideo;

FROM CritFilt               IMPORT
    (* PROC *)                  QueryCriticalPathFilter;

FROM Kbio                   IMPORT
    (* TYPE *)                  avidmode;
    
FROM NetStatic              IMPORT
    (* TYPE *)                  DiagramView,
    (* VAR *)                   ViewType;

(*--------------------------------------------------------------------------*)
        (*  
            GetLineColor            
            Returns the video mode to use for lines, in network view,
            critical or normal, tree view, always normal. 
         *)  
  
PROCEDURE GetLineColor(CriticalPath : BOOLEAN) : avidmode;

VAR 
    FilterNumber      : CARDINAL;
    LineVidMode       : avidmode;
    CriticalFilterSet : BOOLEAN;
    
BEGIN        

    LineVidMode := videonetwork;
    IF ((CriticalPath) AND (ViewType = NetworkView)) THEN
         FilterNumber := 0;
         CriticalFilterSet := QueryCriticalPathFilter(FilterNumber);
      (* see if there is a method to return the video mode given a filter number*)
         CASE FilterNumber OF
              3: LineVidMode := videofilter3;
            | 4: LineVidMode := videofilter4; 
            | 5: LineVidMode := videofilter5;
         ELSE
                 LineVidMode := videonetwork;
         END;
    END;
    
    RETURN(LineVidMode);
    
END GetLineColor;


(*--------------------------------------------------------------------------*)
BEGIN                       (* NetVideo *)
END NetVideo.
