#!/usr/bin/env python3
# UTF-8 -> Shift_JIS 変換表 coms/utf8tab.inc を作る。Unicode 昇順の (uni(LE 2B), sjis(hi,lo)) の並び。
# 対象: 区点の第1/第2水準・記号・英数・かな(Shift_JIS 先頭 81-84,88-9F,E0-EA)。NEC/IBM拡張は含めない(MZ-2500の漢字ROMにあるか不明)。
import sys
m = {}
for lead in list(range(0x81, 0x85)) + list(range(0x88, 0xA0)) + list(range(0xE0, 0xEB)):
    for trail in range(0x40, 0xFD):
        if trail == 0x7F: continue
        if lead == 0xEA and trail > 0xA4: continue
        code = bytes([lead, trail])
        for codec in ('shift_jis', 'cp932'):
            try:
                u = code.decode(codec)
            except UnicodeDecodeError:
                continue
            if len(u) == 1:
                k = ord(u)
                if k not in m or (lead << 8 | trail) < m[k]:
                    m[k] = lead << 8 | trail
# 互換: 波ダッシュ/全角チルダ、ハイフン類
for k, v in ((0xFF5E, 0x8160), (0x301C, 0x8160), (0xFF0D, 0x817C), (0x2212, 0x817C), (0x2225, 0x8161), (0x2016, 0x8161), (0xFFE0, 0x8191), (0xFFE1, 0x8192), (0xFFE2, 0x81CA)):
    m.setdefault(k, v)
m[0x00A5] = 0x005C   # ¥ は LSX の表示で 5Ch(¥)
m[0x203E] = 0x007E   # ‾
items = sorted(m.items())
out = ['; 自動生成 tools/gen_utf8tab.py : Unicode 昇順。1項目4バイト = Unicode(下位,上位) + Shift_JIS(上位,下位)', 'NTAB\tEQU\t%d' % len(items), 'tab:']
for i in range(0, len(items), 4):
    out.append('\tdefb ' + ','.join('%d,%d,%d,%d' % (u & 255, u >> 8, s >> 8, s & 255) for u, s in items[i:i+4]))
open(sys.argv[1], 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print(len(items), 'entries')

# ---- 逆引き表 (coms/sjistab.inc): Shift_JIS 昇順。1項目4バイト = Shift_JIS(上位,下位) + Unicode(下位,上位)。cp932 の対応(～ は U+FF5E)
if len(sys.argv) > 2:
    r = []
    for lead in list(range(0x81, 0x85)) + list(range(0x88, 0xA0)) + list(range(0xE0, 0xEB)):
        for trail in range(0x40, 0xFD):
            if trail == 0x7F: continue
            if lead == 0xEA and trail > 0xA4: continue
            try:
                u = bytes([lead, trail]).decode('cp932')
            except UnicodeDecodeError:
                continue
            if len(u) == 1:
                r.append((lead << 8 | trail, ord(u)))
    out = ['; 自動生成 tools/gen_utf8tab.py : Shift_JIS 昇順。1項目4バイト = Shift_JIS(上位,下位) + Unicode(下位,上位)', 'NSTAB\tEQU\t%d' % len(r), 'stab:']
    for i in range(0, len(r), 4):
        out.append('\tdefb ' + ','.join('%d,%d,%d,%d' % (s >> 8, s & 255, u & 255, u >> 8) for s, u in r[i:i+4]))
    open(sys.argv[2], 'w', encoding='utf-8').write('\n'.join(out) + '\n')
    print(len(r), 'reverse entries')
