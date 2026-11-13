# エミュレータ改造メモ(AI向け): LSX 用「レコード番号方式」ROM無しブート と 改造の勘所

対象: mz2500-web-emulator(C++ コア + CLI + WASM/Web)。このファイルは LSX-Dodgers MZ-2500 移植(別リポジトリ/ツリー)のために行った改造の記録と、同種の改造を AI が安全に進めるための手引き。実機のIPLの動作とは別物で、エミュレータ側の近道である点に注意(実機確認ではない)。

## 1. 何を変えたか(差分: tools/emu_record_boot.patch 相当)
従来、簡易IPL(`core/dummy_ipl.cpp`)は「IPLPRO互換」D88だけをROM無しで起動し、それ以外の有効なD88は `DiskBootProfile::RealIplRequired`(=IPL ROM が必要)と判定していた。LSXのブートディスクは次の形で、従来判定から外れていた。

- C0/H1/R1 に IPLPRO ヘッダ(256B)。`[0x18..19]`=入口, `[0x1E..1F]`=ペイロードの先頭レコード番号, `[0x20..]`=転送先ページ列(FFh終端), `[0x30..36]`=起動時のバンク0-6割当。ここまでは従来と同じ。
- ペイロード(8KB/バンク)が **レコード番号**で並ぶ(実IPLと同じ読み方)。従来の簡易IPLは「C=n/H=0 + C=n+1/H=1」の固定配置を仮定しており、LSXディスクの C0/H0 は標準の 512B×9 セクタなので読めず `is_iplpro_compatible()` が false になっていた。

追加した処理:
1. `D88Disk::read_ipl_record(record, dst)` : record r → `i = r ^ 0x10`, `C=i/32, H=(i/16)&1, R=i%16+1` の 256B を読む(`read_decoded` 経由=補数はデコード済み)。
2. `D88Disk::is_iplpro_record_compatible()` : ヘッダが IPLPRO で、バンク列が妥当で、`start>=16`、`バンク数*32` レコードが全部読めれば true。
3. `Mz2500::disk_boot_profile()` : `is_iplpro_compatible() || is_iplpro_record_compatible()` を `IplProCompatible` とみなす。
4. `Mz2500::boot_from_disk()` : `!is_iplpro_compatible()` なら、`start + index*32 + s` のレコードでバンクを読む `load_bank_rec` を使って `native_boot_with_header()` を呼ぶ。以降(メモリクリア・バンク割当・PC設定・周辺初期状態)は従来のまま。

変更ファイル: `core/d88.h`, `core/d88.cpp`, `core/mz2500.h`, `core/dummy_ipl.cpp`(計約90行)。

## 2. 簡易IPLが作る起動時の状態(LSX側が前提にしていること)
`native_boot_with_header()` 参照。メイン RAM/VRAM/PCG ゼロクリア、ブロック0-6=ヘッダ[0x30..]、ブロック7=ページ0Fh、割り込み禁止・IM0、SP未設定。**IOCS(RAMの0018H以降)は存在しない**ので、LSX は起動時に `0018H` を見て IOCSOK=0 とし、TINIT を省略して直接 80/40 桁を設定する。ブートローダ(8000H)は FDC を直接叩く(簡易IPL下でもエミュレータの FDC が動く)。

## 3. 使い方・確認
```
# ビルド(コピーしたツリーで)
cmake -B build/native -DCMAKE_BUILD_TYPE=Release && cmake --build build/native -j8 --target mz2500w-cli
# ROM無しで起動(--real-ipl も --rom-dir も付けない)
build/native/mz2500w-cli --disk-a LSX2500_80col.d88 --frames 900 --trace-boot --type 'dir\r:500' --screen-report
```
- `--trace-boot` に `IPLPRO "LSX-DODGERS" (FD1 (record)) -> 1 x 8KB ... PC=8000h` と出ればこの経路。
- `--real-ipl --rom-dir DIR` を付けると従来どおり実IPLで起動(この改造の影響を受けない)。**注意**: 改造後は IPL ROM があっても `--real-ipl` を付けない限り簡易IPLを使う(従来は RealIplRequired の時だけ自動で実IPLへ切替えていた)。
- 主要オプション: `--disk-a/--disk-b IMG`, `--frames N`, `--type 'text\r:FRAME'`(FRAME フレーム時点で入力), `--screen-report`(テキスト画面をダンプ), `--disk-save N:PATH`, `--hdf PATH [--hdf-block N]`(SASI), `--trace-boot`。`./mz2500w-cli` の `--help` 相当は cli/main.cpp 冒頭の usage。

## 4. Web(WASM)側
`web/emulator.js` は `Module._emu_disk_boot_profile(0)` の戻り値で分岐する(2=ROM必須→"SPECIAL D88 REQUIRES IPL ROM")。本改造はコアの `disk_boot_profile()` を直すので、**WASM を再ビルドすれば Web も自動で追従**する(JS の変更は不要)。このセッションでは emscripten が無く WASM の再ビルド・動作確認はしていない。`web/dist/emulator.js` は生成物(ビルドで更新される)。

## 5. 改造するときの勘所(AI向け)
- 構造: `core/` = マシン本体(mz2500.cpp:バス/ポート/メモリ割当, banked_memory:8KB×8 バンク, fdc_mb8877, d88:イメージ, sasi:MZ-1E30, dummy_ipl:ROM無し起動, renderer)。`cli/main.cpp`=ヘッドレス実行(テストはこれ+`--screen-report`)。`wasm/bindings.cpp`=JS用C API。`web/`=フロント。
- 元ツリーは触らず、コピー(例 `cp -r` したディレクトリ)で `build/native` に作り、差分は `diff -ru 元/core 新/core` でパッチにして残す。
- ROM/ファームを同梱・コピーしない(このリポジトリは clean-room 方針。`tools/audit_clean_room.py` あり)。簡易IPLにも ROM 由来のバイトを入れない。
- 判定系(`disk_boot_profile` など)を変えると Web/CLI 両方に効く。CLI の分岐は cli/main.cpp の `boot_disk` ラムダ。
- 変更後の確認: ROM無し(`--trace-boot` の経路表示 + `--screen-report`)と、`--real-ipl` の両方で起動することを確認する。
- SASI HDD: 簡易IPLは `boot_from_sasi_hdd()` で LAD3 の "EHSASI " パーティション表(優先起動エントリ)→パーティション先頭の IPLPRO ヘッダ→ `header[0x1E]` 起点で `バンク数*32` レコード連続、という契約で起動する(256B/ブロックのイメージのみ)。LSX をHDDから起動させる場合は、HDDイメージをこの形式で作る(ヘッダ+ペイロードの置き方はLSX側 tools/ のイメージ作成ツールで合わせる)。
- コマンド範囲(SASI): TEST UNIT READY, REZERO, REQUEST SENSE, FORMAT系, READ(6)/WRITE(6), SEEK, INIT CHARACTERISTICS, 診断, READ/WRITE LONG。SCSI後期のINQUIRY/MODE SELECT等は意図的に未対応(core/sasi.cpp)。
