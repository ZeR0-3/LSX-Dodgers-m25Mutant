# LSX-Dodgers-m25Mutant for SHARP MZ-2500

CP/M-80 / MSX-DOS 互換OS **LSX-Dodgers**(原作: Gaku 氏、[tablacus/LSX-Dodgers](https://github.com/tablacus/LSX-Dodgers)、MIT)を **SHARP MZ-2500** に移植したものです。
MZ-700/1500 版(`M7*.ASM`)を土台に、機種依存部を `src/M25*.ASM` に置き換えています。共通部 `LD*.ASM` は原作のものをそのまま使います(このリポジトリには含めません。ビルド時に原作のディレクトリを指定します)。

> **状態: エミュレータ上でのみ確認。実機(MZ-2500 本体)では一度も動かしていません。**
> mz2500-web-emulator(Web版エミュレータ)の CLI で、実IPL ROM と ROM無しの簡易IPLの両方からの起動を含む自動テスト(`tools/test_all.sh`)が通ります。
> ハードの仕様は資料とエミュレータの挙動から裏取りしたもので、実機との差が残っている可能性があります。

## 試すには
`dist/LSX2500_80col.d88`(80桁25行、標準LSX形式の2DD起動ディスク)を MZ-2500 のエミュレータ(または実機用に書き出したFD)で起動します。
`dist/LSX2500_80col.hdf.gz` は SASI ハードディスクのイメージ(展開して使います。約22MB、FAT16の1パーティション)で、`H:` に見え、HDDからの起動もできます(エミュレータでのみ確認)。
起動すると `A>` プロンプトが出ます。`man` で簡易マニュアルが読めます。

## できること
- **メモリ**: TPA は 0100H〜DFFFH(約56KB)。バンク切替のゲートでユーザ/カーネルの見え方を分けています(`docs/mmu-stage1.md`、`docs/memory-map.md`)。
- **システム情報とページの予約**(BDOS E0h-E3h、`sysinfo`): 機能の有無(IOCS・EMM・RAMディスク・SASI)と、物理ページ(8KB)の所有者を調べ、空きページを予約できる(`docs/page-api.md`)。大きなプログラム用。`ramdisk 32` でRAMディスク(F:)を小さく/0で無効にして、空いた拡張RAMのページを他のプログラムが使える。ページの読み書きは `coms/pglib.inc`(`pgread`/`pgwrite`)にまとめてあり、アプリ向けの決まりは `docs/app-memory-guide.md`。
- **ドライブ**: A: B: = 内蔵FDD(2D/2DD自動判別。X1 / MZ-700 の LSX と同じ標準形式)、C: D: = 外付けFDD(実装のみ)、E: = EMM(MZ-1R37。`FORMAT E:` が必要)、F: = RAMディスク、G: = 未使用(将来用)、H: = SASI HDD(`docs/sasi.md`)。
- **MSX-DOS2 のファイルハンドル呼び出し**(BDOS 43h〜4Bh)、`>` `>>` `<` のリダイレクトと `|` のパイプ、環境変数(`SET` `ENV`、`$NAME`)、バッチ(`GOTO` `IF` `$?` `$1`〜`$9`)。
- **行編集**: TAB補完、履歴(50件、`HIST` で履歴ファイル)、検索(`docs/line-edit.md`)。
- **長いファイル名**(Human68k / TwentyOne 方式。名前の9文字目以降を、ディレクトリエントリの予約領域 +0Ch の10バイトに持つ。最大 18 文字 + `.` + 拡張子3): OS が作成・検索・名前変更・削除・ワイルドカードを扱い、`ls` `dir` は全体を表示します。`LONGNAME.TXT` と `LONGNAMEISHERE.TXT` は別のファイルです。8+3 しか持てない既存の CP/M プログラムは、長い名前のファイルを開けません(`docs/longname.md`)。変換表は要りません(Shift_JIS のまま)。エミュレータでのみ確認。
- **漢字(Shift_JIS)を全角で表示**(`KMODE`)、文字色と反転(`COLOR`、`ESC b` `ESC p`、VT-100 の `ESC [ n m` の一部)、`MODE 40|80`。
- **付属コマンド**(`\BIN`、ソースは `coms/`、使い方は `man 名前`):
  `awk` `cat` `cmp` `color` `cp` `date` `df` `diff` `du` `echo` `egrep` `find` `grep` `hd` `head` `kmode` `ls` `mon` `more` `mv` `pal` `sed` `sh` `sjis` `ramdisk` `sort` `sysinfo` `tail` `tee` `touch` `tr` `uniq` `utf8` `wc` `which` `man`
  - `egrep`: `[..] + ? | ( ) \< \>`、`-ivnclwohABC`、複数ファイル、ワイルドカード、全角対応。
  - `awk`: awk の部分集合(整数のみ。ユーザー関数・`getline < file`・範囲パターン・`%f` は無い)。
  - `sed`: `s`(後方参照 `\1`〜`\9`、フラグ g p I 数字)、`y`、`p P d D n N g G h H x z = q Q a i c b t T { }`、行/正規表現/範囲アドレス、`-n -e -f -E`。`w r l -i` などは無い。
  - ゲーム: `trek`(宇宙戦術)、`wumpus`、`hitblow`(ヒット&ブロー)。
  - 詳しくは `docs/awk-games.md` と、ディスク内の `man`。
- ROM が無くても動くように、エミュレータの簡易IPLに「レコード番号方式」ブートを足した改造版でのブートも確認しています(`docs/emulator-modding.md`、`tools/emu_record_boot.patch`)。

## 未対応・未確認
- **実機での動作はすべて未確認**です(特に FDC、SASI、EMM/拡張RAM、漢字、色、RTC)。
- 2HD、F1〜F10/GRAPH/HELP キー、HDDの複数パーティション、フォーマット/パーティション作成ツール(PCで作ってください)。
- 行編集でのかな漢字変換(辞書ROMの利用は未調査。全角の名前はバッチやリダイレクト経由なら使える)。SGR の太字・下線、背景色の独立指定(MZ-2500 のテキスト属性は1セル1色のため不可)。
- `awk`/`sed` の制限は各 `man` を参照。

## ビルドとテスト
必要なもの: Python 3、[z88dk](https://github.com/z88dk/z88dk) の `z80asm`、原作 [LSX-Dodgers](https://github.com/tablacus/LSX-Dodgers) のソースディレクトリ(`LD*.ASM`)。
テストにはエミュレータ CLI と IPL ROM など(**著作物のため、このリポジトリには含めません。各自で用意してください**)が要ります。

    tools/setup_env.sh <作業dir> <z88dk.tgz か git 作業ツリー> <mz2500-web-emulator.zip> <ROMを入れたzipまたはdir>
    source <作業dir>/env.sh
    tools/build_all.sh <原作dir> <原作のldsys.d88(無ければ空文字)> <出力dir>      # 4種類の起動ディスクとHDDイメージ
    tools/test_all.sh <出力dir>                                                    # 約25分

`coms/*.asm` は `build.py` が自動で拾って `\BIN` に入れます(先頭に `;@cp932` と書いたソースは Shift_JIS に直してから組みます)。
コマンドを足したら `man/<名前>.txt` と `man/index.txt` も更新してください。

## ドキュメント
`docs/HANDOFF.md`(経緯と引き継ぎ)、`docs/hardware-notes.md`、`docs/mmu-stage1.md`、`docs/memory-map.md`、`docs/block-devices.md`、`docs/sasi.md`、`docs/kanji.md`、`docs/line-edit.md`、`docs/mon.md`、`docs/man.md`、`docs/awk-games.md`、`docs/page-api.md`、`docs/app-memory-guide.md`、`docs/emulator-modding.md`。
`docs/old-readme.md` は MMU 化の前の README(ブート方式やデバッグで分かったことの記録が残っています。一部は古い記述です)。

## ライセンス
MIT License(`LICENSE`)。原作部分の著作権は Gaku 氏、MZ-2500 移植部分は ZeR0-3。
