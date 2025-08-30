unit UMain;

interface

uses
  Winapi.Windows, Winapi.TlHelp32,
  System.SysUtils, System.Classes, System.Generics.Collections, System.StrUtils, System.UITypes, System.Math,
  System.RegularExpressions,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls;

type
  TFormMain = class(TForm)
    PanelTop: TPanel;
    btnRefresh: TButton;
    btnDebug: TButton;
    lvProcs: TListView;
    PanelRead: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    edAddress: TEdit;
    edSize: TEdit;
    btnRead: TButton;
    memOut: TMemo;
    btnBase: TButton;
    btnInspect: TButton;
    btnPrev: TButton;
    btnNext: TButton;
    Label3: TLabel;
    edSearch: TEdit;
    cbEncoding: TComboBox;
    chkCase: TCheckBox;
    btnSearch: TButton;
    btnFindNext: TButton;
    cbSearchMode: TComboBox;
    btnScanAll: TButton;
    btnClearHits: TButton;
    lvHits: TListView;
    chkRegexMultiline: TCheckBox;
    chkRegexDotAll: TCheckBox;
    btnMap: TButton;
    lvMap: TListView;
    procedure FormCreate(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnDebugClick(Sender: TObject);
    procedure btnReadClick(Sender: TObject);
    procedure btnBaseClick(Sender: TObject);
    procedure btnInspectClick(Sender: TObject);
    procedure btnPrevClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnSearchClick(Sender: TObject);
    procedure btnFindNextClick(Sender: TObject);
    procedure btnScanAllClick(Sender: TObject);
    procedure btnClearHitsClick(Sender: TObject);
    procedure lvHitsDblClick(Sender: TObject);
    procedure btnMapClick(Sender: TObject);
    procedure lvMapDblClick(Sender: TObject);
  private
    procedure SetupListView;
    procedure LoadProcesses;
    function EnableDebugPrivilege(const Enable: Boolean): Boolean;
    function ParseHex64(const S: string; out V: UInt64): Boolean;
    function HexDump(const Bytes: TBytes; Base: UInt64; Count: NativeUInt): string;
    function Hex64(V: UInt64; Digits: Integer = 16): string;
    function GetMainModuleBase(PID: Cardinal; out Base: UInt64): Boolean;
    function QueryReadableSpan(hProc: THandle; Addr: UInt64; Requested: UInt64; out CanRead: UInt64; out Info: MEMORY_BASIC_INFORMATION): Boolean;
    function IsReadableProtect(Prot: DWORD): Boolean;
    function FindNextReadable(hProc: THandle; Start: UInt64; ForwardDir: Boolean; out OutBase: UInt64): Boolean;
    procedure DumpMemoryMap(hProc: THandle);
    function BuildSearchPattern(const Text: string; EncodingIndex: Integer; CaseInsensitive: Boolean; out Pattern: TBytes): Boolean;
    function FindPatternFrom(hProc: THandle; Start: UInt64; const Pattern: TBytes; EncodingIndex: Integer; CaseInsensitive: Boolean; out FoundAt: UInt64): Boolean;
    function ParseHexPattern(const S: string; out Pat: TBytes; out Mask: TBytes): Boolean;
    function BytesIndexOfMasked(const Data: TBytes; DataLen: NativeInt; const Pat, Mask: TBytes): NativeInt;
    function FindHexFrom(hProc: THandle; Start: UInt64; const Pat, Mask: TBytes; out FoundAt: UInt64): Boolean;
    function FindRegexFrom(hProc: THandle; Start: UInt64; const PatternText: string; EncodingIndex: Integer; CaseInsensitive: Boolean; out FoundAt: UInt64): Boolean;
    procedure PopulateMemoryMapList(hProc: THandle);
    function ProtectToString(P: DWORD): string;
  private
    FLastSearchPattern: TBytes;
    FLastEncodingIndex: Integer;
    FLastCaseInsensitive: Boolean;
    FNextSearchAddr: UInt64;
    FLastMode: Integer; // 0=Text,1=Hex,2=Regex
    FLastRegex: string;
  public
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

// Delphi/SDKのバージョンによっては未定義の場合があるため定義
{$IFNDEF PROCESS_QUERY_LIMITED_INFORMATION}
const
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
{$ENDIF}
{$IFNDEF TH32CS_SNAPMODULE32}
const
  TH32CS_SNAPMODULE32 = $00000010;
{$ENDIF}

// DelphiのWinapi.Windowsにある宣言差異を避けるため、
// 明示的にポインタ版を宣言して利用する
function AdjustTokenPrivilegesPtr(TokenHandle: THandle; DisableAllPrivileges: BOOL;
  NewState: PTokenPrivileges; BufferLength: DWORD;
  PreviousState: PTokenPrivileges; ReturnLength: PDWORD): BOOL; stdcall;
  external 'advapi32.dll' name 'AdjustTokenPrivileges';

procedure TFormMain.FormCreate(Sender: TObject);
begin
  SetupListView;
  edAddress.Text := '7FF6' ; // サンプル: 先頭は適当に変更してください
  edSize.Text := '256';
  LoadProcesses;
  // initialize search UI defaults
  if Assigned(cbSearchMode) then
  begin
    cbSearchMode.Items.Clear;
    cbSearchMode.Items.Add('Text');
    cbSearchMode.Items.Add('Hex');
    cbSearchMode.Items.Add('Regex');
    cbSearchMode.ItemIndex := 0;
  end;
  if Assigned(cbEncoding) then
  begin
    if cbEncoding.Items.Count = 0 then
    begin
      cbEncoding.Items.Add('ASCII');
      cbEncoding.Items.Add('UTF-16LE');
      cbEncoding.ItemIndex := 0;
    end;
  end;
end;

procedure TFormMain.SetupListView;
begin
  lvProcs.ViewStyle := vsReport;
  lvProcs.ReadOnly := True;
  lvProcs.RowSelect := True;
  lvProcs.HideSelection := False;
  lvProcs.Columns.Clear;
  with lvProcs.Columns.Add do begin
    Caption := 'PID';
    Width := 80;
  end;
  with lvProcs.Columns.Add do begin
    Caption := 'Image';
    Width := 260;
  end;
  if Assigned(lvHits) then
  begin
    lvHits.ViewStyle := vsReport;
    lvHits.ReadOnly := True;
    lvHits.RowSelect := True;
    lvHits.HideSelection := False;
    lvHits.Columns.Clear;
    with lvHits.Columns.Add do begin
      Caption := 'Address'; Width := 180; end;
    with lvHits.Columns.Add do begin
      Caption := 'Note'; Width := 80; end;
    with lvHits.Columns.Add do begin
      Caption := 'Hex'; Width := 360; end;
    with lvHits.Columns.Add do begin
      Caption := 'ASCII'; Width := 200; end;
  end;
  if Assigned(lvMap) then
  begin
    lvMap.ViewStyle := vsReport;
    lvMap.ReadOnly := True;
    lvMap.RowSelect := True;
    lvMap.HideSelection := False;
    lvMap.Columns.Clear;
    with lvMap.Columns.Add do begin Caption := 'Base'; Width := 180; end;
    with lvMap.Columns.Add do begin Caption := 'End'; Width := 180; end;
    with lvMap.Columns.Add do begin Caption := 'Size'; Width := 120; end;
    with lvMap.Columns.Add do begin Caption := 'State'; Width := 80; end;
    with lvMap.Columns.Add do begin Caption := 'Protect'; Width := 120; end;
  end;
end;

procedure TFormMain.LoadProcesses;
var
  Snap: THandle;
  pe: TProcessEntry32W;
  item: TListItem;
begin
  lvProcs.Items.BeginUpdate;
  try
    lvProcs.Items.Clear;
    Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if Snap = INVALID_HANDLE_VALUE then
      raise Exception.CreateFmt('CreateToolhelp32Snapshot failed: %s', [SysErrorMessage(GetLastError)]);

    try
      ZeroMemory(@pe, SizeOf(pe));
      pe.dwSize := SizeOf(pe);
      if Process32FirstW(Snap, pe) then
      repeat
        item := lvProcs.Items.Add;
        item.Caption := IntToStr(pe.th32ProcessID);
        item.SubItems.Add(ExtractFileName(pe.szExeFile));
      until not Process32NextW(Snap, pe);
    finally
      CloseHandle(Snap);
    end;
  finally
    lvProcs.Items.EndUpdate;
  end;
end;

function TFormMain.EnableDebugPrivilege(const Enable: Boolean): Boolean;
var
  hToken: THandle;
  NewState: TOKEN_PRIVILEGES;
begin
  Result := False;
  if not OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, hToken) then
    Exit;
  try
    ZeroMemory(@NewState, SizeOf(NewState));
    // LUID を取得
    if not LookupPrivilegeValue(nil, 'SeDebugPrivilege', NewState.Privileges[0].Luid) then
      Exit;

    NewState.PrivilegeCount := 1;
    if Enable then
      NewState.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED
    else
      NewState.Privileges[0].Attributes := 0;

    // 明示的にポインタ版を呼び出す
    if not AdjustTokenPrivilegesPtr(hToken, False, @NewState, DWORD(SizeOf(NewState)), nil, nil) then
      Exit;

    Result := GetLastError = ERROR_SUCCESS;
  finally
    CloseHandle(hToken);
  end;
end;

function TFormMain.ParseHex64(const S: string; out V: UInt64): Boolean;
var
  T: string;
  I64: Int64;
begin
  T := S.Trim;
  if T.StartsWith('0x', True) then
    T := T.Substring(2)
  else if T.StartsWith('$') then
    T := T.Substring(1);
  if T = '' then
    Exit(False);

  // StrToInt64 は $ プレフィクスで16進を解釈する
  Result := TryStrToInt64('$' + T, I64);
  if Result then
    V := UInt64(I64);
end;

function TFormMain.HexDump(const Bytes: TBytes; Base: UInt64; Count: NativeUInt): string;
const
  BytesPerLine = 16;
var
  sb: TStringBuilder;
  i, j: Integer;
  b: Byte;
  c: Char;
  lineAddr: UInt64;
begin
  sb := TStringBuilder.Create(Count * 4 + 1024);
  try
    i := 0;
    while i < Integer(Count) do
    begin
      lineAddr := Base + UInt64(i);
      sb.Append(Hex64(lineAddr, 16)).Append('  ');

      // hex
      for j := 0 to BytesPerLine - 1 do
      begin
        if i + j < Integer(Count) then
          sb.Append(IntToHex(Bytes[i + j], 2)).Append(' ')
        else
          sb.Append('   ');
        if j = 7 then sb.Append(' ');
      end;

      sb.Append(' |');

      // ascii
      for j := 0 to BytesPerLine - 1 do
      begin
        if i + j < Integer(Count) then
        begin
          b := Bytes[i + j];
          if (b >= 32) and (b < 127) then
            c := Char(b)
          else
            c := '.';
          sb.Append(c);
        end
        else
          sb.Append(' ');
      end;

      sb.AppendLine('|');
      Inc(i, BytesPerLine);
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function TFormMain.Hex64(V: UInt64; Digits: Integer): string;
const
  HEX: string = '0123456789abcdef';
var
  i: Integer;
begin
  if Digits <= 0 then Digits := 1;
  SetLength(Result, Digits);
  for i := Digits downto 1 do
  begin
    Result[i] := HEX[1 + Integer(V and $F)];
    V := V shr 4;
  end;
end;

function TFormMain.GetMainModuleBase(PID: Cardinal; out Base: UInt64): Boolean;
var
  snap: THandle;
  me: MODULEENTRY32W;
begin
  Result := False;
  Base := 0;
  snap := CreateToolhelp32Snapshot(TH32CS_SNAPMODULE or TH32CS_SNAPMODULE32, PID);
  if snap = INVALID_HANDLE_VALUE then Exit;
  try
    ZeroMemory(@me, SizeOf(me));
    me.dwSize := SizeOf(me);
    if Module32FirstW(snap, me) then
    begin
      Base := UInt64(NativeUInt(me.modBaseAddr));
      Result := Base <> 0;
    end;
  finally
    CloseHandle(snap);
  end;
end;

function TFormMain.QueryReadableSpan(hProc: THandle; Addr: UInt64; Requested: UInt64; out CanRead: UInt64; out Info: MEMORY_BASIC_INFORMATION): Boolean;
var
  vq: SIZE_T;
  regionEnd: UInt64;
  prot: DWORD;
begin
  CanRead := 0;
  ZeroMemory(@Info, SizeOf(Info));
  vq := VirtualQueryEx(hProc, Pointer(NativeUInt(Addr)), Info, SizeOf(Info));
  if vq = 0 then
    Exit(False);

  // 判定: コミット済みかつ読み取り可能で、ガードページでない
  prot := Info.Protect;
  if (Info.State <> MEM_COMMIT) or ((prot and PAGE_GUARD) <> 0) or ((prot and PAGE_NOACCESS) <> 0) then
    Exit(True); // 有効情報は返せた

  // 読み取り可能属性か判定
  if (prot and (PAGE_READONLY or PAGE_READWRITE or PAGE_WRITECOPY or PAGE_EXECUTE_READ or PAGE_EXECUTE_READWRITE or PAGE_EXECUTE_WRITECOPY)) = 0 then
    Exit(True);

  regionEnd := UInt64(NativeUInt(Info.BaseAddress)) + UInt64(Info.RegionSize);
  if Addr < UInt64(NativeUInt(Info.BaseAddress)) then
    Exit(True);
  CanRead := regionEnd - Addr;
  if CanRead > Requested then
    CanRead := Requested;
  Result := True;
end;

function TFormMain.IsReadableProtect(Prot: DWORD): Boolean;
begin
  Result := ((Prot and PAGE_NOACCESS) = 0) and ((Prot and PAGE_GUARD) = 0) and
    ((Prot and (PAGE_READONLY or PAGE_READWRITE or PAGE_WRITECOPY or PAGE_EXECUTE_READ or PAGE_EXECUTE_READWRITE or PAGE_EXECUTE_WRITECOPY)) <> 0);
end;

function TFormMain.FindNextReadable(hProc: THandle; Start: UInt64; ForwardDir: Boolean; out OutBase: UInt64): Boolean;
var
  mbi: MEMORY_BASIC_INFORMATION;
  addr: UInt64;
  vq: SIZE_T;
  lastReadable: UInt64;
begin
  Result := False;
  OutBase := 0;
  lastReadable := 0;
  if ForwardDir then
  begin
    addr := Start;
    while True do
    begin
      vq := VirtualQueryEx(hProc, Pointer(NativeUInt(addr)), mbi, SizeOf(mbi));
      if vq = 0 then Break;
      if (mbi.State = MEM_COMMIT) and IsReadableProtect(mbi.Protect) then
      begin
        if UInt64(NativeUInt(mbi.BaseAddress)) > Start then
        begin
          OutBase := UInt64(NativeUInt(mbi.BaseAddress));
          Exit(True);
        end;
      end;
      addr := UInt64(NativeUInt(mbi.BaseAddress)) + UInt64(mbi.RegionSize);
      if addr <= UInt64(NativeUInt(mbi.BaseAddress)) then Break; // wrap
    end;
  end
  else
  begin
    // 後方検索: 0 から順にたどって、Start より前の最後の readable を記録
    addr := 0;
    while True do
    begin
      vq := VirtualQueryEx(hProc, Pointer(NativeUInt(addr)), mbi, SizeOf(mbi));
      if vq = 0 then Break;
      if (mbi.State = MEM_COMMIT) and IsReadableProtect(mbi.Protect) then
      begin
        if UInt64(NativeUInt(mbi.BaseAddress)) < Start then
          lastReadable := UInt64(NativeUInt(mbi.BaseAddress))
        else
          Break;
      end;
      addr := UInt64(NativeUInt(mbi.BaseAddress)) + UInt64(mbi.RegionSize);
      if addr <= UInt64(NativeUInt(mbi.BaseAddress)) then Break; // wrap
    end;
    if lastReadable <> 0 then
    begin
      OutBase := lastReadable;
      Exit(True);
    end;
  end;
end;

procedure TFormMain.DumpMemoryMap(hProc: THandle);
var
  addr: UInt64;
  mbi: MEMORY_BASIC_INFORMATION;
  vq: SIZE_T;
  sb: TStringBuilder;
  protStr, stateStr: string;
begin
  sb := TStringBuilder.Create(1024 * 64);
  try
    addr := 0;
    sb.AppendLine('Base                Size        State      Protect');
    while True do
    begin
      vq := VirtualQueryEx(hProc, Pointer(NativeUInt(addr)), mbi, SizeOf(mbi));
      if vq = 0 then Break;

      case mbi.State of
        MEM_COMMIT: stateStr := 'COMMIT ';
        MEM_RESERVE: stateStr := 'RESERVE';
      else
        stateStr := 'FREE   ';
      end;

      protStr := IntToHex(mbi.Protect, 8);

      sb.Append(Hex64(UInt64(NativeUInt(mbi.BaseAddress)), 16)).Append('  ')
        .Append(Format('%10d', [UInt64(mbi.RegionSize)])).Append('  ')
        .Append(stateStr).Append('  ')
        .Append(protStr).AppendLine;

      addr := UInt64(NativeUInt(mbi.BaseAddress)) + UInt64(mbi.RegionSize);
      if addr <= UInt64(NativeUInt(mbi.BaseAddress)) then Break;
    end;

    memOut.Lines.BeginUpdate;
    try
      memOut.Clear;
      memOut.Text := sb.ToString;
    finally
      memOut.Lines.EndUpdate;
    end;
  finally
    sb.Free;
  end;
end;

procedure TFormMain.btnRefreshClick(Sender: TObject);
begin
  LoadProcesses;
end;

procedure TFormMain.btnDebugClick(Sender: TObject);
begin
  if EnableDebugPrivilege(True) then
    ShowMessage('SeDebugPrivilege を有効化しました。必要に応じて再試行してください。')
  else
    ShowMessage('SeDebugPrivilege の有効化に失敗しました。管理者で実行してください。');
end;

procedure TFormMain.btnReadClick(Sender: TObject);
var
  PID: Cardinal;
  hProc: THandle;
  addr: UInt64;
  sizeReq: Integer;
  bytesRead: NativeUInt;
  buf: TBytes;
  ok: BOOL;
begin
  if lvProcs.Selected = nil then
  begin
    ShowMessage('プロセスを選択してください。');
    Exit;
  end;

  PID := StrToIntDef(lvProcs.Selected.Caption, 0);
  if PID = 0 then
  begin
    ShowMessage('PID が不正です。');
    Exit;
  end;

  if not ParseHex64(edAddress.Text, addr) then
  begin
    ShowMessage('アドレスは16進で入力してください（例: 0x7FF6ABCDE000）。');
    Exit;
  end;

  sizeReq := StrToIntDef(Trim(edSize.Text), 0);
  if sizeReq <= 0 then
  begin
    ShowMessage('サイズは1以上の数値で入力してください。');
    Exit;
  end;

  if sizeReq > 65536 then
  begin
    if MessageDlg('64KBを超える読み取りです。続行しますか？', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  end;

  // VirtualQueryEx には PROCESS_QUERY_INFORMATION がより安全
  hProc := OpenProcess(PROCESS_VM_READ or PROCESS_QUERY_INFORMATION, False, PID);
  if hProc = 0 then
  begin
    ShowMessage(Format('OpenProcess 失敗: %s', [SysErrorMessage(GetLastError)]));
    Exit;
  end;

  try
    // 範囲確認と適正サイズ決定
    var mbi: MEMORY_BASIC_INFORMATION;
    var canRead: UInt64 := 0;
    if not QueryReadableSpan(hProc, addr, UInt64(sizeReq), canRead, mbi) then
    begin
      ShowMessage('指定アドレスが無効です。');
      Exit;
    end;

    if canRead = 0 then
    begin
      ShowMessage('指定アドレスは読み取り不可の領域です（未コミット/ガード/NOACCESS）。');
      Exit;
    end;

    if canRead > UInt64(sizeReq) then
      canRead := UInt64(sizeReq);

    SetLength(buf, canRead);
    bytesRead := 0;
    ok := ReadProcessMemory(hProc, Pointer(addr), Pointer(buf), canRead, bytesRead);

    if (not ok) and (bytesRead = 0) then
    begin
      ShowMessage(Format('ReadProcessMemory 失敗: %s', [SysErrorMessage(GetLastError)]));
      Exit;
    end;

    memOut.Lines.BeginUpdate;
    try
      memOut.Clear;
      memOut.Lines.Add('PID ' + IntToStr(PID)
        + '  Address 0x' + Hex64(addr, 16)
        + '  Read ' + UIntToStr(UInt64(bytesRead)) + ' bytes' + IfThen(not ok and (bytesRead>0), ' (partial)', ''));
      memOut.Lines.Add('');
      memOut.Text := memOut.Text + HexDump(buf, addr, bytesRead);
    finally
      memOut.Lines.EndUpdate;
    end;

  finally
    CloseHandle(hProc);
  end;
end;

procedure TFormMain.btnBaseClick(Sender: TObject);
var
  pid: Cardinal;
  base: UInt64;
begin
  if lvProcs.Selected = nil then
  begin
    ShowMessage('プロセスを選択してください。');
    Exit;
  end;
  pid := StrToIntDef(lvProcs.Selected.Caption, 0);
  if (pid = 0) or (not GetMainModuleBase(pid, base)) then
  begin
    ShowMessage('モジュールベースの取得に失敗しました。');
    Exit;
  end;
  edAddress.Text := '0x' + Hex64(base, 16);
end;

procedure TFormMain.btnInspectClick(Sender: TObject);
var
  pid: Cardinal;
  h: THandle;
  addr: UInt64;
  mbi: MEMORY_BASIC_INFORMATION;
  can: UInt64;
begin
  if lvProcs.Selected = nil then Exit;
  pid := StrToIntDef(lvProcs.Selected.Caption, 0);
  if (pid = 0) or (not ParseHex64(edAddress.Text, addr)) then Exit;

  h := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, pid);
  if h = 0 then
  begin
    ShowMessage('OpenProcessに失敗しました: ' + SysErrorMessage(GetLastError));
    Exit;
  end;
  try
    if not QueryReadableSpan(h, addr, 4096, can, mbi) then
    begin
      ShowMessage('VirtualQueryExに失敗しました: ' + SysErrorMessage(GetLastError));
      Exit;
    end;
    ShowMessage('Base=' + '0x' + Hex64(UInt64(NativeUInt(mbi.BaseAddress)), 16)
      + ' Size=' + UIntToStr(UInt64(mbi.RegionSize))
      + ' State=' + IntToHex(mbi.State, 8)
      + ' Protect=' + IntToHex(mbi.Protect, 8)
      + ' ReadableSpan=' + UIntToStr(can));
  finally
    CloseHandle(h);
  end;
end;

procedure TFormMain.btnPrevClick(Sender: TObject);
var
  pid: Cardinal;
  h: THandle;
  addr, base: UInt64;
begin
  if lvProcs.Selected = nil then Exit;
  pid := StrToIntDef(lvProcs.Selected.Caption, 0);
  if (pid = 0) or (not ParseHex64(edAddress.Text, addr)) then Exit;
  h := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, pid);
  if h = 0 then Exit;
  try
    if FindNextReadable(h, addr, False, base) then
      edAddress.Text := '0x' + Hex64(base, 16)
    else
      ShowMessage('前方にReadable領域が見つかりません。');
  finally
    CloseHandle(h);
  end;
end;

procedure TFormMain.btnNextClick(Sender: TObject);
var
  pid: Cardinal;
  h: THandle;
  addr, base: UInt64;
begin
  if lvProcs.Selected = nil then Exit;
  pid := StrToIntDef(lvProcs.Selected.Caption, 0);
  if (pid = 0) or (not ParseHex64(edAddress.Text, addr)) then Exit;
  h := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, pid);
  if h = 0 then Exit;
  try
    if FindNextReadable(h, addr, True, base) then
      edAddress.Text := '0x' + Hex64(base, 16)
    else
      ShowMessage('次のReadable領域が見つかりません。');
  finally
    CloseHandle(h);
  end;
end;

function TFormMain.BuildSearchPattern(const Text: string; EncodingIndex: Integer; CaseInsensitive: Boolean; out Pattern: TBytes): Boolean;
var
  i: Integer;
  s: string;
begin
  Result := False;
  SetLength(Pattern, 0);
  s := Text;
  if s = '' then Exit;

  case EncodingIndex of
    0: begin
         // ASCII
         if CaseInsensitive then
           s := AnsiUpperCase(s);
         SetLength(Pattern, Length(s));
         for i := 1 to Length(s) do
           Pattern[i-1] := Byte(Ord(s[i]) and $FF);
         Result := Length(Pattern) > 0;
       end;
    1: begin
         // UTF-16 LE (UnicodeString内部表現)
         if CaseInsensitive then
           s := UpperCase(s);
         SetLength(Pattern, Length(s) * 2);
         for i := 1 to Length(s) do
         begin
           Pattern[(i-1)*2] := Byte(Ord(s[i]) and $FF);
           Pattern[(i-1)*2 + 1] := Byte((Ord(s[i]) shr 8) and $FF);
         end;
         Result := Length(Pattern) > 0;
       end;
  else
    Exit(False);
  end;
end;

function BytesIndexOf(const Data: TBytes; DataLen: NativeInt; const Pat: TBytes): NativeInt;
var
  i, j: NativeInt;
  last: NativeInt;
begin
  if (Length(Pat) = 0) or (DataLen < Length(Pat)) then
    Exit(-1);
  last := DataLen - Length(Pat);
  i := 0;
  while i <= last do
  begin
    j := 0;
    while (j < Length(Pat)) and (Data[i + j] = Pat[j]) do Inc(j);
    if j = Length(Pat) then Exit(i);
    Inc(i);
  end;
  Result := -1;
end;

procedure UppercaseAsciiInPlace(var Buf: TBytes; Count: NativeInt);
var
  k: NativeInt;
  b: Byte;
begin
  for k := 0 to Count-1 do
  begin
    b := Buf[k];
    if (b >= Ord('a')) and (b <= Ord('z')) then
      Buf[k] := b - 32;
  end;
end;

procedure UppercaseUtf16LeAsciiInPlace(var Buf: TBytes; Count: NativeInt);
var
  k: NativeInt;
  lo, hi: Byte;
begin
  k := 0;
  while k + 1 < Count do
  begin
    lo := Buf[k];
    hi := Buf[k+1];
    if (hi = 0) and (lo >= Ord('a')) and (lo <= Ord('z')) then
      Buf[k] := lo - 32;
    Inc(k, 2);
  end;
end;

function TFormMain.FindPatternFrom(hProc: THandle; Start: UInt64; const Pattern: TBytes; EncodingIndex: Integer; CaseInsensitive: Boolean; out FoundAt: UInt64): Boolean;
const
  MAX_CHUNK: UInt64 = 262144; // 256KB
var
  addr, regionStart, regionEnd: UInt64;
  mbi: MEMORY_BASIC_INFORMATION;
  vq: SIZE_T;
  cur: UInt64;
  toRead: UInt64;
  readBytes: NativeUInt;
  buf: TBytes;
  work: TBytes;
  idx: NativeInt;
  step: UInt64;
begin
  Result := False;
  FoundAt := 0;
  addr := Start;

  while True do
  begin
    vq := VirtualQueryEx(hProc, Pointer(NativeUInt(addr)), mbi, SizeOf(mbi));
    if vq = 0 then Break;
    regionStart := UInt64(NativeUInt(mbi.BaseAddress));
    regionEnd := regionStart + UInt64(mbi.RegionSize);
    if addr < regionStart then
      addr := regionStart;

    if (mbi.State = MEM_COMMIT) and IsReadableProtect(mbi.Protect) then
    begin
      cur := addr;
      while cur < regionEnd do
      begin
        toRead := Min(regionEnd - cur, MAX_CHUNK);
        SetLength(buf, toRead);
        readBytes := 0;
        if not ReadProcessMemory(hProc, Pointer(NativeUInt(cur)), Pointer(buf), toRead, readBytes) then
        begin
          if readBytes = 0 then Break;
        end;
        SetLength(buf, readBytes);

        // prepare work buffer for case-insensitive
        work := Copy(buf);
        if CaseInsensitive then
        begin
          case EncodingIndex of
            0: UppercaseAsciiInPlace(work, Length(work));
            1: UppercaseUtf16LeAsciiInPlace(work, Length(work));
          end;
        end;

        idx := BytesIndexOf(work, Length(work), Pattern);
        if idx >= 0 then
        begin
          FoundAt := cur + UInt64(idx);
          Exit(True);
        end;

        if Length(Pattern) > 1 then
        begin
          var overlap: UInt64 := UInt64(Length(Pattern) - 1);
          if UInt64(readBytes) > overlap then
            step := UInt64(readBytes) - overlap
          else
            step := 1;
        end
        else
          step := UInt64(readBytes);
        cur := cur + step;
      end;
    end;

    addr := regionEnd;
    if addr <= regionStart then Break; // wrap
  end;
end;

function TFormMain.ParseHexPattern(const S: string; out Pat: TBytes; out Mask: TBytes): Boolean;
var
  parts: TArray<string>;
  p: string;
  b: Integer;
  v: Integer;
begin
  Result := False;
  SetLength(Pat, 0);
  SetLength(Mask, 0);
  parts := S.Split([' ', ','], TStringSplitOptions.ExcludeEmpty);
  for p in parts do
  begin
    if (p = '?') or (p = '??') then
    begin
      b := 0;
      v := 0;
    end
    else
    begin
      if Length(p) = 1 then
        Exit(False);
      if not TryStrToInt('$' + p, v) then
        Exit(False);
      v := v and $FF;
      b := 1;
    end;
    SetLength(Pat, Length(Pat)+1);
    SetLength(Mask, Length(Mask)+1);
    Pat[High(Pat)] := Byte(v);
    Mask[High(Mask)] := Byte(b);
  end;
  Result := Length(Pat) > 0;
end;

function TFormMain.BytesIndexOfMasked(const Data: TBytes; DataLen: NativeInt; const Pat, Mask: TBytes): NativeInt;
var
  i, j: NativeInt;
  last: NativeInt;
begin
  if (Length(Pat) = 0) or (DataLen < Length(Pat)) then
    Exit(-1);
  last := DataLen - Length(Pat);
  i := 0;
  while i <= last do
  begin
    j := 0;
    while j < Length(Pat) do
    begin
      if (Mask[j] = 1) and (Data[i + j] <> Pat[j]) then Break;
      Inc(j);
    end;
    if j = Length(Pat) then Exit(i);
    Inc(i);
  end;
  Result := -1;
end;

function TFormMain.FindHexFrom(hProc: THandle; Start: UInt64; const Pat, Mask: TBytes; out FoundAt: UInt64): Boolean;
const
  MAX_CHUNK: UInt64 = 262144;
var
  addr, regionStart, regionEnd: UInt64;
  mbi: MEMORY_BASIC_INFORMATION;
  vq: SIZE_T;
  cur: UInt64;
  toRead: UInt64;
  readBytes: NativeUInt;
  buf: TBytes;
  idx: NativeInt;
  step: UInt64;
begin
  Result := False;
  FoundAt := 0;
  addr := Start;
  while True do
  begin
    vq := VirtualQueryEx(hProc, Pointer(NativeUInt(addr)), mbi, SizeOf(mbi));
    if vq = 0 then Break;
    regionStart := UInt64(NativeUInt(mbi.BaseAddress));
    regionEnd := regionStart + UInt64(mbi.RegionSize);
    if addr < regionStart then
      addr := regionStart;

    if (mbi.State = MEM_COMMIT) and IsReadableProtect(mbi.Protect) then
    begin
      cur := addr;
      while cur < regionEnd do
      begin
        toRead := Min(regionEnd - cur, MAX_CHUNK);
        SetLength(buf, toRead);
        readBytes := 0;
        if not ReadProcessMemory(hProc, Pointer(NativeUInt(cur)), Pointer(buf), toRead, readBytes) then
        begin
          if readBytes = 0 then Break;
        end;
        SetLength(buf, readBytes);

        idx := BytesIndexOfMasked(buf, Length(buf), Pat, Mask);
        if idx >= 0 then
        begin
          FoundAt := cur + UInt64(idx);
          Exit(True);
        end;

        if Length(Pat) > 1 then
        begin
          var overlap2: UInt64 := UInt64(Length(Pat) - 1);
          if UInt64(readBytes) > overlap2 then
            step := UInt64(readBytes) - overlap2
          else
            step := 1;
        end
        else
          step := UInt64(readBytes);
        cur := cur + step;
      end;
    end;
    addr := regionEnd;
    if addr <= regionStart then Break;
  end;
end;

function TFormMain.FindRegexFrom(hProc: THandle; Start: UInt64; const PatternText: string; EncodingIndex: Integer; CaseInsensitive: Boolean; out FoundAt: UInt64): Boolean;
const
  MAX_CHUNK: UInt64 = 262144;
  OVERLAP: UInt64 = 1024;
var
  addr, regionStart, regionEnd: UInt64;
  mbi: MEMORY_BASIC_INFORMATION;
  vq: SIZE_T;
  cur: UInt64;
  toRead: UInt64;
  readBytes: NativeUInt;
  buf: TBytes;
  s: string;
  i: NativeInt;
  ro: TRegExOptions;
  rx: TRegEx;
  m: TMatch;
  bpc: Integer;
  chunkStartAddr: UInt64;
begin
  Result := False;
  FoundAt := 0;
  addr := Start;
  ro := [];
  if CaseInsensitive then
    ro := ro + [roIgnoreCase];
  if Assigned(chkRegexMultiline) and chkRegexMultiline.Checked then
    ro := ro + [roMultiLine];
  if Assigned(chkRegexDotAll) and chkRegexDotAll.Checked then
    ro := ro + [roSingleLine];
  rx := TRegEx.Create(PatternText, ro);
  bpc := 1;
  if EncodingIndex = 1 then bpc := 2;

  while True do
  begin
    vq := VirtualQueryEx(hProc, Pointer(NativeUInt(addr)), mbi, SizeOf(mbi));
    if vq = 0 then Break;
    regionStart := UInt64(NativeUInt(mbi.BaseAddress));
    regionEnd := regionStart + UInt64(mbi.RegionSize);
    if addr < regionStart then
      addr := regionStart;

    if (mbi.State = MEM_COMMIT) and IsReadableProtect(mbi.Protect) then
    begin
      cur := addr;
      while cur < regionEnd do
      begin
        toRead := Min(regionEnd - cur, MAX_CHUNK);
        if (cur + toRead) < regionEnd then
          toRead := toRead + OVERLAP;
        SetLength(buf, toRead);
        readBytes := 0;
        if not ReadProcessMemory(hProc, Pointer(NativeUInt(cur)), Pointer(buf), toRead, readBytes) then
        begin
          if readBytes = 0 then Break;
        end;
        SetLength(buf, readBytes);
        chunkStartAddr := cur;

        // convert buffer to string according to encoding
        if EncodingIndex = 0 then
        begin
          SetLength(s, Length(buf));
          for i := 0 to Length(buf)-1 do
            s[1+i] := Char(buf[i]);
        end
        else
        begin
          // UTF-16LE: even length only
          SetLength(s, Length(buf) div 2);
          for i := 0 to (Length(buf) div 2) - 1 do
            s[1+i] := Char(Word(buf[i*2]) or (Word(buf[i*2+1]) shl 8));
        end;

        m := rx.Match(s);
        if m.Success then
        begin
          FoundAt := chunkStartAddr + UInt64((m.Index - 1) * bpc);
          Exit(True);
        end;

        if readBytes = 0 then Break;
        if readBytes > OVERLAP then
          cur := cur + UInt64(readBytes - OVERLAP)
        else
          cur := cur + UInt64(readBytes);
      end;
    end;

    addr := regionEnd;
    if addr <= regionStart then Break;
  end;
end;

function TFormMain.ProtectToString(P: DWORD): string;
begin
  Result := '';
  if (P and PAGE_NOACCESS) <> 0 then Exit('NOACCESS');
  if (P and PAGE_GUARD) <> 0 then Result := Result + 'G';
  if (P and (PAGE_EXECUTE or PAGE_EXECUTE_READ or PAGE_EXECUTE_READWRITE or PAGE_EXECUTE_WRITECOPY)) <> 0 then Result := Result + 'X';
  if (P and (PAGE_READONLY or PAGE_READWRITE or PAGE_WRITECOPY or PAGE_EXECUTE_READ or PAGE_EXECUTE_READWRITE or PAGE_EXECUTE_WRITECOPY)) <> 0 then Result := Result + 'R';
  if (P and (PAGE_READWRITE or PAGE_EXECUTE_READWRITE)) <> 0 then Result := Result + 'W';
  if Result = '' then Result := IntToHex(P, 8);
end;

procedure TFormMain.PopulateMemoryMapList(hProc: THandle);
var
  addr: UInt64;
  mbi: MEMORY_BASIC_INFORMATION;
  vq: SIZE_T;
  item: TListItem;
  stateStr: string;
  base, endaddr: UInt64;
begin
  if lvMap = nil then Exit;
  lvMap.Items.BeginUpdate;
  try
    lvMap.Items.Clear;
    addr := 0;
    while True do
    begin
      vq := VirtualQueryEx(hProc, Pointer(NativeUInt(addr)), mbi, SizeOf(mbi));
      if vq = 0 then Break;
      base := UInt64(NativeUInt(mbi.BaseAddress));
      endaddr := base + UInt64(mbi.RegionSize);
      case mbi.State of
        MEM_COMMIT: stateStr := 'COMMIT';
        MEM_RESERVE: stateStr := 'RESERVE';
      else
        stateStr := 'FREE';
      end;
      item := lvMap.Items.Add;
      item.Caption := '0x' + Hex64(base, 16);
      item.SubItems.Add('0x' + Hex64(endaddr, 16));
      item.SubItems.Add(UIntToStr(UInt64(mbi.RegionSize)));
      item.SubItems.Add(stateStr);
      item.SubItems.Add(ProtectToString(mbi.Protect));

      addr := endaddr;
      if addr <= base then Break;
    end;
  finally
    lvMap.Items.EndUpdate;
  end;
end;
procedure TFormMain.btnSearchClick(Sender: TObject);
var
  pid: Cardinal;
  h: THandle;
  startAddr, found: UInt64;
  ok: Boolean;
  pat, mask: TBytes;
begin
  if lvProcs.Selected = nil then Exit;
  pid := StrToIntDef(lvProcs.Selected.Caption, 0);
  if pid = 0 then Exit;
  if not ParseHex64(edAddress.Text, startAddr) then
  begin
    ShowMessage('Addressが不正です');
    Exit;
  end;
  FLastMode := cbSearchMode.ItemIndex;

  h := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, pid);
  if h = 0 then
  begin
    ShowMessage('OpenProcessに失敗: ' + SysErrorMessage(GetLastError));
    Exit;
  end;
  try
    case FLastMode of
      0: begin
           if not BuildSearchPattern(edSearch.Text, cbEncoding.ItemIndex, chkCase.Checked, FLastSearchPattern) then
           begin
             ShowMessage('検索パターンを指定してください');
             Exit;
           end;
           FLastEncodingIndex := cbEncoding.ItemIndex;
           FLastCaseInsensitive := chkCase.Checked;
           ok := FindPatternFrom(h, startAddr, FLastSearchPattern, FLastEncodingIndex, FLastCaseInsensitive, found);
         end;
      1: begin
           if not ParseHexPattern(edSearch.Text, pat, mask) then
           begin
             ShowMessage('HEXパターンが不正です（例: DE AD BE EF または ?? でワイルドカード）');
             Exit;
           end;
           ok := FindHexFrom(h, startAddr, pat, mask, found);
         end;
      2: begin
           FLastRegex := edSearch.Text;
           FLastEncodingIndex := cbEncoding.ItemIndex;
           FLastCaseInsensitive := chkCase.Checked;
           ok := FindRegexFrom(h, startAddr, FLastRegex, FLastEncodingIndex, FLastCaseInsensitive, found);
         end;
    else
      ok := False;
    end;
    if ok then
    begin
      edAddress.Text := '0x' + Hex64(found, 16);
      FNextSearchAddr := found + 1;
      btnReadClick(nil);
    end
    else
      ShowMessage('見つかりませんでした。');
  finally
    CloseHandle(h);
  end;
end;

procedure TFormMain.btnFindNextClick(Sender: TObject);
var
  pid: Cardinal;
  h: THandle;
  found: UInt64;
  ok: Boolean;
begin
  if (cbSearchMode.ItemIndex = 0) and (Length(FLastSearchPattern) = 0) then
  begin
    btnSearchClick(nil);
    Exit;
  end;
  if lvProcs.Selected = nil then Exit;
  pid := StrToIntDef(lvProcs.Selected.Caption, 0);
  if pid = 0 then Exit;

  h := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, pid);
  if h = 0 then Exit;
  try
    case cbSearchMode.ItemIndex of
      0: ok := FindPatternFrom(h, FNextSearchAddr, FLastSearchPattern, FLastEncodingIndex, FLastCaseInsensitive, found);
      1: begin
           var pat, mask: TBytes; if not ParseHexPattern(edSearch.Text, pat, mask) then Exit;
           ok := FindHexFrom(h, FNextSearchAddr, pat, mask, found);
         end;
      2: ok := FindRegexFrom(h, FNextSearchAddr, FLastRegex, FLastEncodingIndex, FLastCaseInsensitive, found);
    else ok := False; end;
    if ok then
    begin
      edAddress.Text := '0x' + Hex64(found, 16);
      FNextSearchAddr := found + 1;
      btnReadClick(nil);
    end
    else
      ShowMessage('これ以上見つかりません。');
  finally
    CloseHandle(h);
  end;
end;

procedure TFormMain.btnScanAllClick(Sender: TObject);
const
  MAX_HITS = 200;
var
  pid: Cardinal;
  h: THandle;
  startAddr, found: UInt64;
  count: Integer;
  ok: Boolean;
  item: TListItem;
  pat, mask: TBytes;
  previewBuf: TBytes;
  readBytes: NativeUInt;
  hexPrev, asciiPrev: string;
  k: Integer;
begin
  if lvProcs.Selected = nil then Exit;
  pid := StrToIntDef(lvProcs.Selected.Caption, 0);
  if pid = 0 then Exit;
  if not ParseHex64(edAddress.Text, startAddr) then Exit;

  lvHits.Items.BeginUpdate;
  try
    lvHits.Items.Clear;
  finally
    lvHits.Items.EndUpdate;
  end;

  h := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, pid);
  if h = 0 then Exit;
  try
    count := 0;
    var cursor := startAddr;
    while count < MAX_HITS do
    begin
      case cbSearchMode.ItemIndex of
        0: begin
             if (Length(FLastSearchPattern) = 0) then
               if not BuildSearchPattern(edSearch.Text, cbEncoding.ItemIndex, chkCase.Checked, FLastSearchPattern) then Break;
             ok := FindPatternFrom(h, cursor, FLastSearchPattern, cbEncoding.ItemIndex, chkCase.Checked, found);
           end;
        1: begin
             if not ParseHexPattern(edSearch.Text, pat, mask) then Break;
             ok := FindHexFrom(h, cursor, pat, mask, found);
           end;
        2: begin
             ok := FindRegexFrom(h, cursor, edSearch.Text, cbEncoding.ItemIndex, chkCase.Checked, found);
           end;
      else
        ok := False;
      end;
      if not ok then Break;
      // preview bytes at found
      SetLength(previewBuf, 32);
      readBytes := 0;
      if not ReadProcessMemory(h, Pointer(NativeUInt(found)), Pointer(previewBuf), Length(previewBuf), readBytes) then
        readBytes := 0;
      SetLength(previewBuf, readBytes);
      hexPrev := '';
      asciiPrev := '';
      for k := 0 to High(previewBuf) do
      begin
        hexPrev := hexPrev + IntToHex(previewBuf[k], 2) + ' ';
        if (previewBuf[k] >= 32) and (previewBuf[k] < 127) then
          asciiPrev := asciiPrev + Char(previewBuf[k])
        else
          asciiPrev := asciiPrev + '.';
      end;

      item := lvHits.Items.Add;
      item.Caption := '0x' + Hex64(found, 16);
      item.SubItems.Add('#' + IntToStr(count+1));
      item.SubItems.Add(hexPrev);
      item.SubItems.Add(asciiPrev);
      cursor := found + 1;
      Inc(count);
    end;
  finally
    CloseHandle(h);
  end;
end;

procedure TFormMain.btnClearHitsClick(Sender: TObject);
begin
  lvHits.Items.Clear;
end;

procedure TFormMain.lvHitsDblClick(Sender: TObject);
begin
  if lvHits.Selected <> nil then
  begin
    edAddress.Text := lvHits.Selected.Caption;
    btnReadClick(nil);
  end;
end;

procedure TFormMain.btnMapClick(Sender: TObject);
var
  pid: Cardinal;
  h: THandle;
begin
  if lvProcs.Selected = nil then Exit;
  pid := StrToIntDef(lvProcs.Selected.Caption, 0);
  if pid = 0 then Exit;
  h := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, pid);
  if h = 0 then Exit;
  try
    PopulateMemoryMapList(h);
  finally
    CloseHandle(h);
  end;
end;

procedure TFormMain.lvMapDblClick(Sender: TObject);
begin
  if (lvMap <> nil) and (lvMap.Selected <> nil) then
  begin
    edAddress.Text := lvMap.Selected.Caption; // Base column text
    btnReadClick(nil);
  end;
end;

end.
