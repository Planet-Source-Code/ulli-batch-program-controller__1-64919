VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "cPS"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
Option Explicit

'Constants
Private Const AGRB            As String = "All group- and record-processing bypassed due to "
Private Const MLID            As String = "erging logic has been disabled"
Private Const TTNO            As String = "The total number of "
Private Const FRMT            As String = "#,0"
Private Const TitleLength     As Long = 14

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'Enums
Public Enum CollatingOrder
    PS_Ascending = 1
    PS_Descending = 2
End Enum
#If False Then
Private PS_Ascending, PS_Descending
#End If

Public Enum StreamControl
    PS_SkipRecord = 1 'Internal meaning is FetchNextRecord
    PS_ReleaseRecord = 2
    PS_EndOfStream = 3
    PS_Absent = 4
End Enum
#If False Then
Private PS_SkipRecord, PS_ReleaseRecord, PS_EndOfStream, PS_Absent
#End If

Public Enum NullOrder
    PS_NullIsLow = 1
    PS_NullIsHigh = 2
End Enum
#If False Then
Private PS_NullIsLow, PS_NullIsHigh
#End If

Public Enum RecordInfo 'see RecordInfoChars below
    PS_Selected = 1
    PS_Matching = 2
    PS_Waiting = 3
    PS_Holding = 4
    PS_Finished = 5
    PS_Omitted = 6
End Enum
#If False Then
Private PS_Selected, PS_Matching, PS_Waiting, PS_Holding, PS_Finished, PS_Omitted
#End If
Private Const RecordInfoChars  As String = "SMWHFO"

Public Enum TraceLevel
    PS_Silent = 0
    PS_Minimal = 1
    PS_Normal = 2
    PS_Extended = 3
End Enum
#If False Then
Private PS_Silent, PS_Minimal, PS_Normal, PS_Extended
#End If

Public Enum ActionTypes
    PS_InitializeProgram = 0
    PS_OpenStream = 1
    PS_FetchRecord = 2
    PS_CheckRecord = 3
    PS_SequenceError = 4
    PS_OpenGroup = 5
    PS_ProcessRecord = 6
    PS_CloseGroup = 7
    PS_CloseStream = 8
    PS_TerminateProgram = 9
End Enum
#If False Then
Private PS_InitializeProgram, PS_OpenStream, PS_FetchRecord, PS_CheckRecord, PS_SequenceError, PS_OpenGroup, PS_ProcessRecord, PS_CloseGroup, PS_CloseStream, PS_TerminateProgram
#End If

Private Enum InternalSortOrder
    iAscending = 1
    iDescending = -1
    iGreater = iAscending
    iLess = iDescending
End Enum
#If False Then ':) Line inserted by Formatter
Private iAscending, iDescending, iGreater, iLess ':) Line inserted by Formatter
#End If ':) Line inserted by Formatter

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'Events
Public Event Error(ByVal ErrorNumber As Long, ByVal ErrorText As String)
Public Event ActionRequest(ByVal Switch As Long, ByVal ActionType As ActionTypes, ByVal ActionNumber As Long, ByVal ActionName As String)
Public Event Trace(ByVal TraceMessage As String)

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'Types

Private Type GroupProps
    CurrentKey                As Variant
    NextKey                   As Variant
    NullSubstitute            As Variant
    GroupCount                As Long
    ItemsInGroup              As Long
    RecordsInGroup()          As Long
    SortOrder                 As InternalSortOrder
End Type

Private Type StreamProps
    StreamState               As StreamControl
    ProcessedCount            As Long
    RecordCount               As Long
    Opened                    As Boolean
End Type

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'Property Vars
Private myActionType          As ActionTypes
Private myActionName          As String
Private ActionNames           As Variant
Private myActionNumber        As Long
Private myActiveStreams       As Long
Private myAnimation           As Boolean
Private myAnimTitle           As String
Private myAnimX               As Long
Private myAnimY               As Long
Private myAutoInc             As Long
Private myBusy                As Boolean
Private myCallCount           As Long
Private myClosingDown         As Boolean
Private myControlMP           As Boolean
Private myCurrentGroup        As Long
Private myCurrentStream       As Long
Private myErrorNotify         As Boolean
Private myGroupProps()        As GroupProps
Private myGroupTrigger        As Long
Private myHaltOnSequenceError As Boolean
Private myKeyInError          As Long
Private myLastErrorNumber     As Long
Private myLastErrorText       As String
Private myMatchCount          As Long
Private myMatches             As String
Private myMaxNumber           As Long
Private myNullOrder           As InternalSortOrder
Private myNumberOfGroups      As Long
Private myNumberOfStreams     As Long
Private myRecordKeys()        As Variant
Private myRunId               As String
Private mySequenceErrorCount  As Long
Private myStartingUp          As Boolean
Private myStreamProps()       As StreamProps
Private mySwitches()          As Long
Private myTraceRequest        As TraceLevel

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'Working Vars
Private AbortRequest          As Boolean
Private DefMatches            As String
Private i                     As Long
Private IniProcPerformed      As Boolean
Private j                     As Long
Private k                     As Long
Private PreviousStream        As Long
Private PropName              As String
Private sIns                  As String
Private SourceCode            As String
Private StartTime             As Date

Public Sub Abort(Optional ByVal ErrNum As Long = 0, Optional ErrText As String = "Unknown Error")

    If myBusy Then
        If AbortRequest Then
            Display "Abort is already being serviced", PS_Normal
          Else
            AbortRequest = True
            myLastErrorNumber = ErrNum
            myLastErrorText = ErrText
            Display "Client has requested Abort due to Error Number " & ErrNum & " (" & Trim$(ErrText) & "); entering termination sequence", PS_Normal
            myClosingDown = True
        End If
      Else
        ErrLocked "Abort", 28
    End If

End Sub

Public Property Get ActionName() As String

    If myBusy Then
        ActionName = myActionName
      Else
        ErrLocked "ActionName", 30
    End If

End Property

Public Property Get ActionNumber() As Long

    If myBusy Then
        ActionNumber = myActionNumber
      Else
        ErrLocked "ActionNumber", 31
    End If

End Property

Public Property Get ActionType() As ActionTypes

    If myBusy Then
        ActionType = myActionType
      Else
        ErrLocked "ActionType", 29
    End If

End Property

Public Property Get ActiveStreams() As Long

    Select Case myActionType
      Case PS_InitializeProgram, PS_OpenStream, PS_TerminateProgram
        ErrLocked "ActiveStreams", 32
      Case Else
        ActiveStreams = myActiveStreams
    End Select

End Property

Private Function AddWhere() As String

    If myBusy Then
        AddWhere = " in " & ActionNames(myActionType) & " " & myActionNumber
    End If

End Function

Public Property Let Animation(ByVal x As Long, ByVal y As Long, Title As String, ByVal nuAnimation As Boolean)

    myAnimation = CBool(nuAnimation)
    myAnimX = x
    myAnimY = y
    If Len(Title) Then
        AnimTitle = Title
    End If

End Property

Public Property Get AnimTitle() As String

    AnimTitle = myAnimTitle

End Property

Public Property Let AnimTitle(ByVal nuAnimTitle As String)

    myAnimTitle = Left$(nuAnimTitle, TitleLength)

End Property

Private Sub Append(Optional Text As String = vbNullString, Optional ByVal Inset As Long = 0, Optional ByVal Befr As Long = 0, Optional ByVal Aftr As Long = 0)

    Do While Befr
        SourceCode = SourceCode & vbCrLf
        Dec Befr
    Loop
    SourceCode = SourceCode & vbCrLf & Left$(sIns, Inset) & Text
    Do While Aftr
        SourceCode = SourceCode & vbCrLf
        Dec Aftr
    Loop

End Sub

Public Property Get AutoInc() As Long

    AutoInc = myAutoInc

End Property

Public Property Let AutoInc(ByVal nuAutoInc As Long)

    If nuAutoInc = 0 Then
        myAutoInc = nuAutoInc
      Else
        If CheckStreamNumber(nuAutoInc) Then
            myAutoInc = nuAutoInc
        End If
    End If

End Property

Private Sub BuildSwitchTable()

    ReDim mySwitches(PS_InitializeProgram To PS_TerminateProgram, 0 To IIf(myNumberOfGroups > myNumberOfStreams, myNumberOfGroups, myNumberOfStreams))
    k = 0
    For i = PS_InitializeProgram To PS_TerminateProgram
        Select Case i
          Case PS_OpenGroup, PS_CloseGroup
            For j = 0 To myNumberOfGroups
                Inc k
                mySwitches(i, j) = k
            Next j
          Case PS_InitializeProgram, PS_SequenceError, PS_TerminateProgram
            Inc k
            mySwitches(i, 0) = k
          Case Else
            For j = 1 To myNumberOfStreams
                Inc k
                mySwitches(i, j) = k
            Next j
        End Select
    Next i

End Sub

Public Property Get Busy() As Boolean

    Busy = myBusy

End Property

Public Property Get CallCount() As Long

    If myBusy Then
        CallCount = myCallCount
      Else
        ErrLocked "CallCount", 33
    End If

End Property

Private Function CheckKeyNumber(KeyNumber As Long) As Boolean

    If KeyNumber > 0 And KeyNumber <= myNumberOfGroups Then
        CheckKeyNumber = True
      Else
        ErrInvProp "Key-/group-number", False, CStr(KeyNumber)
    End If

End Function

Private Function CheckRecords() As Boolean

    CheckRecords = True
    For myActionNumber = 1 To myNumberOfStreams
        With myStreamProps(myActionNumber)
            If .StreamState = PS_SkipRecord Then 'this record was just read
                ResetKeys myActionNumber
                Perform PS_CheckRecord, myActionNumber, "Check record " & .RecordCount & " of stream " & myActionNumber
                If AbortRequest Then
                    Exit Function
                  Else
                    Select Case .StreamState
                      Case PS_SkipRecord 'still skip
                        CheckRecords = False
                        Display "Skipped record " & Format$(.RecordCount, FRMT) & " of stream " & myActionNumber, PS_Extended
                      Case PS_ReleaseRecord
                        Display "Released record " & Format$(.RecordCount, FRMT) & " of stream " & myActionNumber, PS_Extended
                    End Select
                End If
            End If
        End With
    Next myActionNumber

End Function

Private Function CheckStreamNumber(StreamNumber As Long) As Boolean

    If StreamNumber > 0 And StreamNumber <= myNumberOfStreams Then
        CheckStreamNumber = True
      Else
        ErrInvProp "StreamNumber", False, CStr(StreamNumber)
    End If

End Function

Private Sub Class_Initialize()

    MaxNumber = 9
    NumberOfGroups = 1
    NumberOfStreams = 1
    RunId = "NoId"
    TraceRequest = PS_Silent
    NullValue = PS_NullIsLow
    ControlMP = True
    Animation(0, 0, "") = False
    myLastErrorNumber = 0
    myLastErrorText = "No Error"
    ActionNames = Array("InitializeProgram", "OpenStream", "FetchRecord", "CheckRecord", "SequenceError", "OpenGroup", "ProcessRecord", "CloseGroup", "CloseStream", "TerminateProgram")

End Sub

Private Sub Class_Terminate()

    If myBusy Then
        MsgBox "Abort due to class destruction", , "WinPS"
        Abort
    End If
    Unload fAnim

End Sub

Private Sub CloseGroup(Group As GroupProps)

    Perform PS_CloseGroup, myActionNumber, "Terminate group " & myActionNumber
    With Group
        Inc myGroupProps(myActionNumber + 1).ItemsInGroup, Sgn(.ItemsInGroup)
        For i = 1 To myNumberOfStreams
            Inc myGroupProps(myActionNumber + 1).RecordsInGroup(i), .RecordsInGroup(i)
        Next i
    End With

End Sub

Private Sub CloseGroups()

    If Not myStartingUp Then
        For myActionNumber = 1 To myGroupTrigger
            CloseGroup myGroupProps(myActionNumber)
            If myClosingDown Then
                Display Format$(myGroupProps(myActionNumber).GroupCount, FRMT) & " control break(s) at level " & myActionNumber & " have been detected", PS_Normal
            End If
        Next myActionNumber
    End If

End Sub

Private Sub CloseRemainingGroups()

    If Not myStartingUp Then
        For myActionNumber = myGroupTrigger + 1 To myNumberOfGroups
            CloseGroup myGroupProps(myActionNumber)
            Display Format$(myGroupProps(myActionNumber).GroupCount, FRMT) & " control break(s) at level " & myActionNumber & " have been detected", PS_Normal
        Next myActionNumber
    End If

End Sub

Private Sub CloseStreams()

    For myActionNumber = 1 To myNumberOfStreams
        With myStreamProps(myActionNumber)
            If .StreamState = PS_Absent Then
                Display "Stream " & myActionNumber & " was omitted in this run", PS_Extended
              Else
                If .Opened Then
                    Perform PS_CloseStream, myActionNumber, "Close stream " & myActionNumber
                    Display "Stream " & myActionNumber & " has been closed; " & Format$(.RecordCount, FRMT) & " record(s) were fetched" & IIf(.RecordCount, " and " & IIf(.RecordCount = .ProcessedCount, "all", Format$(.ProcessedCount, FRMT)) & " were processed", vbNullString), PS_Normal
                End If
            End If
        End With
    Next myActionNumber

End Sub

Private Function Compare(OpA As Variant, OpB As Variant, KeyNumber As Long, Optional AlB As Boolean = False) As Long

  'Compares two Operands and returns -SortOrder for a < b ; 0 for a = b and +SortOrder for a > b

    With myGroupProps(KeyNumber)
        Select Case True
          Case AlB 'A is always less B
            Compare = IIf(KeyNumber, -.SortOrder, iLess)
          Case IsNull(OpA) And Not IsNull(OpB)
            Compare = -myNullOrder * .SortOrder
          Case IsNull(OpB) And Not IsNull(OpA)
            Compare = myNullOrder * .SortOrder
          Case IsNull(OpA) And IsNull(OpB), OpA = OpB
            Compare = 0
          Case OpA > OpB
            Compare = .SortOrder
          Case Else
            Compare = -.SortOrder
        End Select
    End With

End Function

Public Property Get ControlMP() As Boolean

    ControlMP = myControlMP

End Property

Public Property Let ControlMP(ByVal nuControlMP As Boolean)

    If myBusy Then
        myControlMP = CBool(nuControlMP)
        If myControlMP Then
            Screen.MousePointer = vbHourglass
          Else
            Screen.MousePointer = vbDefault
        End If
    End If

End Property

Public Sub CreateSkeleton(ByVal Streams As Long, ByVal Groups As Long)

  'Call this from the Immediate Window and then paste the generated code into your project

  Const MsgboxTitle         As String = "PS Source Generator"
  Const PrivateFunction     As String = "Private Function "
  Const EndFunction         As String = "End Function"
  Const PrivateSub          As String = "Private Sub "
  Const EndSub              As String = "End Sub"
  Const SelectCaseActNum    As String = "Select Case ActionNumber"
  Const sCase               As String = "  Case "
  Const EndSelect           As String = "End Select"
  Const End_If              As String = "End If"
  Const WithPS              As String = "With PS"
  Const EndWith             As String = "End With"
  Const PlaceCodeTo         As String = "'Place code to "
  Const Here                As String = " here"

    If Streams > 100 Or Groups > 100 Or (Streams * Groups) > 1000 Then
        MsgBox "Too many streams (" & Streams & ") or group levels (" & Groups & ")", vbCritical, MsgboxTitle
      Else
        If MsgBox("Generate source code for " & Streams & " data streams and " & Groups & " control break levels?", vbYesNo Or vbQuestion, MsgboxTitle) = vbYes Then
            Screen.MousePointer = vbHourglass
            sIns = String$(5, vbTab)
            On Error Resume Next
                SourceCode = vbNullString
                Append "'Source Code generated by " & Version & " " & App.LegalCopyright
                Append "Private WithEvents PS As cPS", , 1
                Append PrivateFunction & "RunBatchProg(RunId As String) As Long", , 1
                Append "Set PS = New cPS", 1, 1
                Append WithPS, 1
                Append "If .VersionNumber >= " & VersionNumber & " Then", 2
                Append ".MaxNumber = " & IIf(Streams > Groups, Streams, Groups), 3
                Append ".NumberOfStreams = " & Streams, 3
                Append ".NumberOfGroups = " & Groups, 3
                Append "'Set other properties as appropriate...", 3, 1
                Append "RunBatchProg = .Run(RunId)", 3, 1
                Append "  Else", 2
                Append "MsgBox ""PS Version incompatible; DLL Version Info is:"" & vbCrLf & vbCrLf & .Version", 3
                Append "RunBatchProg = -1", 3
                Append End_If, 2
                Append EndWith, 1
                Append "Set PS = Nothing", 1
                Append EndFunction, , 1
                Append PrivateSub & "PS_ActionRequest(ByVal Switch As Long, ByVal ActionType As WinPS.ActionTypes, ByVal ActionNumber As Long, ByVal ActionName As String)", , 1
                Append WithPS, 1, 1
                Append "Select Case ActionType", 2
                Append sCase & "PS_InitializeProgram", 2, 1
                Append "InitializeProgram", 3
                Append sCase & "PS_OpenStream", 2, 1
                Append SelectCaseActNum, 3
                DoEvents
                For i = 1 To Streams
                    Append sCase & i, 3
                    Append "If Not OpenStream" & i & " Then", 4
                    Append ".StreamState(" & i & ") = PS_Absent", 5
                    Append End_If, 4
                Next i
                Append EndSelect, 3
                Append sCase & "PS_FetchRecord", 2, 1
                Append SelectCaseActNum, 3
                DoEvents
                For i = 1 To Streams
                    Append sCase & i, 3
                    Append "If Not FetchRecordFrom" & i & " Then", 4
                    Append ".StreamState(" & i & ") = PS_EndOfStream", 5
                    Append End_If, 4
                Next i
                Append EndSelect, 3
                Append sCase & "PS_CheckRecord", 2, 1
                Append SelectCaseActNum, 3
                DoEvents
                For i = 1 To Streams
                    Append sCase & i, 3
                    Append "If CheckRecordFrom" & i & " Then", 4
                    Append ".StreamState(" & i & ") = PS_ReleaseRecord", 5
                    Append End_If, 4
                Next i
                Append EndSelect, 3
                Append sCase & "PS_SequenceError", 2, 1
                Append "SequenceError", 3
                Append sCase & "PS_OpenGroup", 2, 1
                Append SelectCaseActNum, 3
                DoEvents
                For i = 1 To Groups
                    Append sCase & i, 3
                    Append "OpenGroup" & i, 4
                Next i
                Append sCase & "0", 3
                Append "InitializeProcessing", 4
                Append EndSelect, 3
                Append sCase & "PS_ProcessRecord", 2, 1
                Append SelectCaseActNum, 3
                DoEvents
                For i = 1 To Streams
                    Append sCase & i, 3
                    Append "ProcessRecordFrom" & i, 4
                Next i
                Append EndSelect, 3
                Append sCase & "PS_CloseGroup", 2, 1
                DoEvents
                Append SelectCaseActNum, 3
                For i = 1 To Groups
                    Append sCase & i, 3
                    Append "CloseGroup" & i, 4
                Next i
                Append sCase & "0", 3
                Append "TerminateProcessing", 4
                Append EndSelect, 3
                Append sCase & "PS_CloseStream", 2, 1
                Append SelectCaseActNum, 3
                DoEvents
                For i = 1 To Streams
                    Append sCase & i, 3
                    Append "CloseStream" & i, 4
                Next i
                Append EndSelect, 3
                Append sCase & "PS_TerminateProgram", 2, 1
                Append "TerminateProgram", 3
                Append EndSelect, 2, 1
                Append EndWith, 1
                Append EndSub, , 1
                Append
                Append PrivateSub & "PS_Trace(ByVal TraceMessage As String)"
                Append "Debug.Print TraceMessage", 1, 1
                Append EndSub, , 1
                Append PrivateSub & "PS_Error(ByVal ErrorNumber As Long, ByVal ErrorText As String)", , 1
                Append "Debug.Print ""Error ("" & ErrorNumber & "") "" & ErrorText", 1, 1
                Append EndSub, , 1, 1
                Append PrivateSub & "InitializeProgram()"
                Append PlaceCodeTo & "initialize the program here", 1, 1
                Append EndSub, , 1, 1
                DoEvents
                For i = 1 To Streams
                    Append PrivateFunction & "OpenStream" & i & "() As Boolean"
                    Append PlaceCodeTo & "open data stream " & i & Here, 1, 1
                    Append "'Return True if data stream was opened successfully and is available", 1
                    Append "OpenStream" & i & " = True 'default - data stream present and successfully opened", 1, 1
                    Append EndFunction, , 1, 1
                Next i
                DoEvents
                For i = 1 To Streams
                    Append PrivateFunction & "FetchRecordFrom" & i & "() As Boolean"
                    Append PlaceCodeTo & "fetch next record from data stream " & i & Here, 1, 1
                    Append "'Return True if record was fetched successfully and is available", 1
                    Append "FetchRecordFrom" & i & " = True 'default - record was fetched successfully", 1, 1
                    Append EndFunction, , 1, 1
                Next i
                DoEvents
                For i = 1 To Streams
                    Append PrivateFunction & "CheckRecordFrom" & i & "() As Boolean"
                    Append PlaceCodeTo & "check and filter record from data stream " & i & Here, 1, 1
                    Append "'Return True if record passed thru filter and is available for processing", 1
                    Append "CheckRecordFrom" & i & " = True 'default - record will be processed", 1, 1
                    Append "If CheckRecordFrom" & i & " Then", 1, 1
                    Append WithPS, 2
                    Append "'Transfer stream " & i & " record key(s) to PS", 3
                    DoEvents
                    For j = Groups To 1 Step -1
                        Append ".RecordKey(" & i & ", " & j & ") = " & "Stream" & i & "Key" & j & "FieldName", 3
                    Next j
                    Append EndWith, 2
                    Append End_If, 1
                    Append EndFunction, , 1, 1
                Next i
                Append PrivateSub & "SequenceError()"
                Append PlaceCodeTo & "handle key sequence error here", 1, 1
                Append "'Information available:", 1, 1
                Append "'---------------------", 1
                Append "'Stream Number: PS.CurrentStream", 1
                Append "'Record Number: PS.RecordCount(PS.CurrentStream)", 1
                Append "'Key Number:    PS.KeyInError", 1
                Append "'Key Contents:  PS.CurrentKey(PS.KeyInError)", 1
                Append "'Error Number:  PS.LastErrorNumber", 1
                Append "'Error Text  :  PS.LastErrorText", 1
                Append EndSub, , 1, 1
                Append PrivateSub & "InitializeProcessing()"
                Append PlaceCodeTo & "initialize processing here", 1, 1
                Append EndSub, , 1, 1
                DoEvents
                For i = Groups To 1 Step -1
                    Append PrivateSub & "OpenGroup" & i & "()"
                    Append PlaceCodeTo & "open group " & i & Here, 1, 1
                    Append EndSub, , 1, 1
                Next i
                DoEvents
                For i = 1 To Streams
                    Append PrivateSub & "ProcessRecordFrom" & i & "()"
                    Append PlaceCodeTo & "process record from data stream " & i & Here, 1, 1
                    Append EndSub, , 1, 1
                Next i
                DoEvents
                For i = 1 To Groups
                    Append PrivateSub & "CloseGroup" & i & "()"
                    Append PlaceCodeTo & "close group " & i & Here, 1, 1
                    Append EndSub, , 1, 1
                Next i
                Append PrivateSub & "TerminateProcessing()"
                Append PlaceCodeTo & "terminate processing here", 1, 1
                Append EndSub, , 1, 1
                DoEvents
                For i = 1 To Streams
                    Append PrivateSub & "CloseStream" & i & "()"
                    Append PlaceCodeTo & "close data stream " & i & Here, 1, 1
                    Append EndSub, , 1, 1
                Next i
                Append PrivateSub & "TerminateProgram()"
                Append PlaceCodeTo & "terminate program here", 1, 1
                Append EndSub, , 1
                Screen.MousePointer = vbDefault
                Clipboard.Clear
                Clipboard.SetText SourceCode
                If Err Then
                    MsgBox "Source Code creation failed.", vbCritical, MsgboxTitle
                  Else
                    MsgBox "Source Code successfully created and copied to clipboard." & vbCrLf & _
                           "You may now stop your project and paste the code.", vbInformation, MsgboxTitle
                End If
            On Error GoTo 0
        End If
    End If

End Sub

Public Property Get CurrentGroup() As Long

    If (myActionType = PS_OpenGroup Or myActionType = PS_CloseGroup) And myActionNumber > 0 Then
        CurrentGroup = myCurrentGroup
      Else 'NOT (MYActionType...
        ErrLocked "CurrentGroup", 34
    End If

End Property

Public Property Get CurrentKey(ByVal KeyNumber As Long) As Variant

    If CheckKeyNumber(KeyNumber) Then
        If myActionType = PS_SequenceError Or myActionType = PS_ProcessRecord Or ((myActionType = PS_OpenGroup Or myActionType = PS_CloseGroup) And myActionNumber) Then
            CurrentKey = myGroupProps(KeyNumber).CurrentKey
          Else
            ErrLocked "CurrentKey", 35
        End If
    End If

End Property

Public Property Get CurrentStream() As Long

    PropName = "CurrentStream"
    If myActionNumber > 0 Then
        Select Case myActionType
          Case PS_OpenGroup, PS_ProcessRecord, PS_SequenceError
            CurrentStream = myCurrentStream
          Case PS_CloseGroup
            CurrentStream = PreviousStream
          Case Else
            ErrLocked PropName, 36
        End Select
      Else
        ErrLocked PropName, 36
    End If

End Property

Private Function Dec(ByRef What As Long, Optional ByVal By As Long = 1) As Long

    What = What - By
    Dec = What

End Function

Private Sub DetectControlBreak()

    If myStartingUp Or myClosingDown Then
        myGroupTrigger = myNumberOfGroups
      Else
        For myGroupTrigger = myNumberOfGroups To 1 Step -1
            With myGroupProps(myGroupTrigger)
                If Compare(.NextKey, .CurrentKey, myGroupTrigger) Then
                    Exit Sub
                End If
            End With
        Next myGroupTrigger
    End If

End Sub

Private Sub Display(Text As String, Level As TraceLevel)

    If Level <= myTraceRequest Then
        'fire trace event
        RaiseEvent Trace(Text)
    End If

End Sub

Public Property Get ElapsedTime() As Date

    If myBusy Then
        ElapsedTime = Now - StartTime
      Else
        ErrLocked "ElapsedTime", 37
    End If

End Property

Private Sub ErrInvProp(PropName As String, InvType As Boolean, ParamVal As String)

    If InvType Then
        myLastErrorNumber = vbObjectError + 1
        myLastErrorText = "The data type " & ParamVal & " value for '" & PropName & "' is invalid" & AddWhere
      Else
        myLastErrorNumber = vbObjectError
        myLastErrorText = "The property value " & ParamVal & " for '" & PropName & "' is invalid" & AddWhere
    End If
    If myErrorNotify Then
        'fire error event
        RaiseEvent Error$(myLastErrorNumber, myLastErrorText)
      Else
        PrepStop
        Err.Raise myLastErrorNumber, myRunId, myLastErrorText
    End If

End Sub

Private Sub ErrLocked(PropName As String, ErrNum As Long)

    myLastErrorNumber = vbObjectError + ErrNum
    myLastErrorText = "'" & PropName & "' is currently locked" & AddWhere
    If myErrorNotify Then
        'fire error event
        RaiseEvent Error$(myLastErrorNumber, myLastErrorText)
      Else
        PrepStop
        Err.Raise myLastErrorNumber, myRunId, myLastErrorText
    End If

End Sub

Public Property Let ErrorNotify(ByVal nuErrorNotify As Boolean)

    myErrorNotify = CBool(nuErrorNotify)

End Property

Public Property Get ErrorNotify() As Boolean

    ErrorNotify = myErrorNotify

End Property

Private Function FatalSequenceError() As Boolean

    If Not myStartingUp Then
        With myGroupProps(myGroupTrigger)
            If Compare(.NextKey, .CurrentKey, myGroupTrigger) = iLess Then ' a < b if PS_Ascending; a > b if PS_Descending
                NewToCurrent
                myKeyInError = myGroupTrigger
                myLastErrorNumber = vbObjectError + 11
                myLastErrorText = "Key sequence error in key " & myKeyInError & " of record " & myStreamProps(myCurrentStream).RecordCount & " in stream " & myCurrentStream
                If myActiveStreams > 1 Or myHaltOnSequenceError Then
                    FatalSequenceError = True
                    myLastErrorNumber = vbObjectError + 12
                    myLastErrorText = "Fatal " & myLastErrorText
                    myClosingDown = True
                End If
                Inc mySequenceErrorCount
                Display myLastErrorText, IIf(myActiveStreams = 1, PS_Extended, PS_Minimal)
                Perform PS_SequenceError, myCurrentStream, "Sequence error"
            End If
        End With
    End If

End Function

Private Sub FetchRecords()

    For myActionNumber = 1 To myNumberOfStreams
        With myStreamProps(myActionNumber)
            If .StreamState = PS_SkipRecord Then 'fetch next record
                Perform PS_FetchRecord, myActionNumber, "Fetch record " & .RecordCount + 1 & " of stream " & myActionNumber
                If AbortRequest Then
                    Exit Sub
                  Else
                    If .StreamState = PS_SkipRecord Then 'not eof
                        Inc .RecordCount
                    End If
                End If
            End If
        End With
    Next myActionNumber

End Sub

Private Sub FindSmallestKey()

  Dim Initially As Boolean

    PreviousStream = myCurrentStream
    myCurrentStream = 0
    Initially = True
    For i = 1 To myNumberOfStreams
        Select Case myStreamProps(i).StreamState
          Case PS_EndOfStream
            Mid$(myMatches, i, 1) = "F"
            Mid$(DefMatches, i, 1) = "F"
          Case PS_ReleaseRecord
            For j = myNumberOfGroups To 0 Step -1
                Select Case Compare(myRecordKeys(i, j), myGroupProps(j).NextKey, j, Initially)
                  Case iGreater 'a > b if PS_Ascending; a < b if PS_Descending
                    Exit For
                  Case iLess 'a < b if PS_Ascending; a > b if PS_Descending
                    For k = j To 0 Step -1
                        myGroupProps(k).NextKey = myRecordKeys(i, k)
                    Next k
                    myCurrentStream = i
                    myMatches = DefMatches
                    Mid$(myMatches, i, 1) = Mid$(RecordInfoChars, PS_Selected, 1)
                    Exit For
                End Select
            Next j
            If j = 0 And myNumberOfGroups > 0 Then
                Mid$(myMatches, i, 1) = Mid$(RecordInfoChars, PS_Matching, 1)
                Inc myMatchCount
            End If
            Initially = False
        End Select
    Next i
    myClosingDown = (myCurrentStream = 0)

End Sub

Public Property Get GroupCount(ByVal GroupNumber As Long) As Long

    If CheckKeyNumber(GroupCount) Then
        If myBusy Then
            GroupCount = myGroupProps(GroupNumber).GroupCount
          Else
            ErrLocked "GroupCount", 2
        End If
    End If

End Property

Public Property Get GroupIsVoid() As Boolean

    If myActionType = PS_CloseGroup And myActionNumber Then
        With myGroupProps(myActionNumber)
            Select Case myActionNumber
              Case Is < myNumberOfGroups
                GroupIsVoid = (.ItemsInGroup = 0 Or (.ItemsInGroup And myGroupProps(myActionNumber + 1).ItemsInGroup = 0 And myGroupTrigger > myActionNumber))
              Case myNumberOfGroups
                GroupIsVoid = (.ItemsInGroup = 0)
            End Select
        End With
      Else
        ErrLocked "GroupIsVoid", 3
    End If

End Property

Public Property Get GroupTrigger() As Long

    Select Case myActionType
      Case PS_OpenGroup, PS_ProcessRecord, PS_CloseGroup
        GroupTrigger = IIf(myStartingUp Or myClosingDown, 0, myGroupTrigger)
      Case Else
        ErrLocked "GroupTrigger", 4
    End Select

End Property

Public Property Let HaltOnSequenceError(nuHaltOnSequenceError As Boolean)

    myHaltOnSequenceError = CBool(nuHaltOnSequenceError)

End Property

Public Property Get HaltOnSequenceError() As Boolean

    HaltOnSequenceError = myHaltOnSequenceError

End Property

Private Function Inc(ByRef What As Long, Optional ByVal By As Long = 1) As Long

    What = What + By
    Inc = What

End Function

Public Sub IncItemCount()

    If myActionType = PS_ProcessRecord Then
        Inc myGroupProps(1).ItemsInGroup
      Else
        ErrLocked "IncItemCount", 5
    End If

End Sub

Public Property Get IsAnimated() As Boolean

    IsAnimated = myAnimation

End Property

Public Property Get IsClosingDown() As Boolean

    If myActionType = PS_CloseGroup Then
        IsClosingDown = myClosingDown
      Else
        ErrLocked "IsClosingDown", 6
    End If

End Property

Private Function IsData(Var As Variant) As Boolean

    IsData = Not (IsObject(Var) Or IsArray(Var) Or IsEmpty(Var) Or IsError(Var))

End Function

Public Property Get IsStartingUp() As Boolean

    Select Case myActionType
      Case PS_OpenGroup, PS_ProcessRecord
        IsStartingUp = myStartingUp
      Case Else
        ErrLocked "IsStartingUp", 7
    End Select

End Property

Public Property Get ItemsInGroup() As Long

    If myActionType = PS_CloseGroup And myActionNumber And myActionNumber <= myNumberOfGroups Then
        ItemsInGroup = myGroupProps(myActionNumber).ItemsInGroup
      Else
        ErrLocked "ItemsInGroup", 8
    End If

End Property

Public Property Get KeyInError() As Long

    If myActionType = PS_SequenceError Then
        KeyInError = myKeyInError
      Else
        ErrLocked "KeyInError", 9
    End If

End Property

Public Property Get LastErrorNumber() As Long

    LastErrorNumber = myLastErrorNumber

End Property

Public Property Get LastErrorText() As String

    LastErrorText = myLastErrorText

End Property

Public Property Get MaxNumber() As Long

    MaxNumber = myMaxNumber

End Property

Public Property Let MaxNumber(ByVal nuMaxNumber As Long)

    myMaxNumber = nuMaxNumber

End Property

Private Sub NewToCurrent()

    For i = myGroupTrigger To 0 Step -1
        myGroupProps(i).CurrentKey = myGroupProps(i).NextKey
    Next i

End Sub

Public Property Get NullSubstitute(ByVal KeyNumber As Long) As Variant

    If CheckKeyNumber(KeyNumber) Then
        NullSubstitute = myGroupProps(KeyNumber).NullSubstitute
    End If

End Property

Public Property Let NullSubstitute(ByVal KeyNumber As Long, ByVal nuNullSubstitute As Variant)

    PropName = "NullSubstitute"
    If CheckKeyNumber(KeyNumber) Then
        Select Case True
          Case myBusy
            ErrLocked PropName, 10
          Case IsData(nuNullSubstitute)  'IsData includes Null
            myGroupProps(KeyNumber).NullSubstitute = nuNullSubstitute
          Case Else
            ErrInvProp PropName, False, CStr(nuNullSubstitute)
        End Select
    End If

End Property

Public Property Get NullValue() As NullOrder

    NullValue = IIf(myNullOrder = 1, PS_NullIsLow, PS_NullIsHigh)

End Property

Public Property Let NullValue(nuCompare As NullOrder)

    PropName = "NullValue"
    Select Case True
      Case myBusy
        ErrLocked PropName, 11
      Case nuCompare = PS_NullIsLow Or nuCompare = PS_NullIsHigh
        myNullOrder = IIf(nuCompare = PS_NullIsLow, iAscending, iDescending)
      Case Else
        ErrInvProp PropName, False, CStr(nuCompare)
    End Select

End Property

Public Property Get NumberOfGroups() As Long

    NumberOfGroups = myNumberOfGroups

End Property

Public Property Let NumberOfGroups(ByVal nuNumberOfGroups As Long)

    PropName = "NumberOfGroups"
    If myBusy Then
        ErrLocked PropName, 12
      Else
        If nuNumberOfGroups >= 0 And nuNumberOfGroups <= myMaxNumber Then
            myNumberOfGroups = nuNumberOfGroups
            ReDim myGroupProps(0 To myNumberOfGroups + 1)
            For i = 0 To myNumberOfGroups + 1
                With myGroupProps(i)
                    .CurrentKey = Null
                    .NextKey = Null
                    .NullSubstitute = Null
                    .GroupCount = 0
                    .SortOrder = iAscending
                    If myNumberOfStreams Then
                        ReDim myGroupProps(i).RecordsInGroup(1 To myNumberOfStreams)
                    End If
                End With
            Next i
            BuildSwitchTable
          Else
            ErrInvProp PropName, False, CStr(nuNumberOfGroups)
        End If
    End If

End Property

Public Property Get NumberOfStreams() As Long

    NumberOfStreams = myNumberOfStreams

End Property

Public Property Let NumberOfStreams(ByVal nuNumberOfStreams As Long)

    PropName = "NumberOfStreams"
    If myBusy Then
        ErrLocked PropName, 13
      Else
        If nuNumberOfStreams >= 0 And nuNumberOfStreams <= myMaxNumber Then
            myNumberOfStreams = nuNumberOfStreams
            ReDim myStreamProps(1 To myNumberOfStreams)
            For i = 1 To myNumberOfGroups + 1
                ReDim myGroupProps(i).RecordsInGroup(1 To myNumberOfStreams)
            Next i
            For i = 1 To myNumberOfStreams
                myStreamProps(i).StreamState = PS_SkipRecord 'preset to fetch record
            Next i
            BuildSwitchTable
          Else
            ErrInvProp PropName, False, CStr(nuNumberOfStreams)
        End If
    End If

End Property

Private Sub OpenGroups()

    For myActionNumber = myGroupTrigger To 1 Step -1
        Perform PS_OpenGroup, myActionNumber, "Initialize group " & myActionNumber
        With myGroupProps(myActionNumber)
            For i = 1 To myNumberOfStreams
                .RecordsInGroup(i) = 0
            Next i
            .ItemsInGroup = 0
            Inc .GroupCount
        End With
    Next myActionNumber

End Sub

Private Sub OpenStreams()

    For myActionNumber = 1 To myNumberOfStreams
        With myStreamProps(myActionNumber)
            If .StreamState <> PS_Absent Then 'stream is active
                Perform PS_OpenStream, myActionNumber, "Open stream " & myActionNumber
                If AbortRequest Then
                    Exit Sub
                End If
            End If
            If .StreamState <> PS_Absent Then 'stream is not absent
                Inc myActiveStreams
                .Opened = True
                Mid$(DefMatches, myActionNumber, 1) = Mid$(RecordInfoChars, IIf(myNumberOfGroups = 0, PS_Holding, PS_Waiting), 1)
                Display "Stream " & myActionNumber & " has been opened", PS_Normal
              Else
                Display "Stream " & myActionNumber & " is not active in this run", PS_Normal
            End If
        End With
    Next myActionNumber

End Sub

Private Sub Perform(ActType As ActionTypes, ActNumber As Long, ActName As String)

    myActionType = ActType
    myActionNumber = ActNumber
    myActionName = ActName
    Inc myCallCount
    j = mySwitches(myActionType, myActionNumber)
    If myTraceRequest = PS_Extended Then
        Display "Calling " & ActType & "/" & ActNumber & "(" & j & ") " & myActionName & IIf((myActionType = PS_OpenGroup Or myActionType = PS_ProcessRecord) And ActNumber <> 0, " (" & myMatches & ")", vbNullString), PS_Extended
    End If

    'fire action request event
    RaiseEvent ActionRequest(j, myActionType, myActionNumber, myActionName)

End Sub

Private Sub PrepStop()

    myBusy = False
    If myControlMP Then
        Screen.MousePointer = vbNormal
    End If
    If myAnimation Then
        Unload fAnim
    End If

End Sub

Public Property Get ProcessedCount(ByVal StreamNumber As Long) As Long

    If CheckStreamNumber(StreamNumber) Then
        If myBusy Then
            ProcessedCount = myStreamProps(StreamNumber).ProcessedCount
          Else
            ErrLocked "ProcessedCount", 14
        End If
    End If

End Property

Private Sub ProgramTermination()

    myStartingUp = False
    If IniProcPerformed Then
        Perform PS_CloseGroup, 0, "Terminate processing"
        IniProcPerformed = False
    End If
    If myActiveStreams > 1 Then
        Display TTNO & "matching key pairs was " & Format$(myMatchCount, FRMT), PS_Normal
    End If
    If mySequenceErrorCount > 0 Then
        Display Format$(mySequenceErrorCount, FRMT) & " Key sequence error(s) were detected", PS_Normal
    End If
    CloseStreams
    Perform PS_TerminateProgram, 0, "Terminate program"
    myBusy = False

End Sub

Public Property Get RecordCount(ByVal StreamNumber As Long) As Long

    If CheckStreamNumber(StreamNumber) Then
        If myBusy Then
            RecordCount = myStreamProps(StreamNumber).RecordCount
          Else
            ErrLocked "RecordCount", 15
        End If
    End If

End Property

Public Property Get RecordIs(ByVal StreamNumber As Long) As RecordInfo

    If CheckStreamNumber(StreamNumber) Then
        If (myActionType = PS_OpenGroup Or myActionType = PS_ProcessRecord) And myActionNumber > 0 Then
            RecordIs = InStr(RecordInfoChars, Mid$(myMatches, StreamNumber, 1))
          Else
            ErrLocked "RecordIs", 16
        End If
    End If

End Property

Public Property Get RecordKey(ByVal StreamNumber As Long, ByVal KeyNumber As Long) As Variant

    If CheckStreamNumber(StreamNumber) Then
        If CheckKeyNumber(KeyNumber) Then
            If myStreamProps(StreamNumber).StreamState = PS_ReleaseRecord And (myActionType = PS_SequenceError Or myActionType = PS_OpenGroup Or myActionType = PS_ProcessRecord) Then
                RecordKey = myRecordKeys(StreamNumber, KeyNumber)
              Else
                ErrLocked "RecordKey", 18
            End If
        End If
    End If

End Property

Public Property Let RecordKey(ByVal StreamNumber As Long, ByVal KeyNumber As Long, ByVal nuRecordKey As Variant)

    PropName = "RecordKey"
    If CheckStreamNumber(StreamNumber) Then
        If CheckKeyNumber(KeyNumber) Then
            If IsData(nuRecordKey) Then
                If myActionType = PS_OpenStream Or myActionType = PS_CheckRecord Then
                    If IsNull(nuRecordKey) Then
                        myRecordKeys(StreamNumber, KeyNumber) = myGroupProps(KeyNumber).NullSubstitute
                      Else
                        If VarType(nuRecordKey) = VarType(myRecordKeys(StreamNumber, KeyNumber)) Or IsNull(myRecordKeys(StreamNumber, KeyNumber)) Then
                            myRecordKeys(StreamNumber, KeyNumber) = nuRecordKey
                          Else
                            ErrInvProp PropName, True, TypeName(nuRecordKey)
                        End If
                    End If
                  Else
                    ErrLocked PropName, 17
                End If
              Else
                ErrInvProp PropName, False, CStr(nuRecordKey)
            End If
        End If
    End If

End Property

Public Property Get RecordsInGroup(ByVal FromStream As Long) As Long

    If myActionType = PS_CloseGroup And myActionNumber Then
        If CheckStreamNumber(FromStream) Then
            RecordsInGroup = myGroupProps(myActionNumber).RecordsInGroup(FromStream)
        End If
      Else
        ErrLocked "RecordsInGroup", 19
    End If

End Property

Public Property Get RecRelation() As String

    Select Case myActionType
      Case PS_OpenGroup, PS_ProcessRecord
        RecRelation = myMatches
      Case Else
        ErrLocked "RecRelation", 38
    End Select

End Property

Public Sub Reset()

    Class_Terminate
    Class_Initialize

End Sub

Private Sub ResetKeys(OfStream As Long)

    For j = 1 To myNumberOfGroups
        myRecordKeys(OfStream, j) = Null
    Next j

End Sub

Public Function Run(Optional ByVal Id As String) As Long

    If myBusy Then
        ErrLocked "Run", 20
      Else
        myBusy = True
        myRunId = IIf(Id = vbNullString, myRunId, Id)
        myAnimTitle = IIf(AnimTitle = vbNullString, myRunId, myAnimTitle)
        If myControlMP Then
            Screen.MousePointer = vbHourglass
        End If
        If myAnimation Then
            Load fAnim
            With fAnim
                .Caption = myAnimTitle
                .Move myAnimX - .Width / 2, myAnimY - .Height / 2
                .Show
                DoEvents
            End With
        End If
        AbortRequest = False

        ReDim myRecordKeys(0 To myNumberOfStreams, 0 To myNumberOfGroups)
        myGroupProps(0).CurrentKey = 0
        For i = 1 To myNumberOfStreams
            With myStreamProps(i)
                .RecordCount = 0
                .ProcessedCount = 0
                .Opened = False
            End With
            myRecordKeys(i, 0) = i
            ResetKeys i
        Next i
        myMatches = String$(myNumberOfStreams, Mid$(RecordInfoChars, PS_Omitted, 1))
        DefMatches = myMatches
        myMatchCount = 0
        myCallCount = 0
        mySequenceErrorCount = 0
        myActiveStreams = 0

        'Client starts
        StartTime = Now
        myStartingUp = True
        Display "Run (" & myRunId & ") starts on " & Format$(StartTime, "Long Date") & " at " & Format$(StartTime, "Long Time"), PS_Minimal
        Display "The client program must provide code for " & k & " distinct action modules", PS_Normal
        Perform PS_InitializeProgram, 0, "Initialize program"
        If Not AbortRequest Then
            Display "Service for " & myNumberOfStreams & " stream(s) and " & myNumberOfGroups & " group level(s) will be provided", PS_Normal
            OpenStreams
            Select Case True
              Case myActiveStreams > 1 And myNumberOfGroups > 0
                Display "Merging logic has been activated for " & myActiveStreams & " out of " & myNumberOfStreams & " stream(s)", PS_Normal
                Display "Key sequence errors will be fatal", PS_Extended
              Case myActiveStreams = 0
                'do nothing - lack of streams
              Case myActiveStreams = 1
                Display "M" & MLID, PS_Normal
              Case Else 'streams but no groups
                Display "No group keys; m" & MLID & " and the active streams will be serialized", PS_Normal
            End Select
        End If

        'Main Loop starts here
        '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
        Do
            If Not AbortRequest Then
                Do
                    FetchRecords
                    If AbortRequest Then
                        Exit Do
                    End If
                Loop Until CheckRecords
            End If
            If Not AbortRequest Then
                If myStartingUp And myActiveStreams Then
                    Perform PS_OpenGroup, 0, "Initialize processing"
                    IniProcPerformed = True
                End If
                If AbortRequest Then
                    myGroupTrigger = myNumberOfGroups
                  Else
                    FindSmallestKey 'may set ClosingDown
                    DetectControlBreak 'sets the triggering group
                    CloseGroups 'closes groups from 1 up to triggering group
                End If
            End If
            If AbortRequest Or FatalSequenceError Then
                CloseRemainingGroups
            End If
            If myClosingDown Then
                For i = 1 To myNumberOfGroups
                    myGroupProps(i).CurrentKey = Null
                Next i
                If myStartingUp Then
                    If AbortRequest Then
                        Display AGRB & "abort request", PS_Normal
                      Else
                        Display AGRB & "lack of " & IIf(myActiveStreams = 0, "streams", "records"), PS_Normal
                    End If
                End If
                ProgramTermination
              Else
                NewToCurrent
                OpenGroups 'opens groups from triggering group down to 1
                If myCurrentStream = myAutoInc Then
                    Inc myGroupProps(1).ItemsInGroup
                End If
                Inc myGroupProps(1).RecordsInGroup(myCurrentStream)
                With myStreamProps(myCurrentStream)
                    Perform PS_ProcessRecord, myCurrentStream, "Process record " & .RecordCount & " of stream " & myCurrentStream
                    myGroupTrigger = 0
                    .StreamState = PS_SkipRecord
                    Inc .ProcessedCount
                End With
            End If
            myStartingUp = False
            If myAnimation Then
                DoEvents
            End If
        Loop While myBusy
        '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
        'Main Loop ends here

        Erase myGroupProps, myStreamProps, myRecordKeys
        Display TTNO & " module activation requests was " & Format$(myCallCount, FRMT), PS_Normal
        Display "Run (" & myRunId & ") terminates on " & Format$(Now, "Long Date") & " at " & Format$(Now, "Long Time") & "; Return Code is " & Format$(myLastErrorNumber, "0;-0;zero"), PS_Minimal
        Display "The elapsed time was " & Format$(Now - StartTime, "Long Time"), PS_Minimal
        If myControlMP Then
            On Error Resume Next
                Screen.MousePointer = vbNormal
            On Error GoTo 0
        End If
    End If
    If myAnimation Then
        Unload fAnim
    End If
    Run = myLastErrorNumber

End Function

Public Property Get RunId() As String

    RunId = myRunId

End Property

Public Property Let RunId(nuRunId As String)

    If myBusy Then
        ErrLocked "RunID", 21
      Else
        myRunId = nuRunId
    End If

End Property

Public Property Get SequenceErrorCount() As Long

    If myBusy Then
        SequenceErrorCount = mySequenceErrorCount
      Else
        ErrLocked "SequenceErrorCount", 22
    End If

End Property

Public Property Get SequenceErrorIsFatal() As Boolean

    If myActionType = PS_SequenceError Then
        SequenceErrorIsFatal = (myActiveStreams > 1)
      Else
        ErrLocked "SequenceErrorIsFatal", 23
    End If

End Property

Public Property Get SortOrder(ByVal KeyNumber As Long) As CollatingOrder

    If CheckKeyNumber(KeyNumber) Then
        SortOrder = IIf(myGroupProps(KeyNumber).SortOrder = iAscending, PS_Ascending, PS_Descending)
    End If

End Property

Public Property Let SortOrder(ByVal KeyNumber As Long, ByVal nuSortOrder As CollatingOrder)

    If CheckKeyNumber(KeyNumber) Then
        PropName = "SortOrder"
        If myActionType <> PS_InitializeProgram Then
            ErrLocked PropName, 24
          Else
            If nuSortOrder = PS_Ascending Or nuSortOrder = PS_Descending Then
                myGroupProps(KeyNumber).SortOrder = IIf(nuSortOrder = PS_Ascending, iAscending, iDescending)
              Else
                ErrInvProp PropName, False, CStr(nuSortOrder)
            End If
        End If
    End If

End Property

Public Property Get StreamIsPresent(ByVal StreamNumber As Long) As Boolean

    If CheckStreamNumber(StreamNumber) Then
        If myActionType <> PS_InitializeProgram And myActionType <> PS_TerminateProgram Then
            StreamIsPresent = (myStreamProps(StreamNumber).StreamState <> PS_Absent)
          Else
            ErrLocked "StreamIsPresent", 25
        End If
    End If

End Property

Public Property Get StreamState(ByVal StreamNumber As Long) As StreamControl

    If CheckStreamNumber(StreamNumber) Then
        If myActionType <> PS_InitializeProgram And myActionType <> PS_TerminateProgram Then
            StreamState = myStreamProps(StreamNumber).StreamState
          Else
            ErrLocked "StreamState", 27
        End If
    End If

End Property

Public Property Let StreamState(ByVal StreamNumber As Long, ByVal nuStreamState As StreamControl)

    If CheckStreamNumber(StreamNumber) Then
        PropName = "StreamState"
        With myStreamProps(StreamNumber)
            Select Case myActionType
              Case PS_InitializeProgram, PS_OpenStream
                If nuStreamState = PS_Absent Then
                    .StreamState = nuStreamState
                  Else
                    ErrInvProp PropName, False, CStr(nuStreamState)
                End If
              Case PS_FetchRecord
                If nuStreamState = PS_EndOfStream Then
                    .StreamState = nuStreamState
                    Display "Fetching from stream " & StreamNumber & " has ended after " & Format$(.RecordCount, FRMT) & " record(s)", PS_Extended
                  Else
                    ErrInvProp PropName, False, CStr(nuStreamState)
                End If
              Case PS_CheckRecord
                If nuStreamState = PS_SkipRecord Or nuStreamState = PS_ReleaseRecord Or nuStreamState = PS_EndOfStream Then
                    .StreamState = nuStreamState
                  Else
                    ErrInvProp PropName, False, CStr(nuStreamState)
                End If
              Case Else
                ErrLocked PropName, 26
            End Select
        End With
    End If

End Property

Public Property Get TraceRequest() As TraceLevel

    TraceRequest = myTraceRequest

End Property

Public Property Let TraceRequest(ByVal nuTraceRequest As TraceLevel)

    Select Case nuTraceRequest
      Case PS_Silent, PS_Normal, PS_Minimal, PS_Extended
        myTraceRequest = nuTraceRequest
      Case Else
        ErrInvProp "TraceRequest", False, CStr(nuTraceRequest)
    End Select

End Property

Public Property Get Version() As String

    Version = "PS.DLL - Current Version is  " & App.Major & "." & App.Minor & "  Build " & Format$(App.Revision, "00")

End Property

Public Property Get VersionNumber() As Long

    VersionNumber = App.Major * 10000 + App.Minor * 100 + App.Revision

End Property

':) Ulli's VB Code Formatter V2.21.6 (2006-Mrz-30 13:57)  Decl: 164  Code: 1512  Total: 1676 Lines
':) CommentOnly: 23 (1,4%)  Commented: 94 (5,6%)  Empty: 311 (18,6%)  Max Logic Depth: 7
