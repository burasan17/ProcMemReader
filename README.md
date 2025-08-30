# Process Memory Reader (Delphi VCL)

English and Japanese instructions are provided below.

## English

### Overview
A small Delphi VCL GUI to read memory of another process on Windows. It lists processes, lets you enable SeDebugPrivilege, validates addresses with VirtualQueryEx, reads with ReadProcessMemory, and shows a hex/ASCII dump. It also includes memory map browsing and powerful search (Text / Hex with wildcards / Regex).

### Features
- Process list: enumerate processes with PID and image name.
- Debug privilege: Enable SeDebugPrivilege to improve access (administrator recommended).
- Safe read: Validate pages via VirtualQueryEx; auto-size to readable span; tolerate partial reads.
- Hex dump: 16 bytes per line, address, hex and ASCII columns.
- Helpers:
  - Main Module Base: Fill the main module base address of the selected process.
  - Inspect: Show MEMORY_BASIC_INFORMATION for current address.
  - Prev/Next readable: Jump to previous/next readable region.
- Search modes:
  - Text (ASCII / UTF‑16LE, optional case-insensitive).
  - Hex bytes with wildcard: e.g. `DE AD BE EF` or `DE AD ?? EF` (space/comma separated, `?` per byte).
  - Regex (ASCII / UTF‑16LE) with options: Multiline, DotAll; case-insensitive toggle.
  - Find Next: continue from last match.
  - Scan All: collect up to 200 hits with hex/ASCII preview, double-click to jump/read.
- Memory Map view: List all regions (Base, End, Size, State, Protect). Double‑click a row to set Address and read.

### Requirements
- Windows 10/11 x64.
- Delphi 12 (Athens) Community Edition or higher.
- Build target: Win64 recommended (reading 64‑bit process address space).
- Run as Administrator for best access; some protected processes (PPL) are not readable even with SeDebugPrivilege.

### Build
1. Open `ProcMemReader.dpr` (or `ProcMemReader.dproj`) in RAD Studio/Delphi IDE.
2. Ensure Win64 platform is installed (Tools > Manage Platforms → Windows 64-bit).
3. Choose Target Platform = Windows 64-bit, then Build.
   - Note: Community Edition does not support command‑line `dcc64`; build in the IDE.

### Usage
1. Run as Administrator. Click “Enable Debug Privilege”.
2. Select a target process in the list.
3. Populate Address:
   - Click “Main Module Base” to set a valid starting address.
   - Or use Memory Map → double‑click any readable region’s Base.
   - “Inspect” shows State/Protect/Size for the current Address.
4. Size: start with 512–1024 bytes. Click “Read”.
5. Search:
   - Enter pattern and choose a Search Mode (Text/Hex/Regex).
   - Text: choose Encoding (ASCII/UTF‑16LE) and Case‑insensitive if needed.
   - Hex: space/comma‑separated bytes; wildcard `?` or `??` per byte (example: `48 8B ?? ?? 48 8B`).
   - Regex: supports Multiline and DotAll. Encoding follows the Encoding selector.
   - Click “Search” for first hit, “Find Next” for subsequent hits, or “Scan All” to list hits.
   - Double‑click a hit to jump and read.

### Notes & Troubleshooting
- Invalid address: “Address is invalid” means not mapped or kernel range. Use Main Module Base, Memory Map, or Next Readable.
- Unreadable region: “Unreadable (uncommitted/guard/noaccess)” → move within the region or to the next readable one.
- Partial copy (ERROR_PARTIAL_COPY): App accepts partial reads and annotates them. Try smaller Size or a slightly shifted Address (e.g., +0x1000).
- Protected processes: Some system/security processes (PPL) cannot be read.
- 32/64‑bit: Reading high addresses of a 64‑bit process from a 32‑bit app will fail. Build Win64.

---

## 日本語 (Japanese)

### 概要
Windows上の他プロセスのメモリをGUIで読み取るDelphi VCLアプリです。プロセス列挙、SeDebugPrivilegeの有効化、VirtualQueryExによる範囲検証、ReadProcessMemoryの読み取り、Hex/ASCIIダンプ表示に対応。メモリマップ表示や強力な検索（テキスト／HEXワイルドカード／正規表現）も搭載しています。

### 機能
- プロセス一覧: PIDと実行ファイル名を表示。
- デバッグ特権: SeDebugPrivilegeを有効化（管理者実行推奨）。
- 安全な読み取り: VirtualQueryExでページ状態を確認し、読める範囲に自動調整。部分読み取りも許容。
- Hexダンプ: 1行16バイト、アドレス・Hex・ASCIIを表示。
- 補助機能:
  - Main Module Base: 選択プロセスのメインモジュール基底アドレスを自動入力。
  - Inspect: 現在アドレスのMEMORY_BASIC_INFORMATIONを表示。
  - Prev/Next readable: 直前/次の読める領域へジャンプ。
- 検索モード:
  - テキスト（ASCII / UTF‑16LE、大小無視オプション）。
  - HEX（ワイルドカード対応）: 例 `DE AD BE EF` や `DE AD ?? EF`（区切り: 空白/カンマ、`?`は1バイト）。
  - 正規表現（ASCII / UTF‑16LE）: Multiline/DotAll、大小無視を選択可。
  - Find Next: 直前ヒットの続きから再検索。
  - Scan All: 最大200件のヒットを収集し、Hex/ASCIIプレビュー付きで一覧表示。ダブルクリックでジャンプ＆読み取り。
- メモリマップ表示: Base/End/Size/State/Protectを一覧。ダブルクリックでAddressに反映して読み取り。

### 動作要件
- Windows 10/11 x64。
- Delphi 12 (Athens) Community Edition 以上。
- ビルドターゲットはWin64を推奨（64bitプロセスのアドレス空間を読むため）。
- 管理者での起動推奨。保護プロセス(PPL)等は特権があっても読めない場合があります。

### ビルド手順
1. RAD Studio/Delphi IDEで `ProcMemReader.dpr`（または `.dproj`）を開く。
2. Tools > Manage Platforms で Windows 64-bit を導入済みか確認。
3. ターゲットを Win64 に切り替えてビルド。
   - 注意: Community Editionはコマンドライン `dcc64` に非対応のため、IDEからビルドしてください。

### 使い方
1. 管理者で起動し「Enable Debug Privilege」を押す。
2. 対象プロセスを選択。
3. Addressの設定:
   - 「Main Module Base」で有効なアドレスを自動入力。
   - もしくは「Refresh Map」でメモリマップを表示し、ダブルクリックでBaseをAddressへ反映。
   - 「Inspect」でState/Protect/Sizeを確認。
4. Sizeはまず512〜1024で試し、「Read」でダンプ表示。
5. 検索:
   - 検索語を入力し、Search Mode（Text/Hex/Regex）を選択。
   - TextはEncoding（ASCII/UTF‑16LE）やCase-insensitiveを適宜指定。
   - Hexは空白/カンマ区切り、ワイルドカードは `?`/`??`（1バイト）を使用。
   - RegexはMultiline/DotAllのON/OFFに対応。Encodingは選択に従います。
   - 「Search」で最初のヒット、「Find Next」で次のヒット、「Scan All」で一覧化。ダブルクリックでジャンプ＆読み取り。

### 注意・トラブルシューティング
- 「指定アドレスが無効です」: 未マップまたはカーネル側。Main Module Baseやメモリマップ、Next readableで調整してください。
- 「読み取り不可（未コミット/ガード/NOACCESS）」: ページ保護によるもの。ページ境界をずらす（+0x1000等）、またはNext readableで移動。
- ERROR_PARTIAL_COPY: 部分読み取りは許容され、(partial) と表示されます。サイズを小さくする、アドレスを少しずらす等で改善。
- 保護プロセス: 一部のシステム/セキュリティプロセスは読み取り不可です。
- 32/64bit差: 64bitプロセスの高位アドレスはアプリも64bitでビルドしてください。

### セキュリティ上の注意
他プロセスのメモリ読み取りは環境やソフトウェアによっては制限や検知の対象になる場合があります。自己責任でご利用ください。

---

## Folder Structure
```
ProcMemReader/
  ProcMemReader.dpr
  UMain.pas
  UMain.dfm
  README.md  <-- this file
```

## License
MIT License. See `LICENSE` for details.

## Author
- burasan17
