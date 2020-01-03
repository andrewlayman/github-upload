del *.lst
if exist *.lst goto error
rem link step omitted
goto end
IF EXIST OK.BAT c:\COMMAND/C OK %1
:error
IF EXIST ERROR.BAT c:\COMMAND/C ERROR %1
:end
