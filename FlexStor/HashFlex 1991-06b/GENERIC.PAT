.head
del *.lst
.def
m2c {#.def}
.between
if exist *.lst goto error
.mod
m2comp {#.mod}
if exist *.lst goto error
.link
rem link step omitted
.tail
goto end
IF EXIST OK.BAT c:\COMMAND/C OK %1
:error
IF EXIST ERROR.BAT c:\COMMAND/C ERROR %1
:end
