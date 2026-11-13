#!/usr/bin/env python3
"""標準LSX形式(FAT12, 512B/セクタ, 9セクタ x 2面)のD88をサブディレクトリごと読む。
  d88_fat.py image.d88 ls  [PATH]      ディレクトリの全エントリ(. と .. の先頭クラスタ、日付・時刻も)
  d88_fat.py image.d88 cat PATH        ファイルを標準出力へ
PATH は SUB\\DEEP\\NAME.EXT の形(/ も可)。"""
import struct, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_boot_disk import read_d88
img, cmd = sys.argv[1], sys.argv[2]
path = sys.argv[3] if len(sys.argv) > 3 else ''
s = read_d88(img)
def lsn(L):
    t, r = divmod(L, 9)
    return s.get((t >> 1, t & 1, r + 1), b'\0' * 512)
b0 = lsn(0)
spc, rsv, nfat, rent, fsz = b0[13], b0[14] | b0[15] << 8, b0[16], b0[17] | b0[18] << 8, b0[22] | b0[23] << 8
fat = b''.join(lsn(rsv + i) for i in range(fsz))
root0 = rsv + fsz * nfat; rsec = rent * 32 // 512; data0 = root0 + rsec
def nxt(c):
    o = c * 3 // 2; v = fat[o] | fat[o + 1] << 8
    return (v >> 4) if c & 1 else (v & 0xFFF)
def chain(c, limit=None):
    out = b''
    while 2 <= c < 0xFF0:
        for k in range(spc): out += lsn(data0 + (c - 2) * spc + k)
        c = nxt(c)
        if limit is not None and len(out) >= limit: break
    return out
def entries(dc):
    raw = b''.join(lsn(root0 + i) for i in range(rsec)) if dc == 0 else chain(dc)
    for i in range(0, len(raw), 32):
        e = raw[i:i + 32]
        if e[0] == 0: break
        if e[0] == 0xE5: continue
        yield e
def key(n):
    a, _, b = n.upper().partition('.')
    return a.ljust(8).encode() + b.ljust(3).encode()
def find(path):
    dc, ent = 0, None
    for part in [p for p in path.replace('/', '\\').split('\\') if p]:
        ent = None
        for e in entries(dc):
            if e[:11] == key(part): ent = e; break
        if ent is None: sys.stderr.write('not found: %s\n' % part); sys.exit(1)
        dc = ent[26] | ent[27] << 8
    return dc, ent
def fmt(e):
    d, t = struct.unpack('<HH', e[24:26] + e[22:24])
    return '%-11s attr=%02X clus=%d size=%d %04d-%02d-%02d %02d:%02d:%02d' % (
        e[:11].decode('latin1'), e[11], e[26] | e[27] << 8, struct.unpack('<I', e[28:32])[0],
        1980 + (d >> 9), (d >> 5) & 15, d & 31, t >> 11, (t >> 5) & 63, (t & 31) * 2)
if cmd == 'ls':
    dc, _ = find(path)
    for e in entries(dc): print(fmt(e))
else:
    dc, ent = find(path)
    size = struct.unpack('<I', ent[28:32])[0]
    sys.stdout.buffer.write(chain(ent[26] | ent[27] << 8, size)[:size])
