IMPLEMENTATION MODULE Expenses;


    (* Expenses -- Records historical information about money and 
                   effort spend during periods of time.  Each expense
                   list is a component of a resource assignment.

       29-May-90  AJL  - Initial version. 
       06-Jul-90  AJL  - Added the create, copy and dispose procs.

    *)

IMPORT Filing;

FROM FlexStor               IMPORT
    (* TYPE *)                  AnExtHandle, AnExtStoragePreference,
                                AnExtStatus,
    (* PROC *)                  CreateExtObject, GetExtSize, NumberOfElements,
                                SetExtData, DiscardExtObject, ReleaseObject,
                                CreateExtObjectWithSize, LockObject, CopyExtObject,
                                LockObjectArray, SetExtSize, ArraySize,
                                GetExtStatus, ReleaseUnchangedObject;

FROM SYSTEM IMPORT
    (* TYPE *)      ADDRESS, TSIZE;

FROM Timei  IMPORT
    (* TYPE *)      ADate;




PROCEDURE InitializeExpense( VAR Expense : AnExpenseRecord );
BEGIN
    WITH Expense DO
        StartDate := 0;
        EndDate := 0;
        AmountSpent := 0.0;
        TimeSpent   := 0L;
        Category    := 0;
        PlannedExpense := FALSE;
    END;
END InitializeExpense;





PROCEDURE CreateExpenseArrayHandle(     PStartDate  : ADate;
                                        Speed  : AnExtStoragePreference
                                   ) : AnExtHandle;
VAR
    Handle : AnExtHandle;
    Expenses : POINTER TO AnExpenseRecord;
    Size : CARDINAL;
BEGIN
    IF (CreateExtObjectWithSize( Handle, ExtSlow, TSIZE(AnExpenseRecord) )) THEN
        Size := LockObject(Handle,Expenses);
        InitializeExpense(Expenses^);
        Expenses^.StartDate := PStartDate;
        Expenses^.EndDate   := PStartDate;
    ELSE
        Handle := AnExtHandle( NIL );
    END;

END CreateExpenseArrayHandle;


PROCEDURE DisposeExpenseArrayHandle(VAR Handle : AnExtHandle);
BEGIN
    DiscardExtObject(Handle);
END DisposeExpenseArrayHandle;


PROCEDURE CopyExpenseArrayHandle( VAR Target : AnExtHandle;
                                      Source : AnExtHandle;
                                      Speed  : AnExtStoragePreference );
BEGIN
    IF (Source = AnExtHandle(NIL)) OR
       (NOT CopyExtObject( Source, Speed, Target )) THEN
        Target := AnExtHandle(NIL);
    END;
END CopyExpenseArrayHandle;



  (*  ForEachExpense  - Call a routine for each expense record.

      Preconditions  - Must have a valid expense handle.
                       Must provide a procedure to be called for each
                       expense record.
                       Context is user context and not used by this procedure.
                       use it to pass any data you want between levels.

      Postconditions - your procedure will have been called once for
                       each found expense.  If there were no expense
                       records, then it will never have been called.
  *)

(*$O-*)     (*  Because the ExpenseArray^[Loop] construct may screw up  25-Jan-88 LAA
                when optimization is on.  *)

PROCEDURE ForEachExpense   ( ExpenseHandle    : AnExtHandle;
                             CalledEachTime   : AnExpenseProc;
                             Context          : ADDRESS );
VAR ExpenseArray      : AnExpenseArray;
    Loop, Count       : CARDINAL;
BEGIN

    Count := LockObjectArray(ExpenseHandle,ExpenseArray,TSIZE(AnExpenseRecord));
    IF Count > 0  THEN
        FOR Loop := 0 TO Count - 1 DO
            IF CalledEachTime( ExpenseArray^[Loop], Context ) = FALSE THEN
                ReleaseObject( ExpenseHandle );
                RETURN;
            END;
        END;
    END;
    ReleaseObject( ExpenseHandle );

END ForEachExpense;

(*$O=*)







PROCEDURE StoreExpenses(     Expenses    : AnExtHandle;
                             StorageProc : Filing.AStoreProc;
                             Context     : ADDRESS );
VAR
    ExpenseArray      : AnExpenseArray;
    Size              : CARDINAL;
BEGIN
    IF (Expenses = AnExtHandle(NIL)) THEN
        StorageProc(NIL,0,Context);
    ELSE
        Size := LockObject(Expenses,ExpenseArray);
        StorageProc(ExpenseArray,Size,Context);
        ReleaseUnchangedObject( Expenses );
    END;
END StoreExpenses;




PROCEDURE LoadExpenses (     Expenses    : AnExtHandle;
                             StoragePref : AnExtStoragePreference;
                             PredictSize : Filing.APredictSizeProc;
                             LoadProc    : Filing.ALoadProc;
                             ReadNext    : Filing.AReadNextProc;
                             Context     : ADDRESS ):BOOLEAN;
VAR P : ADDRESS;
    MaxSize, ActualSize : CARDINAL;
BEGIN
    ActualSize := PredictSize(Context);
    IF (GetExtStatus() = ExtGood) AND
       (CreateExtObjectWithSize( Expenses, ExtSlow, ActualSize )) THEN
        MaxSize := LockObject( Expenses, P );
        LoadProc(P,MaxSize,ActualSize,Context);
        ReleaseObject(   Expenses );
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END;
END LoadExpenses;



END Expenses.

