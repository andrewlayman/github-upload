IMPLEMENTATION MODULE VidType;

    (* MODIFICATION HISTORY:
       
       1989 May 25, AJL  - Original version.
       1989 Nov 27, AJL  - Initialize the structures with some harmless values.

    *)  


VAR
    i : AQuestionType;

BEGIN
        (* Initialize the structures with some harmless values. *)
    WITH VideoConfiguration DO
        ComputerType := IBMPC;
        BoardType    := GenericColorBoard;
        TubeType     := MonoTube;
        AutoDetect   := TRUE;
    END;
    FOR i := MIN(AQuestionType) TO MAX(AQuestionType) DO
        Answers[i] := 1;
    END; 
END VidType.
