Rem   Batch file built by REBUILD on 06-14-1990 at 12:28:27
Rem
Del Trouble.Log
IF EXIST B4COMPIL.BAT c:COMMAND/C B4COMPIL.BAT
IF EXIST GENERIC.PAT DEL GENERIC.PAT
IF EXIST CHECKING.PAT DEL CHECKING.PAT
Rem
Rem  Create the two standard pattern files, GENERIC.PAT and CHECKING.PAT
Rem
ECHO .head>>GENERIC.PAT
ECHO del *.lst>>GENERIC.PAT
ECHO .def>>GENERIC.PAT
ECHO m2c {#.def}>>GENERIC.PAT
ECHO .between>>GENERIC.PAT
ECHO if exist *.lst goto error>>GENERIC.PAT
ECHO .mod>>GENERIC.PAT
ECHO m2comp {#.mod}>>GENERIC.PAT
ECHO if exist *.lst goto error>>GENERIC.PAT
ECHO .link>>GENERIC.PAT
ECHO rem link step omitted>>GENERIC.PAT
ECHO .tail>>GENERIC.PAT
ECHO goto end>>GENERIC.PAT
ECHO IF EXIST OK.BAT c:COMMAND/C OK %%1>>GENERIC.PAT
ECHO :error>>GENERIC.PAT
ECHO IF EXIST ERROR.BAT c:COMMAND/C ERROR %%1>>GENERIC.PAT
ECHO :end>>GENERIC.PAT
Rem
Rem  Now the CHECKING pattern file.  Only difference is that
Rem  the modula compiler is run with extra checking on.
Rem
ECHO .head>>CHECKING.PAT
ECHO del *.lst>>CHECKING.PAT
ECHO .def>>CHECKING.PAT
ECHO m2c {#.def}>>CHECKING.PAT
ECHO .between>>CHECKING.PAT
ECHO if exist *.lst goto error>>CHECKING.PAT
ECHO .mod>>CHECKING.PAT
ECHO m2comp {#.mod/r+/t+}>>CHECKING.PAT
ECHO if exist *.lst goto error>>CHECKING.PAT
ECHO .link>>CHECKING.PAT
ECHO rem link step omitted>>CHECKING.PAT
ECHO .tail>>CHECKING.PAT
ECHO goto end>>CHECKING.PAT
ECHO IF EXIST OK.BAT c:COMMAND/C OK %%1>>CHECKING.PAT
ECHO :error>>CHECKING.PAT
ECHO IF EXIST ERROR.BAT c:COMMAND/C ERROR %%1>>CHECKING.PAT
ECHO :end>>CHECKING.PAT

:01
M2Make TimeLine/pf=Generic/S=EXE
c:Command/c CmdFile TimeLine /s=15000/b EXE
IF EXIST *.LST ECHO Compile failure on TimeLine at 01>>TROUBLE.LOG
IF EXIST *.LST GOTO 02
M2L TimeLine/s=15000/b
IF NOT EXIST TimeLine.EXE ECHO Link failure for TimeLine>>TROUBLE.LOG
tag !

:0101
    M2Make TLStats/pf=Generic/S=OVL
    c:Command/c CmdFile TLStats (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLStats at 0101>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0102
    M2L TLStats(TimeLine)/o/b
    IF NOT EXIST TLStats.OVL ECHO Link failure for TLStats>>TROUBLE.LOG

:0101
    M2Make TLTskChk/pf=Generic/S=OVL
    c:Command/c CmdFile TLTskChk (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLTskChk at 0101>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0102
    M2L TLTskChk(TimeLine)/o/b
    IF NOT EXIST TLTskChk.OVL ECHO Link failure for TLTskChk>>TROUBLE.LOG


:0102
    M2Make TLMouse/pf=Generic/S=OVL
    c:Command/c CmdFile TLMouse (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMouse at 0102>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0103
    M2L TLMouse(TimeLine)/o/b
    IF NOT EXIST TLMouse.OVL ECHO Link failure for TLMouse>>TROUBLE.LOG

:0103
    M2Make TLMenus/pf=Generic/S=OVL
    c:Command/c CmdFile TLMenus (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMenus at 0103>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0104
    M2L TLMenus(TimeLine)/o/b
    IF NOT EXIST TLMenus.OVL ECHO Link failure for TLMenus>>TROUBLE.LOG

:0104
    M2Make TLStart/pf=Generic/S=OVL
    c:Command/c CmdFile TLStart (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLStart at 0104>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0105
    M2L TLStart(TimeLine)/o/b
    IF NOT EXIST TLStart.OVL ECHO Link failure for TLStart>>TROUBLE.LOG

:0105
    M2Make TLReg/pf=Generic/S=OVL
    c:Command/c CmdFile TLReg (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLReg at 0105>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0106
    M2L TLReg(TimeLine)/o/b
    IF NOT EXIST TLReg.OVL ECHO Link failure for TLReg>>TROUBLE.LOG

:0106
    M2Make TLMain/pf=Generic/S=OVL
    c:Command/c CmdFile TLMain (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMain at 0106>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0107
    M2L TLMain(TimeLine)/o/b
    IF NOT EXIST TLMain.OVL ECHO Link failure for TLMain>>TROUBLE.LOG

:0107
    M2Make TLEMS/pf=Generic/S=OVL
    c:Command/c CmdFile TLEMS (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLEMS at 0107>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0108
    M2L TLEMS(TimeLine)/o/b
    IF NOT EXIST TLEMS.OVL ECHO Link failure for TLEMS>>TROUBLE.LOG

:0108
    M2Make TLSwapF/pf=Generic/S=OVL
    c:Command/c CmdFile TLSwapF (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLSwapF at 0108>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0109
    M2L TLSwapF(TimeLine)/o/b
    IF NOT EXIST TLSwapF.OVL ECHO Link failure for TLSwapF>>TROUBLE.LOG

:0109
    M2Make TLBTSMac/pf=Generic/S=OVL
    c:Command/c CmdFile TLBTSMac (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLBTSMac at 0109>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010A
    M2L TLBTSMac(TimeLine)/o/b
    IF NOT EXIST TLBTSMac.OVL ECHO Link failure for TLBTSMac>>TROUBLE.LOG

:010A
    M2Make TLCaptio/pf=Generic/S=OVL
    c:Command/c CmdFile TLCaptio (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLCaptio at 010A>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010B
    M2L TLCaptio(TimeLine)/o/b
    IF NOT EXIST TLCaptio.OVL ECHO Link failure for TLCaptio>>TROUBLE.LOG

:010B
    M2Make TLMemoEd/pf=Generic/S=OVL
    c:Command/c CmdFile TLMemoEd (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMemoEd at 010B>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010C
    M2L TLMemoEd(TimeLine)/o/b
    IF NOT EXIST TLMemoEd.OVL ECHO Link failure for TLMemoEd>>TROUBLE.LOG

:010C
    M2Make TLFBase/pf=Generic/S=OVL
    c:Command/c CmdFile TLFBase (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLFBase at 010C>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010D
    M2L TLFBase(TimeLine)
    IF NOT EXIST TLFBase.OVL ECHO Link failure for TLFBase>>TROUBLE.LOG

:010C01
        M2Make TLDOSFrm/pf=Generic/S=OVL
        c:Command/c CmdFile TLDOSFrm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDOSFrm at 010C01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C02
        M2L TLDOSFrm(TLFBase)/o/b
        IF NOT EXIST TLDOSFrm.OVL ECHO Link failure for TLDOSFrm>>TROUBLE.LOG

:010C02
        M2Make TLAssgn/pf=Generic/S=OVL
        c:Command/c CmdFile TLAssgn (TLFBase) OVL
        IF EXIST *.LST ECHO Compile failure on TLAssgn at 010C02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C03
        M2L TLAssgn(TLFBase)
        IF NOT EXIST TLAssgn.OVL ECHO Link failure for TLAssgn>>TROUBLE.LOG

:010C0201
            M2Make TLChange/pf=Generic/S=OVL
            c:Command/c CmdFile TLChange (TLAssgn)/o/b OVL
            IF EXIST *.LST ECHO Compile failure on TLChange at 010C0201>>TROUBLE.LOG
            IF EXIST *.LST GOTO 010C0202
            M2L TLChange(TLAssgn)/o/b
            IF NOT EXIST TLChange.OVL ECHO Link failure for TLChange>>TROUBLE.LOG
:010C0202


:010C03
        M2Make TLRsrc/pf=Generic/S=OVL
        c:Command/c CmdFile TLRsrc (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRsrc at 010C03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C04
        M2L TLRsrc(TLFBase)/o/b
        IF NOT EXIST TLRsrc.OVL ECHO Link failure for TLRsrc>>TROUBLE.LOG

:010C04
        M2Make TLFForm/pf=Generic/S=OVL
        c:Command/c CmdFile TLFForm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLFForm at 010C04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C05
        M2L TLFForm(TLFBase)/o/b
        IF NOT EXIST TLFForm.OVL ECHO Link failure for TLFForm>>TROUBLE.LOG

:010C05
        M2Make TLLink/pf=Generic/S=OVL
        c:Command/c CmdFile TLLink (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLLink at 010C05>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C06
        M2L TLLink(TLFBase)/o/b
        IF NOT EXIST TLLink.OVL ECHO Link failure for TLLink>>TROUBLE.LOG

:010C06
        M2Make TLDir411/pf=Generic/S=OVL
        c:Command/c CmdFile TLDir411 (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDir411 at 010C06>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C07
        M2L TLDir411(TLFBase)/o/b
        IF NOT EXIST TLDir411.OVL ECHO Link failure for TLDir411>>TROUBLE.LOG

:010C07
        M2Make TLRepFor/pf=Generic/S=OVL
        c:Command/c CmdFile TLRepFor (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRepFor at 010C07>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C08
        M2L TLRepFor(TLFBase)/o/b
        IF NOT EXIST TLRepFor.OVL ECHO Link failure for TLRepFor>>TROUBLE.LOG

:010C08

:010C09

:010C0A

:010C0B

:010C0C

:010C0D
        M2Make TLSchFor/pf=Generic/S=OVL
        c:Command/c CmdFile TLSchFor (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSchFor at 010C0D>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0E
        M2L TLSchFor(TLFBase)/o/b
        IF NOT EXIST TLSchFor.OVL ECHO Link failure for TLSchFor>>TROUBLE.LOG

:010C0E

:010C0F

:010C0G

:010C0H
:010C0S


:010D
    M2Make TLFilter/pf=Generic/S=OVL
    c:Command/c CmdFile TLFilter (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLFilter at 010D>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010E
    M2L TLFilter(TimeLine)/o/b
    IF NOT EXIST TLFilter.OVL ECHO Link failure for TLFilter>>TROUBLE.LOG

:010E

:010F

:010G
    M2Make TLGoTo/pf=Generic/S=OVL
    c:Command/c CmdFile TLGoTo (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLGoTo at 010G>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010H
    M2L TLGoTo(TimeLine)/o/b
    IF NOT EXIST TLGoTo.OVL ECHO Link failure for TLGoTo>>TROUBLE.LOG

:010H

:010I

:010J
    M2Make TLRsrcEd/pf=Generic/S=OVL
    c:Command/c CmdFile TLRsrcEd (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRsrcEd at 010J>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010K
    M2L TLRsrcEd(TimeLine)/o/b
    IF NOT EXIST TLRsrcEd.OVL ECHO Link failure for TLRsrcEd>>TROUBLE.LOG

:010K

:010L
    M2Make TLPlan/pf=Generic/S=OVL
    c:Command/c CmdFile TLPlan (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLPlan at 010L>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010M
    M2L TLPlan(TimeLine)
    IF NOT EXIST TLPlan.OVL ECHO Link failure for TLPlan>>TROUBLE.LOG

:010L01
        M2Make TLRPlan/pf=Generic/S=OVL
        c:Command/c CmdFile TLRPlan (TLPlan)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRPlan at 010L01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010L02
        M2L TLRPlan(TLPlan)/o/b
        IF NOT EXIST TLRPlan.OVL ECHO Link failure for TLRPlan>>TROUBLE.LOG

:010L02

:010L03
        M2Make TLCPM/pf=Generic/S=OVL
        c:Command/c CmdFile TLCPM (TLPlan)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCPM at 010L03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010L04
        M2L TLCPM(TLPlan)/o/b
        IF NOT EXIST TLCPM.OVL ECHO Link failure for TLCPM>>TROUBLE.LOG
:010L04


:010M
    M2Make TLGetIt/pf=Generic/S=OVL
    c:Command/c CmdFile TLGetIt (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLGetIt at 010M>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010N
    M2L TLGetIt(TimeLine)
    IF NOT EXIST TLGetIt.OVL ECHO Link failure for TLGetIt>>TROUBLE.LOG

:010M01

:010M02

:010M03
:010M04


:010N
    M2Make TlxPrep/pf=Generic/S=OVL
    c:Command/c CmdFile TlxPrep (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TlxPrep at 010N>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010O
    M2L TlxPrep(TimeLine)
    IF NOT EXIST TlxPrep.OVL ECHO Link failure for TlxPrep>>TROUBLE.LOG

:010N01
        M2Make TlxCnfg/pf=Generic/S=OVL
        c:Command/c CmdFile TlxCnfg (TlxPrep)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TlxCnfg at 010N01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010N02
        M2L TlxCnfg(TlxPrep)/o/b
        IF NOT EXIST TlxCnfg.OVL ECHO Link failure for TlxCnfg>>TROUBLE.LOG
:010N02


:010O
    M2Make TlxTl5/pf=Generic/S=OVL
    c:Command/c CmdFile TlxTl5 (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TlxTl5 at 010O>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010P
    M2L TlxTl5(TimeLine)/o/b
    IF NOT EXIST TlxTl5.OVL ECHO Link failure for TlxTl45>>TROUBLE.LOG

:010P
:011C
    M2Make TLDOS/pf=Generic/S=OVL
    c:\Command/c CmdFile TLDOS (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLDOS at 011C>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011D
    M2L TLDOS(TimeLine)/o/b
    IF NOT EXIST TLDOS.OVL ECHO Link failure for TLDOS>>TROUBLE.LOG
:011D

:0112
    M2Make TLRollem/pf=Generic/S=OVL
    c:Command/c CmdFile TLRollem (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRollem at 0112>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0113
    M2L TLRollem(TimeLine)/o/b
    IF NOT EXIST TLRollem.OVL ECHO Link failure for TLRollem>>TROUBLE.LOG

:0113

:0117

:011J
    M2Make TLSpread/pf=Generic/S=OVL
    c:Command/c CmdFile TLSpread (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLSpread at 011J>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011K
    M2L TLSpread(TimeLine)/o/b
    IF NOT EXIST TLSpread.OVL ECHO Link failure for TLSpread>>TROUBLE.LOG

:011K

:011U
    M2Make TLRenum/pf=Generic/S=OVL
    c:Command/c CmdFile TLRenum (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRenum at 011U>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011V
    M2L TLRenum(TimeLine)/o/b
    IF NOT EXIST TLRenum.OVL ECHO Link failure for TLRenum>>TROUBLE.LOG

:011V
:011V0L


:011X
    M2Make TLMagic/pf=Generic/S=OVL
    c:Command/c CmdFile TLMagic (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMagic at 011X>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011Y
    M2L TLMagic(TimeLine)/o/b
    IF NOT EXIST TLMagic.OVL ECHO Link failure for TLMagic>>TROUBLE.LOG

:011Y

:02
IF EXIST AFCOMPIL.BAT c:COMMAND/C AFCOMPIL.BAT
:LOGOUT
