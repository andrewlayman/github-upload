IMPLEMENTATION MODULE Paranoia;

BEGIN                       (* Paranoia *)
    AnxietyLevel     := Paranoid;
    ProgramState     := BeforeRootInit;  (* Now in root module init *)
    InitializationOK := TRUE;            (* So far, so good *)
END Paranoia.
