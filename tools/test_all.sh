#!/usr/bin/env bash
# dist/ の4種類をエミュレータ(実IPL)で起動して DIR/COPY を確認する。全部通れば PASS
# 使い方: tools/test_all.sh <distdir>   (事前に source <作業dir>/env.sh)
set -uo pipefail
D=$1; HERE=$(cd "$(dirname "$0")" && pwd); rc=0
python3 "$HERE/make_blank_disk.py" /tmp/_blank2dd.d88 2dd >/dev/null
python3 "$HERE/make_blank_disk.py" /tmp/_blank2d.d88 2d >/dev/null
for f in "$D"/LSX2500_*.d88; do
  for b in /tmp/_blank2dd.d88:729088 /tmp/_blank2d.d88:361472; do
    disk=${b%%:*}; want=${b##*:}
    out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-b "$disk" --frames 2000 \
      --type 'dir ld2500.bin\r:700' --type 'copy a:type.com b:\r:900' --type 'dir b:\r:1200' --screen-report 2>&1 | grep '^screen:')
    if echo "$out" | grep -q "LD2500.BIN" && echo "$out" | grep -q "TYPE.COM" && echo "$out" | grep -q "$want free"; then
      echo "PASS $(basename $f) + $(basename $disk)"; else echo "FAIL $(basename $f) + $(basename $disk)"; echo "$out" | head -12; rc=1; fi
  done
done
# ディスクが無いドライブへのアクセスはタイムアウトして Error! になり、システムが続行できること
# (E1h bit0 の時間基準が止まっているとここでハングする。C6h bit3=VBLANK許可が必要)
for f in "$D"/LSX2500_*.d88; do
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 1500 \
    --type 'dir b:\r:700' --type 'dir ld2500.bin\r:1100' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "Error!" && echo "$out" | grep -q "A:LD2500.BIN"; then echo "PASS $(basename $f) (B:にディスク無し)"
  else echo "FAIL $(basename $f) (B:にディスク無し)"; echo "$out" | head -8; rc=1; fi
done

# 物理フォーマット(FORMAT.COM -> WTTRK): 未フォーマットのD88を物理+論理フォーマットし、標準値の空き容量になること
# (FORMAT.COM は取り込み時に機種ID判定を1バイトパッチしてある: tools/make_boot_disk.py)
python3 "$HERE/make_blank_disk.py" /tmp/_unf2dd.d88 unf2dd >/dev/null
python3 "$HERE/make_blank_disk.py" /tmp/_unf2d.d88 unf2d >/dev/null
for f in "$D"/LSX2500_*.d88; do
  for b in /tmp/_unf2dd.d88:1:730112 /tmp/_unf2d.d88:0:362496; do
    IFS=: read disk kind want <<<"$b"
    rm -f /tmp/_fmt_out.d88
    "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-b "$disk" --disk-save 1:/tmp/_fmt_out.d88 --frames 10000 \
      --type 'format b:\r:600' --type "$kind:800" --type '\r:1000' >/dev/null 2>&1
    out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-b /tmp/_fmt_out.d88 --frames 1500 \
      --type 'dir b:\r:700' --type 'copy a:type.com b:\r:900' --type 'dir b:\r:1200' --screen-report 2>&1 | grep '^screen:')
    if echo "$out" | grep -q "$want free" && echo "$out" | grep -q "TYPE.COM"; then echo "PASS $(basename $f) 物理フォーマット $(basename $disk)"
    else echo "FAIL $(basename $f) 物理フォーマット $(basename $disk)"; echo "$out" | head -8; rc=1; fi
  done
done
# 外付けの MODE.COM は機種ID未対応として何もせず終了し、画面を壊さないこと(機種IDを1にすると壊れる: HANDOFF §5)。
# ただし内部コマンド MODE(画面幅の切替)が同名で先に実行されるので、ここでは MODE.COM を直接指定するのではなく dir だけ確認する
for f in "$D"/LSX2500_*.d88; do
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 1200 \
    --type 'dir ld2500.bin\r:800' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "A:LD2500.BIN"; then echo "PASS $(basename $f) dir"
  else echo "FAIL $(basename $f) dir"; echo "$out" | head -8; rc=1; fi
done

# カーソル点滅: プロンプトで待機中にカーソルセルが約30フレーム間隔で明暗を繰り返すこと
for f in "$D"/LSX2500_80col.d88 "$D"/LSX2500_40col.d88 "$D"/LSX2500_80col_noiocs.d88; do
  rm -rf /tmp/_blink && mkdir -p /tmp/_blink
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 500 --frame-dump /tmp/_blink:400:499 >/dev/null 2>&1
  case $(basename $f) in *80col*) box="16 16 24 32";; *) box="32 16 48 32";; esac   # 40桁は1文字=16ドット幅
  if python3 "$HERE/check_blink.py" /tmp/_blink $box >/tmp/_blink.log; then echo "PASS $(basename $f) カーソル点滅 ($(cat /tmp/_blink.log))"
  else echo "FAIL $(basename $f) カーソル点滅"; cat /tmp/_blink.log; rc=1; fi
done

# ワイルドカード: SHIFTを押したまま * / ? を入力する(--type は SHIFT 保持が4フレームと短く文字が化けるので --key-pulse で明示。SHIFTは長め、キーは8フレーム: 4フレームだとキー走査の位相で取りこぼすことがある)
# SHIFT=行11/bit2, '*'=行9/bit2, '?'=行4/bit0
for f in "$D"/LSX2500_*.d88; do
  o1=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 1500 --type 'dir t:600' --key-pulse 11,2:640:40 --key-pulse 9,2:646:8 --type '.com\r:700' --screen-report 2>&1 | grep '^screen:')
  o2=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 1500 --type 'dir ma:600' --key-pulse 11,2:640:40 --key-pulse 4,0:646:8 --type '.com\r:700' --screen-report 2>&1 | grep '^screen:')
  if echo "$o1" | grep -q "TYPE.COM" && ! echo "$o1" | grep -q "LD2500.BIN" && echo "$o2" | grep -q "A:MAG.COM" && ! echo "$o2" | grep -q "MAGA.COM"; then echo "PASS $(basename $f) ワイルドカード(* ?)"
  else echo "FAIL $(basename $f) ワイルドカード(* ?)"; rc=1; fi
done

# LOCK(列11 bit1)で英小文字が大文字になり、KANA(列11 bit3)で半角カナが入力できること
# '/'=行4/bit0 -> ﾒ, 'H'=行5/bit0 -> ｸ, 'S'=行6/bit3 -> ﾄ, SHIFT+'Z'(行7/bit2... 下の表記参照) は省略
for f in "$D"/LSX2500_*.d88; do
  o1=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 900 --key-pulse 11,1:500:300 --type 'abc:600' --screen-report 2>&1 | grep '^screen:')
  o2=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 900 --key-pulse 11,3:500:300 --key-pulse 4,0:600:6 --key-pulse 5,0:620:6 --key-pulse 6,3:640:6 --screen-report 2>&1 | grep '^screen:')
  if echo "$o1" | grep -q "A>ABC" && echo "$o2" | grep -q "A>ﾒｸﾄ"; then echo "PASS $(basename $f) LOCK/KANA"
  else echo "FAIL $(basename $f) LOCK/KANA"; echo "$o1" | sed -n 2p; echo "$o2" | sed -n 2p; rc=1; fi
done

# ブートローダ: LD2500.BIN のセクタが読めない(CRCエラー/RNF)とき、リトライの後 'E' を出して止まる(ハングしない・暴走しない)
for f in "$D"/LSX2500_80col.d88; do
  for m in crc rnf; do
    python3 "$HERE/make_bad_boot_disk.py" "$f" /tmp/_bad_$m.d88 $m
    out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_bad_$m.d88 --frames 3000 --screen-report 2>&1 | grep '^screen:')
    if echo "$out" | grep -q "IPL is loading" && echo "$out" | grep -qE "^screen: E +$" && ! echo "$out" | grep -q "LSX-Dodgers"; then echo "PASS ブート時セクタ不良($m) -> E 表示"
    else echo "FAIL ブート時セクタ不良($m)"; echo "$out" | head -4; rc=1; fi
  done
done

# OS動作中にデータセクタが読めない(CRCエラー)とき、COPYが Error! で終わり、その後もシステムが使えること
for f in "$D"/LSX2500_*.d88; do
  # LD2500.BIN(LSN49から。オーバーレイを含む)の終わりより後ろのシリンダから壊す
  thr=$(python3 -c "import os,sys; n=-(-os.path.getsize(sys.argv[1])//512); print((49+n-1)//18+1)" "$D/_80col/LD2500.BIN")
  python3 "$HERE/make_bad_boot_disk.py" "$f" /tmp/_bad_data.d88 data $thr
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_bad_data.d88 --disk-b /tmp/_blank2dd.d88 --frames 6000 \
    --type 'copy a:type.com b:\r:700' --type 'dir ld2500.bin\r:4000' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "Error!" && echo "$out" | grep -q "A:LD2500.BIN"; then echo "PASS $(basename $f) データ読み出しエラーから復帰"
  else echo "FAIL $(basename $f) データ読み出しエラーから復帰"; echo "$out" | head -8; rc=1; fi
done

# MON: IOCSのモニタ(機能00h)が起動し(メモリ表示 D0 ができ)、R で LSX に戻って DIR が使えること
for f in "$D"/LSX2500_*.d88; do
  o1=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 1300 --type 'imon\r:800' --type 'd0\r:1100' --screen-report 2>&1 | grep '^screen:')
  o2=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 2400 --type 'imon\r:800' --type 'd0\r:1100' --type 'r\r:1500' --type 'dir ld2500.bin\r:2000' --screen-report 2>&1 | grep '^screen:')
  if echo "$o1" | grep -q ":0000=80 BB" && echo "$o2" | grep -q "A:LD2500.BIN" && ! echo "$o2" | grep -q "Error!"; then echo "PASS $(basename $f) IMON(IOCSモニタ)往復"
  else echo "FAIL $(basename $f) IMON(IOCSモニタ)往復"; echo "$o1" | head -4; echo "$o2" | head -4; rc=1; fi
done

# MON.COM(IOCS非依存の外部モニタ): A で組んだ命令を L で逆アセンブルして元の文に戻り、D/F/M も動くこと
for f in "$D"/LSX2500_*.d88; do
  o=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 4000 --type 'mon\r:400' --type 'a 8100\r:600' --type 'jr 8100\r:900' --type 'ld (ix+5),0ffh\r:1200' --type 'bit 3,(iy-2)\r:1500' --type 'djnz 8100\r:1800' --type 'ld hl,(1234)\r:2100' --type 'out (0b4h),a\r:2400' --type '.\r:2700' --type 'l 8100 6\r:3000' --type 'f 8200 8207 5a\r:3300' --type 'd 8200 820f\r:3500' --type 'q\r:3800' --screen-report 2>&1 | grep '^screen:')
  if echo "$o" | grep -q "=DD 36 05 FF" && echo "$o" | grep -q "FD CB FE 5E  BIT 3,(IY-02H)" && echo "$o" | grep -q "10 F4        DJNZ 8100H" && echo "$o" | grep -q "D3 B4        OUT (0B4H),A" && echo "$o" | grep -q "8200: 5A 5A 5A 5A 5A 5A 5A 5A "; then echo "PASS $(basename $f) MON.COM(A/L/F/D)"
  else echo "FAIL $(basename $f) MON.COM(A/L/F/D)"; echo "$o" | tail -14; rc=1; fi
done

# ビープ(Ctrl+G): PC2(E3h bit set/reset)が約953Hz(IOCSのBELLと同じ周期 6294T@6MHz)で49周期。周期は±2%、回数は49
for f in "$D"/LSX2500_80col.d88; do
  r=$(MZ_TRACE_ALL=1 "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 900 --key-pulse 11,4:600:14 --key-pulse 4,7:603:6 --trace-io 2>&1 \
    | python3 -c "
import sys
t=[int(l.split()[1]) for l in sys.stdin if l.startswith('[iot]') and l.split()[4:6]==['OUT','E3'] and l.split()[7] in ('05','04')]
n=len(t)//2
per=(t[2]-t[0]) if len(t)>2 else 0
print('OK' if n==49 and abs(per-6294)<=6294*0.02 else 'NG', n, per)")
  if [ "${r%% *}" = OK ]; then echo "PASS $(basename $f) ビープ($r)"; else echo "FAIL $(basename $f) ビープ($r)"; rc=1; fi
done

# ドライブ3,4(C:,D:)に実体が無いとき、Error! になってシステムが続行できること(エミュレータのFDDは2台のみ。実機の外付けFDDは未確認)
for f in "$D"/LSX2500_*.d88; do
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 3500 \
    --type 'dir c:\r:700' --type 'dir d:\r:1400' --type 'dir ld2500.bin\r:2300' --screen-report 2>&1 | grep '^screen:')
  if [ "$(echo "$out" | grep -c 'Error!')" = 2 ] && echo "$out" | grep -q "A:LD2500.BIN"; then echo "PASS $(basename $f) C:,D:(実体なし)でも続行"
  else echo "FAIL $(basename $f) C:,D:(実体なし)"; echo "$out" | head -8; rc=1; fi
done

# F:(拡張RAMのRAMディスク)と E:(EMM)。INITが検出してDPBを設定する(E:のFATLN=F280h: 640KB=4セクタ, F:のFATLN=F2A0h: 1)。EMMなし(--no-emm)ならE:は0
for f in "$D"/LSX2500_*.d88; do
  m=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 800 --memory-report F280 --memory-report F2A0 2>&1 | tr '\n' ' ')
  n=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --no-emm --frames 800 --memory-report F280 --memory-report F2A0 2>&1 | tr '\n' ' ')
  if echo "$m" | grep -q "memory\[f280\]=04" && echo "$m" | grep -q "memory\[f2a0\]=01" && echo "$n" | grep -q "memory\[f280\]=00"; then echo "PASS $(basename $f) E:,F:の検出(EMMあり/なし)"
  else echo "FAIL $(basename $f) E:,F:の検出"; echo "$m"; echo "$n"; rc=1; fi
done

# F:,E: へ複数クラスタのファイルをコピーして B: へ戻し、内容がバイト単位で一致すること(E:は FORMAT E: が必要)
for f in "$D"/LSX2500_*.d88; do
  want=$(python3 "$HERE/d88_cat.py" "$f" LD2500.BIN | md5sum)
  for drv in f e; do
    python3 "$HERE/make_blank_disk.py" /tmp/_mb.d88 2dd >/dev/null
    pre=(); [ $drv = e ] && pre=(--type 'format e:\r:500' --type '\r:800' --type '\r:1000')
    "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-b /tmp/_mb.d88 --disk-save 1:/tmp/_mo.d88 --frames 6000 "${pre[@]}" \
      --type "copy a:ld2500.bin $drv:\r:1600" --type "copy $drv:ld2500.bin b:x.bin\r:3200" >/dev/null 2>&1
    got=$(python3 "$HERE/d88_cat.py" /tmp/_mo.d88 X.BIN | md5sum)
    if [ "$got" = "$want" ]; then echo "PASS $(basename $f) ${drv^^}: 経由のコピーが一致"; else echo "FAIL $(basename $f) ${drv^^}: 経由のコピー"; rc=1; fi
  done
done

# F:を使い切り、E:は64KB/128KBを超えるまで書いて、最初と最後のファイルが一致すること(アドレス上位の検証)
for f in "$D"/LSX2500_80col.d88; do
  # コピー元は9088バイト(128の倍数)の固定ファイル。LD2500.BINの大きさは本体の配置で変わるので使わない
  python3 -c "open('/tmp/_f9k.bin','wb').write(bytes((i*7+i//251)%256 for i in range(9088)))"
  want=$(md5sum < /tmp/_f9k.bin)
  for drv in f e; do
    N=12; t=600; args=()
    if [ $drv = e ]; then N=15; t=1300; args+=(--type 'format e:\r:500' --type '\r:800' --type '\r:1000'); fi
    for i in $(seq 1 $N); do args+=(--type "copy b:src.bin $drv:f$i.bin\r:$t"); t=$((t+300)); done
    args+=(--type "copy $drv:f$N.bin b:last.bin\r:$t"); t=$((t+400))
    args+=(--type "copy $drv:f1.bin b:first.bin\r:$t"); t=$((t+400))
    python3 "$HERE/make_blank_disk.py" /tmp/_mb.d88 2dd >/dev/null; python3 "$HERE/d88_put.py" /tmp/_mb.d88 /tmp/_f9k.bin SRC.BIN >/dev/null
    "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-b /tmp/_mb.d88 --disk-save 1:/tmp/_mo.d88 --frames $((t+300)) "${args[@]}" >/dev/null 2>&1
    g1=$(python3 "$HERE/d88_cat.py" /tmp/_mo.d88 FIRST.BIN | md5sum); g2=$(python3 "$HERE/d88_cat.py" /tmp/_mo.d88 LAST.BIN | md5sum)
    if [ "$g1" = "$want" ] && [ "$g2" = "$want" ]; then echo "PASS $(basename $f) ${drv^^}: ${N}ファイル(全域)の先頭と末尾が一致"; else echo "FAIL $(basename $f) ${drv^^}: 全域"; rc=1; fi
  done
done

# 隠れる領域(A000H-DFFFH。ゲートがバウンスバッファ経由で渡す)にあるFCB・DMA・文字列・ハンドル読みのバッファが使えること(tests/hidden.asm)
mkdir -p /tmp/_hid; cp "$HERE/../tests/hidden.asm" /tmp/_hid/; (cd /tmp/_hid && "$LSX_Z80ASM" -b -m=z80 hidden.asm >/dev/null)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_hid/i.d88; python3 "$HERE/d88_put.py" /tmp/_hid/i.d88 /tmp/_hid/hidden.bin HID.COM >/dev/null
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_hid/i.d88 --frames 1500 --type 'hid\r:700' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "HID1-OK" && echo "$out" | grep -q "HID2-OK" && ! echo "$out" | grep -qE "^screen: F[1-4]"; then echo "PASS $(basename $f) 隠れ領域のFCB/DMA/文字列/ハンドル読み"
  else echo "FAIL $(basename $f) 隠れ領域のFCB/DMA/文字列/ハンドル読み"; echo "$out" | tail -5; rc=1; fi
done

# ブロック読み書き(26h/27h): 隠れる領域(C000H)に置いた37バイトFCBで700Bを書いて読み戻し、ランダムレコードが進む(tests/blk.asm)
mkdir -p /tmp/_blk; cp "$HERE/../tests/blk.asm" /tmp/_blk/; (cd /tmp/_blk && "$LSX_Z80ASM" -b -m=z80 blk.asm >/dev/null)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_blk/i.d88; python3 "$HERE/d88_put.py" /tmp/_blk/i.d88 /tmp/_blk/blk.bin BLK.COM >/dev/null
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_blk/i.d88 --frames 1500 --type 'blk\r:700' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "BLK-OK"; then echo "PASS $(basename $f) 26h/27hブロック読み書き(隠れるFCB)"
  else echo "FAIL $(basename $f) 26h/27hブロック読み書き(隠れるFCB)"; echo "$out" | tail -4; rc=1; fi
done

# 26h/27h: DMAも隠れる領域(C000H)・FCBも隠れる領域。700Bの書き→読み、EOF超えの短い読み(A=1, HL=700)(tests/blk2.asm)
mkdir -p /tmp/_b2; cp "$HERE/../tests/blk2.asm" /tmp/_b2/; (cd /tmp/_b2 && "$LSX_Z80ASM" -b -m=z80 blk2.asm >/dev/null)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_b2/i.d88; python3 "$HERE/d88_put.py" /tmp/_b2/i.d88 /tmp/_b2/blk2.bin BLK2.COM >/dev/null
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_b2/i.d88 --frames 1500 --type 'blk2\r:700' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "BLK2-OK"; then echo "PASS $(basename $f) 26h/27hブロック読み書き(隠れるDMAとFCB)"
  else echo "FAIL $(basename $f) 26h/27hブロック読み書き(隠れるDMAとFCB)"; echo "$out" | tail -4; rc=1; fi
done

# TRAP38(未初期化領域EFh=RST 28Hの実行)がユーザマップでも "$8000" を出してウォームブートで戻ること(tests/trap.asm)
mkdir -p /tmp/_tr; cp "$HERE/../tests/trap.asm" /tmp/_tr/; (cd /tmp/_tr && "$LSX_Z80ASM" -b -m=z80 trap.asm >/dev/null)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_tr/i.d88; python3 "$HERE/d88_put.py" /tmp/_tr/i.d88 /tmp/_tr/trap.bin TRAP.COM >/dev/null
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_tr/i.d88 --frames 1300 --type 'trap\r:700' --type 'dir trap.com\r:1000' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q '^screen: \$8000' && echo "$out" | grep -q "A:TRAP.COM"; then echo "PASS $(basename $f) TRAP38(ユーザマップ)"
  else echo "FAIL $(basename $f) TRAP38(ユーザマップ)"; echo "$out" | tail -5; rc=1; fi
done

# ユーザの RST 18H (IOCS呼び出し, tests/iocs.asm): IOCSの文字出力で戻ってこられること。IOCS無し(IOCSOK=0, tests/noiocs.asm)ではメッセージを出してウォームブート
mkdir -p /tmp/_io; cp "$HERE/../tests/iocs.asm" "$HERE/../tests/noiocs.asm" /tmp/_io/; (cd /tmp/_io && "$LSX_Z80ASM" -b -m=z80 iocs.asm >/dev/null && "$LSX_Z80ASM" -b -m=z80 noiocs.asm >/dev/null)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_io/i.d88; python3 "$HERE/d88_put.py" /tmp/_io/i.d88 /tmp/_io/iocs.bin IOC.COM >/dev/null; python3 "$HERE/d88_put.py" /tmp/_io/i.d88 /tmp/_io/noiocs.bin NOIO.COM >/dev/null
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_io/i.d88 --frames 1500 --type 'ioc\r:700' --type 'noio\r:1100' --screen-report 2>&1 | grep '^screen:')
  ok1=0; echo "$out" | grep -q "IOC-OK" && ok1=1
  case "$f" in
    *noiocs*) ;;  # TINIT省略でIOCSカーソル位置が不定のためZの位置は問わない(IOC-OKのみ)
    *40col*) echo "$out" | head -1 | grep -q '^screen: ZSX-Dodgers' || ok1=0;;
  esac
  ok2=0; echo "$out" | grep -q "No IOCS (IPL ROM)" && ! echo "$out" | grep -q "SHOULD-NOT" && ok2=1
  # 自前ハンドラ(UI_CRT)を表に入れて呼ぶ。アドレスはこの画像のビルドのmapから
  vd="$D/_$(basename "$f" .d88 | sed 's/^LSX2500_//')"
  ua=$(grep -a '^UI_CRT ' "$vd/conv/body25.map" | sed 's/.*= \$\([0-9A-Fa-f]*\).*/\1/')
  sed "s/^UICRT\tequ 0/UICRT\tequ 0${ua}h/" "$HERE/../tests/iocsnat.asm" > /tmp/_io/iocsnat.asm
  (cd /tmp/_io && "$LSX_Z80ASM" -b -m=z80 iocsnat.asm >/dev/null)
  cp "$f" /tmp/_io/n.d88; python3 "$HERE/d88_put.py" /tmp/_io/n.d88 /tmp/_io/iocsnat.bin NAT.COM >/dev/null
  out3=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_io/n.d88 --frames 900 --type 'nat\r:700' --screen-report 2>&1 | grep '^screen:')
  ok3=0; echo "$out3" | grep -q "YNAT-OK" && ok3=1
  if [ $ok1 = 1 ] && [ $ok2 = 1 ] && [ $ok3 = 1 ]; then echo "PASS $(basename $f) RST 18H(IOCS呼び出し/IOCS無しで停止)"
  else echo "FAIL $(basename $f) RST 18H(IOCS呼び出し/IOCS無しで停止) ok1=$ok1 ok2=$ok2 ok3=$ok3"; echo "$out" | head -8; echo "$out3" | head -8; rc=1; fi
done

# ROM無しブート(改造版エミュレータの簡易IPL, --real-ipl も ROMも無し): 起動してコマンドが動き、IOCS無し状態で自前CRT1C(振り分け表)が使えること
if [ -n "${LSX_CLI_NOROM:-}" ]; then
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_io/r.d88; python3 "$HERE/d88_put.py" /tmp/_io/r.d88 /tmp/_io/iocs.bin IOC.COM >/dev/null; python3 "$HERE/d88_put.py" /tmp/_io/r.d88 /tmp/_io/noiocs.bin NOIO.COM >/dev/null
  out=$("$LSX_CLI_NOROM" --disk-a /tmp/_io/r.d88 --frames 1500 --type 'dir\r:500' --type 'ioc\r:800' --type 'noio\r:1100' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "A:IOC.COM" && echo "$out" | grep -q "ZIOC-OK" && echo "$out" | grep -q "No IOCS (IPL ROM)"; then echo "PASS $(basename $f) ROM無しブート(簡易IPL)"
  else echo "FAIL $(basename $f) ROM無しブート(簡易IPL)"; echo "$out" | grep -v '^screen: *$' | tail -8; rc=1; fi
done
fi

# SASI HDD (H:): FDで起動して --hdf のHDDを H: として読み書きできる(実IPL)。書いた内容がHDDイメージ上で正しいこと
for f in "$D"/LSX2500_*.d88; do
  v=$(basename "$f" .d88 | sed 's/^LSX2500_//')
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --hdf "$D/LSX2500_$v.hdf" --hdf-save /tmp/_sasi_out.hdf --frames 2600 --type 'copy a:ld2500.bin h:big.bin\r:500' --type 'cls\r:900' --type 'dir h:*.bin\r:1200' --screen-report 2>&1 | grep -a '^screen:')
  chk=$(HERE="$HERE" python3 - "$D/_$v/LD2500.BIN" <<'PY'
import sys, struct, os
sys.path.insert(0, os.environ['HERE'])
import make_hdd as m
img = open('/tmp/_sasi_out.hdf', 'rb').read(); L = m.layout(); p0 = m.BASE * 256
root = img[p0 + L['root0'] * 512:p0 + L['root0'] * 512 + 512 * 32]
ref = open(sys.argv[1], 'rb').read(); ok = 0
for i in range(0, len(root), 32):
    e = root[i:i + 32]
    if e[:11] == b'BIG     BIN':
        cl = struct.unpack('<H', e[26:28])[0]; sz = struct.unpack('<I', e[28:32])[0]
        lsn = L['data0'] + (cl - 2) * 2
        ok = int(img[p0 + lsn * 512:p0 + lsn * 512 + sz] == ref)
print(ok)
PY
)
  if echo "$out" | grep -q 'H:LD2500.BIN' && echo "$out" | grep -q 'free H:' && echo "$out" | grep -q 'H:BIG.BIN' && [ "$chk" = 1 ]; then echo "PASS $(basename $f) SASI H:(読み書き)"
  else echo "FAIL $(basename $f) SASI H:(読み書き) chk=$chk"; echo "$out" | grep -v '^screen: *$' | head -12; rc=1; fi
done
# SASI HDDからのブート(ROM無し簡易IPL, FD無し): H>プロンプトで起動しコマンドが動く。書込みも反映される
if [ -n "${LSX_CLI_NOROM:-}" ]; then
for f in "$D"/LSX2500_*.hdf; do
  out=$("$LSX_CLI_NOROM" --hdf "$f" --frames 1800 --type 'copy h:\bin\echo.com h:e2.com\r:500' --type 'e2 hdd-boot-ok\r:900' --type 'dir h:*.bin\r:1200' --screen-report 2>&1 | grep -a '^screen:')
  if echo "$out" | grep -q 'hdd-boot-ok' && echo "$out" | grep -q 'H:LD2500.BIN' && echo "$out" | grep -q 'H>'; then echo "PASS $(basename $f) SASI HDDブート(ROM無し簡易IPL)"
  else echo "FAIL $(basename $f) SASI HDDブート(ROM無し簡易IPL)"; echo "$out" | grep -v '^screen: *$' | head -10; rc=1; fi
done
fi

# 履歴ファイル(HIST。HDDの AUTOEXEC.BAT が hist h:\history.txt を実行): 入力した行が H:\HISTORY.TXT に追記され(空行・直前と同じ行は除く)、
#   再起動すると履歴へ読み込まれる(hist で古い順に出る)。hist off で追記が止まる
if [ -n "${LSX_CLI_NOROM:-}" ]; then
for f in "$D"/LSX2500_*.hdf; do
  rm -f /tmp/_hs.hdf
  a=$("$LSX_CLI_NOROM" --hdf "$f" --hdf-save /tmp/_hs.hdf --frames 3000 --type 'rem one\r:600' --type 'rem two\r:800' --type 'rem two\r:1000' --type 'hist off\r:1200' --type 'rem off\r:1400' --type 'cat h:\history.txt\r:1600' --screen-report 2>&1 | grep -a '^screen:' | sed 's/ *$//; s/^screen: //' | grep -v '^$' | tr '\n' '|')
  b=$("$LSX_CLI_NOROM" --hdf /tmp/_hs.hdf --frames 1500 --type 'hist\r:600' --screen-report 2>&1 | grep -a '^screen:' | sed 's/ *$//; s/^screen: //' | grep -v '^$' | tr '\n' '|')
  case "$a" in *'H>cat h:\history.txt|rem one|rem two|hist off|H>'*) ok1=1;; *) ok1=0;; esac
  case "$b" in *'H>hist|rem one|rem two|hist off|hist|'*) ok2=1;; *) ok2=0;; esac
  if [ $ok1 = 1 ] && [ $ok2 = 1 ]; then echo "PASS $(basename $f) 履歴ファイル(HIST: 追記、重複除外、hist off、再起動後の読み込み)"
  else echo "FAIL $(basename $f) 履歴ファイル ok1=$ok1 ok2=$ok2"; echo "$a"; echo "$b"; rc=1; fi
done
fi

# 漢字表示(src/M25KJ.ASM, ESC k 1 / KMODE): 既定はOFF(Shift_JISのバイトは今までどおり1セルずつ)。ON で全角は横2セル(漢字ROM)。
#   無効な2バイト目は1バイト目を捨てて通常処理。行の最後の桁に来た全角は1セル空けて次の行へ。KMODE OFF で戻る
mkdir -p /tmp/_kj; cp "$HERE/../tests/kj_text.asm" "$HERE/../tests/kj_edge.asm" "$HERE/../coms/kmode.asm" /tmp/_kj/
(cd /tmp/_kj && for n in kj_text kj_edge kmode; do "$LSX_Z80ASM" -b -m=z80 $n.asm >/dev/null; done)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_kj/k.d88
  for pr in kj_text:KJT.COM kj_edge:KJE.COM kmode:KMODE.COM; do python3 "$HERE/d88_put.py" /tmp/_kj/k.d88 /tmp/_kj/${pr%%:*}.bin ${pr##*:} >/dev/null; done
  off=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_kj/k.d88 --frames 800 --type 'cls\r:500' --type 'kjt\r:560' --screen-report 2>&1 | grep -a '^screen:' | grep -a -c '〓')
  on=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_kj/k.d88 --frames 1000 --type 'kmode\r:500' --type 'kjt\r:600' --screen-report 2>&1 | grep -a '^screen:')
  edge=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_kj/k.d88 --frames 1000 --type 'kje\r:500' --screen-report 2>&1 | grep -a '^screen:' | sed 's/^screen: //; s/ *$//')
  back=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_kj/k.d88 --frames 1200 --type 'kmode\r:500' --type 'kmode off\r:650' --type 'kjt\r:800' --screen-report 2>&1 | grep -a '^screen:' | grep -a -c '〓')
  ok=1
  [ "$off" = 0 ] || ok=0
  echo "$on" | grep -q 'AB 〓〓〓〓〓〓〓〓 ｱz' || ok=0
  echo "$on" | grep -q '^screen: 〓〓〓〓〓〓 C' || ok=0
  echo "$edge" | grep -qx 'A' || ok=0
  echo "$edge" | grep -qx 'B' || ok=0
  echo "$edge" | grep -q '^〓〓z$' || ok=0
  echo "$edge" | awk '/^〓〓z$/{ if (prev ~ /^x+$/ && (length(prev)+1) % 40 == 0) f=1 } {prev=$0} END{exit !f}' || ok=0
  [ "$back" = 0 ] || ok=0
  if [ $ok = 1 ]; then echo "PASS $(basename $f) 漢字表示(ESC k / KMODE、2セル、無効な2バイト目、行末)"
  else echo "FAIL $(basename $f) 漢字表示 off=$off back=$back"; echo "$on" | grep -v '^screen: *$' | tail -4; echo "$edge" | tail -6; rc=1; fi
done

# 色(ESC b n 文字色 / ESC p,q 反転 / COLOR.COM): アトリビュートV-RAM(70800H)の値で確認。ANSI順の色番号をMZ-2500のGRBビットへ変換する
#   R,G,B,X(反転+青),W,C,Y → 02 04 01 41 07 05 06。COLOR.COM は 引数なしで白・反転OFFへ戻す
mkdir -p /tmp/_cl; cp "$HERE/../tests/col_text.asm" "$HERE/../coms/color.asm" /tmp/_cl/
(cd /tmp/_cl && for n in col_text color; do "$LSX_Z80ASM" -b -m=z80 $n.asm >/dev/null; done)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_cl/k.d88
  python3 "$HERE/d88_put.py" /tmp/_cl/k.d88 /tmp/_cl/col_text.bin COLT.COM >/dev/null
  python3 "$HERE/d88_put.py" /tmp/_cl/k.d88 /tmp/_cl/color.bin COLOR.COM >/dev/null
  a1=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_cl/k.d88 --frames 800 --type 'colt\r:550' --phys-dump 70800:7 2>&1 | grep -a 'phys 70800' | sed 's/.*: //; s/ *$//')
  if [ "$a1" = '02 04 01 41 07 05 06' ]; then echo "PASS $(basename $f) 色(ESC b / ESC p,q)"
  else echo "FAIL $(basename $f) 色 [$a1]"; rc=1; fi
done

# SGR (ESC [ n;n m): 31,32,34 / 7;34 / (空=0) / 96 / ?25h は無視 / 33;1(1は無視)。ESC b と同じ並びになること
mkdir -p /tmp/_sg; cp "$HERE/../tests/sgr_text.asm" /tmp/_sg/
(cd /tmp/_sg && "$LSX_Z80ASM" -b -m=z80 sgr_text.asm >/dev/null)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_sg/k.d88
  python3 "$HERE/d88_put.py" /tmp/_sg/k.d88 /tmp/_sg/sgr_text.bin SGRT.COM >/dev/null
  a1=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_sg/k.d88 --frames 800 --type 'sgrt\r:550' --phys-dump 70800:7 2>&1 | grep -a 'phys 70800' | sed 's/.*: //; s/ *$//')
  if [ "$a1" = '02 04 01 41 07 05 06' ]; then echo "PASS $(basename $f) SGR(ESC [ m)"
  else echo "FAIL $(basename $f) SGR [$a1]"; rc=1; fi
done

# 日本語ファイル名(Shift_JIS 全角・半角カナ): 作成(リダイレクト)・cp・mv・touch・ワイルドカード・ls の出力(R.LST)のバイトで確認(元のLSXの漢字名対応がそのまま効くこと)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_jn.d88
  python3 "$HERE/d88_put.py" /tmp/_jn.d88 "$HERE/../tests/jname.bat" JNAME.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_jn.d88 --disk-save 0:/tmp/_jn_out.d88 --frames 1300 --type 'jname\r:450' >/dev/null 2>&1
  got=$(python3 "$HERE/d88_cat.py" /tmp/_jn_out.d88 R.LST 2>/dev/null | od -An -tx1 | tr -d ' \n')
  if [ "$got" = '82a082a22e5458540d0a82a882a92e5458540d0ab1b22e5458540d0a' ]; then echo "PASS $(basename $f) 日本語ファイル名(全角・半角カナ)"
  else echo "FAIL $(basename $f) 日本語ファイル名 [$got]"; rc=1; fi
done

# 長いファイル名(Human68k/TwentyOne 方式: 名前の9文字目以降を dirent +0Ch の10バイトに持つ)の表示: ls / dir が name1+name2.ext を出す。
#   Windows 流の予約領域(制御文字を含む)は名前に取り違えない。試験用イメージは d88_put.py の第4引数で作る
mkdir -p /tmp/_lnm; echo hi > /tmp/_lnm/h.txt
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_lnm/a.d88
  P="python3 $HERE/d88_put.py /tmp/_lnm/a.d88"
  $P "$HERE/../tests/lname.bat" LNAME.BAT >/dev/null
  $P /tmp/_lnm/h.txt LONGNAME.TXT ISHERE >/dev/null
  $P /tmp/_lnm/h.txt ABCDEFGH.DAT 日本語 >/dev/null
  $P /tmp/_lnm/h.txt WINDOWS8.TXT $'\x08_' >/dev/null
  $P /tmp/_lnm/h.txt SHORT.TXT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_lnm/a.d88 --disk-save 0:/tmp/_lnm/o.d88 --frames 1500 --type 'lname\r:450' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_lnm/o.d88 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n'; }
  ok=1
  r1=$(g R1.LST)
  [ "$r1" = '4c4f4e474e414d454953484552452e5458540d0a53484f52542e5458540d0a57494e444f5753382e5458540d0a' ] || { ok=0; echo "  NG ls txt [$r1]"; }
  r2=$(g R2.LST); [ "$r2" = '414243444546474893fa967b8cea2e4441540d0a' ] || { ok=0; echo "  NG ls dat [$r2]"; }
  r3=$(g R3.LST); case "$r3" in *'413a4c4f4e474e414d454953484552452e5458540d0a'*'413a57494e444f5753382e5458540d0a'*) ;; *) ok=0; echo "  NG dir txt [$r3]";; esac
  r4=$(g R4.LST); case "$r4" in *'413a414243444546474893fa967b8cea2e4441540d0a'*) ;; *) ok=0; echo "  NG dir dat [$r4]";; esac
  if [ $ok = 1 ]; then echo "PASS $(basename $f) 長いファイル名の表示(ls / dir)"; else echo "FAIL $(basename $f) 長いファイル名の表示"; rc=1; fi
done

# 長いファイル名の作成・検索・名前変更・削除(OS 本体の対応): LONGNAMEISHERE.TXT / LONGNAMEOTHER.TXT / LONGNAME.TXT は別のファイル。
#   リダイレクトでの作成、type、ren(長い名前へ)、del(完全一致のものだけ消える)、ワイルドカードの一覧を確かめる。del はキー待ちなのでキーを送る
mkdir -p /tmp/_ln2
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ln2/a.d88
  python3 "$HERE/d88_put.py" /tmp/_ln2/a.d88 "$HERE/../tests/lname2.bat" LNAME2.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ln2/a.d88 --disk-save 0:/tmp/_ln2/o.d88 --frames 4500 --type 'lname2\r:450' --type 'x:2200' --type 'x:3000' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_ln2/o.d88 "$1" 2>/dev/null | tr -d '\r' | sed 's/^ *//' | tr '\n' '|'; }
  ok=1
  case "$(g R1.LST)" in '25 A:LONGNAMEISHERE.TXT|24 A:LONGNAMEOTHER.TXT|17 A:LONGNAME.TXT|'*) ;; *) ok=0; echo "  NG r1 [$(g R1.LST)]";; esac
  [ "$(python3 "$HERE/d88_cat.py" /tmp/_ln2/o.d88 R2.LST | tr -d ' \r\n')" = abc ] || { ok=0; echo "  NG r2"; }
  [ "$(python3 "$HERE/d88_cat.py" /tmp/_ln2/o.d88 R3.LST | tr -d ' \r\n')" = xyz ] || { ok=0; echo "  NG r3"; }
  [ "$(python3 "$HERE/d88_cat.py" /tmp/_ln2/o.d88 R4.LST | tr -d ' \r\n')" = s ] || { ok=0; echo "  NG r4"; }
  case "$(g R5.LST)" in '25 A:RENAMEDLONGNAMEX.TXT|24 A:LONGNAMEOTHER.TXT|17 A:LONGNAME.TXT|'*) ;; *) ok=0; echo "  NG r5 [$(g R5.LST)]";; esac
  case "$(g R6.LST)" in '25 A:RENAMEDLONGNAMEX.TXT|24 A:LONGNAMEOTHER.TXT|'*) ;; *) ok=0; echo "  NG r6 [$(g R6.LST)]";; esac
  case "$(g R7.LST)" in '25 A:RENAMEDLONGNAMEX.TXT|'*) ;; *) ok=0; echo "  NG r7 [$(g R7.LST)]";; esac
  if [ $ok = 1 ]; then echo "PASS $(basename $f) 長いファイル名(作成・type・ren・del・一覧)"; else echo "FAIL $(basename $f) 長いファイル名(作成・ren・del)"; rc=1; fi
done

# 長いファイル名と付属コマンド: cp のワイルドカード・cp -r で名前が保たれる(以前は同じ名前に潰れて上書きされた)、cat、mv(長い名前へ/から)
mkdir -p /tmp/_ln3
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ln3/a.d88
  python3 "$HERE/d88_put.py" /tmp/_ln3/a.d88 "$HERE/../tests/lname3.bat" LNAME3.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ln3/a.d88 --disk-save 0:/tmp/_ln3/o.d88 --frames 5000 --type 'lname3\r:450' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_ln3/o.d88 "$1" 2>/dev/null | tr -d '\r' | sed 's/^ *//' | tr '\n' '|'; }
  ok=1
  case "$(g R1.LST)" in '25 A:LONGNAMEISHERE.TXT|24 A:LONGNAMEOTHER.TXT|'*) ;; *) ok=0; echo "  NG r1 [$(g R1.LST)]";; esac
  case "$(g R2.LST)" in '25 A:LONGNAMEISHERE.TXT|24 A:LONGNAMEOTHER.TXT|'*) ;; *) ok=0; echo "  NG r2 [$(g R2.LST)]";; esac
  for p in 'R3 xyz' 'R4 abc' 'R5 xyz' 'R6 xyz'; do set -- $p
    [ "$(python3 "$HERE/d88_cat.py" /tmp/_ln3/o.d88 $1.LST | tr -d ' \r\n')" = $2 ] || { ok=0; echo "  NG $1"; }; done
  if [ $ok = 1 ]; then echo "PASS $(basename $f) 長いファイル名(cp ワイルドカード・cp -r・cat・mv)"; else echo "FAIL $(basename $f) 長いファイル名(cp mv)"; rc=1; fi
done

# 長いファイル名と付属コマンド(2): find / du は長い名前のディレクトリへ正しく入る、egrep / sed は同じ先頭8文字のファイルを取り違えない
mkdir -p /tmp/_ln4
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ln4/a.d88
  python3 "$HERE/d88_put.py" /tmp/_ln4/a.d88 "$HERE/../tests/lname4.bat" LNAME4.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ln4/a.d88 --disk-save 0:/tmp/_ln4/o.d88 --frames 6000 --type 'lname4\r:450' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_ln4/o.d88 "$1" 2>/dev/null | tr -d '\r' | sed 's/^ *//; s/ *$//' | tr '\n' '|'; }
  ok=1
  [ "$(g R1.LST)" = 'LONGDIRONE\F.TXT|LONGDIRTWO\F.TXT|' ] || { ok=0; echo "  NG r1 [$(g R1.LST)]"; }
  case "$(g R2.LST)" in *'23 LONGDIRONE\|26 LONGDIRTWO\|'*) ;; *) ok=0; echo "  NG r2 [$(g R2.LST)]";; esac
  [ "$(g R3.LST)" = 'LONGNAMEISHERE.TXT:hello|' ] || { ok=0; echo "  NG r3 [$(g R3.LST)]"; }
  [ "$(g R4.LST)" = 'LONGNAME.TXT:world|' ] || { ok=0; echo "  NG r4 [$(g R4.LST)]"; }
  [ "$(g R5.LST)" = 'hello|world|' ] || { ok=0; echo "  NG r5 [$(g R5.LST)]"; }
  case "$(g R6.LST)" in *LONGBATNAME.BAT*) ;; *) ok=0; echo "  NG r6 [$(g R6.LST)]";; esac
  if [ $ok = 1 ]; then echo "PASS $(basename $f) 長いファイル名(find du egrep sed which)"; else echo "FAIL $(basename $f) 長いファイル名(find du egrep sed which)"; rc=1; fi
done

# 長いファイル名と予約領域: Windows 流の予約領域(制御文字・00hの後に非0)や LA バイナリの印があるエントリは、短い名前のまま開け・複写でき、名前変更後も長い名前に化けない
mkdir -p /tmp/_ln5; echo hi > /tmp/_ln5/h.txt
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ln5/a.d88
  P="python3 $HERE/d88_put.py /tmp/_ln5/a.d88"
  $P /tmp/_ln5/h.txt WINDOWS8.TXT $'\x08_' >/dev/null
  $P /tmp/_ln5/h.txt NTCASE12.TXT $'\x18\x00\x00\x00' >/dev/null
  $P /tmp/_ln5/h.txt LABIN123.TXT $'\x00\x40\x00\x00\x00\x00\xA0' >/dev/null
  $P "$HERE/../tests/lname5.bat" LNAME5.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ln5/a.d88 --disk-save 0:/tmp/_ln5/o.d88 --frames 3500 --type 'lname5\r:450' >/dev/null 2>&1
  ok=1
  for n in R1 R2 R3 R4 R5; do [ "$(python3 "$HERE/d88_cat.py" /tmp/_ln5/o.d88 $n.LST 2>/dev/null | tr -d ' \r\n')" = hi ] || { ok=0; echo "  NG $n"; }; done
  r6=$(python3 "$HERE/d88_cat.py" /tmp/_ln5/o.d88 R6.LST 2>/dev/null | tr -d '\r' | sed 's/^ *//' | tr '\n' '|')
  case "$r6" in '3 A:WINDOWS8.TXT|3 A:NT2.TXT|3 A:LABIN123.TXT|3 A:W2.TXT|'*) ;; *) ok=0; echo "  NG r6 [$r6]";; esac
  if [ $ok = 1 ]; then echo "PASS $(basename $f) 長いファイル名(Windows予約領域・LAバイナリの印)"; else echo "FAIL $(basename $f) 長いファイル名(予約領域)"; rc=1; fi
done

# find の起点 ".\": カレントと同じ(以前は BDOS の "." 成分の癖で DEEP\DEEP\DEEP… と降り続けた)
mkdir -p /tmp/_fc
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_fc/a.d88
  python3 "$HERE/d88_put.py" /tmp/_fc/a.d88 "$HERE/../tests/findcwd.bat" KG.BAT >/dev/null
  python3 "$HERE/d88_put.py" /tmp/_fc/a.d88 "$HERE/../tests/findcwd.bat" KA.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_fc/a.d88 --disk-save 0:/tmp/_fc/o.d88 --frames 4500 --type 'kg\r:450' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_fc/o.d88 "$1" 2>/dev/null | tr -d '\r' | tr '\n' '|'; }
  if [ "$(g A3.LST)" = 'DEEP\|X.TXT|DEEP\Y.DAT|' ] && [ "$(g A4.LST)" = 'DEEP\|' ] && [ "$(g A5.LST)" = 'deep\Y.DAT|' ]; then echo "PASS $(basename $f) find .\\ (カレント起点)"; else echo "FAIL $(basename $f) find .\\ [$(g A3.LST)] [$(g A4.LST)] [$(g A5.LST)]"; rc=1; fi
done

# BDOS E4h (長いファイル名の登録): 登録しないと長い名前のファイルは 8+3 の FCB で開けず、登録すると開ける
mkdir -p /tmp/_lr; cp "$HERE/../tests/lnreg.asm" /tmp/_lr/; (cd /tmp/_lr && "$LSX_Z80ASM" -b -m=z80 lnreg.asm >/dev/null)
echo hi > /tmp/_lr/h.txt; printf 'lnreg n > r1.lst\r\nlnreg > r2.lst\r\n' > /tmp/_lr/b.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_lr/i.d88
  python3 "$HERE/d88_put.py" /tmp/_lr/i.d88 /tmp/_lr/h.txt LONGNAME.TXT ISHERE >/dev/null
  python3 "$HERE/d88_put.py" /tmp/_lr/i.d88 /tmp/_lr/b.bat B.BAT >/dev/null; python3 "$HERE/d88_put.py" /tmp/_lr/i.d88 /tmp/_lr/lnreg.bin LNREG.COM >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_lr/i.d88 --disk-save 0:/tmp/_lr/o.d88 --frames 2200 --type 'b\r:450' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_lr/o.d88 "$1" 2>/dev/null | tr -d ' \r\n'; }
  if [ "$(g R1.LST)" = NG ] && [ "$(g R2.LST)" = OK ]; then echo "PASS $(basename $f) BDOS E4h 長いファイル名の登録"; else echo "FAIL $(basename $f) BDOS E4h [$(g R1.LST)] [$(g R2.LST)]"; rc=1; fi
done

# TPAの上限: F:から約56KBのCOM(0100H-DFFFHのうち、スタック用に256B残す)を読み込んで実行できること(ゲート方式のTPA拡張)
for f in "$D"/LSX2500_*.d88; do
  python3 "$HERE/make_big_com.py" /tmp/_big.com 56000
  python3 "$HERE/make_blank_disk.py" /tmp/_bb.d88 2dd >/dev/null; python3 "$HERE/d88_put.py" /tmp/_bb.d88 /tmp/_big.com BIG.COM
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-b /tmp/_bb.d88 --frames 6500 \
    --type 'copy b:big.com f:\r:700' --type 'f:big\r:3300' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "LOAD OK"; then echo "PASS $(basename $f) F:から56KBのCOMを読み込んで実行(TPA拡張)"
  else echo "FAIL $(basename $f) F:から56KBのCOMを実行"; echo "$out" | tail -4; rc=1; fi
done

# F:から約42KBのCOM(旧方式のTPAは0100H-B005H。ローダの上限は42500〜43000の間。2026-11-07 に BDOS を 0B006H へ下げて以前の46000から変更。現行のゲート方式は次の56KBのテスト)を読み込んで実行できること。自分のデータの和を検算して LOAD OK を出す。
# バッファがバンク0-5を順に通るので、窓バンク(1/3)の両方の経路を通る
for f in "$D"/LSX2500_*.d88; do
  python3 "$HERE/make_big_com.py" /tmp/_big.com 42000
  python3 "$HERE/make_blank_disk.py" /tmp/_bb.d88 2dd >/dev/null; python3 "$HERE/d88_put.py" /tmp/_bb.d88 /tmp/_big.com BIG.COM
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-b /tmp/_bb.d88 --frames 4500 \
    --type 'copy b:big.com f:\r:700' --type 'f:big\r:3300' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "LOAD OK"; then echo "PASS $(basename $f) F:から42KBのCOMを読み込んで実行"
  else echo "FAIL $(basename $f) F:から42KBのCOMを実行"; echo "$out" | tail -4; rc=1; fi
done

# ハードウェアスクロール(80桁): 200行を type して (1) 約1700フレーム以内に終わる(従来の画面コピー方式は約2100フレーム) (2) 終了後に最後の行が残る
# (3) COM起動(mode)で表示開始セルが0へ戻り、画面の文字は保たれる。40桁も同じハードスクロール(2026-11-12。以前のコピー方式は途中の画面がちらついた)
python3 -c "open('/tmp/_long.txt','w').write(''.join('LINE %03d abcdefghijklmnopqrstuvwxyz 0123456789\r\n'%i for i in range(1,201))+'\x1a')"
python3 "$HERE/make_blank_disk.py" /tmp/_lb.d88 2dd >/dev/null; python3 "$HERE/d88_put.py" /tmp/_lb.d88 /tmp/_long.txt LONG.TXT
for f in "$D"/LSX2500_80col.d88 "$D"/LSX2500_80col_noiocs.d88 "$D"/LSX2500_40col.d88; do
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-b /tmp/_lb.d88 --frames 1700 --type 'type b:long.txt\r:600' --screen-report 2>&1 | grep '^screen:')
  case $(basename $f) in
    *80col*) if echo "$out" | grep -q "LINE 200" && echo "$out" | tail -1 | grep -q "A>"; then echo "PASS $(basename $f) ハードスクロール: 200行がフレーム1700以内に完了"
             else echo "FAIL $(basename $f) ハードスクロール速度/表示"; echo "$out" | tail -3; rc=1; fi ;;
    *) out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-b /tmp/_lb.d88 --frames 3600 --type 'type b:long.txt\r:600' --screen-report 2>&1 | grep '^screen:')
       if echo "$out" | grep -q "LINE 200" && echo "$out" | tail -1 | grep -q "A>"; then echo "PASS $(basename $f) 200行のtype(40桁のハードスクロール)"
       else echo "FAIL $(basename $f) 200行のtype"; echo "$out" | tail -3; rc=1; fi ;;
  esac
done
for f in "$D"/LSX2500_*.d88; do
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-b /tmp/_lb.d88 --frames 2300 \
    --type 'type b:long.txt\r:600' --type 'pwd\r:1750' --screen-report --crtc-report 2>&1)
  st=$(echo "$out" | grep '^crtc:' | sed 's/.*\$01=\([0-9a-f]*\) \$02=\([0-9a-f]*\).*/\1:\2/')
  # COM起動で0:0に戻り、その後 mode の出力ぶん(1〜2行)しかスクロールしていないこと(80桁は 0x50 か 0xa0、40桁は 0x28 か 0x50 まで)
  if echo "$out" | grep -q "LINE 199" && echo "$out" | grep -q "^screen: A:\\\\" && { [ "$st" = "50:00" ] || [ "$st" = "a0:00" ] || [ "$st" = "28:00" ] || [ "$st" = "00:00" ]; }; then
    echo "PASS $(basename $f) COM起動で表示開始セルを0へ戻す (start=$st)"
  else echo "FAIL $(basename $f) COM起動でのスクロール正規化 (start=$st)"; echo "$out" | grep '^screen:' | tail -4; rc=1; fi
done

# MSX-DOS2 ハンドル層(43h-4Bh): tests/hndtest.asm(正常系: 作成/書き/seek/読み/dup/ioctl/閉じる/1500バイト/コンソール読み)と
# tests/hndtest2.asm(エラー系: 存在しない/不正・未使用ハンドル/create-new/書き込み禁止/末尾基準seek/EOF/ハンドル枯渇/stderr/開きっぱなし終了)。画面に "NG " が1つも出ず、終了表示が出ること
HT=$(cd "$HERE/../tests" && pwd); mkdir -p /tmp/_ht; cp "$HT"/*.asm "$HT"/*.inc /tmp/_ht/
(cd /tmp/_ht && "$LSX_Z80ASM" -b -m=z80 hndtest.asm >/dev/null && "$LSX_Z80ASM" -b -m=z80 hndtest2.asm >/dev/null)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ht/img.d88; python3 "$HERE/d88_put.py" /tmp/_ht/img.d88 /tmp/_ht/hndtest.bin HNDTEST.COM >/dev/null
  python3 "$HERE/d88_put.py" /tmp/_ht/img.d88 /tmp/_ht/hndtest2.bin HNDTEST2.COM >/dev/null
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/img.d88 --disk-save 0:/tmp/_ht/out.d88 --frames 3400 \
    --type 'hndtest\r:700' --type 'ab\r:2600' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "HT DONE" && ! echo "$out" | grep -q "NG " && echo "$out" | grep -q "HELLO WORLD!!!Z" && echo "$out" | grep -q "^screen: 04ab"; then
    echo "PASS $(basename $f) ハンドル層(正常系)"
  else echo "FAIL $(basename $f) ハンドル層(正常系)"; echo "$out" | tail -8; rc=1; fi
  # ディスク上の内容: HT1.TXT=15バイト, BIG.BIN=1500バイトで内容一致
  python3 - "$HERE" /tmp/_ht/out.d88 <<'PY'
import subprocess, sys
here, img = sys.argv[1:3]
a = subprocess.run([sys.executable, here + '/d88_cat.py', img, 'HT1.TXT'], capture_output=True).stdout
b = subprocess.run([sys.executable, here + '/d88_cat.py', img, 'BIG.BIN'], capture_output=True).stdout
ok = a == b'HELLO WORLD!!!Z' and b == bytes((3 + 7 * i) & 255 for i in range(300)) * 5
print('PASS ディスク上の内容が一致(HT1.TXT 15B / BIG.BIN 1500B)' if ok else 'FAIL ディスク上の内容 %r %d' % (a, len(b)))
sys.exit(0 if ok else 1)
PY
  [ $? -eq 0 ] || rc=1
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/img.d88 --disk-save 0:/tmp/_ht/out2.d88 --frames 2000 \
    --type 'hndtest2\r:700' --type 'dir t2.txt\r:1600' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "HT2 DONE" && ! echo "$out" | grep -q "NG " && echo "$out" | grep -q "10 A:T2.TXT"; then
    echo "PASS $(basename $f) ハンドル層(エラー系・開きっぱなし終了後にDIRが使える)"
  else echo "FAIL $(basename $f) ハンドル層(エラー系)"; echo "$out" | tail -8; rc=1; fi
done

# リダイレクト(> >> <): tests/rdtest.asm は標準入力($0A,$07)から読んで標準出力($02,$09)へ出す。
# (1) 画面: rdtest < in.txt  (2) ファイル: rdtest < in.txt > o2.txt の内容  (3) type > と >> (追記)  (4) dir > ファイル  (5) 無い入力ファイルはメッセージを出して実行しない
cp "$HT"/rdtest.asm /tmp/_ht/; (cd /tmp/_ht && "$LSX_Z80ASM" -b -m=z80 rdtest.asm >/dev/null)
printf 'alpha\r\nbeta\r\nQ\r\nxyz' > /tmp/_ht/in.txt
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ht/r.d88; python3 "$HERE/d88_put.py" /tmp/_ht/r.d88 /tmp/_ht/rdtest.bin RDTEST.COM >/dev/null; python3 "$HERE/d88_put.py" /tmp/_ht/r.d88 /tmp/_ht/in.txt IN.TXT >/dev/null
  # --type は SHIFT を4フレームしか保持せず ">" の連続入力が化けるので、コマンドはバッチファイルに入れて実行する(バッチの行も同じ解釈経路を通る)
  printf 'rdtest < in.txt\r\nrdtest < in.txt > o2.txt\r\ntype in.txt > a.txt\r\ntype in.txt >> a.txt\r\nrdtest < nosuch.txt\r\ndir > o1.txt\r\n' > /tmp/_ht/cmds.bat
  python3 "$HERE/d88_put.py" /tmp/_ht/r.d88 /tmp/_ht/cmds.bat CMDS.BAT >/dev/null
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/r.d88 --disk-save 0:/tmp/_ht/r_out.d88 --frames 3600 \
    --type 'cmds\r:700' --screen-report 2>&1 | grep '^screen:')
  python3 - "$HERE" /tmp/_ht/r_out.d88 <<'PY'
import subprocess, sys
here, img = sys.argv[1:3]
def cat(n): return subprocess.run([sys.executable, here + '/d88_cat.py', img, n], capture_output=True).stdout
exp_a = b'alpha\r\nbeta\r\nQ\r\nxyz' * 2
ok = cat('O2.TXT') == b'[alpha][beta]|xyz<END>\r\n' and cat('A.TXT') == exp_a and b'A:TYPE.COM\r\n' in cat('O1.TXT') and cat('O1.TXT').rstrip().endswith(b'free A:\\')
sys.exit(0 if ok else 1)
PY
  fl=$?
  if [ $fl -eq 0 ] && echo "$out" | grep -q "^screen: \[alpha\]\[beta\]|xyz<END>" && echo "$out" | grep -q "Cannot open redirect file"; then
    echo "PASS $(basename $f) リダイレクト(< > >>、画面/ファイル、無い入力ファイル、dir >)"
  else echo "FAIL $(basename $f) リダイレクト (file=$fl)"; echo "$out" | tail -8; rc=1; fi
done
# cat.COM (coms/cat.asm): 連結、> でファイルへ、< で標準入力、無いファイルのメッセージ。起動ディスクに CAT.COM が入っていること
printf 'alpha\r\nbeta\r\n' > /tmp/_ht/c1.txt; printf 'line2\r\n' > /tmp/_ht/c2.txt
printf 'cat c1.txt c2.txt\r\ncat c2.txt c1.txt > co.txt\r\ncat nosuch.txt\r\ncat < c1.txt\r\n' > /tmp/_ht/cmds.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ht/r.d88
  for p in "c1.txt C1.TXT" "c2.txt C2.TXT" "cmds.bat CMDS.BAT"; do set -- $p; python3 "$HERE/d88_put.py" /tmp/_ht/r.d88 /tmp/_ht/$1 $2 >/dev/null; done
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/r.d88 --disk-save 0:/tmp/_ht/r_out.d88 --frames 3000 \
    --type 'cmds\r:700' --screen-report 2>&1 | grep '^screen:')
  co=$(python3 "$HERE/d88_cat.py" /tmp/_ht/r_out.d88 CO.TXT | od -An -c | tr -s ' \n' ' ')
  if [ "$co" = " l i n e 2 \r \n a l p h a \r \n b e t a \r \n " ] && echo "$out" | grep -q "cat: cannot open file" \
     && [ "$(echo "$out" | grep -c '^screen: alpha')" = 2 ] && echo "$out" | grep -q "^screen: line2"; then
    echo "PASS $(basename $f) cat.COM (連結、>、<、無いファイル)"
  else echo "FAIL $(basename $f) cat.COM"; echo "$out" | head -10; rc=1; fi
done
# more.COM (coms/more.asm): 1画面ずつ(SPACEで次、Qで終了)、標準入力が < のファイルでもキーボードから読める、> でファイルへ出すときはページ送りせず無加工
python3 -c "import sys; sys.stdout.buffer.write(b''.join(b'line %02d\r\n'%i for i in range(1,61)))" > /tmp/_ht/long.txt
printf 'more long.txt > mo.txt\r\n' > /tmp/_ht/c2.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ht/r.d88
  for p in "long.txt LONG.TXT" "c2.bat C2.BAT"; do set -- $p; python3 "$HERE/d88_put.py" /tmp/_ht/r.d88 /tmp/_ht/$1 $2 >/dev/null; done
  o1=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/r.d88 --frames 2400 --type 'more long.txt\r:700' --key-pulse space:1400:6 --screen-report 2>&1 | grep '^screen:' | sed 's/ *$//' | grep -v '^screen:$')
  o2=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/r.d88 --frames 2600 --type 'more < long.txt\r:700' --key-pulse space:1400:6 --key-pulse q:1900:6 --screen-report 2>&1 | grep '^screen:' | sed 's/ *$//' | grep -v '^screen:$')
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/r.d88 --disk-save 0:/tmp/_ht/mo_out.d88 --frames 2000 --type 'c2\r:700' >/dev/null 2>&1
  if echo "$o1" | tail -2 | tr '\n' '|' | grep -q 'line 48|screen: --More--|' && echo "$o1" | grep -q 'line 25' \
     && echo "$o2" | tail -2 | tr '\n' '|' | grep -q 'line 48|screen: A>|' \
     && python3 "$HERE/d88_cat.py" /tmp/_ht/mo_out.d88 MO.TXT | cmp -s - /tmp/_ht/long.txt; then
    echo "PASS $(basename $f) more.COM (ページ送り、Qで終了、< でもキー入力、> は無加工)"
  else echo "FAIL $(basename $f) more.COM"; echo "$o1" | tail -3; echo "$o2" | tail -3; rc=1; fi
done
# grep.COM (coms/grep.asm): 大小無視 -i、行番号 -n、件数 -c、反転 -v、^ $ . *、< での標準入力、引数なしの usage
printf 'Hello World\r\nfoo bar\r\nHELLO again\r\nabc123\r\n\r\nlast line no newline' > /tmp/_ht/g.txt
printf 'grep hello g.txt\r\ngrep -i hello g.txt\r\ngrep -n "o b" g.txt\r\ngrep -c o g.txt\r\ngrep ^abc.*3$ g.txt\r\ngrep -n line < g.txt\r\ngrep zzz g.txt\r\ngrep\r\n' > /tmp/_ht/gc.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ht/r.d88
  for p in "g.txt G.TXT" "gc.bat GC.BAT"; do set -- $p; python3 "$HERE/d88_put.py" /tmp/_ht/r.d88 /tmp/_ht/$1 $2 >/dev/null; done
  o=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/r.d88 --frames 3600 --type 'gc\r:700' --screen-report 2>&1 | grep '^screen:' | sed 's/ *$//' | grep -v '^screen:$' | sed -n '/^screen: A>gc/,$p' | tail -n +2 | tr '\n' '|')
  exp='screen: Hello World|screen: HELLO again|screen: 2:foo bar|screen: 3|screen: abc123|screen: 6:last line no newline|screen: usage: grep [-ivnc] pattern [file]|screen: A>|'
  if [ "$o" = "$exp" ]; then echo "PASS $(basename $f) grep.COM (-i -n -c、^ \$ . *、<、usage)"
  else echo "FAIL $(basename $f) grep.COM"; echo "$o"; rc=1; fi
done
# 環境変数 (src/M25ENV.ASM): set NAME=値 / 削除 / 一覧(set, env)、$NAME ${NAME} $$ の展開、未定義は空、使い方エラー
printf 'xyz\r\n' > /tmp/_ht/c1.txt
printf 'set F=c1.txt\r\nset G="c1 .txt"\r\ncat $F\r\ncat ${F}x\r\ncat $Q$F\r\ncat $$F\r\nset BAD\r\nset X=1\r\nset Y=2\r\nset X=\r\nset\r\nset F=\r\nset G=\r\nset Y=\r\nenv\r\n' > /tmp/_ht/e.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ht/r.d88
  for p in "c1.txt C1.TXT" "e.bat E.BAT"; do set -- $p; python3 "$HERE/d88_put.py" /tmp/_ht/r.d88 /tmp/_ht/$1 $2 >/dev/null; done
  o=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/r.d88 --frames 3200 --type 'e\r:700' --screen-report 2>&1 | grep '^screen:' | sed 's/ *$//' | grep -v '^screen:$' | sed -n '/^screen: A>e/,$p' | tail -n +2 | tr '\n' '|')
  exp='screen: xyz|screen: xyz|screen: xyz|screen: cat: cannot open file|screen: usage: set NAME=value|screen: F=c1.txt|screen: G=c1 .txt|screen: Y=2|screen: A>|'
  if [ "$o" = "$exp" ]; then echo "PASS $(basename $f) 環境変数 (set/env/\$展開)"
  else echo "FAIL $(basename $f) 環境変数"; echo "$o"; rc=1; fi
done
# 終了コード/バッチ (src/M25BAT.ASM): BDOS 62h(_TERM) と $?、バッチ引数 $1-$9(足りない分は消える)、:label / GOTO(前方・後方・無いラベル)、IF [NOT] EXIST / str==str
# tests/ex3.asm は終了コード3で終わる。x.bat: $? の値(3 / dir成功=0 / 実行できないコマンド=1)。f.bat: IF と GOTO と引数。g.bat: 後方 GOTO のループ、無いラベルは Error! でバッチ終了
cp "$HT"/ex3.asm /tmp/_ht/; (cd /tmp/_ht && "$LSX_Z80ASM" -b -m=z80 ex3.asm >/dev/null)
printf 'xyz\r\n' > /tmp/_ht/c1.txt
printf 'ex3\r\nset A=$?\r\ndir c1.txt > x.txt\r\nset B=$?\r\nnosuch\r\nset C=$?\r\nenv\r\n' > /tmp/_ht/x.bat
printf 'set N=-\r\nif $1==abc set N=${1}_yes\r\nif not $1==abc set N=${1}_no\r\nif exist c1.txt set E=1\r\nif not exist nofile.zzz set F=2\r\nif exist nofile.zzz set W=bad\r\nif $1==abc goto L1\r\nset S=skipped\r\n:L1\r\nset T=done\r\nset X=$1$2\r\nenv\r\n' > /tmp/_ht/f.bat
printf 'set CNT=a\r\n:TOP\r\nif $CNT==aaa goto END\r\nset CNT=${CNT}a\r\ngoto TOP\r\n:END\r\nset R=$CNT\r\nenv\r\ngoto NOPE\r\nset Z=1\r\nenv\r\n' > /tmp/_ht/g.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ht/r.d88
  for p in "ex3.bin EX3.COM" "c1.txt C1.TXT" "x.bat X.BAT" "f.bat F.BAT" "g.bat G.BAT"; do set -- $p; python3 "$HERE/d88_put.py" /tmp/_ht/r.d88 /tmp/_ht/$1 $2 >/dev/null; done
  scr() { sed 's/ *$//' | grep -v '^screen:$' | sed -n "/^screen: A>$1/,\$p" | tr '\n' '|'; }
  o=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/r.d88 --frames 2600 --type 'x\r:700' --screen-report 2>&1 | grep '^screen:' | scr x)
  [ "$o" = 'screen: A>x|screen: Error!|screen: A=3|screen: B=0|screen: C=1|screen: A>|' ] && r1=1 || { r1=0; echo "$o"; }
  o=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/r.d88 --frames 4200 --type 'f abc q\r:700' --type 'f zzz\r:2000' --screen-report 2>&1 | grep '^screen:' | scr 'f abc')
  [ "$o" = 'screen: A>f abc q|screen: 1=abc|screen: 2=q|screen: N=abc_yes|screen: E=1|screen: F=2|screen: T=done|screen: X=abcq|screen: A>f zzz|screen: 1=zzz|screen: N=zzz_no|screen: E=1|screen: F=2|screen: S=skipped|screen: T=done|screen: X=zzz|screen: A>|' ] && r2=1 || { r2=0; echo "$o"; }
  o=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ht/r.d88 --frames 3800 --type 'g\r:700' --screen-report 2>&1 | grep '^screen:' | scr g)
  [ "$o" = 'screen: A>g|screen: CNT=aaa|screen: R=aaa|screen: Error!|screen: A>|' ] && r3=1 || { r3=0; echo "$o"; }
  if [ $r1 = 1 ]; then echo "PASS $(basename $f) 終了コード (_TERM 62h / \$?)"; else echo "FAIL $(basename $f) 終了コード"; rc=1; fi
  if [ $r2 = 1 ]; then echo "PASS $(basename $f) バッチ引数・IF・前方GOTO"; else echo "FAIL $(basename $f) バッチ引数・IF"; rc=1; fi
  if [ $r3 = 1 ]; then echo "PASS $(basename $f) 後方GOTO(ループ)・無いラベル"; else echo "FAIL $(basename $f) GOTO"; rc=1; fi
done
# 行編集 (src/M25EDT.ASM): TAB補完(ファイル名・コマンド名、候補が複数なら一覧)、履歴(↑↓、入力済みの文字で始まるものだけ)、^F(部分一致検索)
# キー(--key-pulse 行,ビット): TAB=3,0 ↑=3,3 ↓=3,4 CTRL=11,4 F=4,6。最後の行(プロンプト)の内容を見る
for f in "$D"/LSX2500_*.d88; do
  last() { grep '^screen:' | sed 's/ *$//' | grep -v '^screen:$' | tail -n "${1:-1}" | tr '\n' '|'; }
  ed() { "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames "$@" --screen-report 2>&1; }
  e1=$(ed 900 --type 'type ld2:600' --key-pulse 3,0:700:4 --type 'x:760' | last)
  e2=$(ed 800 --type 'd:600' --key-pulse 3,0:660:4 | last 2)
  e3=$(ed 1300 --type 'rem a1\r:600' --type 'rem b2\r:760' --type 're:900' --key-pulse 3,3:940:4 --key-pulse 3,3:980:4 --key-pulse 3,4:1020:4 | last)
  e4=$(ed 1300 --type 'rem a1\r:600' --type 'rem b2\r:760' --type 'a1:900' --key-pulse 11,4:940:30 --key-pulse 4,6:950:6 | last)
  # 履歴は12件より深くさかのぼれる(オーバーレイ化前は7件まで): 12回↑で最初の h01 に戻る
  h=(); t=600; for i in 01 02 03 04 05 06 07 08 09 10 11 12; do h+=(--type "rem h$i"'\r'":$t"); t=$((t+100)); done
  u=2000; for i in 1 2 3 4 5 6 7 8 9 10 11 12; do h+=(--key-pulse 3,3:$u:4); u=$((u+30)); done
  e5=$(ed 2500 "${h[@]}" --type 'rem:1900' | last)
  if [ "$e1" = 'screen: A>type ld2500.bin x|' ] && [ "$e2" = 'screen: d  dir  del|screen: A>d|' ] && [ "$e3" = 'screen: A>rem b2|' ] && [ "$e4" = 'screen: A>rem a1|' ] && [ "$e5" = 'screen: A>rem h01|' ]; then
    echo "PASS $(basename $f) 行編集 (TAB補完・一覧・履歴・^F・履歴12件)"
  else echo "FAIL $(basename $f) 行編集"; echo "$e1"; echo "$e2"; echo "$e3"; echo "$e4"; echo "$e5"; rc=1; fi
done
# 画面幅の実行時切替 (src/M25MODE.ASM): MODE 40 / MODE 80。CRTC(レジスタ7,8)と画面の桁数が切り替わり、dir とスクロール(80桁はハード、40桁はコピー)が動くこと
for f in "$D"/LSX2500_*.d88; do
  w() { grep '^screen:' | head -1 | sed 's/^screen: //' | awk '{print length($0)}'; }
  r7() { grep '^crtc:' | sed 's/.*\$07=\([0-9a-f]*\) \$08=\([0-9a-f]*\).*/\1:\2/'; }
  run() { "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-b /tmp/_lb.d88 --frames "$@" --screen-report --crtc-report 2>&1; }
  o1=$(run 1400 --type 'mode 40\r:500' --type 'dir ld.com\r:800'); o2=$(run 1900 --type 'mode 40\r:500' --type 'mode 80\r:800' --type 'dir ld.com\r:1100')
  ok=1
  [ "$(echo "$o1" | w)" = 40 ] && [ "$(echo "$o1" | r7)" = 08:58 ] && echo "$o1" | grep -q "A:LD.COM" || { ok=0; echo "40: $(echo "$o1" | w) $(echo "$o1" | r7)"; }
  [ "$(echo "$o2" | w)" = 80 ] && [ "$(echo "$o2" | r7)" = 09:59 ] && echo "$o2" | grep -q "A:LD.COM" || { ok=0; echo "80: $(echo "$o2" | w) $(echo "$o2" | r7)"; }
  if [ $ok = 1 ]; then echo "PASS $(basename $f) MODE 40 / MODE 80 で桁数とCRTCが切り替わる"; else echo "FAIL $(basename $f) MODE 40/80"; rc=1; fi
  # 切り替え後に200行を type (40桁=コピー方式、80桁=ハード方式)
  o3=$(run 3600 --type 'mode 40\r:500' --type 'type b:long.txt\r:800'); o4=$(run 2600 --type 'mode 40\r:500' --type 'mode 80\r:800' --type 'type b:long.txt\r:1100')
  if echo "$o3" | grep -q "LINE 200" && echo "$o3" | grep '^screen:' | sed 's/ *$//' | grep -v '^screen:$' | tail -1 | grep -q "A>" \
     && echo "$o4" | grep -q "LINE 200" && echo "$o4" | grep '^screen:' | sed 's/ *$//' | grep -v '^screen:$' | tail -1 | grep -q "A>"; then
    echo "PASS $(basename $f) MODE切替後の200行type (40桁/80桁)"
  else echo "FAIL $(basename $f) MODE切替後のスクロール"; echo "$o3" | grep '^screen:' | tail -3; echo "$o4" | grep '^screen:' | tail -3; rc=1; fi
done
# sh.COM / echo.COM (coms/sh.asm, coms/echo.asm): zsh/bash のサブセットを BAT に変換する。生成BATが期待どおり(golden)で、実際に走らせた出力も正しいこと。
# 同名(入力=出力)なら中止、非対応構文(&&と||の混在)は rem [sh] 行+警告になること
mkdir -p /tmp/_sh
printf 'x=1\r\n[ -f c1.txt ] && [ -d d ] || echo hi\r\n' > /tmp/_sh/u.sh
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_sh/r.d88
  python3 "$HERE/d88_put.py" /tmp/_sh/r.d88 "$HERE/../tests/sh/t2.sh" T.SH >/dev/null
  python3 "$HERE/d88_put.py" /tmp/_sh/r.d88 "$HERE/../tests/sh/c1.txt" C1.TXT >/dev/null
  python3 "$HERE/d88_put.py" /tmp/_sh/r.d88 /tmp/_sh/u.sh U.SH >/dev/null
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_sh/r.d88 --disk-save 0:/tmp/_sh/o.d88 --frames 5000 \
    --type 'sh t.sh\r:700' --type 't\r:1500' --type 'sh u.sh\r:2800' --type 'sh t.bat\r:3400' --screen-report 2>&1 | grep '^screen:' | sed 's/ *$//' | grep -v '^screen:$')
  python3 "$HERE/d88_cat.py" /tmp/_sh/o.d88 T.BAT | cmp -s - "$HERE/../tests/sh/t2.golden.bat" && g=1 || g=0
  u=$(python3 "$HERE/d88_cat.py" /tmp/_sh/o.d88 U.BAT | tr -d '\r' | tr '\n' '|')
  if [ $g = 1 ] && echo "$out" | grep -q "screen: hello world" && echo "$out" | grep -q "screen: item b" && echo "$out" | grep -q "screen: empty" \
     && echo "$out" | grep -q "line 2: unsupported" && echo "$out" | grep -q "same file" \
     && [ "$u" = 'set x=1|rem [sh] [ -f c1.txt ] && [ -d d ] || echo hi|:QIT|' ]; then
    echo "PASS $(basename $f) sh.COM (golden BAT、実行結果、非対応構文、同名ガード)"
  else echo "FAIL $(basename $f) sh.COM (golden=$g u=$u)"; echo "$out" | tail -12; rc=1; fi
done
# パイプ (src/M25PIPE.ASM): a | b、3段、最後の段の > 、cat | more。F: の一時ファイルが消えること(F: の空きが元に戻る)
mkdir -p /tmp/_pp
printf 'alpha\r\nbeta\r\ngamma\r\nalpine\r\n' > /tmp/_pp/p.txt
printf 'cat p.txt | grep al\r\ncat p.txt | grep al | grep -n a > po.txt\r\ncat p.txt | more\r\ndir f:\r\n' > /tmp/_pp/pp.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_pp/q.d88
  python3 "$HERE/d88_put.py" /tmp/_pp/q.d88 /tmp/_pp/p.txt P.TXT >/dev/null
  python3 "$HERE/d88_put.py" /tmp/_pp/q.d88 /tmp/_pp/pp.bat PP.BAT >/dev/null
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_pp/q.d88 --disk-save 0:/tmp/_pp/qo.d88 --frames 3500 --type 'pp\r:700' --screen-report 2>&1 | grep '^screen:' | sed 's/ *$//' | grep -v '^screen:$')
  po=$(python3 "$HERE/d88_cat.py" /tmp/_pp/qo.d88 PO.TXT | tr -d '\r' | tr '\n' '|')
  if [ "$(echo "$out" | grep -c 'screen: alpine')" = 2 ] && echo "$out" | grep -q 'screen: gamma' && [ "$po" = '1:alpha|2:alpine|' ] && echo "$out" | grep -q '125952 free F:' ; then
    echo "PASS $(basename $f) パイプ (2段、3段+>、more、一時ファイル削除)"
  else echo "FAIL $(basename $f) パイプ (po=$po)"; echo "$out" | tail -12; rc=1; fi
done
# PROMPT 環境変数 (src/M25CWD.ASM): 定義時はプロンプトが A:\DIR> になり、cd / cd .. / cd \ / ドライブ付きに追従する。未定義なら従来の A>
printf 'set PROMPT=1\r\n' > /tmp/_sh/pr.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_sh/pr.d88; python3 "$HERE/d88_put.py" /tmp/_sh/pr.d88 /tmp/_sh/pr.bat PR.BAT >/dev/null
  p1=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_sh/pr.d88 --frames 3200 --type 'pr\r:700' --type 'mkdir sub\r:1100' --type 'cd sub\r:1300' --type 'mkdir in\r:1500' --type 'cd in\r:1700' --type 'cd ..\r:1900' --type 'cd in\r:2100' --type 'cd \\\r:2300' --type 'cd sub\r:2500' --type 'cd ..\r:2700' --screen-report 2>&1 | grep '^screen: A' | sed 's/ *$//' | sed 's/^screen: //' | sed 's/>.*//' | tr '\n' ' ')
  p2=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 1800 --type 'mkdir sub\r:900' --type 'cd sub\r:1300' --screen-report 2>&1 | grep '^screen: A' | sed 's/ *$//' | sed 's/^screen: //' | sed 's/>.*//' | tr '\n' ' ')
  if [ "$p1" = 'A A:\ A:\ A:\SUB A:\SUB A:\SUB\IN A:\SUB A:\SUB\IN A:\ A:\SUB A:\ ' ] && [ "$p2" = 'A A A ' ]; then
    echo "PASS $(basename $f) PROMPT (cd追従、未定義は A>)"
  else echo "FAIL $(basename $f) PROMPT p1=[$p1] p2=[$p2]"; rc=1; fi
done
# ls.COM (coms/ls.asm): 名前順の桁組み(コンソール)、ファイル出力時は1行1ファイル、-l/-a、ワイルドカード、ディレクトリの中身、一致なし、不正なオプション
mkdir -p /tmp/_ls
printf 'mkdir sub\r\ncopy type.com sub\\t1.com\r\ncopy type.com sub\\t2.com\r\nls ty* > o1.txt\r\nls sub > o2.txt\r\nls -l sub > o3.txt\r\nls -a sub > o4.txt\r\nls zzz > o5.txt\r\nls -x > o6.txt\r\nls -l ld2500.bin > o8.txt\r\n' > /tmp/_ls/l.bat
for f in "$D"/LSX2500_*.d88; do
  lsz=$(python3 -c "import os,sys; print(os.path.getsize(sys.argv[1]))" "$D/_$(basename "$f" .d88 | sed 's/^LSX2500_//')/LD2500.BIN")
  cp "$f" /tmp/_ls/i.d88; python3 "$HERE/d88_put.py" /tmp/_ls/i.d88 /tmp/_ls/l.bat L.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ls/i.d88 --disk-save 0:/tmp/_ls/o.d88 --frames 3000 --type 'l\r:700' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_ls/o.d88 "$1" | tr -d '\r' | tr '\n' '|'; }
  o8=$(g O8.TXT | sed 's/  */ /g')
  scr=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ls/i.d88 --frames 1300 --type 'ls\r:700' --screen-report 2>&1 | grep '^screen:' | sed 's/ *$//')
  if [ "$(g O1.TXT)" = 'TYPE.COM|' ] && [ "$(g O2.TXT)" = 'T1.COM|T2.COM|' ] && [ "$(g O3.TXT | sed 's/  */ /g')" = '---- 105 1996-08-00 00:00 T1.COM|---- 105 1996-08-00 00:00 T2.COM|' ] \
     && [ "$(g O4.TXT)" = '.\|..\|T1.COM|T2.COM|' ] && [ "$(g O5.TXT)" = 'ls: no match|' ] && [ "$(g O6.TXT)" = 'usage: ls [-l1am] [path]|' ] \
     && [ "$o8" = "---- $lsz 1996-08-00 00:00 LD2500.BIN|" ] && echo "$scr" | grep -qE '^screen: [A-Z0-9]+\.COM +[A-Z0-9]+\.'; then
    echo "PASS $(basename $f) ls (桁組み、-l、-a、ワイルドカード、ディレクトリ、一致なし、usage)"
  else echo "FAIL $(basename $f) ls"; for n in O1 O2 O3 O4 O5 O6; do echo "$n: $(g $n.TXT)"; done; echo "o8=$o8"; echo "$scr" | head -8; rc=1; fi
done
# 外部コマンド群 (coms/: wc head tail tee sort uniq hd touch) と、コンソール入力(cat con > file を Ctrl-Z で終える)
mkdir -p /tmp/_uc
python3 - <<'PY'
open('/tmp/_uc/in.txt','wb').write(b''.join(('line%02d\r\n'%i).encode() for i in range(1,13)))
open('/tmp/_uc/fr.txt','wb').write(b'banana\r\napple\r\ncherry\r\napple\r\nbanana\r\nbanana\r\ndate\r\n')
open('/tmp/_uc/b.bat','wb').write(b'head in.txt > h1.txt\r\nhead -n 3 in.txt > h2.txt\r\ntail in.txt > t1.txt\r\ntail -n 2 in.txt > t2.txt\r\nwc in.txt > w1.txt\r\nwc -l fr.txt > w2.txt\r\nsort fr.txt > s1.txt\r\nsort -r -u fr.txt > s2.txt\r\nsort fr.txt | uniq -c > u1.txt\r\ncat fr.txt | uniq > u2.txt\r\nhd fr.txt > x1.txt\r\ncat fr.txt | tee tt.txt > tt2.txt\r\ntouch nn.txt\r\nwc in.txt fr.txt > w3.txt\r\n')
PY
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_uc/i.d88
  for n in in.txt:IN.TXT fr.txt:FR.TXT b.bat:B.BAT; do python3 "$HERE/d88_put.py" /tmp/_uc/i.d88 /tmp/_uc/${n%%:*} ${n##*:} >/dev/null; done
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_uc/i.d88 --disk-save 0:/tmp/_uc/o.d88 --frames 6000 --type 'b\r:800' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_uc/o.d88 "$1" | tr -d '\r' | sed 's/  */ /g' | tr '\n' '|'; }
  ok=1
  [ "$(g H1.TXT)" = 'line01|line02|line03|line04|line05|line06|line07|line08|line09|line10|' ] || ok=0
  [ "$(g H2.TXT)" = 'line01|line02|line03|' ] || ok=0
  [ "$(g T1.TXT)" = 'line03|line04|line05|line06|line07|line08|line09|line10|line11|line12|' ] || ok=0
  [ "$(g T2.TXT)" = 'line11|line12|' ] || ok=0
  [ "$(g W1.TXT)" = ' 12 12 96 in.txt|' ] || ok=0
  [ "$(g W2.TXT)" = ' 7 fr.txt|' ] || ok=0
  [ "$(g S1.TXT)" = 'apple|apple|banana|banana|banana|cherry|date|' ] || ok=0
  [ "$(g S2.TXT)" = 'date|cherry|banana|apple|' ] || ok=0
  [ "$(g U1.TXT)" = ' 2 apple| 3 banana| 1 cherry| 1 date|' ] || ok=0
  [ "$(g U2.TXT)" = 'banana|apple|cherry|apple|banana|date|' ] || ok=0
  [ "$(g X1.TXT)" = '000000 62 61 6e 61 6e 61 0d 0a 61 70 70 6c 65 0d 0a 63 |banana..apple..c||000010 68 65 72 72 79 0d 0a 61 70 70 6c 65 0d 0a 62 61 |herry..apple..ba||000020 6e 61 6e 61 0d 0a 62 61 6e 61 6e 61 0d 0a 64 61 |nana..banana..da||000030 74 65 0d 0a |te..||' ] || ok=0
  [ "$(g TT.TXT)" = 'banana|apple|cherry|apple|banana|banana|date|' ] || ok=0
  [ "$(g TT2.TXT)" = 'banana|apple|cherry|apple|banana|banana|date|' ] || ok=0
  [ "$(g W3.TXT)" = ' 12 12 96 in.txt| 7 7 52 fr.txt| 19 19 148 total|' ] || ok=0
  python3 "$HERE/d88_cat.py" /tmp/_uc/o.d88 NN.TXT >/dev/null 2>&1 || ok=0
  if [ $ok = 1 ]; then echo "PASS $(basename $f) wc/head/tail/tee/sort/uniq/hd/touch"
  else echo "FAIL $(basename $f) wc/head/tail/tee/sort/uniq/hd/touch"; rc=1; fi
  # コンソールから cat > file / cat con > file を Ctrl-Z (CTRL=11,4 + Z=7,2) で終える
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --disk-save 0:/tmp/_uc/c.d88 --frames 2300 --type 'cat > c1.txt\r:800' --type 'hello\r:1000' --type 'world\r:1100' \
    --key-pulse 11,4:1190:16 --key-pulse 7,2:1195:6 --type 'cat con > c2.txt\r:1300' --type 'abc\r:1500' --key-pulse 11,4:1590:16 --key-pulse 7,2:1595:6 --type 'dir c*.txt\r:1800' >/dev/null 2>&1
  c1=$(python3 "$HERE/d88_cat.py" /tmp/_uc/c.d88 C1.TXT | tr -d '\r' | tr '\n' '|'); c2=$(python3 "$HERE/d88_cat.py" /tmp/_uc/c.d88 C2.TXT | tr -d '\r' | tr '\n' '|')
  if [ "$c1" = 'hello|world|' ] && [ "$c2" = 'abc|' ]; then echo "PASS $(basename $f) コンソール入力を Ctrl-Z で終える (cat > file, cat con > file)"
  else echo "FAIL $(basename $f) Ctrl-Z c1=[$c1] c2=[$c2]"; rc=1; fi
done
# 外部コマンド (coms/: cmp diff tr find which mv) と BDOS 6Bh (_GENV: PATH を which が読む)
mkdir -p /tmp/_nc
python3 - <<'PY'
open('/tmp/_nc/a.txt','wb').write(b'alpha\r\nbeta\r\ngamma\r\ndelta\r\n')
open('/tmp/_nc/b.txt','wb').write(b'alpha\r\nBETA\r\ngamma\r\ndelta\r\neps\r\n')
open('/tmp/_nc/c.txt','wb').write(b'alpha\r\nbeta\r\ngamma\r\ndelta\r\n')
open('/tmp/_nc/short.txt','wb').write(b'alpha\r\nbe')
big=b''.join(('row%04d\r\n'%i).encode() for i in range(200))
open('/tmp/_nc/big1.txt','wb').write(big)
open('/tmp/_nc/big2.txt','wb').write(big.replace(b'row0150',b'rowX150'))
bat='''cmp a.txt c.txt > o1.txt
echo $? > e1.txt
cmp a.txt b.txt > o2.txt
echo $? > e2.txt
cmp a.txt short.txt > o3.txt
cmp a.txt nosuch.txt > o4.txt
cmp big1.txt big2.txt > o5.txt
diff a.txt b.txt > o6.txt
diff a.txt c.txt > o7.txt
cat a.txt | tr a-z A-Z > o8.txt
cat a.txt | tr -d a-e > o9.txt
cat a.txt | tr ae XY > o0.txt
mkdir sub
mkdir sub\\deep
copy a.txt sub\\x.txt
copy a.txt sub\\deep\\y.dat
find sub > f1.txt
find sub -name x* > f2.txt
find sub -type d > f3.txt
find sub -name *.dat > f4.txt
find sub -type f > f5.txt
path a:\\bin
cd sub
which cat nosuch dir > a:\\w1.txt
find . > a:\\f6.txt
cd ..
copy big1.txt big1c.txt
touch zero.txt
mv zero.txt sub\\z.txt
mv big1.txt sub\\deep\\
cmp big1c.txt sub\\deep\\big1.txt > m1.txt
mv big1c.txt f:
mv f:big1c.txt big4.txt
cmp big4.txt sub\\deep\\big1.txt > m2.txt
mv c.txt d.txt
mv sub subx
mv nosuch.txt q.txt > m5.txt
mv a.txt b.txt > m6.txt
mv > m7.txt
mv d.txt subx\\ > m8.txt
dir subx > d3.txt
dir subx\\deep > d2.txt
'''
open('/tmp/_nc/t.bat','wb').write(bat.replace('\n','\r\n').encode())
PY
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_nc/i.d88
  for n in a b c short big1 big2; do python3 "$HERE/d88_put.py" /tmp/_nc/i.d88 /tmp/_nc/$n.txt $(echo $n | tr a-z A-Z).TXT >/dev/null; done
  python3 "$HERE/d88_put.py" /tmp/_nc/i.d88 /tmp/_nc/t.bat T.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_nc/i.d88 --disk-save 0:/tmp/_nc/o.d88 --frames 9000 --type 't\r:800' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_nc/o.d88 "$1" 2>/dev/null | tr -d '\r' | sed 's/  */ /g' | tr '\n' '|'; }
  ok=1
  chk() { if [ "$(g $1)" != "$2" ]; then ok=0; echo "  NG $1: [$(g $1)] (期待 [$2])"; fi; }
  chk O1.TXT ''; chk E1.TXT '0 |'; chk O2.TXT 'a.txt b.txt differ: byte 8, line 2|'; chk E2.TXT '1 |'
  chk O3.TXT 'cmp: EOF on short.txt|'; chk O4.TXT 'cmp: cannot open nosuch.txt|'
  chk O5.TXT 'big1.txt big2.txt differ: byte 1354, line 151|'
  chk O6.TXT '< 2: beta|> 2: BETA|> 5: eps|'; chk O7.TXT ''
  chk O8.TXT 'ALPHA|BETA|GAMMA|DELTA|'; chk O9.TXT 'lph|t|gmm|lt|'; chk O0.TXT 'XlphX|bYtX|gXmmX|dYltX|'
  chk F1.TXT 'sub\DEEP\|sub\X.TXT|sub\DEEP\Y.DAT|'; chk F2.TXT 'sub\X.TXT|'; chk F3.TXT 'sub\DEEP\|'
  chk F4.TXT 'sub\DEEP\Y.DAT|'; chk F5.TXT 'sub\X.TXT|sub\DEEP\Y.DAT|'
  chk F6.TXT 'DEEP\|X.TXT|DEEP\Y.DAT|'
  chk W1.TXT 'a:\bin\CAT.COM|which: NOSUCH not found|DIR: built-in command|'
  chk M1.TXT ''; chk M2.TXT ''; chk M5.TXT 'mv: cannot rename|'; chk M6.TXT 'mv: cannot rename|'
  chk M7.TXT 'usage: mv from to|'; chk M8.TXT ''
  d2=$(g D2.TXT | sed 's/ [0-9]* free.*//'); [ "$d2" = ' 27 A:Y.DAT| 1800 A:BIG1.TXT|' ] || { ok=0; echo "  NG D2: [$d2]"; }
  d3=$(g D3.TXT | sed 's/ [0-9]* free.*//'); [ "$d3" = ' <DIR> A:DEEP| 27 A:X.TXT| 0 A:Z.TXT| 27 A:D.TXT|' ] || { ok=0; echo "  NG D3: [$d3]"; }
  if [ $ok = 1 ]; then echo "PASS $(basename $f) cmp/diff/tr/find/which/mv (終了コード、PATH、別ディレクトリ/ドライブへの移動、1800バイトの複数ブロック、ディレクトリ名変更)"
  else echo "FAIL $(basename $f) cmp/diff/tr/find/which/mv"; rc=1; fi
done

# EGREP: 正規表現(| ( ) [ ] + ? * \< \> ^ $)、-i -v -n -c -l -w -o -h -A -B -C、複数ファイル、ワイルドカード、全角(Shift_JIS)、空の繰り返し
mkdir -p /tmp/_eg
python3 - <<'PY'
open('/tmp/_eg/t1.txt','wb').write(b'apple pie\r\nbanana split\r\ncherry tart\r\nApple Jam\r\nthe cat sat\r\nconcat cats\r\nabc123\r\nfoo.bar\r\nfoobar\r\nline 10\r\n')
open('/tmp/_eg/t2.txt','wb').write(b'alpha\r\nbeta apple\r\ngamma\r\ndelta\r\nepsilon\r\nzeta\r\neta apple\r\n')
t=['aaab','abab','ababab x','xyz','日本語テキスト','表の計算','ab]cd','a|b','']
open('/tmp/_eg/t3.txt','wb').write(('\r\n'.join(t)+'\r\n').encode('cp932'))
cm=['egrep ap t1.txt > a1.txt','egrep -i apple t1.txt > a2.txt','egrep "a(p|n)" t1.txt > a3.txt','egrep -n "^[a-c].*t$" t1.txt > a4.txt','egrep -c a+ t1.txt > a5.txt','egrep -w cat t1.txt > a6.txt','egrep -o "[0-9]+" t1.txt > a7.txt','egrep apple t1.txt t2.txt > a8.txt','egrep -l apple t1.txt t2.txt > a9.txt','egrep -A1 -n beta t2.txt > b1.txt','egrep -C1 zeta t2.txt > b2.txt','egrep "foo\\.bar" t1.txt > b3.txt','egrep -v "a" t1.txt > b4.txt','egrep -h apple t*.txt > b5.txt','egrep "ba?n" t1.txt > b6.txt','cat t1.txt | egrep -c e > b7.txt',
'egrep "^(ab)+$" t3.txt > c1.txt','egrep -o "(ab)+" t3.txt > c3.txt','egrep "a.*b.*c" t3.txt > c4.txt','egrep "[]x]" t3.txt > c5.txt','egrep 語 t3.txt > c6.txt','egrep 表の t3.txt > c7.txt','egrep -c "^$" t3.txt > c8.txt','egrep "a\\|b" t3.txt > c9.txt','egrep "計.$" t3.txt > d1.txt','egrep "(a*)*b" t3.txt > d3.txt','egrep "(" t3.txt > d7.txt','egrep -B1 -A1 xyz t3.txt > d5.txt']
open('/tmp/_eg/b.bat','wb').write(('\r\n'.join(cm)+'\r\n').encode('cp932'))
PY
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_eg/i.d88
  for n in t1.txt:T1.TXT t2.txt:T2.TXT t3.txt:T3.TXT b.bat:B.BAT; do python3 "$HERE/d88_put.py" /tmp/_eg/i.d88 /tmp/_eg/${n%%:*} ${n##*:} >/dev/null; done
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_eg/i.d88 --disk-save 0:/tmp/_eg/o.d88 --frames 12000 --type 'b\r:800' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_eg/o.d88 "$1" 2>/dev/null | tr -d '\r' | iconv -f cp932 -t utf-8 | tr '\n' '|'; }
  ok=1
  [ "$(g A1.TXT)" = 'apple pie|' ] || ok=0
  [ "$(g A2.TXT)" = 'apple pie|Apple Jam|' ] || ok=0
  [ "$(g A3.TXT)" = 'apple pie|banana split|' ] || ok=0
  [ "$(g A4.TXT)" = '2:banana split|3:cherry tart|' ] || ok=0
  [ "$(g A5.TXT)" = '9|' ] || ok=0
  [ "$(g A6.TXT)" = 'the cat sat|' ] || ok=0
  [ "$(g A7.TXT)" = '123|10|' ] || ok=0
  [ "$(g A8.TXT)" = 't1.txt:apple pie|t2.txt:beta apple|t2.txt:eta apple|' ] || ok=0
  [ "$(g A9.TXT)" = 't1.txt|t2.txt|' ] || ok=0
  [ "$(g B1.TXT)" = '2:beta apple|3-gamma|' ] || ok=0
  [ "$(g B2.TXT)" = 'epsilon|zeta|eta apple|' ] || ok=0
  [ "$(g B3.TXT)" = 'foo.bar|' ] || ok=0
  [ "$(g B4.TXT)" = 'line 10|' ] || ok=0
  [ "$(g B5.TXT)" = 'apple pie|beta apple|eta apple|' ] || ok=0
  [ "$(g B6.TXT)" = 'banana split|' ] || ok=0
  [ "$(g B7.TXT)" = '5|' ] || ok=0
  [ "$(g C1.TXT)" = 'abab|' ] || ok=0
  [ "$(g C3.TXT)" = 'ab|abab|ababab|ab|' ] || ok=0
  [ "$(g C4.TXT)" = 'ab]cd|' ] || ok=0
  [ "$(g C5.TXT)" = 'ababab x|xyz|ab]cd|' ] || ok=0
  [ "$(g C6.TXT)" = '日本語テキスト|' ] || ok=0
  [ "$(g C7.TXT)" = '表の計算|' ] || ok=0
  [ "$(g C8.TXT)" = '1|' ] || ok=0
  [ "$(g C9.TXT)" = 'a|b|' ] || ok=0
  [ "$(g D1.TXT)" = '表の計算|' ] || ok=0
  [ "$(g D3.TXT)" = 'aaab|abab|ababab x|ab]cd|a|b|' ] || ok=0
  [ "$(g D7.TXT)" = 'egrep: bad pattern|' ] || ok=0
  [ "$(g D5.TXT)" = 'ababab x|xyz|日本語テキスト|' ] || ok=0
  if [ $ok = 1 ]; then echo "PASS $(basename $f) egrep (正規表現、-ivnclwohABC、複数ファイル、ワイルドカード、全角、空の繰り返し)"
  else echo "FAIL $(basename $f) egrep"; rc=1; fi
done

# 簡易マニュアル: man 名前 > ファイル (\MAN\名前.TXT を Shift_JIS のまま出す)、名前なし=INDEX、無い名前、大文字小文字
mkdir -p /tmp/_mn
printf 'man grep > m1.txt\r\nman nosuch > m2.txt\r\nman > m3.txt\r\nman WC > m4.txt\r\n' > /tmp/_mn/b.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_mn/i.d88
  python3 "$HERE/d88_put.py" /tmp/_mn/i.d88 /tmp/_mn/b.bat B.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_mn/i.d88 --disk-save 0:/tmp/_mn/o.d88 --frames 5000 --type 'b\r:800' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_mn/o.d88 "$1" | tr -d '\r' | iconv -f cp932 -t utf-8 | head -${2:-1}; }
  ok=1
  [ "$(g M1.TXT)" = 'GREP  行の検索' ] || ok=0
  [ "$(g M2.TXT)" = 'man: no manual entry for NOSUCH' ] || ok=0
  [ "$(g M3.TXT)" = 'LSX-Dodgers MZ-2500 簡易マニュアル     使い方: man 名前   (例: man grep)' ] || ok=0
  [ "$(g M4.TXT)" = 'WC  行数・語数・バイト数' ] || ok=0
  if [ $ok = 1 ]; then echo "PASS $(basename $f) man (名前指定、INDEX、無い名前、大文字)"
  else echo "FAIL $(basename $f) man"; rc=1; fi
done

# 日付(RTC): date コマンド、ファイルの日時、ls -l の日付列、PATH への $PATH 展開
mkdir -p /tmp/_dt
python3 - <<'PY'
bat='''date 2026-11-07 12:34:10
date > d1.txt
touch tt.txt
date 2031-12-31 23:59:00
mkdir dd
copy tt.txt dd\\x.txt
ls -l tt.txt > l1.txt
ls -l dd > l2.txt
date x > d5.txt
date 2026-11-07 > d6.txt
date 11:22:33 > d7.txt
date > d8.txt
path a:\\;b:\\
path a:\\x;$PATH
path > p1.txt
'''
open('/tmp/_dt/t.bat','wb').write(bat.replace('\n','\r\n').encode())
PY
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_dt/i.d88
  python3 "$HERE/d88_put.py" /tmp/_dt/i.d88 /tmp/_dt/t.bat T.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_dt/i.d88 --disk-save 0:/tmp/_dt/o.d88 --frames 4000 --type 't\r:800' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_dt/o.d88 "$1" 2>/dev/null | tr -d '\r' | sed 's/  */ /g' | tr '\n' '|'; }
  ok=1
  chk() { if [ "$(g $1)" != "$2" ]; then ok=0; echo "  NG $1: [$(g $1)] (期待 [$2])"; fi; }
  d1=$(g D1.TXT | cut -c1-16); [ "$d1" = '2026-11-07 12:34' ] || { ok=0; echo "  NG D1: [$d1]"; }
  chk L1.TXT '---- 0 2026-11-07 12:34 TT.TXT|'; chk L2.TXT '---- 0 2031-12-31 23:59 X.TXT|'
  chk D5.TXT 'usage: date [YYYY-MM-DD] [HH:MM[:SS]]|'
  d6=$(g D6.TXT | cut -c1-16); [ "$d6" = '2026-11-07 23:59' ] || { ok=0; echo "  NG D6: [$d6]"; }
  d7=$(g D7.TXT | cut -c1-16); [ "$d7" = '2026-11-07 11:22' ] || { ok=0; echo "  NG D7: [$d7]"; }
  d8=$(g D8.TXT | cut -c1-16); [ "$d8" = '2026-11-07 11:22' ] || { ok=0; echo "  NG D8: [$d8]"; }
  chk P1.TXT 'a:\x;a:\;b:\|'
  if [ $ok = 1 ]; then echo "PASS $(basename $f) date(RTC読み出し/設定、ファイル日時、ls -l の日付、\$PATH展開)"
  else echo "FAIL $(basename $f) date"; rc=1; fi
done

# cp / du / df (cp -r は mkdir 相当を内部で行う)
mkdir -p /tmp/_cp
python3 - <<'PY'
big=b''.join(('row%04d\r\n'%i).encode() for i in range(200))
open('/tmp/_cp/a.txt','wb').write(b'alpha\r\nbeta\r\n')
open('/tmp/_cp/big.txt','wb').write(big)
bat='''mkdir srcd
mkdir srcd\\sub
mkdir srcd\\sub\\deep
copy a.txt srcd\\a1.txt
copy big.txt srcd\\big.txt
copy a.txt srcd\\sub\\b.dat
copy big.txt srcd\\sub\\deep\\c.txt
cp -r srcd dst1 > r1.txt
cp -r srcd dst1 > r2.txt
cp srcd > r3.txt
cp srcd dst9 > r3b.txt
cp a.txt nosuch\\x.txt > r4.txt
cp a.txt a.txt > r5.txt
cp a.txt copy1.txt > r6.txt
cp big.txt copy1.txt > r7.txt
mkdir sub2
cp *.txt sub2 > r8.txt
cp a.txt sub2\\ > r9.txt
cp -r srcd f:\\ > r10.txt
cp -r srcd b:\\new > r11.txt
cp -r nosuch q > r12.txt
cp a.txt b:q
du srcd > u1.txt
du -s dst1 > u2.txt
du -k srcd > u3.txt
df a: f: > df1.txt
find dst1 > fd1.txt
find f: > fd2.txt
find b: > fd3.txt
dir sub2 > dr1.txt
cmp big.txt dst1\\big.txt > c1.txt
cmp big.txt dst1\\sub\\deep\\c.txt > c2.txt
cmp big.txt dst1\\srcd\\sub\\deep\\c.txt > c3.txt
cmp big.txt f:srcd\\sub\\deep\\c.txt > c4.txt
cmp copy1.txt big.txt > c5.txt
cmp big.txt b:new\\sub\\deep\\c.txt > c6.txt
'''
open('/tmp/_cp/t.bat','wb').write(bat.replace('\n','\r\n').encode())
PY
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_cp/i.d88
  python3 "$HERE/make_blank_disk.py" /tmp/_cp/b.d88 2dd >/dev/null
  for n in a big; do python3 "$HERE/d88_put.py" /tmp/_cp/i.d88 /tmp/_cp/$n.txt $(echo $n | tr a-z A-Z).TXT >/dev/null; done
  python3 "$HERE/d88_put.py" /tmp/_cp/i.d88 /tmp/_cp/t.bat T.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_cp/i.d88 --disk-b /tmp/_cp/b.d88 --disk-save 0:/tmp/_cp/o.d88 --frames 20000 --type 't\r:800' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_cp/o.d88 "$1" 2>/dev/null | tr -d '\r' | sed 's/  */ /g' | tr '\n' '|'; }
  ok=1
  chk() { if [ "$(g $1)" != "$2" ]; then ok=0; echo "  NG $1: [$(g $1)] (期待 [$2])"; fi; }
  chk R1.TXT ''; chk R2.TXT ''; chk R3.TXT 'usage: cp [-r] from to|'; chk R3B.TXT 'cp: source is a directory (use -r)|'
  chk R4.TXT 'cp: nosuch\x.txt: no such directory|'; chk R5.TXT 'cp: a.txt: same file|'; chk R6.TXT ''; chk R7.TXT ''
  chk R8.TXT ''; chk R9.TXT ''; chk R10.TXT ''; chk R11.TXT ''; chk R12.TXT 'cp: source not found|'
  chk U1.TXT ' 1800 srcd\SUB\DEEP\| 1813 srcd\SUB\| 3626 srcd\|'; chk U2.TXT ' 7252 dst1\|'
  chk U3.TXT ' 2 srcd\SUB\DEEP\| 2 srcd\SUB\| 4 srcd\|'
  chk FD1.TXT 'dst1\A1.TXT|dst1\BIG.TXT|dst1\SUB\|dst1\SRCD\|dst1\SUB\B.DAT|dst1\SUB\DEEP\|dst1\SUB\DEEP\C.TXT|dst1\SRCD\A1.TXT|dst1\SRCD\BIG.TXT|dst1\SRCD\SUB\|dst1\SRCD\SUB\B.DAT|dst1\SRCD\SUB\DEEP\|dst1\SRCD\SUB\DEEP\C.TXT|'
  chk FD2.TXT 'f:SRCD\|f:SRCD\A1.TXT|f:SRCD\BIG.TXT|f:SRCD\SUB\|f:SRCD\SUB\B.DAT|f:SRCD\SUB\DEEP\|f:SRCD\SUB\DEEP\C.TXT|'
  chk FD3.TXT 'b:NEW\|b:Q|b:NEW\A1.TXT|b:NEW\BIG.TXT|b:NEW\SUB\|b:NEW\SUB\B.DAT|b:NEW\SUB\DEEP\|b:NEW\SUB\DEEP\C.TXT|'
  for c in C1 C2 C3 C4 C5 C6; do chk $c.TXT ''; done
  # df: 全体 = 使用中 + 空き
  python3 - "$(g DF1.TXT)" <<'PY' || { ok=0; echo "  NG DF1"; }
import sys
L=[l for l in sys.argv[1].split('|') if l.startswith(('A:','F:'))]
assert len(L)==2, L
for l in L:
    _,t,u,fr=l.split(); assert int(t)>0 and int(t)==int(u)+int(fr), l
PY
  # sub2 に *.txt がコピーされている / COPY1.TXT は上書きで 1800 バイト
  s2=$(g DR1.TXT | sed 's/ [0-9]* free.*//'); case "$s2" in *' 13 A:A.TXT|'*' 1800 A:BIG.TXT|'*) ;; *) ok=0; echo "  NG DR1: [$s2]";; esac
  # cp -r が作ったディレクトリの "." と ".." が正しい (. = 自分の先頭クラスタ、.. = 親)
  python3 - /tmp/_cp/o.d88 "$HERE" <<'PY' || { ok=0; echo "  NG . / .."; }
import subprocess, sys, re
img, here = sys.argv[1], sys.argv[2]
def ls(p):
    out = subprocess.run([sys.executable, '-I', here + '/d88_fat.py', img, 'ls', p], capture_output=True, text=True).stdout
    return {l[:11].strip(): int(re.search(r'clus=(\d+)', l).group(1)) for l in out.splitlines()}
root = ls('')
d1 = ls('DST1'); assert d1['.'] == root['DST1'] and d1['..'] == 0, (d1, root)
s = ls('DST1/SUB'); assert s['.'] == d1['SUB'] and s['..'] == root['DST1'], s
dp = ls('DST1/SUB/DEEP'); assert dp['.'] == s['DEEP'] and dp['..'] == d1['SUB'], dp
PY
  if [ $ok = 1 ]; then echo "PASS $(basename $f) cp/du/df (cp -r の再帰、ワイルドカード、F:/B: への複写、上書き、同一ファイル・存在しない先、du の合計、df の収支、. と .. のクラスタ)"
  else echo "FAIL $(basename $f) cp/du/df"; rc=1; fi
done
# AWK: パターン、欄、NR NF、正規表現、sub/gsub/match/split、配列(in/delete/for-in)、if/while/do/for、printf、-F -v -f、ファイル出力、割り算の0
mkdir -p /tmp/_aw
python3 - <<'PY'
open('/tmp/_aw/t1.txt','wb').write(b'apple 10 red\r\nbanana 20 yellow\r\ncherry 5 red\r\ndate 40 brown\r\n')
open('/tmp/_aw/pw.txt','wb').write(b'root:x:0:0:root:/root:/bin/sh\r\nuser:x:1000:100:Some User:/home/user:/bin/ash\r\n\r\nlast:x:5:5\r\n')
open('/tmp/_aw/p1.awk','wb').write(b"""BEGIN { print "start"; total = 0 }
/red/ { n++; print NR ": " $1 " (" NF ")" }
$2 > 15 { big = big $1 "," }
{ total += $2 }
END { print "n=" n, "total=" total, "big=" big; printf("%-8s|%5d|%05d|%x|%c\\n", "ab", 42, 42, 255, 65) }
""")
open('/tmp/_aw/p2.awk','wb').write(b"""BEGIN { OFS = "-" }
NR == 1 { $2 = $2 * 2; print; print NF }
NR == 2 { gsub(/an/, "AN"); print; sub(/y/, "[&]", $0); print $0 }
NR == 3 { x = match($0, /r+/); print x, RSTART, RLENGTH; print index($0, "rr"), toupper($1), length($1) }
NR == 4 { next }
END {
  i = 0; do { i++; if (i == 2) continue; if (i > 4) break; t = t i } while (1)
  print t, (3 > 2 ? "yes" : "no"), ("abc" < "abd"), (10 < 9), ("10" < "9")
  a["x"] = 1; a["y"] = 2; delete a["x"]; n = 0; for (k in a) n++; print n, ("x" in a), ("y" in a)
  print "q" > "o1.txt"; print "r" > "o1.txt"
  v = "A"; w = v++; print v, w, -v, !v, 5 % 3, 2 ** 3, -3, 7 / 2
}
""")
open('/tmp/_aw/p3.awk','wb').write(b"""BEGIN { n = split("3 1 2", a); for (i = 1; i <= n; i++) s = s a[i]; print s, n, v, w + 1 }
NF == 0 { print "blank at", NR; next }
{ print $1, $NF, $(NF-1), NF }
$3 ~ "^[0-9]+$" && $3 + 0 > 0 { c++ }
$1 !~ /^r/ { d = d substr($1, 1, 2) }
END { print c, d, NR, FILENAME }
""")
cm=['awk -f p1.awk t1.txt > r1.txt','awk -f p2.awk t1.txt > r2.txt','awk -F: -v v=7 -v w=2 -f p3.awk pw.txt > r3.txt',
 'awk "{print $$2, $$1}" t1.txt > r4.txt','awk "BEGIN{print 5/0}" > r5.txt','awk "BEGIN{print 1,}" > r6.txt','awk "{ print }" nofile.txt > r7.txt',
 'awk "BEGIN{while((getline)>0) c++; print c}" < t1.txt > r8.txt']
open('/tmp/_aw/b.bat','wb').write(('\r\n'.join(cm)+'\r\n').encode())
PY
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_aw/i.d88
  for n in t1.txt:T1.TXT pw.txt:PW.TXT p1.awk:P1.AWK p2.awk:P2.AWK p3.awk:P3.AWK b.bat:B.BAT; do python3 "$HERE/d88_put.py" /tmp/_aw/i.d88 /tmp/_aw/${n%%:*} ${n##*:} >/dev/null; done
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_aw/i.d88 --disk-save 0:/tmp/_aw/o.d88 --frames 16000 --type 'b\r:800' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_aw/o.d88 "$1" 2>/dev/null | tr -d '\r' | tr '\n' '|'; }
  ok=1
  [ "$(g R1.TXT)" = 'start|1: apple (3)|3: cherry (3)|n=2 total=75 big=banana,date,|ab      |   42|00042|ff|A|' ] || ok=0
  [ "$(g R2.TXT)" = 'apple-20-red|3|bANANa 20 yellow|bANANa 20 [y]ellow|4-4-2|4-CHERRY-6|134-yes-1-0-1|1-0-1|1-0--1-0-2-8--3-3|' ] || ok=0
  [ "$(g O1.TXT)" = 'q|r|' ] || ok=0
  [ "$(g R3.TXT)" = '3 1 2 1 7 3|root /bin/sh /root 7|user /bin/ash /home/user 7|blank at 3|last 5 5 4|2 usla 4 pw.txt|' ] || ok=0
  [ "$(g R4.TXT)" = '10 apple|20 banana|5 cherry|40 date|' ] || ok=0
  [ "$(g R5.TXT)" = 'awk: division by zero|' ] || ok=0
  [ "$(g R6.TXT)" = 'awk: syntax error  near: |' ] || ok=0
  [ "$(g R7.TXT)" = 'awk: cannot open nofile.txt|' ] || ok=0
  [ "$(g R8.TXT)" = '4|' ] || ok=0
  if [ $ok = 1 ]; then echo "PASS $(basename $f) awk (パターン、欄、正規表現、関数、配列、制御構文、printf、-F -v -f、リダイレクト、エラー)"
  else echo "FAIL $(basename $f) awk"; rc=1; fi
done

# SED: s(後方参照・フラグ)、アドレス(行/正規表現/範囲/$/!)、a i c y n N D P、ホールドスペース、ラベル、-f -n -e -E、ワイルドカード、標準入力、エラー
mkdir -p /tmp/_sd
python3 - <<'PY'
open('/tmp/_sd/a.txt','wb').write(b'apple pie\r\nbanana split\r\ncherry tart\r\napple crumble\r\n')
open('/tmp/_sd/b.txt','wb').write(b'x1\r\nx2\r\n')
open('/tmp/_sd/sc.sed','wb').write(b's/apple/APPLE/\r\n/banana/d\r\n$a END\r\n')
cm=['sed s/apple/APPLE/ a.txt > r1.txt','sed -n 2,3p a.txt > r2.txt',
 'sed "s/\\(a[a-z]*\\) \\(p[a-z]*\\)/<\\2:\\1>/" a.txt > r3.txt','sed -E "s/(a|c)(p|h)?/<\\1\\2>/g" a.txt > r4.txt',
 'sed "1!G;h;$$!d" a.txt > r5.txt','sed -e "2a added" -e "3c CHANGED" -e "1i head" a.txt > r6.txt',
 'sed "s/a/X/2;s/P/_/gI" a.txt > r7.txt','sed -f sc.sed a.txt b.txt > r8.txt',
 'sed -n "/apple/,/cherry/p;$$=" a.txt > r9.txt','sed "/cherry/,+1d;y/ae/AE/" a.txt > r10.txt',
 'sed -n "$$=" ?.txt > r11.txt','sed "2q" a.txt > r12.txt','sed "s/a/b" a.txt > r13.txt','sed p nofile.txt > r14.txt',
 'sed s/e/E/g < a.txt > r15.txt','sed "N;s/\\r*\\n/+/" a.txt > r16.txt','sed -n "/apple/{n;p}" a.txt > r17.txt']
open('/tmp/_sd/b.bat','wb').write(('\r\n'.join(cm)+'\r\n').encode())
PY
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_sd/i.d88
  for n in a.txt:A.TXT b.txt:B.TXT sc.sed:SC.SED b.bat:B.BAT; do python3 "$HERE/d88_put.py" /tmp/_sd/i.d88 /tmp/_sd/${n%%:*} ${n##*:} >/dev/null; done
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_sd/i.d88 --disk-save 0:/tmp/_sd/o.d88 --frames 18000 --type 'b\r:800' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_sd/o.d88 "$1" 2>/dev/null | tr -d '\r' | tr '\n' '|'; }
  ok=1
  [ "$(g R1.TXT)" = 'APPLE pie|banana split|cherry tart|APPLE crumble|' ] || ok=0
  [ "$(g R2.TXT)" = 'banana split|cherry tart|' ] || ok=0
  [ "$(g R3.TXT)" = '<pie:apple>|banana split|cherry tart|apple crumble|' ] || ok=0
  [ "$(g R4.TXT)" = '<ap>ple pie|b<a>n<a>n<a> split|<ch>erry t<a>rt|<ap>ple <c>rumble|' ] || ok=0
  [ "$(g R5.TXT)" = 'apple crumble|cherry tart|banana split|apple pie|' ] || ok=0
  [ "$(g R6.TXT)" = 'head|apple pie|banana split|added|CHANGED|apple crumble|' ] || ok=0
  [ "$(g R7.TXT)" = 'a__le _ie|banXna s_lit|cherry tart|a__le crumble|' ] || ok=0
  [ "$(g R8.TXT)" = 'APPLE pie|cherry tart|APPLE crumble|x1|x2|END|' ] || ok=0
  [ "$(g R9.TXT)" = 'apple pie|banana split|cherry tart|apple crumble|4|' ] || ok=0
  [ "$(g R10.TXT)" = 'ApplE piE|bAnAnA split|' ] || ok=0
  [ "$(g R11.TXT)" = '6|' ] || ok=0
  [ "$(g R12.TXT)" = 'apple pie|banana split|' ] || ok=0
  [ "$(g R13.TXT)" = 'sed: unterminated command|' ] || ok=0
  [ "$(g R14.TXT)" = 'sed: cannot open nofile.txt|' ] || ok=0
  [ "$(g R15.TXT)" = 'applE piE|banana split|chErry tart|applE crumblE|' ] || ok=0
  [ "$(g R16.TXT)" = 'apple pie+banana split|cherry tart+apple crumble|' ] || ok=0
  [ "$(g R17.TXT)" = 'banana split|' ] || ok=0
  if [ $ok = 1 ]; then echo "PASS $(basename $f) sed (s と後方参照、アドレスと範囲、a i c y n N D P、ホールド、-f -n -e -E、ワイルドカード、標準入力、エラー)"
  else echo "FAIL $(basename $f) sed"; rc=1; fi
done

# SYSINFO と物理ページの予約(BDOS E0h-E3h): 機能表示、予約→二重予約の失敗→解放、予約したまま終了→次の起動で解放、
#   07h-09h の窓(tests/pgwin.asm)に書いたパターンが dir / mode / color / ファイル出力のあとも残る
mkdir -p /tmp/_pg; cp "$HERE/../tests/pgwin.asm" /tmp/_pg/; (cd /tmp/_pg && "$LSX_Z80ASM" -b -m=z80 pgwin.asm >/dev/null)
printf 'pgwin f > r1.txt\r\ndir > r0.txt\r\nmode 40\r\nmode 80\r\ncolor 2\r\ncolor\r\nsysinfo c > r5.txt\r\nsysinfo > r6.txt\r\nsysinfo t > r2.txt\r\npgwin v > r3.txt\r\n' > /tmp/_pg/b.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_pg/i.d88
  python3 "$HERE/d88_put.py" /tmp/_pg/i.d88 /tmp/_pg/b.bat B.BAT >/dev/null; python3 "$HERE/d88_put.py" /tmp/_pg/i.d88 /tmp/_pg/pgwin.bin PGWIN.COM >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_pg/i.d88 --disk-save 0:/tmp/_pg/o.d88 --frames 9000 --type 'b\r:800' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_pg/o.d88 "$1" 2>/dev/null | tr -d '\r' | tr '\n' '|'; }
  ok=1
  [ "$(g R1.TXT)" = 'FILL-OK|' ] || ok=0
  [ "$(g R3.TXT)" = 'VERIFY-OK|' ] || ok=0
  [ "$(g R5.TXT)" = 'alloc any: 07|' ] || ok=0
  g R6.TXT | grep -q 'PAGEMGR:Y' || ok=0
  g R6.TXT | grep -q 'pages 00-0F / 10-1F: TTTTTTO...TOOOOO RRRRRRRRRRRRRRRR' || ok=0
  [ "$(g R2.TXT)" = 'alloc any: 00 07|owner now: 04|alloc same: F0|free: 00|owner after: 00|free again: F0|alloc TPA page 3: F0|' ] || ok=0
  g R6.TXT | grep -q 'IOCS:Y' || ok=0
  if [ $ok = 1 ]; then echo "PASS $(basename $f) sysinfo と物理ページ(E0h-E3h: 情報、予約/二重予約/解放、起動で自動解放、07h-09hの窓)"
  else echo "FAIL $(basename $f) sysinfo と物理ページ"; rc=1; fi
done

# pglib.inc (pgread/pgwrite): 予約したページへ書いて、BDOSを呼んだ後に読み戻して一致、範囲外はCF=1、割り込み状態が保たれる
mkdir -p /tmp/_pl; cp "$HERE/../coms/pglib.inc" "$HERE/../tests/pgtest.asm" /tmp/_pl/; (cd /tmp/_pl && "$LSX_Z80ASM" -b -m=z80 pgtest.asm >/dev/null)
printf 'pgtest > r1.txt\r\n' > /tmp/_pl/b.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_pl/i.d88
  python3 "$HERE/d88_put.py" /tmp/_pl/i.d88 /tmp/_pl/b.bat B.BAT >/dev/null; python3 "$HERE/d88_put.py" /tmp/_pl/i.d88 /tmp/_pl/pgtest.bin PGTEST.COM >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_pl/i.d88 --disk-save 0:/tmp/_pl/o.d88 --frames 4000 --type 'b\r:800' >/dev/null 2>&1
  if [ "$(python3 "$HERE/d88_cat.py" /tmp/_pl/o.d88 R1.TXT 2>/dev/null | tr -d '\r' | tr '\n' '|')" = 'mid|PGLIB-OK|' ]; then echo "PASS $(basename $f) pglib (pgread/pgwrite: 往復・範囲外・割り込み状態)"
  else echo "FAIL $(basename $f) pglib"; rc=1; fi
done

# バンク4(8000H-9FFFH)を窓にしたまま BDOS(出力/検索/open/read/status)を呼んでも、窓とその中身が保たれる(割り込み許可のまま)
mkdir -p /tmp/_b4; cp "$HERE/../tests/pgbank4.asm" /tmp/_b4/; (cd /tmp/_b4 && "$LSX_Z80ASM" -b -m=z80 pgbank4.asm >/dev/null)
printf 'pgbank4 > r1.txt\r\n' > /tmp/_b4/b.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_b4/i.d88
  python3 "$HERE/d88_put.py" /tmp/_b4/i.d88 /tmp/_b4/b.bat B.BAT >/dev/null; python3 "$HERE/d88_put.py" /tmp/_b4/i.d88 /tmp/_b4/pgbank4.bin PGBANK4.COM >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_b4/i.d88 --disk-save 0:/tmp/_b4/o.d88 --frames 4000 --type 'b\r:800' >/dev/null 2>&1
  if [ "$(python3 "$HERE/d88_cat.py" /tmp/_b4/o.d88 R1.TXT 2>/dev/null | tr -d '\r' | tr '\n' '|')" = 'mid|BANK4-OK|' ]; then echo "PASS $(basename $f) バンク4の窓はBDOS呼び出しをまたいで保たれる"
  else echo "FAIL $(basename $f) バンク4の窓"; rc=1; fi
done

# RAMDISK (F: の縮小・無効化・復元): 大きさの表示、32KB へ縮小して拡張RAMの空きがページ表に出る、F:に書ける、0 で F: 無効、128KB へ戻して書ける、不正な値は使い方表示
mkdir -p /tmp/_rd
printf 'ramdisk > r1.txt\r\nramdisk 32 > r2.txt\r\nsysinfo > r3.txt\r\ncopy b.bat f: > r9.txt\r\ndir f: > r4.txt\r\nramdisk > r5.txt\r\nramdisk 0 > r6.txt\r\nsysinfo > r7.txt\r\nramdisk 128 > ra.txt\r\ncopy b.bat f: > rb.txt\r\ndir f: > rc.txt\r\nramdisk 7 > rd.txt\r\n' > /tmp/_rd/b.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_rd/i.d88
  python3 "$HERE/d88_put.py" /tmp/_rd/i.d88 /tmp/_rd/b.bat B.BAT >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_rd/i.d88 --disk-save 0:/tmp/_rd/o.d88 --frames 9000 --type 'b\r:800' >/dev/null 2>&1
  g() { python3 "$HERE/d88_cat.py" /tmp/_rd/o.d88 "$1" 2>/dev/null | tr -d '\r' | tr '\n' '|'; }
  ok=1
  [ "$(g R1.TXT)" = 'RAMDISK F: 128KB|' ] || ok=0
  g R2.TXT | grep -q '128KB ->  32KB (F: formatted)' || ok=0
  g R3.TXT | grep -q 'RAMDISK 8KB pages: 04' || ok=0
  g R3.TXT | grep -q 'pages 00-0F / 10-1F: TTTTTTO...TOOOOO RRRR............|' || ok=0
  g R4.TXT | grep -q '27136 free F:' || ok=0
  [ "$(g R5.TXT)" = 'RAMDISK F:  32KB|' ] || ok=0
  g R6.TXT | grep -q ' 32KB ->   0KB (F: formatted)' || ok=0
  g R7.TXT | grep -q 'RAMDISK(F:):N' || ok=0
  g R7.TXT | grep -q 'pages 00-0F / 10-1F: TTTTTTO...TOOOOO ................|' || ok=0
  g RA.TXT | grep -q '  0KB -> 128KB (F: formatted)' || ok=0
  g RC.TXT | grep -q '125440 free F:' || ok=0
  g RD.TXT | grep -q '^usage: ramdisk' || ok=0
  if [ $ok = 1 ]; then echo "PASS $(basename $f) ramdisk (F:を32KBへ縮小→空きページが見える→0で無効→128KBへ復元、書き込みできる)"
  else echo "FAIL $(basename $f) ramdisk"; rc=1; fi
done

# ls の色付け: 画面へ出すと COM=緑・ディレクトリ=水色・LD2500.BIN=白 のピクセルが出る。-m では緑/水色が出ない
for f in "$D"/LSX2500_*.d88; do
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 700 --type 'ls\r:500' --screenshot /tmp/_lsc.ppm >/dev/null 2>&1
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a "$f" --frames 700 --type 'ls -m\r:500' --screenshot /tmp/_lsm.ppm >/dev/null 2>&1
  r=$(python3 -c "
from PIL import Image
a=set(c for n,c in Image.open('/tmp/_lsc.ppm').convert('RGB').getcolors(100000))
b=set(c for n,c in Image.open('/tmp/_lsm.ppm').convert('RGB').getcolors(100000))
g=(0,255,0); c=(0,255,255)
print('ok' if (g in a and c in a and g not in b and c not in b) else 'ng')
")

  if [ "$r" = ok ]; then echo "PASS $(basename $f) ls の色付け(既定=色付き、-m=白のみ)"
  else echo "FAIL $(basename $f) ls の色付け"; rc=1; fi
done

# pal.COM (4096色パレットボード): pal soft で文字色が柔らかくなり(緑=144,240,144 / 白=192,192,192)、pal で標準(0,255,0 / 255,255,255)へ戻る。不正な引数は usage
mkdir -p /tmp/_pl; cp "$HERE/../coms/pal.asm" /tmp/_pl/; (cd /tmp/_pl && "$LSX_Z80ASM" -b -m=z80 pal.asm >/dev/null)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_pl/i.d88; python3 "$HERE/d88_put.py" /tmp/_pl/i.d88 /tmp/_pl/pal.bin PAL.COM >/dev/null
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_pl/i.d88 --frames 900 --type 'pal soft\r:450' --type 'ls\r:650' --screenshot /tmp/_pl/a.ppm >/dev/null 2>&1
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_pl/i.d88 --frames 1200 --type 'pal soft\r:450' --type 'pal\r:650' --type 'ls\r:850' --screenshot /tmp/_pl/b.ppm >/dev/null 2>&1
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_pl/i.d88 --frames 1300 --type 'pal soft\r:450' --type 'mode 40\r:650' --type 'mode 80\r:850' --type 'ls\r:1050' --screenshot /tmp/_pl/c.ppm >/dev/null 2>&1
  u=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_pl/i.d88 --frames 700 --type 'pal 99 zzz\r:450' --screen-report 2>&1 | grep -c 'usage: pal')
  r=$(python3 -c "
from PIL import Image
a=set(c for n,c in Image.open('/tmp/_pl/a.ppm').convert('RGB').getcolors(100000))
b=set(c for n,c in Image.open('/tmp/_pl/b.ppm').convert('RGB').getcolors(100000))
c=set(c for n,c in Image.open('/tmp/_pl/c.ppm').convert('RGB').getcolors(100000))
print('ok' if ((144,240,144) in a and (192,192,192) in a and (0,255,0) not in a and (0,255,0) in b and (255,255,255) in b and (144,240,144) not in b and (144,240,144) in c and (0,255,0) not in c) else 'ng')
")
  if [ "$r" = ok ] && [ "$u" = 1 ]; then echo "PASS $(basename $f) pal (soft、標準へ戻す、mode切替後も保つ、usage)"
  else echo "FAIL $(basename $f) pal r=$r u=$u"; rc=1; fi
done

# utf8.COM (UTF-8 → Shift_JIS): ファイル/標準入力/パイプ、-c(LF→CRLF)、半角カナ、全角、表に無い文字・絵文字は ?
mkdir -p /tmp/_u8; cp "$HERE/../coms/utf8.asm" "$HERE/../coms/utf8tab.inc" /tmp/_u8/; (cd /tmp/_u8 && "$LSX_Z80ASM" -b -m=z80 utf8.asm >/dev/null)
python3 - <<'PY'
t='ABC 日本語 ｱｲｳ 漢字ﾃｽﾄ ～ ‥ 　全角 😀 é ¥ ① 髙\nline2 ﾊﾟ 々〆ヶ\n'
open('/tmp/_u8/u.txt','wb').write(t.encode('utf-8'))
def conv(crlf):
    out=bytearray()
    for ch in t:
        if ch=='\n': out+= b'\r\n' if crlf else b'\n'; continue
        if ch=='¥': out.append(0x5c); continue
        if ch=='～': out+=b'\x81\x60'; continue
        try:
            b=ch.encode('shift_jis')
            if len(b)==2 and (b[0] in (0x87,0xED,0xEE) or b[0]>=0xFA): raise ValueError
            out+=b
        except Exception: out+=b'?'
    return bytes(out)
open('/tmp/_u8/e1.bin','wb').write(conv(1)); open('/tmp/_u8/e2.bin','wb').write(conv(0))
PY
printf 'utf8 -c u.txt > o1.txt\r\nutf8 u.txt > o2.txt\r\ncat u.txt | utf8 > o3.txt\r\nutf8 > o4.txt < u.txt\r\n' > /tmp/_u8/b.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_u8/i.d88
  for n in utf8.bin:UTF8.COM u.txt:U.TXT b.bat:B.BAT; do python3 "$HERE/d88_put.py" /tmp/_u8/i.d88 /tmp/_u8/${n%%:*} ${n##*:} >/dev/null; done
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_u8/i.d88 --disk-save 0:/tmp/_u8/o.d88 --frames 2500 --type 'b\r:600' >/dev/null 2>&1
  ok=1
  for pair in O1.TXT:e1.bin O2.TXT:e2.bin O3.TXT:e2.bin O4.TXT:e2.bin; do
    python3 "$HERE/d88_cat.py" /tmp/_u8/o.d88 "${pair%%:*}" > /tmp/_u8/got.bin 2>/dev/null
    cmp -s /tmp/_u8/got.bin /tmp/_u8/${pair##*:} || { ok=0; echo "  ${pair%%:*} 不一致"; }
  done
  if [ $ok = 1 ]; then echo "PASS $(basename $f) utf8 (ファイル/-c/パイプ/リダイレクト、全角・半角カナ・?)"
  else echo "FAIL $(basename $f) utf8"; rc=1; fi
done

# sjis.COM (Shift_JIS → UTF-8): ファイル/パイプ、-l(CR を取る)、半角カナ・全角・2バイトUTF-8(° × ÷ ±)
mkdir -p /tmp/_sj; cp "$HERE/../coms/sjis.asm" "$HERE/../coms/sjistab.inc" /tmp/_sj/; (cd /tmp/_sj && "$LSX_Z80ASM" -b -m=z80 sjis.asm >/dev/null)
python3 - <<'PY'
t='ABC 日本語 ｱｲｳ 漢字ﾃｽﾄ ～ 　全角 ヶ ° × ÷ ± \\path ?\r\nline2 ﾊﾟ 々〆\r\n'
open('/tmp/_sj/s.txt','wb').write(t.encode('cp932'))
open('/tmp/_sj/e1.bin','wb').write(t.encode('utf-8')); open('/tmp/_sj/e2.bin','wb').write(t.replace('\r','').encode('utf-8'))
PY
printf 'sjis s.txt > p1.txt\r\nsjis -l s.txt > p2.txt\r\ncat s.txt | sjis -l > p3.txt\r\n' > /tmp/_sj/b.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_sj/i.d88
  for n in sjis.bin:SJIS.COM s.txt:S.TXT b.bat:B.BAT; do python3 "$HERE/d88_put.py" /tmp/_sj/i.d88 /tmp/_sj/${n%%:*} ${n##*:} >/dev/null; done
  "$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_sj/i.d88 --disk-save 0:/tmp/_sj/o.d88 --frames 3000 --type 'b\r:600' >/dev/null 2>&1
  ok=1
  for pair in P1.TXT:e1.bin P2.TXT:e2.bin P3.TXT:e2.bin; do
    python3 "$HERE/d88_cat.py" /tmp/_sj/o.d88 "${pair%%:*}" > /tmp/_sj/got.bin 2>/dev/null
    cmp -s /tmp/_sj/got.bin /tmp/_sj/${pair##*:} || { ok=0; echo "  ${pair%%:*} 不一致"; }
  done
  if [ $ok = 1 ]; then echo "PASS $(basename $f) sjis (ファイル/-l/パイプ、全角・半角カナ・2バイト)"
  else echo "FAIL $(basename $f) sjis"; rc=1; fi
done

# ゲーム: 起動してキー入力を受け、終了できる (hitblow は降参で答えを出す)
mkdir -p /tmp/_gm
printf 'hitblow\r\n' > /tmp/_gm/b.bat
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_gm/i.d88
  python3 "$HERE/d88_put.py" /tmp/_gm/i.d88 /tmp/_gm/b.bat B.BAT >/dev/null
  r=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_gm/i.d88 --frames 5000 --type 'b\r:800' --type '0123\r:1700' --type 'q\r:2100' --type 'n:2600' --screen-report 2>&1 | grep -a '^screen:' | tr -d '\n')
  if echo "$r" | grep -aq '0123' && echo "$r" | grep -aq 'A>'; then echo "PASS $(basename $f) ゲーム (hitblow 起動・入力・降参・終了)"
  else echo "FAIL $(basename $f) ゲーム"; rc=1; fi
done

# ユーザマップ表 UMAP: バンク2・6 を別ページに差し替えて UMAP も書き換えると、BDOS・IOCS(RST 18H)を呼んだあとも差し替え先のまま保たれる(tests/umap.asm)
mkdir -p /tmp/_um; cp "$HERE/../tests/umap.asm" /tmp/_um/; (cd /tmp/_um && "$LSX_Z80ASM" -b -m=z80 umap.asm >/dev/null)
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_um/i.d88; python3 "$HERE/d88_put.py" /tmp/_um/i.d88 /tmp/_um/umap.bin UMAP.COM >/dev/null
  case "$f" in *noiocs*) arg=" n"; need="UMAP-ISOLATED-OK";; *) arg=""; need="UMAP-IOCS-OK";; esac
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_um/i.d88 --frames 900 --type "umap$arg\r:500" --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "UMAP-INIT-OK" && echo "$out" | grep -q "UMAP-BDOS-OK" && echo "$out" | grep -q "$need" && echo "$out" | grep -q "UMAP-DONE" && ! echo "$out" | grep -q "UMAP-NG"; then echo "PASS $(basename $f) UMAP(ユーザマップ表の差し替え)"
  else echo "FAIL $(basename $f) UMAP(ユーザマップ表の差し替え)"; echo "$out" | tail -8; rc=1; fi
done

# E5h EXEC(子を新しいページで起動し、終了したら戻る。tests/exectest.asm + execchild.asm): 親のパターンと予約ページが無傷・子の終了コード・内部コマンド・存在しないコマンド・ページが返る
#   事前に ramdisk 64 で空きページを作る。 execfail: F: が128KBのままなら A=0F0h。 nestp/nestc: 親→子→孫(ramdisk 0 で14枚以上の空きを作る)
mkdir -p /tmp/_ex; for s in execchild exectest execfail nestp nestc execrd hwcheck; do cp "$HERE/../tests/$s.asm" /tmp/_ex/; (cd /tmp/_ex && "$LSX_Z80ASM" -b -m=z80 $s.asm >/dev/null); done
for f in "$D"/LSX2500_*.d88; do
  cp "$f" /tmp/_ex/i.d88
  for p in "execchild CHILD" "exectest EXECT" "execfail EXECF" "nestp NESTP" "nestc NESTC" "execrd EXECRD" "hwcheck HWCHECK"; do set -- $p; python3 "$HERE/d88_put.py" /tmp/_ex/i.d88 /tmp/_ex/$1.bin $2.COM >/dev/null; done
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ex/i.d88 --frames 2600 --type 'execf\r:500' --type 'ramdisk 64\r:700' --type 'cls\r:900' --type 'exect\r:1100' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "EXEC-P1-OK" && echo "$out" | grep -q "EXEC-P2-OK" && echo "$out" | grep -q "EXEC-P3-OK" && echo "$out" | grep -q "EXEC-P4-OK" && echo "$out" | grep -q "EXEC-P5-OK" && echo "$out" | grep -q "EXEC-P6-OK" && echo "$out" | grep -q "EXEC-P7-OK" && echo "$out" | grep -q "EXEC-P8-OK" && echo "$out" | grep -q "EXEC-DONE" && ! echo "$out" | grep -q "EXEC-NG"; then echo "PASS $(basename $f) EXEC(E5h: 子の起動・隔離・終了コード・内部コマンド・失敗・ページ返却)"
  else echo "FAIL $(basename $f) EXEC"; echo "$out" | tail -12; rc=1; fi
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ex/i.d88 --frames 1800 --type 'execf\r:500' --type 'ramdisk 0\r:700' --type 'cls\r:900' --type 'nestp\r:1100' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "EXECFAIL-OK" && echo "$out" | grep -q "NEST-C-OK" && echo "$out" | grep -q "NEST-P-OK"; then echo "PASS $(basename $f) EXEC(ページ不足でA=F0h・親→子→孫の入れ子)"
  else echo "FAIL $(basename $f) EXEC(ページ不足・入れ子)"; echo "$out" | tail -12; rc=1; fi
  # 親が >R.TXT でリダイレクトされていても、E5h の後も親の出力が R.TXT へ行く(子の終了で親のリダイレクトを閉じない)
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ex/i.d88 --frames 2300 --type 'ramdisk 64\r:500' --type 'cls\r:700' --type 'execrd >r.txt\r:900' --type 'type r.txt\r:1700' --screen-report 2>&1 | grep '^screen:')
  if echo "$out" | grep -q "RD-BEFORE" && echo "$out" | grep -q "CHILD-OK" && echo "$out" | grep -q "RD-AFTER" && [ -z "$(echo "$out" | awk '/execrd >r.txt/{f=1;next} /type r.txt/{f=0} f && /RD-AFTER/')" ] && echo "$out" | grep -q "RD-AFTER2"; then echo "PASS $(basename $f) EXEC(親のリダイレクトがE5hのあとも残る)"
  else echo "FAIL $(basename $f) EXEC(親のリダイレクト)"; echo "$out" | tail -12; rc=1; fi
  # 実機確認用 HWCHECK.COM(エミュレータでの自己確認: 空きページのパターン一致・空きページからの実行・BDOSをはさんでも残る・E5hで親が無傷)
  out=$("$LSX_CLI" --real-ipl --rom-dir "$LSX_ROMDIR" --disk-a /tmp/_ex/i.d88 --frames 2300 --type 'ramdisk 64\r:500' --type 'cls\r:700' --type 'hwcheck\r:900' --screen-report 2>&1 | grep '^screen:')
  oj=$(echo "$out" | sed 's/^screen: //; s/ *$//' | tr -d '\n')   # 40桁は行が折り返されるので連結してから見る
  if echo "$oj" | grep -qE 'pattern ok=([0-9A-F]+)/\1' && echo "$oj" | grep -qE 'after BDOS calls ok=([0-9A-F]+)/\1' && echo "$oj" | grep -q '07=5A 08=5A' && echo "$oj" | grep -q 'E5h result A=00 parent 8000H-9FFFH intact' && echo "$oj" | grep -q 'HW:DONE'; then echo "PASS $(basename $f) HWCHECK(実機確認COMの自己確認)"
  else echo "FAIL $(basename $f) HWCHECK"; echo "$out" | tail -14; rc=1; fi
done

exit $rc
