Rem   Batch file built by REBUILD on 06-22-1990 at 17:54:44
Rem
Del Trouble.Log
IF EXIST B4COMPIL.BAT c:\COMMAND/C B4COMPIL.BAT
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
ECHO IF EXIST OK.BAT c:\COMMAND/C OK %%1>>GENERIC.PAT
ECHO :error>>GENERIC.PAT
ECHO IF EXIST ERROR.BAT c:\COMMAND/C ERROR %%1>>GENERIC.PAT
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
ECHO IF EXIST OK.BAT c:\COMMAND/C OK %%1>>CHECKING.PAT
ECHO :error>>CHECKING.PAT
ECHO IF EXIST ERROR.BAT c:\COMMAND/C ERROR %%1>>CHECKING.PAT
ECHO :end>>CHECKING.PAT

:01
M2Make TimeLine/pf=Generic/S=EXE
c:\Command/c CmdFile TimeLine /s=15000/b/map EXE
IF EXIST *.LST ECHO Compile failure on TimeLine at 01>>TROUBLE.LOG
IF EXIST *.LST GOTO 02
M2L TimeLine/s=15000/b/map
IF NOT EXIST TimeLine.EXE ECHO Link failure for TimeLine>>TROUBLE.LOG

tag !

:0101
    M2Make TLStats/pf=Generic/S=OVL
    c:\Command/c CmdFile TLStats (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLStats at 0101>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0102
    M2L TLStats(TimeLine)/o/b
    IF NOT EXIST TLStats.OVL ECHO Link failure for TLStats>>TROUBLE.LOG

    M2Make TLTskChk/pf=Generic/S=OVL
    c:\Command/c CmdFile TLTskChk (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLTskChk at 0101>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0102
    M2L TLTskChk(TimeLine)/o/b
    IF NOT EXIST TLTskChk.OVL ECHO Link failure for TLTskChk>>TROUBLE.LOG

:0102
    M2Make TLMouse/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMouse (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMouse at 0102>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0103
    M2L TLMouse(TimeLine)/o/b
    IF NOT EXIST TLMouse.OVL ECHO Link failure for TLMouse>>TROUBLE.LOG

:0103
    M2Make TLMenus/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMenus (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMenus at 0103>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0104
    M2L TLMenus(TimeLine)/o/b
    IF NOT EXIST TLMenus.OVL ECHO Link failure for TLMenus>>TROUBLE.LOG

:0104
    M2Make TLStart/pf=Generic/S=OVL
    c:\Command/c CmdFile TLStart (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLStart at 0104>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0105
    M2L TLStart(TimeLine)/o/b
    IF NOT EXIST TLStart.OVL ECHO Link failure for TLStart>>TROUBLE.LOG

:0105
    M2Make TLReg/pf=Generic/S=OVL
    c:\Command/c CmdFile TLReg (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLReg at 0105>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0106
    M2L TLReg(TimeLine)/o/b
    IF NOT EXIST TLReg.OVL ECHO Link failure for TLReg>>TROUBLE.LOG

:0106
    M2Make TLMain/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMain (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMain at 0106>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0107
    M2L TLMain(TimeLine)/o/b
    IF NOT EXIST TLMain.OVL ECHO Link failure for TLMain>>TROUBLE.LOG

:0107
    M2Make TLEMS/pf=Generic/S=OVL
    c:\Command/c CmdFile TLEMS (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLEMS at 0107>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0108
    M2L TLEMS(TimeLine)/o/b
    IF NOT EXIST TLEMS.OVL ECHO Link failure for TLEMS>>TROUBLE.LOG

:0108
    M2Make TLSwapF/pf=Generic/S=OVL
    c:\Command/c CmdFile TLSwapF (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLSwapF at 0108>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0109
    M2L TLSwapF(TimeLine)/o/b
    IF NOT EXIST TLSwapF.OVL ECHO Link failure for TLSwapF>>TROUBLE.LOG

:0109
    M2Make TLBTSMac/pf=Generic/S=OVL
    c:\Command/c CmdFile TLBTSMac (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLBTSMac at 0109>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010A
    M2L TLBTSMac(TimeLine)/o/b
    IF NOT EXIST TLBTSMac.OVL ECHO Link failure for TLBTSMac>>TROUBLE.LOG

:010A
    M2Make TLCaptio/pf=Generic/S=OVL
    c:\Command/c CmdFile TLCaptio (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLCaptio at 010A>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010B
    M2L TLCaptio(TimeLine)/o/b
    IF NOT EXIST TLCaptio.OVL ECHO Link failure for TLCaptio>>TROUBLE.LOG

:010B
    M2Make TLMemoEd/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMemoEd (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMemoEd at 010B>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010C
    M2L TLMemoEd(TimeLine)/o/b
    IF NOT EXIST TLMemoEd.OVL ECHO Link failure for TLMemoEd>>TROUBLE.LOG

:010C
    M2Make TLFBase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFBase (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLFBase at 010C>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010D
    M2L TLFBase(TimeLine)/MAP
    IF NOT EXIST TLFBase.OVL ECHO Link failure for TLFBase>>TROUBLE.LOG

:010C01
        M2Make TLDOSFrm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLDOSFrm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDOSFrm at 010C01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C02
        M2L TLDOSFrm(TLFBase)/o/b
        IF NOT EXIST TLDOSFrm.OVL ECHO Link failure for TLDOSFrm>>TROUBLE.LOG

:010C02
        M2Make TLAssgn/pf=Generic/S=OVL
        c:\Command/c CmdFile TLAssgn (TLFBase) OVL
        IF EXIST *.LST ECHO Compile failure on TLAssgn at 010C02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C03
        M2L TLAssgn(TLFBase)
        IF NOT EXIST TLAssgn.OVL ECHO Link failure for TLAssgn>>TROUBLE.LOG

:010C0201
            M2Make TLChange/pf=Generic/S=OVL
            c:\Command/c CmdFile TLChange (TLAssgn)/o/b OVL
            IF EXIST *.LST ECHO Compile failure on TLChange at 010C0201>>TROUBLE.LOG
            IF EXIST *.LST GOTO 010C0202
            M2L TLChange(TLAssgn)/o/b
            IF NOT EXIST TLChange.OVL ECHO Link failure for TLChange>>TROUBLE.LOG
:010C0202


:010C03
        M2Make TLRsrc/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRsrc (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRsrc at 010C03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C04
        M2L TLRsrc(TLFBase)/o/b
        IF NOT EXIST TLRsrc.OVL ECHO Link failure for TLRsrc>>TROUBLE.LOG

:010C04
        M2Make TLFForm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLFForm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLFForm at 010C04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C05
        M2L TLFForm(TLFBase)/o/b
        IF NOT EXIST TLFForm.OVL ECHO Link failure for TLFForm>>TROUBLE.LOG

:010C05
        M2Make TLLink/pf=Generic/S=OVL
        c:\Command/c CmdFile TLLink (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLLink at 010C05>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C06
        M2L TLLink(TLFBase)/o/b
        IF NOT EXIST TLLink.OVL ECHO Link failure for TLLink>>TROUBLE.LOG

:010C06
        M2Make TLDir411/pf=Generic/S=OVL
        c:\Command/c CmdFile TLDir411 (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDir411 at 010C06>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C07
        M2L TLDir411(TLFBase)/o/b
        IF NOT EXIST TLDir411.OVL ECHO Link failure for TLDir411>>TROUBLE.LOG

:010C07
        M2Make TLRepFor/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRepFor (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRepFor at 010C07>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C08
        M2L TLRepFor(TLFBase)/o/b
        IF NOT EXIST TLRepFor.OVL ECHO Link failure for TLRepFor>>TROUBLE.LOG

:010C08
        M2Make TLCalndr/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCalndr (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCalndr at 010C08>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C09
        M2L TLCalndr(TLFBase)/o/b
        IF NOT EXIST TLCalndr.OVL ECHO Link failure for TLCalndr>>TROUBLE.LOG

:010C09
        M2Make TLEdge/pf=Generic/S=OVL
        c:\Command/c CmdFile TLEdge (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLEdge at 010C09>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0A
        M2L TLEdge(TLFBase)/o/b
        IF NOT EXIST TLEdge.OVL ECHO Link failure for TLEdge>>TROUBLE.LOG

:010C0A
        M2Make TL2Form/pf=Generic/S=OVL
        c:\Command/c CmdFile TL2Form (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TL2Form at 010C0A>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0B
        M2L TL2Form(TLFBase)/o/b
        IF NOT EXIST TL2Form.OVL ECHO Link failure for TL2Form>>TROUBLE.LOG

:010C0B
        M2Make TLRHForm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRHForm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRHForm at 010C0B>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0C
        M2L TLRHForm(TLFBase)/o/b
        IF NOT EXIST TLRHForm.OVL ECHO Link failure for TLRHForm>>TROUBLE.LOG

:010C0C
        M2Make TLSetClk/pf=Generic/S=OVL
        c:\Command/c CmdFile TLSetClk (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSetClk at 010C0C>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0D
        M2L TLSetClk(TLFBase)/o/b
        IF NOT EXIST TLSetClk.OVL ECHO Link failure for TLSetClk>>TROUBLE.LOG

:010C0D
        M2Make TLSchFor/pf=Generic/S=OVL
        c:\Command/c CmdFile TLSchFor (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSchFor at 010C0D>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0E
        M2L TLSchFor(TLFBase)/o/b
        IF NOT EXIST TLSchFor.OVL ECHO Link failure for TLSchFor>>TROUBLE.LOG

:010C0E
        M2Make TLLayout/pf=Generic/S=OVL
        c:\Command/c CmdFile TLLayout (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLLayout at 010C0E>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0F
        M2L TLLayout(TLFBase)/o/b
        IF NOT EXIST TLLayout.OVL ECHO Link failure for TLLayout>>TROUBLE.LOG

:010C0F
        M2Make TLFltFrm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLFltFrm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLFltFrm at 010C0F>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0G
        M2L TLFltFrm(TLFBase)/o/b
        IF NOT EXIST TLFltFrm.OVL ECHO Link failure for TLFltFrm>>TROUBLE.LOG

:010C0G
        M2Make TLXForm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLXForm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLXForm at 010C0G>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0H
        M2L TLXForm(TLFBase)/o/b
        IF NOT EXIST TLXForm.OVL ECHO Link failure for TLXForm>>TROUBLE.LOG

:010C0H

:010C0I
        M2Make TLXSSOpt/pf=Generic/S=OVL
        c:\Command/c CmdFile TLXSSOpt (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLXSSOpt at 010C0I>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0J
        M2L TLXSSOpt(TLFBase)/o/b
        IF NOT EXIST TLXSSOpt.OVL ECHO Link failure for TLXSSOpt>>TROUBLE.LOG

:010C0J
        M2Make TLIForm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLIForm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLIForm at 010C0J>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0K
        M2L TLIForm(TLFBase)/o/b
        IF NOT EXIST TLIForm.OVL ECHO Link failure for TLIForm>>TROUBLE.LOG

:010C0K
        M2Make TLAsList/pf=Generic/S=OVL
        c:\Command/c CmdFile TLAsList (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLAsList at 010C0K>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0L
        M2L TLAsList(TLFBase)/o/b
        IF NOT EXIST TLAsList.OVL ECHO Link failure for TLAsList>>TROUBLE.LOG

:010C0L

:010C0M

:010C0N

:010C0O
        M2Make TLComm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLComm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLComm at 010C0O>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0P
        M2L TLComm(TLFBase)/o/b
        IF NOT EXIST TLComm.OVL ECHO Link failure for TLComm>>TROUBLE.LOG

:010C0P
        M2Make TLDevSet/pf=Generic/S=OVL
        c:\Command/c CmdFile TLDevSet (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDevSet at 010C0P>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0Q
        M2L TLDevSet(TLFBase)/o/b
        IF NOT EXIST TLDevSet.OVL ECHO Link failure for TLDevSet>>TROUBLE.LOG

:010C0Q

:010C0R
        M2Make TLSetMou/pf=Generic/S=OVL
        c:\Command/c CmdFile TLSetMou (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSetMou at 010C0R>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0S
        M2L TLSetMou(TLFBase)/o/b
        IF NOT EXIST TLSetMou.OVL ECHO Link failure for TLSetMou>>TROUBLE.LOG
:010C0S

        M2Make TLCalcul/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCalcul (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCalcul at 010C0R>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010C0T
        M2L TLCalcul(TLFBase)/o/b
        IF NOT EXIST TLCalcul.OVL ECHO Link failure for TLCalcul>>TROUBLE.LOG
:010C0T

:010D
    M2Make TLFilter/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFilter (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLFilter at 010D>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010E
    M2L TLFilter(TimeLine)/o/b
    IF NOT EXIST TLFilter.OVL ECHO Link failure for TLFilter>>TROUBLE.LOG

:010E
    M2Make TLFSelct/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFSelct (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLFSelct at 010E>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010F
    M2L TLFSelct(TimeLine)/o/b
    IF NOT EXIST TLFSelct.OVL ECHO Link failure for TLFSelct>>TROUBLE.LOG

:010F
    M2Make TLTaskLi/pf=Generic/S=OVL
    c:\Command/c CmdFile TLTaskLi (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLTaskLi at 010F>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010G
    M2L TLTaskLi(TimeLine)/o/b
    IF NOT EXIST TLTaskLi.OVL ECHO Link failure for TLTaskLi>>TROUBLE.LOG

:010G
    M2Make TLGoTo/pf=Generic/S=OVL
    c:\Command/c CmdFile TLGoTo (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLGoTo at 010G>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010H
    M2L TLGoTo(TimeLine)/o/b
    IF NOT EXIST TLGoTo.OVL ECHO Link failure for TLGoTo>>TROUBLE.LOG

:010H
    M2Make TLDepend/pf=Generic/S=OVL
    c:\Command/c CmdFile TLDepend (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLDepend at 010H>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010I
    M2L TLDepend(TimeLine)/o/b
    IF NOT EXIST TLDepend.OVL ECHO Link failure for TLDepend>>TROUBLE.LOG

:010I
    M2Make TLRHist/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRHist (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRHist at 010I>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010J
    M2L TLRHist(TimeLine)/o/b
    IF NOT EXIST TLRHist.OVL ECHO Link failure for TLRHist>>TROUBLE.LOG

:010J
    M2Make TLRsrcEd/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRsrcEd (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRsrcEd at 010J>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010K
    M2L TLRsrcEd(TimeLine)/o/b
    IF NOT EXIST TLRsrcEd.OVL ECHO Link failure for TLRsrcEd>>TROUBLE.LOG

:010K
    M2Make TLLayLis/pf=Generic/S=OVL
    c:\Command/c CmdFile TLLayLis (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLLayLis at 010K>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010L
    M2L TLLayLis(TimeLine)/o/b
    IF NOT EXIST TLLayLis.OVL ECHO Link failure for TLLayLis>>TROUBLE.LOG

:010L
    M2Make TLPlan/pf=Generic/S=OVL
    c:\Command/c CmdFile TLPlan (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLPlan at 010L>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010M
    M2L TLPlan(TimeLine)
    IF NOT EXIST TLPlan.OVL ECHO Link failure for TLPlan>>TROUBLE.LOG

:010L01
        M2Make TLRPlan/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRPlan (TLPlan)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRPlan at 010L01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010L02
        M2L TLRPlan(TLPlan)/o/b
        IF NOT EXIST TLRPlan.OVL ECHO Link failure for TLRPlan>>TROUBLE.LOG

:010L02
        M2Make TLLoops/pf=Generic/S=OVL
        c:\Command/c CmdFile TLLoops (TLPlan)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLLoops at 010L02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010L03
        M2L TLLoops(TLPlan)/o/b
        IF NOT EXIST TLLoops.OVL ECHO Link failure for TLLoops>>TROUBLE.LOG

:010L03
        M2Make TLCPM/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCPM (TLPlan)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCPM at 010L03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010L04
        M2L TLCPM(TLPlan)/o/b
        IF NOT EXIST TLCPM.OVL ECHO Link failure for TLCPM>>TROUBLE.LOG
:010L04


:010M
    M2Make TLGetIt/pf=Generic/S=OVL
    c:\Command/c CmdFile TLGetIt (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLGetIt at 010M>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010N
    M2L TLGetIt(TimeLine)
    IF NOT EXIST TLGetIt.OVL ECHO Link failure for TLGetIt>>TROUBLE.LOG

:010M01

:010M02

:010M03

:010M04
        M2Make TLiTl5/pf=Generic/S=OVL
        c:\Command/c CmdFile TLiTl5 (TLGetIt)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLiTl5 at 010M04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010M05
        M2L TLiTl5(TLGetIt)/o/b
        IF NOT EXIST TLiTl5.OVL ECHO Link failure for TLiTl45>>TROUBLE.LOG
:010M05


:010N
    M2Make TlxPrep/pf=Generic/S=OVL
    c:\Command/c CmdFile TlxPrep (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TlxPrep at 010N>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010O
    M2L TlxPrep(TimeLine)
    IF NOT EXIST TlxPrep.OVL ECHO Link failure for TlxPrep>>TROUBLE.LOG

:010N01
        M2Make TlxCnfg/pf=Generic/S=OVL
        c:\Command/c CmdFile TlxCnfg (TlxPrep)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TlxCnfg at 010N01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010N02
        M2L TlxCnfg(TlxPrep)/o/b
        IF NOT EXIST TlxCnfg.OVL ECHO Link failure for TlxCnfg>>TROUBLE.LOG
:010N02


:010O
    M2Make TlxTl5/pf=Generic/S=OVL
    c:\Command/c CmdFile TlxTl5 (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TlxTl5 at 010O>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010P
    M2L TlxTl5(TimeLine)/o/b
    IF NOT EXIST TlxTl5.OVL ECHO Link failure for TlxTl45>>TROUBLE.LOG

:010P
    M2Make TLCr/pf=Generic/S=OVL
    c:\Command/c CmdFile TLCr (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLCr at 010P>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010Q
    M2L TLCr(TimeLine)
    IF NOT EXIST TLCr.OVL ECHO Link failure for TLCr>>TROUBLE.LOG

:010P01
        M2Make TLCrForm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCrForm (TLCr)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCrForm at 010P01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010P02
        M2L TLCrForm(TLCr)/o/b
        IF NOT EXIST TLCrForm.OVL ECHO Link failure for TLCrForm>>TROUBLE.LOG

:010P02
        M2Make TLCrWork/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCrWork (TLCr)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCrWork at 010P02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010P03
        M2L TLCrWork(TLCr)/o/b
        IF NOT EXIST TLCrWork.OVL ECHO Link failure for TLCrWork>>TROUBLE.LOG
:010P03


:010Q
    M2Make TLXPorts/pf=Generic/S=OVL
    c:\Command/c CmdFile TLXPorts (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLXPorts at 010Q>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010R
    M2L TLXPorts(TimeLine)/o/b
    IF NOT EXIST TLXPorts.OVL ECHO Link failure for TLXPorts>>TROUBLE.LOG

:010R
    M2Make TLRTable/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRTable (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRTable at 010R>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010S
    M2L TLRTable(TimeLine)/o/b
    IF NOT EXIST TLRTable.OVL ECHO Link failure for TLRTable>>TROUBLE.LOG

:010S
    M2Make TLTTable/pf=Generic/S=OVL
    c:\Command/c CmdFile TLTTable (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLTTable at 010S>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010T
    M2L TLTTable(TimeLine)/o/b
    IF NOT EXIST TLTTable.OVL ECHO Link failure for TLTTable>>TROUBLE.LOG

:010T
    M2Make TLXEdges/pf=Generic/S=OVL
    c:\Command/c CmdFile TLXEdges (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLXEdges at 010T>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010U
    M2L TLXEdges(TimeLine)/o/b
    IF NOT EXIST TLXEdges.OVL ECHO Link failure for TLXEdges>>TROUBLE.LOG

:010U
    M2Make TLXRsass/pf=Generic/S=OVL
    c:\Command/c CmdFile TLXRsass (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLXRsass at 010U>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010V
    M2L TLXRsass(TimeLine)/o/b
    IF NOT EXIST TLXRsass.OVL ECHO Link failure for TLXRsass>>TROUBLE.LOG

:010V
    M2Make TLXDB/pf=Generic/S=OVL
    c:\Command/c CmdFile TLXDB (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLXDB at 010V>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010X
    M2L TLXDB(TimeLine)
    IF NOT EXIST TLXDB.OVL ECHO Link failure for TLXDB>>TROUBLE.LOG

:010V01
        M2Make TLXDB3/pf=Generic/S=OVL
        c:\Command/c CmdFile TLXDB3 (TLXDB)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLXDB3 at 010V01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010V02
        M2L TLXDB3(TLXDB)/o/b
        IF NOT EXIST TLXDB3.OVL ECHO Link failure for TLXDB3>>TROUBLE.LOG

:010V02
        M2Make TLXCSV/pf=Generic/S=OVL
        c:\Command/c CmdFile TLXCSV (TLXDB)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLXCSV at 010V02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010V03
        M2L TLXCSV(TLXDB)/o/b
        IF NOT EXIST TLXCSV.OVL ECHO Link failure for TLXCSV>>TROUBLE.LOG

:010V03
        M2Make TLXPLCSV/pf=Generic/S=OVL
        c:\Command/c CmdFile TLXPLCSV (TLXDB)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLXPLCSV at 010V03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010V04
        M2L TLXPLCSV(TLXDB)/o/b
        IF NOT EXIST TLXPLCSV.OVL ECHO Link failure for TLXPLCSV>>TROUBLE.LOG

:010V04
        M2Make TLXTLCSV/pf=Generic/S=OVL
        c:\Command/c CmdFile TLXTLCSV (TLXDB)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLXTLCSV at 010V04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010V05
        M2L TLXTLCSV(TLXDB)/o/b
        IF NOT EXIST TLXTLCSV.OVL ECHO Link failure for TLXTLCSV>>TROUBLE.LOG
:010V05


:010X
    M2Make TLSETCSV/pf=Generic/S=OVL
    c:\Command/c CmdFile TLSETCSV (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLSETCSV at 010X>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010Y
    M2L TLSETCSV(TimeLine)/o/b
    IF NOT EXIST TLSETCSV.OVL ECHO Link failure for TLSETCSV>>TROUBLE.LOG

:010Y
    M2Make TLX123/pf=Generic/S=OVL
    c:\Command/c CmdFile TLX123 (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLX123 at 010Y>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010Z
    M2L TLX123(TimeLine)
    IF NOT EXIST TLX123.OVL ECHO Link failure for TLX123>>TROUBLE.LOG

:010Y01
        M2Make TL1D123/pf=Generic/S=OVL
        c:\Command/c CmdFile TL1D123 (TLX123)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TL1D123 at 010Y01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010Y02
        M2L TL1D123(TLX123)/o/b
        IF NOT EXIST TL1D123.OVL ECHO Link failure for TL1D123>>TROUBLE.LOG

:010Y02
        M2Make TL2D123/pf=Generic/S=OVL
        c:\Command/c CmdFile TL2D123 (TLX123)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TL2D123 at 010Y02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010Y03
        M2L TL2D123(TLX123)/o/b
        IF NOT EXIST TL2D123.OVL ECHO Link failure for TL2D123>>TROUBLE.LOG
:010Y03


:010Z
    M2Make TLXEXCEL/pf=Generic/S=OVL
    c:\Command/c CmdFile TLXEXCEL (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLXEXCEL at 010Z>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0110
    M2L TLXEXCEL(TimeLine)
    IF NOT EXIST TLXEXCEL.OVL ECHO Link failure for TLXEXCEL>>TROUBLE.LOG

:010Z01
        M2Make TL1DXCEL/pf=Generic/S=OVL
        c:\Command/c CmdFile TL1DXCEL (TLXEXCEL)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TL1DXCEL at 010Z01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010Z02
        M2L TL1DXCEL(TLXEXCEL)/o/b
        IF NOT EXIST TL1DXCEL.OVL ECHO Link failure for TL1DXCEL>>TROUBLE.LOG

:010Z02
        M2Make TL2DXCEL/pf=Generic/S=OVL
        c:\Command/c CmdFile TL2DXCEL (TLXEXCEL)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TL2DXCEL at 010Z02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010Z03
        M2L TL2DXCEL(TLXEXCEL)/o/b
        IF NOT EXIST TL2DXCEL.OVL ECHO Link failure for TL2DXCEL>>TROUBLE.LOG
:010Z03


:0110
    M2Make TLRPBase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRPBase (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLRPBase at 0110>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0111
    M2L TLRPBase(TimeLine)
    IF NOT EXIST TLRPBase.OVL ECHO Link failure for TLRPBase>>TROUBLE.LOG

:011001
        M2Make TLGr/pf=Generic/S=OVL
        c:\Command/c CmdFile TLGr (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLGr at 011001>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011002
        M2L TLGr(TLRPBase)/o/b
        IF NOT EXIST TLGr.OVL ECHO Link failure for TLGr>>TROUBLE.LOG

        M2Make TLrr/pf=Generic/S=OVL
        c:\Command/c CmdFile TLrr (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLrr at 011001>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011002
        M2L TLrr(TLRPBase)/o/b
        IF NOT EXIST TLrr.OVL ECHO Link failure for TLrr>>TROUBLE.LOG


:011002
        M2Make TLPrt1D/pf=Generic/S=OVL
        c:\Command/c CmdFile TLPrt1D (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLPrt1D at 011002>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011003
        M2L TLPrt1D(TLRPBase)/o/b
        IF NOT EXIST TLPrt1D.OVL ECHO Link failure for TLPrt1D>>TROUBLE.LOG

:011003
        M2Make TLPrt2D/pf=Generic/S=OVL
        c:\Command/c CmdFile TLPrt2D (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLPrt2D at 011003>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011004
        M2L TLPrt2D(TLRPBase)/o/b
        IF NOT EXIST TLPrt2D.OVL ECHO Link failure for TLPrt2D>>TROUBLE.LOG

:011004
        M2Make TLHR/pf=Generic/S=OVL
        c:\Command/c CmdFile TLHR (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLHR at 011004>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011005
        M2L TLHR(TLRPBase)/o/b
        IF NOT EXIST TLHR.OVL ECHO Link failure for TLHR>>TROUBLE.LOG

:011005
        M2Make ViReport/pf=Generic/S=OVL
        c:\Command/c CmdFile ViReport (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on ViReport at 011005>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011006
        M2L ViReport(TLRPBase)/o/b
        IF NOT EXIST ViReport.OVL ECHO Link failure for ViReport>>TROUBLE.LOG

:011006
        M2Make TLAr/pf=Generic/S=OVL
        c:\Command/c CmdFile TLAr (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLAr at 011006>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011007
        M2L TLAr(TLRPBase)/o/b
        IF NOT EXIST TLAr.OVL ECHO Link failure for TLAr>>TROUBLE.LOG

:011007
        M2Make TLArOptn/pf=Generic/S=OVL
        c:\Command/c CmdFile TLArOptn (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLArOptn at 011007>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011008
        M2L TLArOptn(TLRPBase)/o/b
        IF NOT EXIST TLArOptn.OVL ECHO Link failure for TLArOptn>>TROUBLE.LOG

:011008
        M2Make TLDr/pf=Generic/S=OVL
        c:\Command/c CmdFile TLDr (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDr at 011008>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011009
        M2L TLDr(TLRPBase)/o/b
        IF NOT EXIST TLDr.OVL ECHO Link failure for TLDr>>TROUBLE.LOG

:011009
        M2Make TLSr/pf=Generic/S=OVL
        c:\Command/c CmdFile TLSr (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSr at 011009>>TROUBLE.LOG
        IF EXIST *.LST GOTO 01100A
        M2L TLSr(TLRPBase)/o/b
        IF NOT EXIST TLSr.OVL ECHO Link failure for TLSr>>TROUBLE.LOG

:01100A
        M2Make TLSrOptn/pf=Generic/S=OVL
        c:\Command/c CmdFile TLSrOptn (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSrOptn at 01100A>>TROUBLE.LOG
        IF EXIST *.LST GOTO 01100B
        M2L TLSrOptn(TLRPBase)/o/b
        IF NOT EXIST TLSrOptn.OVL ECHO Link failure for TLSrOptn>>TROUBLE.LOG
:01100B


:0111
    M2Make TLGlue/pf=Generic/S=OVL
    c:\Command/c CmdFile TLGlue (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLGlue at 0111>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0112
    M2L TLGlue(TimeLine)/o/b
    IF NOT EXIST TLGlue.OVL ECHO Link failure for TLGlue>>TROUBLE.LOG

:0112
    M2Make TLRollem/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRollem (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRollem at 0112>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0113
    M2L TLRollem(TimeLine)/o/b
    IF NOT EXIST TLRollem.OVL ECHO Link failure for TLRollem>>TROUBLE.LOG

:0113

:0114
    M2Make TLLnkSum/pf=Generic/S=OVL
    c:\Command/c CmdFile TLLnkSum (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLLnkSum at 0114>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0115
    M2L TLLnkSum(TimeLine)/o/b
    IF NOT EXIST TLLnkSum.OVL ECHO Link failure for TLLnkSum>>TROUBLE.LOG

:0115
    M2Make TLEdits/pf=Generic/S=OVL
    c:\Command/c CmdFile TLEdits (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLEdits at 0115>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0116
    M2L TLEdits(TimeLine)/o/b
    IF NOT EXIST TLEdits.OVL ECHO Link failure for TLEdits>>TROUBLE.LOG

:0116
    M2Make TLHelper/pf=Generic/S=OVL
    c:\Command/c CmdFile TLHelper (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLHelper at 0116>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0117
    M2L TLHelper(TimeLine)/o/b
    IF NOT EXIST TLHelper.OVL ECHO Link failure for TLHelper>>TROUBLE.LOG

:0117
    M2Make TLMKBase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMKBase (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMKBase at 0117>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0118
    M2L TLMKBase(TimeLine)/o/b
    IF NOT EXIST TLMKBase.OVL ECHO Link failure for TLMKBase>>TROUBLE.LOG

:0118
    M2Make TLSort/pf=Generic/S=OVL
    c:\Command/c CmdFile TLSort (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLSort at 0118>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0119
    M2L TLSort(TimeLine)/o/b
    IF NOT EXIST TLSort.OVL ECHO Link failure for TLSort>>TROUBLE.LOG

:0119
    M2Make TLFileMG/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFileMG (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLFileMG at 0119>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011A
    M2L TLFileMG(TimeLine)/o/b
    IF NOT EXIST TLFileMG.OVL ECHO Link failure for TLFileMG>>TROUBLE.LOG

:011A

:011B
    M2Make TLSetVid/pf=Generic/S=OVL
    c:\Command/c CmdFile TLSetVid (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLSetVid at 011B>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011C
    M2L TLSetVid(TimeLine)/o/b
    IF NOT EXIST TLSetVid.OVL ECHO Link failure for TLSetVid>>TROUBLE.LOG

:011C
    M2Make TLDOS/pf=Generic/S=OVL
    c:\Command/c CmdFile TLDOS (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLDOS at 011C>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011D
    M2L TLDOS(TimeLine)/o/b
    IF NOT EXIST TLDOS.OVL ECHO Link failure for TLDOS>>TROUBLE.LOG

:011D
    M2Make TLPSetup/pf=Generic/S=OVL
    c:\Command/c CmdFile TLPSetup (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLPSetup at 011D>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011E
    M2L TLPSetup(TimeLine)/o/b
    IF NOT EXIST TLPSetup.OVL ECHO Link failure for TLPSetup>>TROUBLE.LOG

:011E
:011E08


:011F
    M2Make TLIOutln/pf=Generic/S=OVL
    c:\Command/c CmdFile TLIOutln (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLIOutln at 011F>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011G
    M2L TLIOutln(TimeLine)/o/b
    IF NOT EXIST TLIOutln.OVL ECHO Link failure for TLIOutln>>TROUBLE.LOG

:011G
    M2Make TLFmtInt/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFmtInt (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLFmtInt at 011G>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011H
    M2L TLFmtInt(TimeLine)/o/b
    IF NOT EXIST TLFmtInt.OVL ECHO Link failure for TLFmtInt>>TROUBLE.LOG

:011H
    M2Make TLAlarm/pf=Generic/S=OVL
    c:\Command/c CmdFile TLAlarm (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLAlarm at 011H>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011I
    M2L TLAlarm(TimeLine)/o/b
    IF NOT EXIST TLAlarm.OVL ECHO Link failure for TLAlarm>>TROUBLE.LOG

:011I
    M2Make TLImport/pf=Generic/S=OVL
    c:\Command/c CmdFile TLImport (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLImport at 011I>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011J
    M2L TLImport(TimeLine)
    IF NOT EXIST TLImport.OVL ECHO Link failure for TLImport>>TROUBLE.LOG

:011I01
        M2Make TLITasks/pf=Generic/S=OVL
        c:\Command/c CmdFile TLITasks (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLITasks at 011I01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011I02
        M2L TLITasks(TLImport)/o/b
        IF NOT EXIST TLITasks.OVL ECHO Link failure for TLITasks>>TROUBLE.LOG

:011I02
        M2Make TLIRsrc/pf=Generic/S=OVL
        c:\Command/c CmdFile TLIRsrc (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLIRsrc at 011I02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011I03
        M2L TLIRsrc(TLImport)/o/b
        IF NOT EXIST TLIRsrc.OVL ECHO Link failure for TLIRsrc>>TROUBLE.LOG

:011I03
        M2Make TLIAss/pf=Generic/S=OVL
        c:\Command/c CmdFile TLIAss (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLIAss at 011I03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011I04
        M2L TLIAss(TLImport)/o/b
        IF NOT EXIST TLIAss.OVL ECHO Link failure for TLIAss>>TROUBLE.LOG

:011I04
        M2Make TLIEdges/pf=Generic/S=OVL
        c:\Command/c CmdFile TLIEdges (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLIEdges at 011I04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011I05
        M2L TLIEdges(TLImport)/o/b
        IF NOT EXIST TLIEdges.OVL ECHO Link failure for TLIEdges>>TROUBLE.LOG

:011I05
        M2Make TLCSVImp/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCSVImp (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCSVImp at 011I05>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011I06
        M2L TLCSVImp(TLImport)/o/b
        IF NOT EXIST TLCSVImp.OVL ECHO Link failure for TLCSVImp>>TROUBLE.LOG

:011I06
        M2Make TL123Imp/pf=Generic/S=OVL
        c:\Command/c CmdFile TL123Imp (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TL123Imp at 011I06>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011I07
        M2L TL123Imp(TLImport)/o/b
        IF NOT EXIST TL123Imp.OVL ECHO Link failure for TL123Imp>>TROUBLE.LOG

:011I07
        M2Make TLDB3Imp/pf=Generic/S=OVL
        c:\Command/c CmdFile TLDB3Imp (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDB3Imp at 011I07>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011I08
        M2L TLDB3Imp(TLImport)/o/b
        IF NOT EXIST TLDB3Imp.OVL ECHO Link failure for TLDB3Imp>>TROUBLE.LOG

:011I08
        M2Make TLXLSImp/pf=Generic/S=OVL
        c:\Command/c CmdFile TLXLSImp (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLXLSImp at 011I08>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011I09
        M2L TLXLSImp(TLImport)/o/b
        IF NOT EXIST TLXLSImp.OVL ECHO Link failure for TLXLSImp>>TROUBLE.LOG

:011I09
        M2Make TLEndImp/pf=Generic/S=OVL
        c:\Command/c CmdFile TLEndImp (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLEndImp at 011I09>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011I0A
        M2L TLEndImp(TLImport)/o/b
        IF NOT EXIST TLEndImp.OVL ECHO Link failure for TLEndImp>>TROUBLE.LOG
:011I0A


:011J
    M2Make TLSpread/pf=Generic/S=OVL
    c:\Command/c CmdFile TLSpread (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLSpread at 011J>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011K
    M2L TLSpread(TimeLine)/o/b
    IF NOT EXIST TLSpread.OVL ECHO Link failure for TLSpread>>TROUBLE.LOG

:011K
rem     M2Make TLShowJo/pf=Generic/S=OVL
rem     c:\Command/c CmdFile TLShowJo (TimeLine)/o/b OVL
rem     IF EXIST *.LST ECHO Compile failure on TLShowJo at 011K>>TROUBLE.LOG
rem     IF EXIST *.LST GOTO 011L
rem     M2L TLShowJo(TimeLine)/o/b
rem     IF NOT EXIST TLShowJo.OVL ECHO Link failure for TLShowJo>>TROUBLE.LOG



:011S
    M2Make TL3Cnfg/pf=Generic/S=OVL
    c:\Command/c CmdFile TL3Cnfg (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TL3Cnfg at 011S>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011T
    M2L TL3Cnfg(TimeLine)/o/b
    IF NOT EXIST TL3Cnfg.OVL ECHO Link failure for TL3Cnfg>>TROUBLE.LOG

:011T
    M2Make TLErase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLErase (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLErase at 011T>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011U
    M2L TLErase(TimeLine)/o/b
    IF NOT EXIST TLErase.OVL ECHO Link failure for TLErase>>TROUBLE.LOG

:011U
    M2Make TLRenum/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRenum (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRenum at 011U>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011V
    M2L TLRenum(TimeLine)/o/b
    IF NOT EXIST TLRenum.OVL ECHO Link failure for TLRenum>>TROUBLE.LOG

:011V
:011V0L


:011X
    M2Make TLMagic/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMagic (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMagic at 011X>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011Y
    M2L TLMagic(TimeLine)/o/b
    IF NOT EXIST TLMagic.OVL ECHO Link failure for TLMagic>>TROUBLE.LOG

:011Y
    M2Make TLLogger/pf=Generic/S=OVL
    c:\Command/c CmdFile TLLogger (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLLogger at 011Y>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011Z
    M2L TLLogger(TimeLine)/o/b
    IF NOT EXIST TLLogger.OVL ECHO Link failure for TLLogger>>TROUBLE.LOG

:011Z
    M2Make TLTimer/pf=Generic/S=OVL
    c:\Command/c CmdFile TLTimer (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLTimer at 011Z>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0120
    M2L TLTimer(TimeLine)/o/b
    IF NOT EXIST TLTimer.OVL ECHO Link failure for TLTimer>>TROUBLE.LOG

:0120
    M2Make TLKodak/pf=Generic/S=OVL
    c:\Command/c CmdFile TLKodak (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLKodak at 0120>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0121
    M2L TLKodak(TimeLine)/o/b
    IF NOT EXIST TLKodak.OVL ECHO Link failure for TLKodak>>TROUBLE.LOG

:0121
    M2Make TLLocker/pf=Generic/S=OVL
    c:\Command/c CmdFile TLLocker (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLLocker at 0121>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0122
    M2L TLLocker(TimeLine)/o/b
    IF NOT EXIST TLLocker.OVL ECHO Link failure for TLLocker>>TROUBLE.LOG

:0122
    M2Make TLMagic2/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMagic2 (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMagic2 at 0122>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0123
    M2L TLMagic2(TimeLine)/o/b
    IF NOT EXIST TLMagic2.OVL ECHO Link failure for TLMagic2>>TROUBLE.LOG

:0123
    M2Make TLChkSum/pf=Generic/S=OVL
    c:\Command/c CmdFile TLChkSum (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLChkSum at 0123>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0124
    M2L TLChkSum(TimeLine)/o/b
    IF NOT EXIST TLChkSum.OVL ECHO Link failure for TLChkSum>>TROUBLE.LOG

:02
IF EXIST AFCOMPIL.BAT c:\COMMAND/C AFCOMPIL.BAT
:LOGOUT
