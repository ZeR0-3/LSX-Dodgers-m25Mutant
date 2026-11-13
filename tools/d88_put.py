#!/usr/bin/env python3
"""標準LSX形式(FAT12, 2FAT)のD88のルートへファイルを書き込む(テスト用)。
  d88_put.py image.d88 ローカルファイル NAME.EXT [name2]
  name2 を付けると、名前の9文字目以降(Human68k/TwentyOne 方式: ディレクトリエントリ+0Ch の10バイト。Shift_JIS)として書く
空きクラスタを先頭から使う。BPB(論理セクタ0)から配置を求める。"""
import struct, sys
img, src, dst = sys.argv[1], sys.argv[2], sys.argv[3].upper().replace("\\", "/")
name2 = sys.argv[4].encode('cp932').ljust(10, b'\0') if len(sys.argv) > 4 else bytes(10)
assert len(name2) == 10, 'name2 は10バイトまで'
buf = bytearray(open(img, 'rb').read()); data = open(src, 'rb').read()
offs = struct.unpack('<164I', buf[0x20:0x20 + 164 * 4]); sec = {}
for o in offs:
    if not o: continue
    ns = struct.unpack('<H', buf[o + 4:o + 6])[0]
    for _ in range(ns):
        c, h, r = buf[o], buf[o + 1], buf[o + 2]; sz = struct.unpack('<H', buf[o + 14:o + 16])[0]
        sec[(c, h, r)] = o + 16; o += 16 + sz
def loc(L):
    t, r = divmod(L, 9); return sec[(t >> 1, t & 1, r + 1)]
def rd(L): return bytes(buf[loc(L):loc(L) + 512])
def wr(L, d): buf[loc(L):loc(L) + 512] = d.ljust(512, b'\0')
b0 = rd(0); spc, rsv, nf, rent, fsz = b0[13], b0[14] | b0[15] << 8, b0[16], b0[17] | b0[18] << 8, b0[22] | b0[23] << 8
root0 = rsv + fsz * nf; data0 = root0 + rent * 32 // 512
fat = bytearray(b''.join(rd(rsv + i) for i in range(fsz)))
def get(c):
    o = c * 3 // 2; v = fat[o] | fat[o + 1] << 8; return v >> 4 if c & 1 else v & 0xFFF
def put(c, v):
    o = c * 3 // 2; w = fat[o] | fat[o + 1] << 8
    w = (w & 0x000F) | v << 4 if c & 1 else (w & 0xF000) | v
    fat[o] = w & 255; fat[o + 1] = w >> 8
def alloc(n):
    fr = [c for c in range(2, 1000) if get(c) == 0][:n]
    assert len(fr) == n, 'disk full'
    for i, c in enumerate(fr): put(c, fr[i + 1] if i + 1 < n else 0xFFF)
    return fr
def csec(c, k): return data0 + (c - 2) * spc + k
def chain(c):
    r = []
    while 2 <= c < 0xFF8: r.append(c); c = get(c)
    return r
def key11(nm):
    b, _, e = nm.partition('.'); return b.ljust(8).encode() + e.ljust(3).encode()
def dir_secs(cl):   # cl=0: ルート
    if cl == 0: return list(range(root0, data0))
    return [csec(c, k) for c in chain(cl) for k in range(spc)]
def find_ent(cl, key):
    for L in dir_secs(cl):
        b = rd(L)
        for i in range(0, 512, 32):
            if b[i] == 0: return None
            if b[i] != 0xE5 and b[i:i + 11] == key: return struct.unpack('<H', b[i + 26:i + 28])[0]
    return None
def add_ent(cl, ent):
    while True:
        for L in dir_secs(cl):
            b = bytearray(rd(L))
            for i in range(0, 512, 32):
                if b[i] in (0, 0xE5):
                    b[i:i + 32] = ent; wr(L, bytes(b)); return
        assert cl != 0, 'root full'
        last = chain(cl)[-1]; n = alloc(1)[0]; put(last, n)   # サブディレクトリを1クラスタ延ばす
        for k in range(spc): wr(csec(n, k), b'')
def mkdir(parent, nm):
    c = alloc(1)[0]
    for k in range(spc): wr(csec(c, k), b'')
    d = bytearray(csec(c, 0) and rd(csec(c, 0)))
    d[0:32] = b'.          ' + bytes([0x10]) + bytes(14) + struct.pack('<HI', c, 0)
    d[32:64] = b'..         ' + bytes([0x10]) + bytes(14) + struct.pack('<HI', parent, 0)
    wr(csec(c, 0), bytes(d))
    add_ent(parent, key11(nm) + bytes([0x10]) + bytes(14) + struct.pack('<HI', c, 0))
    return c
parts = dst.split('/'); cur = 0
for d in parts[:-1]:
    n = find_ent(cur, key11(d))
    cur = n if n else mkdir(cur, d)
ncl = max(1, (len(data) + spc * 512 - 1) // (spc * 512)) if data else 0
free = alloc(ncl) if ncl else [0]
for i, c in enumerate(free[:ncl]):
    for k in range(spc):
        p = (i * spc + k) * 512; wr(csec(c, k), data[p:p + 512])
add_ent(cur, key11(parts[-1]) + bytes([0x20]) + name2 + bytes(4) + struct.pack('<H', free[0]) + struct.pack('<I', len(data)))
for k in range(nf):
    for i in range(fsz): wr(rsv + k * fsz + i, bytes(fat[i * 512:(i + 1) * 512]))
open(img, 'wb').write(buf)
