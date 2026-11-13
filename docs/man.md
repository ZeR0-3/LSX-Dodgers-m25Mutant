# 簡易マニュアル MAN.COM と man/*.txt(2026-11-09)

- `man 名前` で `\MAN\名前.TXT` を探して1画面ずつ表示(`man` だけ = `INDEX.TXT` の一覧)。探す順はカレントドライブ → A: → H: → B:。
- 表示するのは標準出力がコンソールのときだけページ送り(SPACE=次の画面 / ENTER=1行 / Q・ESC=終了)。そのあいだだけ `ESC k 1`(漢字ON)を出し、終わると `ESC k 0`。ファイルやパイプへ出すときは何も付けない(`man grep > g.txt` は Shift_JIS のテキストそのまま)。
- ページ送りは `coms/more.asm` と同じコード。ファイルの開き方だけ違う(`coms/man.asm`)。名前は8文字まで、大文字小文字は区別しない。
- 説明文のソースは `man/*.txt`(UTF-8、LF)。`build.py` が Shift_JIS・CRLF に変換して、D88とHDDイメージの `MAN\` に入れる(47ファイル)。**コマンドを足したら `man/<名前>.txt` を書いて `man/index.txt` の一覧にも足す。**
- 内容: 内蔵コマンド(internal)、env、batch、mode、hist、行編集(edit)、リダイレクトとパイプ(pipe)、外部コマンド全部(cat … which、man)。
- 漢字の表示は実機のROMで未確認(エミュレータでは表示される)。KMODEがOFFの端末でも man の間だけONになる。
- テスト: tools/test_all.sh「簡易マニュアル」(4イメージ。名前指定・INDEX・無い名前・大文字)。HDD(H: から起動)でも表示を手で確認。
