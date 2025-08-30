object FormMain: TFormMain
  Caption = 'Process Memory Reader'
  ClientHeight = 600
  ClientWidth = 900
  Position = poScreenCenter
  OnCreate = FormCreate
  object PanelTop: TPanel
    Align = alTop
    Height = 48
    TabOrder = 0
    object btnRefresh: TButton
      Left = 8
      Top = 10
      Width = 120
      Height = 28
      Caption = 'Refresh'
      TabOrder = 0
      OnClick = btnRefreshClick
    end
    object btnDebug: TButton
      Left = 136
      Top = 10
      Width = 200
      Height = 28
      Caption = 'Enable Debug Privilege'
      TabOrder = 1
      OnClick = btnDebugClick
    end
  end
  object lvProcs: TListView
    Align = alTop
    Height = 250
    TabOrder = 1
  end
  object PanelRead: TPanel
    Align = alTop
    Height = 176
    TabOrder = 2
    object Label1: TLabel
      Left = 8
      Top = 12
      Caption = 'Address (hex):'
    end
    object edAddress: TEdit
      Left = 100
      Top = 8
      Width = 220
      Height = 24
      TabOrder = 0
      Text = ''
    end
    object Label2: TLabel
      Left = 340
      Top = 12
      Caption = 'Size (bytes):'
    end
    object edSize: TEdit
      Left = 420
      Top = 8
      Width = 100
      Height = 24
      TabOrder = 1
      Text = '256'
    end
    object btnRead: TButton
      Left = 540
      Top = 7
      Width = 120
      Height = 26
      Caption = 'Read'
      TabOrder = 2
      OnClick = btnReadClick
    end
    object btnBase: TButton
      Left = 670
      Top = 7
      Width = 170
      Height = 26
      Caption = 'Main Module Base'
      TabOrder = 3
      OnClick = btnBaseClick
    end
    object btnInspect: TButton
      Left = 8
      Top = 40
      Width = 100
      Height = 26
      Caption = 'Inspect'
      TabOrder = 4
      OnClick = btnInspectClick
    end
    object btnPrev: TButton
      Left = 116
      Top = 40
      Width = 100
      Height = 26
      Caption = 'Prev readable'
      TabOrder = 5
      OnClick = btnPrevClick
    end
    object btnNext: TButton
      Left = 224
      Top = 40
      Width = 100
      Height = 26
      Caption = 'Next readable'
      TabOrder = 6
      OnClick = btnNextClick
    end
    object Label3: TLabel
      Left = 8
      Top = 76
      Caption = 'Search:'
    end
    object edSearch: TEdit
      Left = 64
      Top = 72
      Width = 300
      Height = 24
      TabOrder = 7
      Text = ''
    end
    object cbEncoding: TComboBox
      Left = 372
      Top = 72
      Width = 120
      Height = 24
      Style = csDropDownList
      TabOrder = 8
      Items.Strings = (
        'ASCII'
        'UTF-16LE')
      ItemIndex = 0
    end
    object chkCase: TCheckBox
      Left = 500
      Top = 74
      Width = 140
      Height = 20
      Caption = 'Case-insensitive'
      TabOrder = 9
      Checked = True
      State = cbChecked
    end
    object btnSearch: TButton
      Left = 650
      Top = 70
      Width = 90
      Height = 26
      Caption = 'Search'
      TabOrder = 10
      OnClick = btnSearchClick
    end
    object btnFindNext: TButton
      Left = 746
      Top = 70
      Width = 94
      Height = 26
      Caption = 'Find Next'
      TabOrder = 11
      OnClick = btnFindNextClick
    end
    object cbSearchMode: TComboBox
      Left = 850
      Top = 72
      Width = 120
      Height = 24
      Style = csDropDownList
      TabOrder = 12
      Items.Strings = (
        'Text'
        'Hex'
        'Regex')
      ItemIndex = 0
    end
    object btnScanAll: TButton
      Left = 540
      Top = 104
      Width = 120
      Height = 26
      Caption = 'Scan All'
      TabOrder = 13
      OnClick = btnScanAllClick
    end
    object btnClearHits: TButton
      Left = 670
      Top = 104
      Width = 120
      Height = 26
      Caption = 'Clear Hits'
      TabOrder = 14
      OnClick = btnClearHitsClick
    end
    object chkRegexMultiline: TCheckBox
      Left = 850
      Top = 100
      Width = 120
      Height = 20
      Caption = 'Regex Multiline'
      TabOrder = 15
    end
    object chkRegexDotAll: TCheckBox
      Left = 980
      Top = 100
      Width = 120
      Height = 20
      Caption = 'Regex DotAll'
      TabOrder = 16
    end
    object btnMap: TButton
      Left = 8
      Top = 136
      Width = 120
      Height = 26
      Caption = 'Refresh Map'
      TabOrder = 17
      OnClick = btnMapClick
    end
  end
  object lvHits: TListView
    Align = alTop
    Height = 160
    TabOrder = 4
    OnDblClick = lvHitsDblClick
  end
  object lvMap: TListView
    Align = alTop
    Height = 220
    TabOrder = 5
    OnDblClick = lvMapDblClick
  end
  object memOut: TMemo
    Align = alClient
    ScrollBars = ssBoth
    WordWrap = False
    TabOrder = 3
  end
end
