VERSION 5.00
Object = "{27395F88-0C0C-101B-A3C9-08002B2F49FB}#1.1#0"; "PICCLP32.OCX"
Begin VB.Form fAnim 
   BackColor       =   &H0080C0FF&
   BorderStyle     =   4  'Festes Werkzeugfenster
   Caption         =   " ...arbeitet"
   ClientHeight    =   1470
   ClientLeft      =   5085
   ClientTop       =   3960
   ClientWidth     =   1665
   ControlBox      =   0   'False
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   MousePointer    =   11  'Sanduhr
   ScaleHeight     =   1470
   ScaleWidth      =   1665
   ShowInTaskbar   =   0   'False
   Begin VB.Timer tim 
      Enabled         =   0   'False
      Left            =   195
      Top             =   1995
   End
   Begin PicClip.PictureClip pcl 
      Left            =   1260
      Top             =   45
      _ExtentX        =   22225
      _ExtentY        =   2461
      _Version        =   393216
      Cols            =   8
      Picture         =   "fAnim.frx":0000
   End
   Begin VB.Image img 
      Height          =   600
      Left            =   45
      Top             =   45
      Width           =   600
   End
End
Attribute VB_Name = "fAnim"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit
Private Declare Sub SetWindowPos Lib "user32" (ByVal hWnd As Long, ByVal hWndInsertAfter As Long, ByVal x As Long, ByVal y As Long, ByVal cx As Long, ByVal cy As Long, ByVal wFlags As Long)
Private Enum ApiConstants
    HWND_TOPMOST = -1
    SWP_NOSIZE = 1
    SWP_NOMOVE = 2
    SWP_NOACTIVATE = 16
    SWP_OPTIONS = SWP_NOSIZE Or SWP_NOMOVE Or SWP_NOACTIVATE
End Enum
#If False Then
Private HWND_TOPMOST, SWP_NOSIZE, SWP_NOMOVE, SWP_NOACTIVATE, SWP_OPTIONS
#End If
Private Frame   As Integer
Private MaxF    As Integer

Private Sub Form_Load()

    SetWindowPos hWnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_OPTIONS
    MaxF = pcl.Cols
    Frame = MaxF
    tim_Timer
    tim.Enabled = True

End Sub

Private Sub Form_Unload(Cancel As Integer)

    tim.Enabled = False

End Sub

Private Sub tim_Timer()

    Frame = Frame + 1
    If Frame >= MaxF Then
        tim.Interval = 1800
        Frame = 0
      Else 'NOT Frame...
        tim.Interval = 70
    End If
    img.Picture = pcl.GraphicCell(Frame)

End Sub

':) Ulli's VB Code Formatter V2.21.6 (2006-Mrz-30 13:57)  Decl: 14  Code: 32  Total: 46 Lines
':) CommentOnly: 0 (0%)  Commented: 1 (2,2%)  Empty: 9 (19,6%)  Max Logic Depth: 2
