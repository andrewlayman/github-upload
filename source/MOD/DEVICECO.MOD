IMPLEMENTATION MODULE DeviceColumns;
(*
        MODIFICATION History -

        18-AUG-89 KKC First version
        23-Aug-89 MWP Ah, the first bug found in a new module. I don't know
                      who KKC is but he should take a course in Error reporting.
        24-Aug-89 MWP Fixed a bug which caused display of device descriptions
                      and names to mess up.
        11-Sep-89 KKC Make the picking list 7 characters wider.
        15-Sep-89 KKC Add please wait message box before build the tree.
        29-Nov-89 RSC 1) Check Available for each DeviceRecord Allocation.
                      2) When sorting, only sort against the short name,
                         not the full description string (BUG # 1801).
                      3) Ajust OpenFile() call to include SHARING attributes.
        30-Nov-89 LAA Did a little clean-up of GetDeviceShortInfo.
        01-Aug-91 LAA Added a new parameter to DoGoToWithPrompts.  This made
                      necessary by a fix for bug #4772.
*)

FROM BalExpr                IMPORT
    (* PROC  *)                 ParseExpression;

FROM Boxes                  IMPORT
    (* TYPE *)                  ABoxType;

FROM Dialog                 IMPORT
    (* TYPE  *)                 ABoxHandle, 
    (* PROC  *)                 FatalError, Error, ProgressBox, ReleaseBox;

FROM Directory              IMPORT
    (* CONST *)                 MaximumFileNameLength,
    (* TYPE  *)                 AFileAttribute, AFileAttributeSet,
                                ASetOfFileNameParts, AFileNamePart,
    (* PROC  *)                 FileLookupStart, FileLookupContinue,
                                GetPathEntry, NormalizeFileName, DOSVersion;

FROM FileAux                IMPORT
    (* PROC *)                  PrepareForIO, CheckIO;

FROM FileSystem             IMPORT
    (* CONST *)                 ReadOnlyMode, FullAccessMode,
    (* TYPE  *)                 File, Response,
    (* PROC  *)                 Close, OpenFile;

FROM GoTo                   IMPORT
    (* TYPE *)                  AGoToNameProc,
    (* PROC *)                  DoGoToWithPrompts, NullGoToCheckProc;

FROM GrafFile               IMPORT
    (* PROC  *)                 StartGrafFileInput, ReadGrafFileLine;

FROM Kbio                   IMPORT
    (* CONST *)                 maxcol,
    (* VAR   *)                 maxrow;

FROM LStrings               IMPORT
    (* PROC  *)                 SetString, SetLengthOf, ConcatS,
                                Copy, StringsEqual, ConcatLS, LengthOf,
                                SubStr, TrimRear, LStringToTString,
                                Compare;

FROM MsgFile                IMPORT
    (* PROC  *)                 GetMessage;

FROM Objects                IMPORT
    (* TYPE *)                  AnObject;

FROM Sorter                 IMPORT
    (* PROC *)                  SortTree;

FROM Space                  IMPORT
    (* PROC *)                  ALLOCATE, DEALLOCATE, HeapAvailable,
                                Available;

FROM SYSTEM                 IMPORT
    (* TYPE *)                  TSIZE;

FROM TreeObjects            IMPORT
    (* TYPE *)                  ATree, ATreeNode,
    (* PROC *)                  CreateTree, CreateTreeNode;

CONST
(*
    MaxDescriptionLength    =       120;
*)
    MaxDescriptionLength    =       161;
    MaxDeviceRecord         =       15;
    ModuleNumber            =       8300;

TYPE
    ADeviceRecord   =   RECORD
        DeviceDesc  :   ARRAY[0..MaxDescriptionLength] OF CHAR;
        DeviceName  :   ARRAY[0..MaximumFileNameLength] OF CHAR;
    END;
    ADeviceRecordPtr    =   POINTER TO ADeviceRecord;




(****************************************************************************
    GetDeviceName   -
        Get the file name that contains device information from the given
        node.
    Preconditions:
        A device tree is already built.
        Given node is a valid tree node from a device tree.
    Postconditions:
        S contians the device name.
****************************************************************************)
PROCEDURE GetDeviceName( Node : ATreeNode; VAR s : ARRAY OF CHAR);
VAR
    DisplayRecord   :   ADeviceRecordPtr;
BEGIN
    DisplayRecord := Node^.Methods^.GetDataObject(Node);
    Copy( DisplayRecord^.DeviceName, s );
END GetDeviceName;




(****************************************************************************
    GetDeviceShortInfo   -
        Given a tree node, returns the device information.  Right now, the
    string is used in a picking list.
    Preconditions:
        A device tree is already built.
        Given node is a valid tree node from a device tree.
    Postconditions:
        s contains the device information. This array is currently eighty
        characters in length.
****************************************************************************)
PROCEDURE GetDeviceShortInfo( Node : ATreeNode; VAR s : ARRAY OF CHAR);

VAR
    DisplayRecord           : ADeviceRecordPtr;
    
BEGIN                       (* GetDeviceShortInfo *)

    DisplayRecord := Node^.Methods^.GetDataObject(Node);

    IF ( NOT ParseExpression( DisplayRecord^.DeviceDesc, 1, s ) ) THEN  (* 30-Nov-89 LAA *)
        GetMessage( ModuleNumber + 1, s ); (* Error in *)
        ConcatLS( s, DisplayRecord^.DeviceName );
    END;

END GetDeviceShortInfo;




(****************************************************************************
    GetDeviceLongInfo -
        Given a tree node, returns the device information.  Right now, the
    string is used in a picking list.
    Preconditions:
        A device tree is already built.
        Given node is a valid tree node from a device tree.
    Postconditions:
        s contains the description.
****************************************************************************)
PROCEDURE GetDeviceLongInfo( Node : ATreeNode; VAR s : ARRAY OF CHAR);
VAR
    DisplayRecord   :   ADeviceRecordPtr;
    TempBuffer      :   ARRAY [0..255] OF CHAR;
    i               :   CARDINAL;
BEGIN
    DisplayRecord := Node^.Methods^.GetDataObject(Node);
    DisplayRecord := Node^.Methods^.GetDataObject(Node);

    IF ( NOT ParseExpression( DisplayRecord^.DeviceDesc, 2, TempBuffer ) ) THEN
        SetLengthOf( s, 0 );
    ELSE
        i := HIGH(s);                                             (* 1-Sep-89 MWP *)
        IF ( LengthOf ( TempBuffer ) >= i ) THEN
           SetLengthOf ( TempBuffer, i - 1 );
        END;
        Copy ( TempBuffer, s );
    END;

END GetDeviceLongInfo;




(****************************************************************************
    DoPickDevice    -
        Pick  a device from a device tree.
    Preconditions:
        DeviceTree is a device tree.
    Postconditions:
        FileName contains the file that has the device information.
****************************************************************************)
PROCEDURE DoPickDevice(
                            DeviceTree : ATree;
                          VAR FileName : ARRAY OF CHAR;
                             VAR Title : ARRAY OF CHAR
                      ) : BOOLEAN;
CONST
    LeftX                   =   16;
    RightX                  =   64;
    TopY                    =   5;
VAR
    Node                    :   ATreeNode;
    StartNode               :   ATreeNode;
    DeviceRecord            :   ADeviceRecordPtr;
    s                       :   ARRAY[0..80] OF CHAR;
    ok                      :   BOOLEAN;
    BottomY                 :   CARDINAL;
BEGIN
    StartNode := DeviceTree^.Methods^.GetFirst(DeviceTree);

    IF ( LengthOf( FileName ) > 0 ) THEN
        Node := StartNode;
        LOOP
            DeviceRecord := Node^.Methods^.GetDataObject(Node);
            GetDeviceName( Node, s );
            IF ( StringsEqual( s, FileName ) ) THEN
                StartNode := Node;
                EXIT;
            END;
            Node := Node^.Methods^.GetNext(Node);
            IF (Node = ATreeNode(NIL)) THEN
                EXIT;
            END;
        END;
    END;

    SetLengthOf( FileName, 0 );
    BottomY := maxrow - 4;
    ok := DoGoToWithPrompts(DeviceTree, LeftX, TopY, RightX, BottomY, Title, 
                                  TRUE, NullGoToCheckProc, GetDeviceShortInfo,
                                  GetDeviceLongInfo, ABoxType{},              (* 01-Aug-91 *)
                                  StartNode);
    IF ( ok ) THEN
        GetDeviceName( StartNode, FileName );
    END;

    RETURN ok;
END DoPickDevice;




(****************************************************************************
    DisposeDeviceTree   -
        Discard a device tree.
    Preconditions:
        DeviceTree is a device tree.
    Postconditions:
        All nodes and storage attached to it will be discarded .
****************************************************************************)

PROCEDURE DisposeDeviceTree(VAR DeviceTree  : ATree);

VAR
    TreeNode            : ATreeNode;
    NextNode            : ATreeNode;
    DeviceRecord        : ADeviceRecordPtr;
BEGIN

    IF (DeviceTree <> NIL) THEN
        TreeNode := DeviceTree^.Methods^.GetFirst(DeviceTree);
        WHILE (TreeNode <> NIL) DO
            NextNode := TreeNode^.Methods^.GetNext(TreeNode);
            DeviceRecord := TreeNode^.Methods^.GetDataObject( TreeNode );
            DISPOSE( DeviceRecord );
            TreeNode^.Methods^.Discard(TreeNode);
            TreeNode := NextNode;
        END;
        DeviceTree^.Methods^.Discard(DeviceTree);
    END;
    DeviceTree := NIL;
END DisposeDeviceTree;




(****************************************************************************
    CompareTwoColumns   -
        Compare two nodes in a device tree.  This function is used for
        sorting the tree.
    Preconditions:
        A device tree is already built.
        Given nodes are valid tree nodes from a device tree.
    Postconditions:
        RETURN
            TRUE        if  First > Second.
            FALSE       otherwise.

    (* 29-Nov-89 RSC Changed this proc to look only at the short name. *)

****************************************************************************)
PROCEDURE CompareTwoColumns( First, Second : AnObject ) : BOOLEAN;
VAR
    FirstNode,
    SecondNode          : ATreeNode;
    FirstName,
    SecondName          : ARRAY [0..maxcol+1] OF CHAR;
BEGIN

    FirstNode   := ATreeNode( First  );
    SecondNode  := ATreeNode( Second );

    GetDeviceShortInfo( FirstNode,  FirstName  );
    GetDeviceShortInfo( SecondNode, SecondName );

    RETURN (Compare( FirstName, SecondName ) > 0);

END CompareTwoColumns;




(****************************************************************************
    AddToTree
        Add one record to a device tree.  Record can be added anywhere in
    the tree because we are going to sort it later.
    Preconditions:
        Tree is a device tree.
    Postconditions:
        A node is created and attached to given device tree.  The node will
        contain the informations of the given record.
****************************************************************************)
PROCEDURE AddToTree(
                              Tree : ATree;
                    VAR DeviceInfo : ADeviceRecordPtr
                   ) : BOOLEAN;
VAR
    Node                : ATreeNode;
BEGIN
    IF (NOT CreateTreeNode(Node)) THEN
        RETURN FALSE;
    END;
    Tree^.Methods^.AddLast(Tree, Node);
    Node^.Methods^.SetDataObject(Node, DeviceInfo);
    RETURN TRUE;
END AddToTree;




(****************************************************************************
    GetDeviceInfo   -
        Read informations from a device file.
    Preconditions:
        Name contains a valid device file name (with both path and extension).
    Postconditions:
        Buffer contains the information from the device file which will be
    used for building a device tree.
****************************************************************************)
PROCEDURE GetDeviceInfo(  VAR Path, Name, Buffer : ARRAY OF CHAR ) : BOOLEAN;
CONST
    DOS3PointZero    = 0300H;
VAR
    f               :       File;
    Mode,
    i               :       CARDINAL;
    s               :       ARRAY[0..255] OF CHAR;
    s1              :       ARRAY[0..3] OF CHAR;
    ok              :       BOOLEAN;
BEGIN
    SetLengthOf(Buffer, 0);

    (* 29-Nov-89 RSC I would have used RequestFileOpenReadOnly, but
                     it does a directory lookup.
    *)
    Mode := ReadOnlyMode;
    IF (DOSVersion() >= DOS3PointZero) THEN
        INC(Mode, FullAccessMode);
    END;

    Copy( Path, s );
    ConcatLS( s, Name );
    LStringToTString(s,s);

    PrepareForIO(f);
    OpenFile( f, s, Mode );
    ok := (CheckIO(f) = done);

    i := 0;
    IF (ok AND StartGrafFileInput(f)) THEN
        ok := FALSE; (* Make sure we read all the right stuff. *)
        LOOP
            IF (NOT ReadGrafFileLine( f, s ) ) THEN EXIT END;
            IF ( ( s[1] <> '-' )  OR ( s[2] <> '-' )  ) THEN
                INC( i );
                IF ( i = 1 ) THEN
                    SetString(s1, "$1");
                    IF ( NOT StringsEqual(s, s1) ) THEN
                        EXIT;
                    END;
                ELSIF ( i = 3 ) THEN
                    Copy( s, Buffer );
                ELSIF ( i = 4 ) THEN
                    ConcatLS( Buffer, s );
                    ok := TRUE;
                    EXIT;
                END;
            END;
        END;
    END;

    Close( f );

    RETURN ok;

END GetDeviceInfo;




(****************************************************************************
    GetDevicePath   -
        Find the path that contains the device files.
    Preconditions:
        Devicepath contains all the possible path.
        DeviceExt contains the file extension of device file.
    Postconditions:
        If we find the path then
            Store path into DevicePath.
            return TRUE.
        otherwise
            return FALSE.
****************************************************************************)
PROCEDURE GetDevicePath(
                        VAR DevicePath : ARRAY OF CHAR;
                        VAR DeviceExt : ARRAY OF CHAR
                       ) : BOOLEAN;
VAR
    FileAttribute   :       AFileAttributeSet;
    Filename        :       ARRAY[0..80] OF CHAR;
    DeviceFile      :       ARRAY[0..80] OF CHAR;
    i               :       CARDINAL;
    Length          :       CARDINAL;
    DeviceFound     :       BOOLEAN;
BEGIN
    i := 0;
    FileAttribute := AFileAttributeSet{ArchiveAttribute};
    DeviceFound := FALSE;
    WHILE ( (NOT DeviceFound ) AND ( GetPathEntry( DevicePath, i, DeviceFile ) ) ) DO
        INC( i );
        NormalizeFileName( DeviceFile,
                              ASetOfFileNameParts{DevicePart,DirectoryPart} );
        Length := LengthOf( DeviceFile );
        ConcatS(DeviceFile, "*.");
        ConcatLS(DeviceFile, DeviceExt);
        IF ( FileLookupStart( DeviceFile, Filename, FileAttribute) ) THEN
            SetLengthOf( DeviceFile, Length );
            Copy( DeviceFile, DevicePath );
            DeviceFound := TRUE;
        END;
    END;
    RETURN DeviceFound;
END GetDevicePath;




(****************************************************************************
    BuildDeviceTree -
        Build a tree contains all devices information.  It is used for
        displaying a picking list.
    Preconditions:
        Devicepath contains all the possible path.
        DeviceExt contains the file extension of device file.
    Postconditions:
        If we find the path then
            DeviceTree points to device tree.
            return TRUE.
        otherwise
            return FALSE.
****************************************************************************)
PROCEDURE BuildDeviceTree(
                           VAR DevicePath : ARRAY OF CHAR ;
                            VAR DeviceExt : ARRAY OF CHAR ;
                           VAR DeviceTree : ATree
                         ) : BOOLEAN ;
VAR
    DeviceInfo      :       ADeviceRecordPtr;
    DeviceFile      :       ARRAY[0..80] OF CHAR;
    s               :       ARRAY[0..255] OF CHAR;
    FileAttribute   :       AFileAttributeSet;
    Filename        :       ARRAY[0..80] OF CHAR;
    NDeviceInfo     :       CARDINAL;
    MoreFile        :       BOOLEAN;
BEGIN

    DeviceTree := NIL;

    IF ( NOT GetDevicePath( DevicePath, DeviceExt ) ) THEN
        GetMessage( ModuleNumber + 3, s );
        ConcatLS ( s, DeviceExt );
        Error(s);
        RETURN FALSE;
    END;

    Copy(DevicePath, DeviceFile);
    ConcatS(DeviceFile, "*.");
    ConcatLS(DeviceFile, DeviceExt);

    IF ((NOT HeapAvailable()) OR (NOT CreateTree(DeviceTree))) THEN
        GetMessage( ModuleNumber + 4, s );
        Error(s);
        RETURN FALSE;
    END;

    NDeviceInfo := 0;
    FileAttribute := AFileAttributeSet{ArchiveAttribute};
    MoreFile := FileLookupStart( DeviceFile, Filename, FileAttribute);

    WHILE ( MoreFile ) DO

        IF (NOT Available(TSIZE(ADeviceRecord))) THEN
            GetMessage( ModuleNumber + 2, s ); (* Not enough memory to make the device name list. *)
            Error(s);
            DisposeDeviceTree(DeviceTree);
            RETURN FALSE;
        END;

        NEW( DeviceInfo );

        WITH DeviceInfo^ DO
            SubStr( Filename, s, 1, 8 );
            TrimRear(s);
            Copy( s, DeviceName );
            Copy( s, DeviceFile );  (* 29-Nov-89 RSC reworked *)

            SubStr( Filename, s, 9, 4 );
            TrimRear(s);
            ConcatLS(DeviceFile, s);

            Copy(DevicePath, s );

            IF ( GetDeviceInfo( s, DeviceFile, DeviceDesc ) ) THEN
                INC ( NDeviceInfo );
                IF (NOT AddToTree(DeviceTree, DeviceInfo)) THEN
                    GetMessage( ModuleNumber + 2, s ); (* Not enough memory to make the device name list. *)
                    Error(s);
                    DisposeDeviceTree(DeviceTree);
                    RETURN FALSE;
                END;
            ELSE
                GetMessage( ModuleNumber + 1, s ); (* Error in *)
                ConcatLS( s, DeviceFile );
                Error(s);
            END;
        END;

        MoreFile := FileLookupContinue( Filename, FileAttribute );
    END;

    IF ( NDeviceInfo = 0 ) THEN
        DisposeDeviceTree(DeviceTree);
        GetMessage( ModuleNumber + 5, s );
        ConcatLS ( s, DeviceExt );
        Error(s);
        RETURN FALSE;
    END;

    RETURN ( SortTree( DeviceTree, CompareTwoColumns ) );
END BuildDeviceTree;




(****************************************************************************
    PickADevice -
        Ask user to enter a device.
    Preconditions:
        PahtName contains the possible paths for device.
        Extension contains the file extension of device.
    Postconditions:
        If user selected a device.
            FileName contains the device file name. (No path and no extension)
            return TRUE.
        otherwise
            return FALSE.
****************************************************************************)
PROCEDURE PickADevice( VAR PathName      : ARRAY OF CHAR;
                       VAR FileName      : ARRAY OF CHAR;
                       VAR Extension     : ARRAY OF CHAR;
                       VAR TitleIn       : ARRAY OF CHAR ) : BOOLEAN;
VAR
    DeviceTree      :       ATree;
    ok              :       BOOLEAN;
    WaitMsg         :       ARRAY[0..255] OF CHAR;
    WaitBoxHandle   :       ABoxHandle;
BEGIN

    GetMessage( ModuleNumber + 6, WaitMsg ); (* Please wait... *)
    WaitBoxHandle := ProgressBox(WaitMsg);
    ok := BuildDeviceTree( PathName, Extension, DeviceTree );
    ReleaseBox( WaitBoxHandle );

    IF ( ok ) THEN
        ok := DoPickDevice( DeviceTree, FileName, TitleIn );
        DisposeDeviceTree( DeviceTree );
    END;
    RETURN ok;
END PickADevice;



END DeviceColumns.
