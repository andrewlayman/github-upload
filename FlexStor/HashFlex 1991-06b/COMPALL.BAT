Rem   Batch file built by REBUILD on 03-10-1991 at 18:11:36
Rem        Exclude items with 'MACRO'
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
c:\Command/c CmdFile TimeLine /s=15000/b EXE
IF EXIST *.LST ECHO Compile failure on TimeLine at 01>>TROUBLE.LOG
IF EXIST *.LST GOTO 02
M2L TimeLine/s=15000/b
IF NOT EXIST TimeLine.EXE ECHO Link failure for TimeLine>>TROUBLE.LOG

:0101
    M2Make TLStats/pf=Generic/S=OVL
    c:\Command/c CmdFile TLStats (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLStats at 0101>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0102
    M2L TLStats(TimeLine)/o/b
    IF NOT EXIST TLStats.OVL ECHO Link failure for TLStats>>TROUBLE.LOG

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
    M2Make TLReg/pf=Generic/S=OVL
    c:\Command/c CmdFile TLReg (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLReg at 0104>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0105
    M2L TLReg(TimeLine)/o/b
    IF NOT EXIST TLReg.OVL ECHO Link failure for TLReg>>TROUBLE.LOG

:0105
    M2Make TLMain/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMain (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMain at 0105>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0106
    M2L TLMain(TimeLine)/o/b
    IF NOT EXIST TLMain.OVL ECHO Link failure for TLMain>>TROUBLE.LOG

:0106
    M2Make TLEMS/pf=Generic/S=OVL
    c:\Command/c CmdFile TLEMS (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLEMS at 0106>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0107
    M2L TLEMS(TimeLine)/o/b
    IF NOT EXIST TLEMS.OVL ECHO Link failure for TLEMS>>TROUBLE.LOG

:0107
    M2Make TLSwapF/pf=Generic/S=OVL
    c:\Command/c CmdFile TLSwapF (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLSwapF at 0107>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0108
    M2L TLSwapF(TimeLine)/o/b
    IF NOT EXIST TLSwapF.OVL ECHO Link failure for TLSwapF>>TROUBLE.LOG

:0108
    M2Make TLBTSMac/pf=Generic/S=OVL
    c:\Command/c CmdFile TLBTSMac (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLBTSMac at 0108>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0109
    M2L TLBTSMac(TimeLine)/o/b
    IF NOT EXIST TLBTSMac.OVL ECHO Link failure for TLBTSMac>>TROUBLE.LOG

:0109
    M2Make TLCaptio/pf=Generic/S=OVL
    c:\Command/c CmdFile TLCaptio (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLCaptio at 0109>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010A
    M2L TLCaptio(TimeLine)/o/b
    IF NOT EXIST TLCaptio.OVL ECHO Link failure for TLCaptio>>TROUBLE.LOG

:010A
    M2Make TLMemoEd/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMemoEd (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMemoEd at 010A>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010B
    M2L TLMemoEd(TimeLine)/o/b
    IF NOT EXIST TLMemoEd.OVL ECHO Link failure for TLMemoEd>>TROUBLE.LOG

:010B
    M2Make TLFBase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFBase (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLFBase at 010B>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010C
    M2L TLFBase(TimeLine)
    IF NOT EXIST TLFBase.OVL ECHO Link failure for TLFBase>>TROUBLE.LOG

:010B01
        M2Make TLAssgn/pf=Generic/S=OVL
        c:\Command/c CmdFile TLAssgn (TLFBase) OVL
        IF EXIST *.LST ECHO Compile failure on TLAssgn at 010B01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B02
        M2L TLAssgn(TLFBase)
        IF NOT EXIST TLAssgn.OVL ECHO Link failure for TLAssgn>>TROUBLE.LOG

:010B0101
            M2Make TLChange/pf=Generic/S=OVL
            c:\Command/c CmdFile TLChange (TLAssgn)/o/b OVL
            IF EXIST *.LST ECHO Compile failure on TLChange at 010B0101>>TROUBLE.LOG
            IF EXIST *.LST GOTO 010B0102
            M2L TLChange(TLAssgn)/o/b
            IF NOT EXIST TLChange.OVL ECHO Link failure for TLChange>>TROUBLE.LOG
:010B0102


:010B02
        M2Make TLTAFORM/pf=Generic/S=OVL
        c:\Command/c CmdFile TLTAFORM (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLTAFORM at 010B02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B03
        M2L TLTAFORM(TLFBase)/o/b
        IF NOT EXIST TLTAFORM.OVL ECHO Link failure for TLTAFORM>>TROUBLE.LOG

:010B03
        M2Make TLRsrc/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRsrc (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRsrc at 010B03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B04
        M2L TLRsrc(TLFBase)/o/b
        IF NOT EXIST TLRsrc.OVL ECHO Link failure for TLRsrc>>TROUBLE.LOG

:010B04
        M2Make TLDOSFrm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLDOSFrm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDOSFrm at 010B04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B05
        M2L TLDOSFrm(TLFBase)/o/b
        IF NOT EXIST TLDOSFrm.OVL ECHO Link failure for TLDOSFrm>>TROUBLE.LOG

:010B05
        M2Make TLColNam/pf=Generic/S=OVL
        c:\Command/c CmdFile TLColNam (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLColNam at 010B05>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B06
        M2L TLColNam(TLFBase)/o/b
        IF NOT EXIST TLColNam.OVL ECHO Link failure for TLColNam>>TROUBLE.LOG

:010B06
        M2Make TLFForm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLFForm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLFForm at 010B06>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B07
        M2L TLFForm(TLFBase)/o/b
        IF NOT EXIST TLFForm.OVL ECHO Link failure for TLFForm>>TROUBLE.LOG

:010B07
        M2Make TLLink/pf=Generic/S=OVL
        c:\Command/c CmdFile TLLink (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLLink at 010B07>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B08
        M2L TLLink(TLFBase)/o/b
        IF NOT EXIST TLLink.OVL ECHO Link failure for TLLink>>TROUBLE.LOG

:010B08
        M2Make TLViewTL/pf=Generic/S=OVL
        c:\Command/c CmdFile TLViewTL (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLViewTL at 010B08>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B09
        M2L TLViewTL(TLFBase)/o/b
        IF NOT EXIST TLViewTL.OVL ECHO Link failure for TLViewTL>>TROUBLE.LOG

:010B09
        M2Make TLViewOT/pf=Generic/S=OVL
        c:\Command/c CmdFile TLViewOT (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLViewOT at 010B09>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0A
        M2L TLViewOT(TLFBase)/o/b
        IF NOT EXIST TLViewOT.OVL ECHO Link failure for TLViewOT>>TROUBLE.LOG

:010B0A
        M2Make TLDir411/pf=Generic/S=OVL
        c:\Command/c CmdFile TLDir411 (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDir411 at 010B0A>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0B
        M2L TLDir411(TLFBase)/o/b
        IF NOT EXIST TLDir411.OVL ECHO Link failure for TLDir411>>TROUBLE.LOG

:010B0B
        M2Make TLRepFor/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRepFor (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRepFor at 010B0B>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0C
        M2L TLRepFor(TLFBase)/o/b
        IF NOT EXIST TLRepFor.OVL ECHO Link failure for TLRepFor>>TROUBLE.LOG

:010B0C
        M2Make TLCalndr/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCalndr (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCalndr at 010B0C>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0D
        M2L TLCalndr(TLFBase)/o/b
        IF NOT EXIST TLCalndr.OVL ECHO Link failure for TLCalndr>>TROUBLE.LOG

:010B0D
        M2Make TLEdge/pf=Generic/S=OVL
        c:\Command/c CmdFile TLEdge (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLEdge at 010B0D>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0E
        M2L TLEdge(TLFBase)/o/b
        IF NOT EXIST TLEdge.OVL ECHO Link failure for TLEdge>>TROUBLE.LOG

:010B0E
        M2Make TL2Form/pf=Generic/S=OVL
        c:\Command/c CmdFile TL2Form (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TL2Form at 010B0E>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0F
        M2L TL2Form(TLFBase)/o/b
        IF NOT EXIST TL2Form.OVL ECHO Link failure for TL2Form>>TROUBLE.LOG

:010B0F
        M2Make TLRHForm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRHForm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRHForm at 010B0F>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0G
        M2L TLRHForm(TLFBase)/o/b
        IF NOT EXIST TLRHForm.OVL ECHO Link failure for TLRHForm>>TROUBLE.LOG

:010B0G

:010B0H
        M2Make TLSchFor/pf=Generic/S=OVL
        c:\Command/c CmdFile TLSchFor (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSchFor at 010B0H>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0I
        M2L TLSchFor(TLFBase)/o/b
        IF NOT EXIST TLSchFor.OVL ECHO Link failure for TLSchFor>>TROUBLE.LOG

:010B0I
        M2Make TLLayout/pf=Generic/S=OVL
        c:\Command/c CmdFile TLLayout (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLLayout at 010B0I>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0J
        M2L TLLayout(TLFBase)/o/b
        IF NOT EXIST TLLayout.OVL ECHO Link failure for TLLayout>>TROUBLE.LOG

:010B0J
        M2Make TLFltFrm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLFltFrm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLFltFrm at 010B0J>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0K
        M2L TLFltFrm(TLFBase)/o/b
        IF NOT EXIST TLFltFrm.OVL ECHO Link failure for TLFltFrm>>TROUBLE.LOG

:010B0K
        M2Make TLXForm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLXForm (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLXForm at 010B0K>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0L
        M2L TLXForm(TLFBase)/o/b
        IF NOT EXIST TLXForm.OVL ECHO Link failure for TLXForm>>TROUBLE.LOG

:010B0L

:010B0M
        M2Make TLXSSOpt/pf=Generic/S=OVL
        c:\Command/c CmdFile TLXSSOpt (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLXSSOpt at 010B0M>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0N
        M2L TLXSSOpt(TLFBase)/o/b
        IF NOT EXIST TLXSSOpt.OVL ECHO Link failure for TLXSSOpt>>TROUBLE.LOG

:010B0N

:010B0O
        M2Make TLAsList/pf=Generic/S=OVL
        c:\Command/c CmdFile TLAsList (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLAsList at 010B0O>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0P
        M2L TLAsList(TLFBase)/o/b
        IF NOT EXIST TLAsList.OVL ECHO Link failure for TLAsList>>TROUBLE.LOG

:010B0P

:010B0X
        M2Make TLCalcul/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCalcul (TLFBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCalcul at 010B0X>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010B0Y
        M2L TLCalcul(TLFBase)/o/b
        IF NOT EXIST TLCalcul.OVL ECHO Link failure for TLCalcul>>TROUBLE.LOG
:010B0Y


:010C
    M2Make TLFilter/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFilter (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLFilter at 010C>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010D
    M2L TLFilter(TimeLine)/o/b
    IF NOT EXIST TLFilter.OVL ECHO Link failure for TLFilter>>TROUBLE.LOG

:010D
    M2Make TLFSelct/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFSelct (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLFSelct at 010D>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010E
    M2L TLFSelct(TimeLine)/o/b
    IF NOT EXIST TLFSelct.OVL ECHO Link failure for TLFSelct>>TROUBLE.LOG

:010E
    M2Make TLTaskLi/pf=Generic/S=OVL
    c:\Command/c CmdFile TLTaskLi (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLTaskLi at 010E>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010F
    M2L TLTaskLi(TimeLine)/o/b
    IF NOT EXIST TLTaskLi.OVL ECHO Link failure for TLTaskLi>>TROUBLE.LOG

:010F
    M2Make TLGoTo/pf=Generic/S=OVL
    c:\Command/c CmdFile TLGoTo (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLGoTo at 010F>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010G
    M2L TLGoTo(TimeLine)/o/b
    IF NOT EXIST TLGoTo.OVL ECHO Link failure for TLGoTo>>TROUBLE.LOG

:010G
    M2Make TLDepend/pf=Generic/S=OVL
    c:\Command/c CmdFile TLDepend (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLDepend at 010G>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010H
    M2L TLDepend(TimeLine)/o/b
    IF NOT EXIST TLDepend.OVL ECHO Link failure for TLDepend>>TROUBLE.LOG

:010H
    M2Make TLRHist/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRHist (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRHist at 010H>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010I
    M2L TLRHist(TimeLine)/o/b
    IF NOT EXIST TLRHist.OVL ECHO Link failure for TLRHist>>TROUBLE.LOG

:010I
    M2Make TLRsrcEd/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRsrcEd (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRsrcEd at 010I>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010J
    M2L TLRsrcEd(TimeLine)/o/b
    IF NOT EXIST TLRsrcEd.OVL ECHO Link failure for TLRsrcEd>>TROUBLE.LOG

:010J
    M2Make TLLayLis/pf=Generic/S=OVL
    c:\Command/c CmdFile TLLayLis (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLLayLis at 010J>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010K
    M2L TLLayLis(TimeLine)/o/b
    IF NOT EXIST TLLayLis.OVL ECHO Link failure for TLLayLis>>TROUBLE.LOG

:010K
    M2Make TLPlan/pf=Generic/S=OVL
    c:\Command/c CmdFile TLPlan (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLPlan at 010K>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010L
    M2L TLPlan(TimeLine)
    IF NOT EXIST TLPlan.OVL ECHO Link failure for TLPlan>>TROUBLE.LOG

:010K01
        M2Make TLRPlan/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRPlan (TLPlan)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRPlan at 010K01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010K02
        M2L TLRPlan(TLPlan)/o/b
        IF NOT EXIST TLRPlan.OVL ECHO Link failure for TLRPlan>>TROUBLE.LOG

:010K02
        M2Make TLLoops/pf=Generic/S=OVL
        c:\Command/c CmdFile TLLoops (TLPlan)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLLoops at 010K02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010K03
        M2L TLLoops(TLPlan)/o/b
        IF NOT EXIST TLLoops.OVL ECHO Link failure for TLLoops>>TROUBLE.LOG

:010K03
        M2Make TLCPM/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCPM (TLPlan)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCPM at 010K03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010K04
        M2L TLCPM(TLPlan)/o/b
        IF NOT EXIST TLCPM.OVL ECHO Link failure for TLCPM>>TROUBLE.LOG

:010K04
        M2Make TLplanEX/pf=Generic/S=OVL
        c:\Command/c CmdFile TLplanEX (TLPlan)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLplanEX at 010K04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010K05
        M2L TLplanEX(TLPlan)/o/b
        IF NOT EXIST TLplanEX.OVL ECHO Link failure for TLplanEX>>TROUBLE.LOG
:010K05


:010L
    M2Make TLGetIt/pf=Generic/S=OVL
    c:\Command/c CmdFile TLGetIt (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLGetIt at 010L>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010M
    M2L TLGetIt(TimeLine)
    IF NOT EXIST TLGetIt.OVL ECHO Link failure for TLGetIt>>TROUBLE.LOG

:010L01
        M2Make TLStart/pf=Generic/S=OVL
        c:\Command/c CmdFile TLStart (TLGetIt)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLStart at 010L01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010L02
        M2L TLStart(TLGetIt)/o/b
        IF NOT EXIST TLStart.OVL ECHO Link failure for TLStart>>TROUBLE.LOG

:010L04
        M2Make TLiTl4/pf=Generic/S=OVL
        c:\Command/c CmdFile TLiTl4 (TLGetIt)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLiTl4 at 010L04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010L05
        M2L TLiTl4(TLGetIt)/o/b
        IF NOT EXIST TLiTl4.OVL ECHO Link failure for TLiTl4>>TROUBLE.LOG

:010L05
        M2Make TLiTl5/pf=Generic/S=OVL
        c:\Command/c CmdFile TLiTl5 (TLGetIt)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLiTl5 at 010L05>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010L06
        M2L TLiTl5(TLGetIt)/o/b
        IF NOT EXIST TLiTl5.OVL ECHO Link failure for TLiTl45>>TROUBLE.LOG
:010L06


:010M
    M2Make TlxPrep/pf=Generic/S=OVL
    c:\Command/c CmdFile TlxPrep (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TlxPrep at 010M>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010N
    M2L TlxPrep(TimeLine)
    IF NOT EXIST TlxPrep.OVL ECHO Link failure for TlxPrep>>TROUBLE.LOG

:010M01
        M2Make TlxCnfg/pf=Generic/S=OVL
        c:\Command/c CmdFile TlxCnfg (TlxPrep)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TlxCnfg at 010M01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010M02
        M2L TlxCnfg(TlxPrep)/o/b
        IF NOT EXIST TlxCnfg.OVL ECHO Link failure for TlxCnfg>>TROUBLE.LOG
:010M02


:010N
    M2Make TlxTl5/pf=Generic/S=OVL
    c:\Command/c CmdFile TlxTl5 (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TlxTl5 at 010N>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010O
    M2L TlxTl5(TimeLine)/o/b
    IF NOT EXIST TlxTl5.OVL ECHO Link failure for TlxTl45>>TROUBLE.LOG

:010O
    M2Make TLCr/pf=Generic/S=OVL
    c:\Command/c CmdFile TLCr (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLCr at 010O>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010P
    M2L TLCr(TimeLine)
    IF NOT EXIST TLCr.OVL ECHO Link failure for TLCr>>TROUBLE.LOG

:010O01
        M2Make TLCrForm/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCrForm (TLCr)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCrForm at 010O01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010O02
        M2L TLCrForm(TLCr)/o/b
        IF NOT EXIST TLCrForm.OVL ECHO Link failure for TLCrForm>>TROUBLE.LOG

:010O02
        M2Make TLCrWork/pf=Generic/S=OVL
        c:\Command/c CmdFile TLCrWork (TLCr)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLCrWork at 010O02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010O03
        M2L TLCrWork(TLCr)/o/b
        IF NOT EXIST TLCrWork.OVL ECHO Link failure for TLCrWork>>TROUBLE.LOG
:010O03


:010P
    M2Make TLXPorts/pf=Generic/S=OVL
    c:\Command/c CmdFile TLXPorts (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLXPorts at 010P>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010Q
    M2L TLXPorts(TimeLine)/o/b
    IF NOT EXIST TLXPorts.OVL ECHO Link failure for TLXPorts>>TROUBLE.LOG

:010Q
    M2Make TLXEdges/pf=Generic/S=OVL
    c:\Command/c CmdFile TLXEdges (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLXEdges at 010Q>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010R
    M2L TLXEdges(TimeLine)/o/b
    IF NOT EXIST TLXEdges.OVL ECHO Link failure for TLXEdges>>TROUBLE.LOG

:010R
    M2Make TLXRsass/pf=Generic/S=OVL
    c:\Command/c CmdFile TLXRsass (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLXRsass at 010R>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010S
    M2L TLXRsass(TimeLine)/o/b
    IF NOT EXIST TLXRsass.OVL ECHO Link failure for TLXRsass>>TROUBLE.LOG



:010X
    M2Make TLRPBase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRPBase (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLRPBase at 010X>>TROUBLE.LOG
    IF EXIST *.LST GOTO 010Y
    M2L TLRPBase(TimeLine)
    IF NOT EXIST TLRPBase.OVL ECHO Link failure for TLRPBase>>TROUBLE.LOG

:010X01
        M2Make TLRTable/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRTable (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRTable at 010X01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X02
        M2L TLRTable(TLRPBase)/o/b
        IF NOT EXIST TLRTable.OVL ECHO Link failure for TLRTable>>TROUBLE.LOG

:010X02
        M2Make TLTTable/pf=Generic/S=OVL
        c:\Command/c CmdFile TLTTable (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLTTable at 010X02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X03
        M2L TLTTable(TLRPBase)/o/b
        IF NOT EXIST TLTTable.OVL ECHO Link failure for TLTTable>>TROUBLE.LOG

:010X03
        M2Make TLGr/pf=Generic/S=OVL
        c:\Command/c CmdFile TLGr (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLGr at 010X03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X04
        M2L TLGr(TLRPBase)/o/b
        IF NOT EXIST TLGr.OVL ECHO Link failure for TLGr>>TROUBLE.LOG

:010X04
        M2Make TLPrt1D/pf=Generic/S=OVL
        c:\Command/c CmdFile TLPrt1D (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLPrt1D at 010X04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X05
        M2L TLPrt1D(TLRPBase)/o/b
        IF NOT EXIST TLPrt1D.OVL ECHO Link failure for TLPrt1D>>TROUBLE.LOG

:010X05
        M2Make TLPrt2D/pf=Generic/S=OVL
        c:\Command/c CmdFile TLPrt2D (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLPrt2D at 010X05>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X06
        M2L TLPrt2D(TLRPBase)/o/b
        IF NOT EXIST TLPrt2D.OVL ECHO Link failure for TLPrt2D>>TROUBLE.LOG

:010X06
        M2Make TLHR/pf=Generic/S=OVL
        c:\Command/c CmdFile TLHR (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLHR at 010X06>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X07
        M2L TLHR(TLRPBase)/o/b
        IF NOT EXIST TLHR.OVL ECHO Link failure for TLHR>>TROUBLE.LOG

:010X07

:010X08
        M2Make TLAr/pf=Generic/S=OVL
        c:\Command/c CmdFile TLAr (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLAr at 010X08>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X09
        M2L TLAr(TLRPBase)/o/b
        IF NOT EXIST TLAr.OVL ECHO Link failure for TLAr>>TROUBLE.LOG

:010X09
        M2Make TLArOptn/pf=Generic/S=OVL
        c:\Command/c CmdFile TLArOptn (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLArOptn at 010X09>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X0A
        M2L TLArOptn(TLRPBase)/o/b
        IF NOT EXIST TLArOptn.OVL ECHO Link failure for TLArOptn>>TROUBLE.LOG

:010X0A
        M2Make TLDr/pf=Generic/S=OVL
        c:\Command/c CmdFile TLDr (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDr at 010X0A>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X0B
        M2L TLDr(TLRPBase)/o/b
        IF NOT EXIST TLDr.OVL ECHO Link failure for TLDr>>TROUBLE.LOG

:010X0B
        M2Make TLSr/pf=Generic/S=OVL
        c:\Command/c CmdFile TLSr (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSr at 010X0B>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X0C
        M2L TLSr(TLRPBase)/o/b
        IF NOT EXIST TLSr.OVL ECHO Link failure for TLSr>>TROUBLE.LOG

:010X0C
        M2Make TLSrOptn/pf=Generic/S=OVL
        c:\Command/c CmdFile TLSrOptn (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSrOptn at 010X0C>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X0D
        M2L TLSrOptn(TLRPBase)/o/b
        IF NOT EXIST TLSrOptn.OVL ECHO Link failure for TLSrOptn>>TROUBLE.LOG

:010X0D
        M2Make TLRR/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRR (TLRPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRR at 010X0D>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010X0E
        M2L TLRR(TLRPBase)/o/b
        IF NOT EXIST TLRR.OVL ECHO Link failure for TLRR>>TROUBLE.LOG
:010X0E


:010Y

:010Z
    M2Make TLRollem/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRollem (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLRollem at 010Z>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0110
    M2L TLRollem(TimeLine)
    IF NOT EXIST TLRollem.OVL ECHO Link failure for TLRollem>>TROUBLE.LOG

:010Z01
        M2Make TLLnkSum/pf=Generic/S=OVL
        c:\Command/c CmdFile TLLnkSum (TLRollem)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLLnkSum at 010Z01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010Z02
        M2L TLLnkSum(TLRollem)/o/b
        IF NOT EXIST TLLnkSum.OVL ECHO Link failure for TLLnkSum>>TROUBLE.LOG

:010Z02
        M2Make TLLnkOT/pf=Generic/S=OVL
        c:\Command/c CmdFile TLLnkOT (TLRollem)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLLnkOT at 010Z02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 010Z03
        M2L TLLnkOT(TLRollem)/o/b
        IF NOT EXIST TLLnkOT.OVL ECHO Link failure for TLLnkOT>>TROUBLE.LOG
:010Z03


:0110

:0111
    M2Make TLEdits/pf=Generic/S=OVL
    c:\Command/c CmdFile TLEdits (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLEdits at 0111>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0112
    M2L TLEdits(TimeLine)/o/b
    IF NOT EXIST TLEdits.OVL ECHO Link failure for TLEdits>>TROUBLE.LOG

:0112
    M2Make TLHelper/pf=Generic/S=OVL
    c:\Command/c CmdFile TLHelper (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLHelper at 0112>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0113
    M2L TLHelper(TimeLine)/o/b
    IF NOT EXIST TLHelper.OVL ECHO Link failure for TLHelper>>TROUBLE.LOG

:0113
    M2Make TLMKBase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMKBase (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMKBase at 0113>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0114
    M2L TLMKBase(TimeLine)/o/b
    IF NOT EXIST TLMKBase.OVL ECHO Link failure for TLMKBase>>TROUBLE.LOG

:0114
    M2Make TLSort/pf=Generic/S=OVL
    c:\Command/c CmdFile TLSort (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLSort at 0114>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0115
    M2L TLSort(TimeLine)/o/b
    IF NOT EXIST TLSort.OVL ECHO Link failure for TLSort>>TROUBLE.LOG

:0115
    M2Make TLFileMG/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFileMG (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLFileMG at 0115>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0116
    M2L TLFileMG(TimeLine)/o/b
    IF NOT EXIST TLFileMG.OVL ECHO Link failure for TLFileMG>>TROUBLE.LOG

:0116

:0117
    M2Make TLSetVid/pf=Generic/S=OVL
    c:\Command/c CmdFile TLSetVid (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLSetVid at 0117>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0118
    M2L TLSetVid(TimeLine)/o/b
    IF NOT EXIST TLSetVid.OVL ECHO Link failure for TLSetVid>>TROUBLE.LOG

:0118
    M2Make TLDOS/pf=Generic/S=OVL
    c:\Command/c CmdFile TLDOS (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLDOS at 0118>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0119
    M2L TLDOS(TimeLine)/o/b
    IF NOT EXIST TLDOS.OVL ECHO Link failure for TLDOS>>TROUBLE.LOG

:0119

:011A

:011C
    M2Make TLFmtInt/pf=Generic/S=OVL
    c:\Command/c CmdFile TLFmtInt (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLFmtInt at 011C>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011D
    M2L TLFmtInt(TimeLine)/o/b
    IF NOT EXIST TLFmtInt.OVL ECHO Link failure for TLFmtInt>>TROUBLE.LOG

:011D
    M2Make TLAlarm/pf=Generic/S=OVL
    c:\Command/c CmdFile TLAlarm (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLAlarm at 011D>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011E
    M2L TLAlarm(TimeLine)/o/b
    IF NOT EXIST TLAlarm.OVL ECHO Link failure for TLAlarm>>TROUBLE.LOG

:011E
    M2Make TLImport/pf=Generic/S=OVL
    c:\Command/c CmdFile TLImport (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLImport at 011E>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011F
    M2L TLImport(TimeLine)
    IF NOT EXIST TLImport.OVL ECHO Link failure for TLImport>>TROUBLE.LOG

:011E01
        M2Make TLITasks/pf=Generic/S=OVL
        c:\Command/c CmdFile TLITasks (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLITasks at 011E01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011E02
        M2L TLITasks(TLImport)/o/b
        IF NOT EXIST TLITasks.OVL ECHO Link failure for TLITasks>>TROUBLE.LOG

:011E02
        M2Make TLIRsrc/pf=Generic/S=OVL
        c:\Command/c CmdFile TLIRsrc (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLIRsrc at 011E02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011E03
        M2L TLIRsrc(TLImport)/o/b
        IF NOT EXIST TLIRsrc.OVL ECHO Link failure for TLIRsrc>>TROUBLE.LOG

:011E03
        M2Make TLIAss/pf=Generic/S=OVL
        c:\Command/c CmdFile TLIAss (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLIAss at 011E03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011E04
        M2L TLIAss(TLImport)/o/b
        IF NOT EXIST TLIAss.OVL ECHO Link failure for TLIAss>>TROUBLE.LOG

:011E04
        M2Make TLIEdges/pf=Generic/S=OVL
        c:\Command/c CmdFile TLIEdges (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLIEdges at 011E04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011E05
        M2L TLIEdges(TLImport)/o/b
        IF NOT EXIST TLIEdges.OVL ECHO Link failure for TLIEdges>>TROUBLE.LOG

:011E05

:011E09
        M2Make TLEndImp/pf=Generic/S=OVL
        c:\Command/c CmdFile TLEndImp (TLImport)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLEndImp at 011E09>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011E0A
        M2L TLEndImp(TLImport)/o/b
        IF NOT EXIST TLEndImp.OVL ECHO Link failure for TLEndImp>>TROUBLE.LOG
:011E0A


:011F
    M2Make TLSPBase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLSPBase (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLSPBase at 011F>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011G
    M2L TLSPBase(TimeLine)
    IF NOT EXIST TLSPBase.OVL ECHO Link failure for TLSPBase>>TROUBLE.LOG

:011F01
        M2Make TLSpread/pf=Generic/S=OVL
        c:\Command/c CmdFile TLSpread (TLSPBase)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLSpread at 011F01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011F02
        M2L TLSpread(TLSPBase)/o/b
        IF NOT EXIST TLSpread.OVL ECHO Link failure for TLSpread>>TROUBLE.LOG
:011F02


:011G
    M2Make TLShowJo/pf=Generic/S=OVL
    c:\Command/c CmdFile TLShowJo (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLShowJo at 011G>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011H
    M2L TLShowJo(TimeLine)/o/b
    IF NOT EXIST TLShowJo.OVL ECHO Link failure for TLShowJo>>TROUBLE.LOG

:011H
    M2Make TLWBSGen/pf=Generic/S=OVL
    c:\Command/c CmdFile TLWBSGen (TimeLine) OVL
    IF EXIST *.LST ECHO Compile failure on TLWBSGen at 011H>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011I
    M2L TLWBSGen(TimeLine)
    IF NOT EXIST TLWBSGen.OVL ECHO Link failure for TLWBSGen>>TROUBLE.LOG

:011H01
        M2Make TLWBSMAN/pf=Generic/S=OVL
        c:\Command/c CmdFile TLWBSMAN (TLWBSGen)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLWBSMAN at 011H01>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011H02
        M2L TLWBSMAN(TLWBSGen)/o/b
        IF NOT EXIST TLWBSMAN.OVL ECHO Link failure for TLWBSMAN>>TROUBLE.LOG

:011H02
        M2Make TLWBSREN/pf=Generic/S=OVL
        c:\Command/c CmdFile TLWBSREN (TLWBSGen)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLWBSREN at 011H02>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011H03
        M2L TLWBSREN(TLWBSGen)/o/b
        IF NOT EXIST TLWBSREN.OVL ECHO Link failure for TLWBSREN>>TROUBLE.LOG

:011H03
        M2Make TLRENUMB/pf=Generic/S=OVL
        c:\Command/c CmdFile TLRENUMB (TLWBSGen)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLRENUMB at 011H03>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011H04
        M2L TLRENUMB(TLWBSGen)/o/b
        IF NOT EXIST TLRENUMB.OVL ECHO Link failure for TLRENUMB>>TROUBLE.LOG

:011H04
        M2Make TLWBSVER/pf=Generic/S=OVL
        c:\Command/c CmdFile TLWBSVER (TLWBSGen)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLWBSVER at 011H04>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011H05
        M2L TLWBSVER(TLWBSGen)/o/b
        IF NOT EXIST TLWBSVER.OVL ECHO Link failure for TLWBSVER>>TROUBLE.LOG

:011H05
        M2Make TLVERIFY/pf=Generic/S=OVL
        c:\Command/c CmdFile TLVERIFY (TLWBSGen)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLVERIFY at 011H05>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011H06
        M2L TLVERIFY(TLWBSGen)/o/b
        IF NOT EXIST TLVERIFY.OVL ECHO Link failure for TLVERIFY>>TROUBLE.LOG

:011H06
        M2Make TLWBSNUM/pf=Generic/S=OVL
        c:\Command/c CmdFile TLWBSNUM (TLWBSGen)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLWBSNUM at 011H06>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011H07
        M2L TLWBSNUM(TLWBSGen)/o/b
        IF NOT EXIST TLWBSNUM.OVL ECHO Link failure for TLWBSNUM>>TROUBLE.LOG

:011H07
        M2Make TLWBSVR/pf=Generic/S=OVL
        c:\Command/c CmdFile TLWBSVR (TLWBSGen)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLWBSVR at 011H07>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011H08
        M2L TLWBSVR(TLWBSGen)/o/b
        IF NOT EXIST TLWBSVR.OVL ECHO Link failure for TLWBSVR>>TROUBLE.LOG

:011H08
        M2Make TLWBSTRA/pf=Generic/S=OVL
        c:\Command/c CmdFile TLWBSTRA (TLWBSGen)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLWBSTRA at 011H08>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011H09
        M2L TLWBSTRA(TLWBSGen)/o/b
        IF NOT EXIST TLWBSTRA.OVL ECHO Link failure for TLWBSTRA>>TROUBLE.LOG

:011H09
        M2Make TLWBSERA/pf=Generic/S=OVL
        c:\Command/c CmdFile TLWBSERA (TLWBSGen)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLWBSERA at 011H09>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011H0A
        M2L TLWBSERA(TLWBSGen)/o/b
        IF NOT EXIST TLWBSERA.OVL ECHO Link failure for TLWBSERA>>TROUBLE.LOG

:011H0A
        M2Make TLDUPLIC/pf=Generic/S=OVL
        c:\Command/c CmdFile TLDUPLIC (TLWBSGen)/o/b OVL
        IF EXIST *.LST ECHO Compile failure on TLDUPLIC at 011H0A>>TROUBLE.LOG
        IF EXIST *.LST GOTO 011H0B
        M2L TLDUPLIC(TLWBSGen)/o/b
        IF NOT EXIST TLDUPLIC.OVL ECHO Link failure for TLDUPLIC>>TROUBLE.LOG
:011H0B


:011I

:011P
    M2Make TLErase/pf=Generic/S=OVL
    c:\Command/c CmdFile TLErase (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLErase at 011P>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011Q
    M2L TLErase(TimeLine)/o/b
    IF NOT EXIST TLErase.OVL ECHO Link failure for TLErase>>TROUBLE.LOG

:011Q
    M2Make TLRenum/pf=Generic/S=OVL
    c:\Command/c CmdFile TLRenum (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLRenum at 011Q>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011R
    M2L TLRenum(TimeLine)/o/b
    IF NOT EXIST TLRenum.OVL ECHO Link failure for TLRenum>>TROUBLE.LOG



:011S
    M2Make TLMagic/pf=Generic/S=OVL
    c:\Command/c CmdFile TLMagic (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLMagic at 011S>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011T
    M2L TLMagic(TimeLine)/o/b
    IF NOT EXIST TLMagic.OVL ECHO Link failure for TLMagic>>TROUBLE.LOG

:011T

:011U
    M2Make TLTimer/pf=Generic/S=OVL
    c:\Command/c CmdFile TLTimer (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLTimer at 011U>>TROUBLE.LOG
    IF EXIST *.LST GOTO 011V
    M2L TLTimer(TimeLine)/o/b
    IF NOT EXIST TLTimer.OVL ECHO Link failure for TLTimer>>TROUBLE.LOG

:011V
:011Z
    M2Make TLXMS/pf=Generic/S=OVL
    c:\Command/c CmdFile TLXMS (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLXMS at 011Z>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0120
    M2L TLXMS(TimeLine)/o/b
    IF NOT EXIST TLXMS.OVL ECHO Link failure for TLXMS>>TROUBLE.LOG

:0120
    M2Make TLVIDMEM/pf=Generic/S=OVL
    c:\Command/c CmdFile TLVIDMEM (TimeLine)/o/b OVL
    IF EXIST *.LST ECHO Compile failure on TLVIDMEM at 0120>>TROUBLE.LOG
    IF EXIST *.LST GOTO 0121
    M2L TLVIDMEM(TimeLine)/o/b
    IF NOT EXIST TLVIDMEM.OVL ECHO Link failure for TLVIDMEM>>TROUBLE.LOG

:02
IF EXIST AFCOMPIL.BAT c:\COMMAND/C AFCOMPIL.BAT
:LOGOUT
