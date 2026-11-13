# MMU再設計 ステージ1(実装済み)

> エミュレータ(実IPL ROM)で確認。**実機は未確認**。上流の LSX-Dodgers とはメモリ配置・BDOS の入口・拡張BIOS表の呼び方が変わる(互換は「COM から見える範囲」で保つ)。

## 目的と結果
- ユーザプログラムの実行中だけバンク5・6(A000H-DFFFH)を専用のユーザページ(ページ04,05)に差し替え、**TPA を 0100H-B005H(約44KB)から 0100H-DFFFH(約56KB)へ広げた**。
- 実測: 56,750B の COM が F: から読み込めて実行できる(旧方式は 42.5〜43KB まで)。ローダの上限は DF00H(スタック用に E000H の手前 256B を残す)。
- 速度: ゲート 1 回 ≈ 266 T(1フレーム ≈ 108K T の 0.25%)。

## メモリマップ
| | バンク5 (A000-BFFF) | バンク6 (C000-DFFF) | バンク7 (E000-FFFF) |
|---|---|---|---|
| ユーザ実行中 | ページ04 (UPG5) | ページ05 (UPG6) | ページ0F(共通) |
| カーネル実行中 | ページ0B (KPG5) | ページ06 (KPG6) | ページ0F(共通) |
バンク0-4 は常に 00,01,02,03,0Ah。

- ユーザの `0005H` = `JP E000H`、`E000H` = `JP UGATE`。`(0006H)` = E000H = TPA の上端。**0005H を書き換えるプログラムは未対応**(許容済み)。
- `0000H` = `JP F003H`(CPM_WBOOT = `JP UWBOOT`)。`0038H` = `EI; RETI`(ページ0に直接)。

## カーネル専用 RAM(カーネル時のバンク5 A000H-B005H)
EDBUF A000H(履歴 1368B)、LDVARS A560H、DTBUF A600H(1KB)、STAGE AA00H(COM ローダの中継 1KB)、カーネルスタック AE00H-B000H。

## ゲート(`src/M25GATE.ASM`、バンク7 = E000H から)
1. **BDOS (`UGATE`)**: DI → ユーザ SP 保存 → 共通スタック GSTK → 9F00H 以上を指すポインタをバウンス(FCB 36B、DMA 128B、文字列 128B、行バッファ、解析、GENV)→ バンク5/6 をカーネルへ → SP=KSTK で `CALL BDOS` → 結果を保存 → ユーザマップへ → コピーアウト → ユーザ SP・IFF を復元して RET。
   - 1Ah/0Dh で DMA を追跡。9 (`$`終端)、48h/49h(ハンドル読み書き)は塊に分割。
   - 26h,27h(ブロック読み書き)は DMA が A000H 以上のとき 128B ずつ BOUNCE を介して繰り返す(`GP_BLK`。1レコード=1バイト、ランダムレコードはカーネルが進める)。28h は 128B バウンス。隠れたFCBは37バイト(+36 のランダムレコード4バイト目)まで受け渡す。
2. **BIOS 入口と拡張BIOS表(`UXG`)**: `F003H` (WBOOT/CONST/CONIN/CONOUT) と F0CAH からの表 (INKEY, PRINT, SCRN, POS, LOC, CHGDRV, GETDPB, FFLUSH, RDFATX, RDFAT, WTTRK, FDRD, FDWT, BPB2DPB, BREAK, COMANL) の各エントリは `CALL UXG` + `DW 飛び先` のスタブ。`INKRN`(1=カーネルのマップで実行中)を見て、カーネルからなら飛び先へ素通し、ユーザからならマップを切り替えて呼ぶ。AF/BC/DE/HL/IX/IY をそのまま通す。**`_GNCL`/`_SNCL` は自己書き換えの JP なのでスタブ化していない(ユーザからは使えない)**。FORMAT.COM は `CALL 000FH`(JP (HL)) で F0D9H/F0DCH 等へ飛ぶ。
3. **COM 起動 (`ULAUNCH`)**: ユーザマップ+SP=E000H、リターン先 0000H を積んで 0100H へ。
4. **ウォームブート (`UWBOOT`)**: カーネルマップ+SP=KSTK で WBOOT1。カーネルからも呼べる。
5. **`UCPIN`**: カーネル→ユーザページへのコピー(バンク4 の窓にユーザページを出す)。

## COM ローダ(`src/M25LOAD.ASM`)
A000H 未満は直接読み、それ以上は STAGE (1KB) に読んで UCPIN で書く。

## ブート
システム本体(INIT+body、17,491B=35セクタ)をページ0Ah, 0Bh, 06 の順に読む(最大48セクタ)。ブートローダのトランポリンは FE00H(バンク7)。※ C000H に置くとページ06に読んだ本体の先頭を壊す(2026-11-08 の不具合 → 修正)。

## 移植上の注意(上流 LSX との差)
- `(0001)` はそのまま F003H(拡張BIOS表は F000H 台のまま)だが、ユーザからは必ずスタブ→ゲート経由になる。
- FORMAT.COM は `LD HL,(0001)` から F0xxH の変数を直接読み書きする(`_DSK` など)。F000H-F0C9H の変数は共通バンクなので見える。
- ポインタ引数が A000H-DFFFH を指す場合のみバウンスのコストがかかる(通常の TPA 内ポインタは素通し)。
- キー走査 (`CHKEY`): 走査の途中で SHIFT/KANA/CTRL が変わったら最初から取り直す(同時押しの取りこぼし対策。2026-11-08)。

## テスト
`tools/test_all.sh`: 既存 165 + 隠れ領域 (`tests/hidden.asm`、4種) + 56KB の COM (4種)。物理フォーマット、ワイルドカード、`<DIR>` 表示などがこの作業で見つけた回帰。

## 2026-11-09 追記: PIPE/CWD のオーバーレイ化、TRAP38
- `M25PIPE`(パイプ)と `M25CWD`(プロンプトのカレントディレクトリ)を常駐(バンク7)からオーバーレイ(ページ0Eh、窓=バンク4)へ移した。状態変数もオーバーレイのページに置く(ページはウォームブートで残る)。常駐側は `M25OVL.ASM` の4つのスタブ(HND_PIPE, HND_PIPEK, HND_CDT, HND_PROMPT)だけ。HND_PIPEK は「続きの段あり」を CY=1 で返し、スタブが COMMAND へ戻らず COMMAND2P へ飛ぶ。
- 常駐の空き(AT_TABLE〜TABLEAD)が 約24B → 約630B。この空きで 26h/27h の隠れDMA対応(約170B)を入れた。
- TRAP38(RST 28H。未初期化領域の実行)の表示 `MSG_A` はカーネルのページにあるため、ユーザマップだとクラッシュしていた → ゲート経由の `UMSGA` を呼ぶ(trap38.bin は39B満杯なので、スタブは本体側の M25GATE に置いた)。
- EDT(行編集)はオーバーレイにできない: BDOS 0Ah でユーザの8000H-9FFFH にある行バッファを使うことがあり、窓(バンク4)で隠れるため。
- テスト: tools/test_all.sh 全体 189/189(+blk2 4, +trap 4)。

## 2026-11-09 追記: ユーザ RST 18H (IOCS) ゲートと IPL ROM 有無
- 起動時に 0018H(JP) と 001AH から IPL ROM/IOCS の有無を検出し、IOCSOK(FDC4H)に格納。
- IOCSOK=0 (ROM無し): TINIT を省略し直接80桁書き込みで初期化、IOCS RAM のページ退避もしない。
  ユーザが RST 18H を呼ぶと "No IOCS (IPL ROM)" を表示してウォームブート。
- IOCSOK≠0: 0018H→UIOCS ゲート。bank0/1 に退避済みIOCS RAM(0Ch/0Dh)を張り、IM2/I=02h/SP=1900H で
  IOCS を実行し、戻りでユーザマップ・IM1・レジスタを復元。
- 制限: IOCS呼び出し中は 0000–3FFF が IOCS RAM に差し替わるためポインタ引数は 4000H 以上のバッファに置くこと。
  ユーザからの TINIT(64h) は Cy=1/A=1 で失敗(原因未調査)。
- テスト: tests/iocs.asm, tests/noiocs.asm (test_all.sh の RST 18H ブロック)。noiocs 画像ではカーソル位置が不定のため文字位置は検査しない。

## 2026-11-09 追記2: RST 18H は関数別の振り分け表
- 表 `IOCT` (FDD7H〜、160関数×DW)。0000=未実装("No IOCS (IPL ROM)"を出してウォームブート) / 0001=ROMのIOCSへ素通し / その他=自前ハンドラ(bank7のゲート側。A,DE,HLを戻して RET で飛ぶ。スタック先頭=ユーザへの戻り先、フラグ不定)。
- 起動時(M25INIT)に作成: ROMあり=全部0001、ROMなし=全部0000にして、自前実装(今は CRT1C=03h → `UI_CRT`)だけ入れる。表外の関数番号はROMがあれば素通し。
- 自前ハンドラの追加は `M25INIT.ASM` の FILLX 手前に `LD HL,ハンドラ / LD (IOCT+2*関数番号),HL` を足し、`build.py` の need に名前を追加。
- テスト: tests/noiocs.asm (表を0にして未実装動作)、tests/iocsnat.asm (表にUI_CRTを入れて呼ぶ。アドレスはmapから)。

## ROM無しブート(簡易IPL)
- tools/emu_record_boot.patch: エミュレータ(mz2500-web-emulator)の簡易IPL(core/dummy_ipl.cpp)に「レコード番号方式」を追加する差分。LSXの起動ディスクはIPLPROヘッダは同じだが本体を実IPLと同じレコード配置(header[1Eh]から32レコード/バンク, record r→C=(r^10h)/32,H=((r^10h)/16)&1,R=(r^10h)%16+1)に置くので、従来のIPLPRO判定では「実IPL必須」になっていた。
- 適用後は ROM/--real-ipl 無しで 4画像とも起動し、dir・COM実行・RST 18H(自前CRT1C)が動く。IOCSOKは0になりTINITは省略(直接初期化)。
- 実機のIPLとは別物のエミュレータ側の近道であり、実機確認ではない。
