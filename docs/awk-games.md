# AWK / SED とゲーム(3本)

エミュレータでの動作だけ確認(実機では未確認)。 すべて `\BIN` の .COM、説明は `man 名前`。

## AWK.COM (coms/awk.asm + re.inc awku.inc awkv.inc awkb.inc awkp.inc)
- awk の部分集合(整数のみ・32ビット)。パターン/BEGIN/END、欄 `$n`(代入可)、NR NF FNR FS OFS ORS FILENAME RSTART RLENGTH、
  if/while/do/for/for-in/break/continue/next/exit/delete、print/printf(`>` `>>`)、正規表現(egrep と同じ re.inc)、
  length substr index split toupper tolower int sprintf sub gsub match rand srand、連想配列、`getline`(次の行)。
- 作り: 字句解析+構文解析(awkp.inc)が 6バイト cell のスタックマシン用の命令列を作り(awkv.inc)、組み込み関数と出力は awkb.inc。
  メモリ: 変数48・配列要素64・欄60・プログラム2KB(-f)。 コマンド行は127文字まで(長いものは -f)。
- 無いもの: 小数、ユーザー関数、`getline < file`、範囲パターン、NF への代入、printf の %f。
- CCP の注意: `$` は `$$`、`\"` は使えない(プログラム中の文字列は '...' で)。
## ゲーム
- TREK.COM 宇宙艦隊戦(独自の名前と文章。古典的な宇宙戦ゲームの考え方による作り直し)、WUMPUS.COM、HITBLOW.COM。
- 日本語メッセージ: ソース先頭に `;@cp932` と書くと build.py が Shell_JIS に直して組む。共通部品は coms/gamelib.inc(BDOS 02h 出力、06h で待たずにキー、ESC E / ESC Y)。

## SED.COM (coms/sed.asm + re.inc)
- sed の部分集合。`s`(フラグ g p I 数字、置換の & \1-\9 \n \t)、`y`、`p P d D n N g G h H x z = q Q`、`a i c`(一行形式と `a\` 形式)、`b t T :label`、`{ }`、`#`。
- アドレス: 行番号、`$`、`/re/`(後ろに I)、`\cREc`、`先頭,末尾`、`先頭,+N`、`0,/re/`、`!`。オプション `-n -e -f -E(-r)`。ファイルは複数・ワイルドカード、省略で標準入力。
- 正規表現は egrep と同じエンジン(re.inc)。sed 用に **キャプチャ(後方参照)** を足した: `RX_CAPS` を定義して include したときだけ有効で、`(` `)` ごとに命令 `0C n` を出し、
  失敗して戻るときは元の位置に戻す(バックトラック用スタックに復元用スタブ `0D n` を積む)。egrep/awk は定義しないので動作は変わらない。
  既定は BRE(`\( \) \| \+ \?`)で、`-E` なら ERE。BRE→ERE の書き換えは getre(sed.asm)で行う。
- 無いもの: `w r e l F -i -s`、`{n,m}`、`\U \L \u \l \E`、`first~step`、`[[:alpha:]]`。行は1000バイト、コマンド100個、正規表現32個まで。
- 実装メモ: 入力は引き戻し無しで1バイト先読み(`fill`)するので `$` や `N`/`n` の「次の行があるか」を調べられる。複数ファイルは全体を1本の流れとして扱い、`$` は最後のファイルの最後の行。
- テスト: tools/test_all.sh の sed ブロック(17項目)。エミュレータのみ、実機は未確認。
