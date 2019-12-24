IMPLEMENTATION MODULE ErrorUtil;
FROM Allocs          IMPORT
                            ATaskPtr;
FROM TreeObjects     IMPORT
                            ATreeNode;         
FROM RealConversions IMPORT
                     RealToString;
FROM Dialog    IMPORT   Message, Error, FatalError, Burp, NotYetImplemented;


FROM SYSTEM    IMPORT   DOSCALL,ADDRESS;
FROM LStrings  IMPORT   SetString, ConcatS, ConcatLS, CtoS, Compare,
                        SubStr, Fill, TrimFront, Copy,LStringToTString;
VAR
cr,lf: CHAR;

PROCEDURE PRT(s: ARRAY OF CHAR);
VAR
i: INTEGER;
BEGIN

FOR i:=1 TO ORD(s[0]) DO
    DOSCALL(5H,s[i]);
END;    
   DOSCALL(5H,cr); 
   DOSCALL(5H,lf); 
END PRT;

PROCEDURE PrintTask(VAR task : ATaskPtr; Msg: ARRAY OF CHAR);
VAR
  s: ARRAY [0..255] OF CHAR;
BEGIN
SetString(s,Msg);
IF (task<>NIL) THEN
    ConcatLS(s,task^.taskname);
ELSE
    ConcatS(s,"NIL");
END;        
PRT(s); 
END PrintTask;

PROCEDURE PrintCard( num : CARDINAL; Msg: ARRAY OF CHAR);
VAR
  s1: ARRAY [0..255] OF CHAR;
  s2: ARRAY [0..255] OF CHAR;
BEGIN
CtoS(num,s2);
SetString(s1,Msg);
ConcatLS(s1,s2);
PRT(s1); 
END PrintCard;
PROCEDURE PrintReal( num : REAL; Msg: ARRAY OF CHAR);
VAR
  s1: ARRAY [0..255] OF CHAR;
  s2: ARRAY [0..255] OF CHAR;
  OK: BOOLEAN;
BEGIN
RealToString(num,3,9,s2,OK);
SetString(s1,Msg);
ConcatLS(s1,s2);
PRT(s1); 
END PrintReal;

PROCEDURE PrintMsg(Msg: ARRAY OF CHAR);
VAR
  s1: ARRAY [0..255] OF CHAR;
BEGIN
SetString(s1,Msg);
PRT(s1); 
END PrintMsg;
PROCEDURE PrintSReal( num : REAL; Msg: ARRAY OF CHAR);
VAR
  s1: ARRAY [0..255] OF CHAR;
  s2: ARRAY [0..255] OF CHAR;
  OK: BOOLEAN;
BEGIN
RealToString(num,3,9,s2,OK);
SetString(s1,Msg);
ConcatLS(s1,s2);
Error(s1); 
END PrintSReal;



PROCEDURE PrintSTask(VAR task : ATaskPtr; Msg: ARRAY OF CHAR);
VAR
  s: ARRAY [0..255] OF CHAR;
BEGIN
SetString(s,Msg);
IF (task<>NIL) THEN
    ConcatLS(s,task^.taskname);
ELSE
    ConcatS(s,"NIL");
END;        
 Error(s); 
END PrintSTask;

PROCEDURE PrintSCard(num : CARDINAL; Msg: ARRAY OF CHAR);
VAR
  s1: ARRAY [0..255] OF CHAR;
  s2: ARRAY [0..255] OF CHAR;
BEGIN
CtoS(num,s2);
SetString(s1,Msg);
ConcatLS(s1,s2);
Error(s1);  
END PrintSCard;

PROCEDURE PrintSMsg(Msg: ARRAY OF CHAR);
VAR
  s1: ARRAY [0..255] OF CHAR;
BEGIN
SetString(s1,Msg);
Error(s1); 
END PrintSMsg;

BEGIN
cr:=CHR(13);
lf:=CHR(10);

END ErrorUtil.
