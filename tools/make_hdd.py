#!/usr/bin/env python3
"""LSX-Dodgers MZ-2500 SASI ハードディスクイメージ(256B/ブロックの生イメージ)を作る。

  ブロック3          : EH-SASI パーティション表("EHSASI " + 16B x 15)。優先起動パーティション1つ
  パーティション     : 先頭 BASE (=0021h) ブロックから NS 論理セクタ(512B)。FAT16
    論理セクタ0      : IPLPRO ヘッダ(256B) とBPBを同居させたブートセクタ(ヘッダの 0x18,0x1E,0x20,0x30 以降は BPB の使わない領域)
    論理セクタ1-16   : ブートローダ(8KB = ブロック2-33。ヘッダ[0x1E]=2 が開始レコード)。予約セクタ(RSV=20)の中
    FAT x2, ルート(512エントリ), データ(クラスタ2=DATA0 から LD2500.BIN を連続配置)
  * ブロック長 256B、容量は正規サイズ 87648 ブロック(22437888B)。エミュレータ(--hdf)が EH-SASI 署名で256B/ブロックと判定する。
  * 実機(MZ-1E30 + 実HDD/HDDエミュレータ)では未確認。

使い方: make_hdd.py out.hdf LD2500.BIN boot_payload.bin [file[:NAME.EXT] ...]
"""
import struct, sys, os

BLK = 256
TOTAL_BLOCKS = 87648
BASE = 0x21            # パーティション先頭ブロック(正規レイアウトの HD1 と同じ)
NS = 20000             # 論理セクタ数(512B) = 約10MB
RSV = 20
SECPCL = 2
ROOTENT = 512
ROOTSEC = ROOTENT * 32 // 512
START_REC = 2          # ブートローダの開始レコード(パーティション先頭からのブロック番号)

def layout():
    fatsz = 1
    while True:
        ncl = (NS - RSV - ROOTSEC - 2 * fatsz) // SECPCL
        need = -(-((ncl + 2) * 2) // 512)
        if need <= fatsz: break
        fatsz = need
    fat0 = RSV; root0 = RSV + 2 * fatsz; data0 = root0 + ROOTSEC
    return dict(fatsz=fatsz, fat0=fat0, root0=root0, data0=data0, ncl=ncl)

def boot_sector():
    h = bytearray(512)
    h[0] = 1; h[1:7] = b'IPLPRO'; h[7:11] = b'LSX-'
    h[0x18:0x1A] = (0x8000).to_bytes(2, 'little')
    h[0x1E:0x20] = START_REC.to_bytes(2, 'little')
    h[0x20:0x23] = bytes([0x08, 0xFF, 0xFF])
    h[0x30:0x37] = bytes([0x00, 0x01, 0x02, 0x03, 0x08, 0x05, 0x06])
    L = layout()
    h[11:13] = (512).to_bytes(2, 'little'); h[13] = SECPCL
    h[14:16] = RSV.to_bytes(2, 'little'); h[16] = 2
    h[17:19] = ROOTENT.to_bytes(2, 'little'); h[19:21] = NS.to_bytes(2, 'little')
    h[21] = 0xF8; h[22:24] = L['fatsz'].to_bytes(2, 'little')
    h[36] = 0x80; h[38] = 0x29
    h[510:512] = b'\x55\xAA'
    return h

def dirent(name, size, cl):
    base, _, ext = name.upper().partition('.')
    e = bytearray(32)
    e[0:11] = base.ljust(8)[:8].encode('ascii') + ext.ljust(3)[:3].encode('ascii')
    e[11] = 0x20
    e[22:24] = (0x0000).to_bytes(2, 'little')
    e[24:26] = (((1996 - 1980) << 9) | (8 << 5) | 1).to_bytes(2, 'little')
    e[26:28] = cl.to_bytes(2, 'little'); e[28:32] = size.to_bytes(4, 'little')
    return bytes(e)

def build(out, sysbin, payload, files):
    L = layout()
    img = bytearray(TOTAL_BLOCKS * BLK)
    sig = b'EHSASI 20220510\0'
    img[3 * BLK:3 * BLK + 16] = sig
    ent = bytearray(16)
    ent[0] = 0x81                              # 優先起動 + ドライブ1
    ent[1:3] = bytes([(NS >> 8) & 0xFF, NS & 0xFF])
    ent[3] = 0x01                              # SASI ID(0)のビットマスク。0は未使用エントリ扱い
    ent[4] = 0                                 # LUN
    ent[5:8] = bytes([(BASE >> 16) & 0xFF, (BASE >> 8) & 0xFF, BASE & 0xFF])
    img[3 * BLK + 16:3 * BLK + 32] = ent
    p0 = BASE * BLK
    img[p0:p0 + 512] = boot_sector()
    pl = payload + bytes(8192 - len(payload)); assert len(pl) == 8192
    img[p0 + START_REC * BLK:p0 + START_REC * BLK + 8192] = pl
    fat = bytearray(L['fatsz'] * 512)
    fat[0:4] = bytes([0xF8, 0xFF, 0xFF, 0xFF])
    root = bytearray(ROOTENT * 32)
    cl = 2; n = 0
    def place(data):          # 連続クラスタへ書く。先頭クラスタ番号を返す
        nonlocal cl
        ncl = max(1, -(-len(data) // (SECPCL * 512)))
        assert cl + ncl <= L['ncl'] + 2, 'ディスクが一杯'
        for i in range(ncl):
            nxt = cl + i + 1 if i < ncl - 1 else 0xFFFF
            fat[(cl + i) * 2:(cl + i) * 2 + 2] = nxt.to_bytes(2, 'little')
        o = p0 + (L['data0'] + (cl - 2) * SECPCL) * 512
        img[o:o + len(data)] = data
        c0 = cl; cl += ncl
        return c0
    flat = [('LD2500.BIN', sysbin)] + [(a, b) for a, b in files if '/' not in a]
    subs = {}
    for a, b in files:
        if '/' in a:
            d, f = a.replace('\\', '/').split('/', 1); subs.setdefault(d.upper(), []).append((f, b))
    for name, data in flat:
        root[n * 32:n * 32 + 32] = dirent(name, len(data), place(data)); n += 1
    for d, lst in subs.items():                    # 1段のサブディレクトリ(連続クラスタ)
        dsz = (len(lst) + 2) * 32
        dcl = cl; cl += max(1, -(-dsz // (SECPCL * 512)))
        for i in range(dcl, cl):
            fat[i * 2:i * 2 + 2] = (i + 1 if i < cl - 1 else 0xFFFF).to_bytes(2, 'little')
        sub = bytearray(max(1, -(-dsz // (SECPCL * 512))) * SECPCL * 512)
        m = 0
        for nm, dt in [('.', None), ('..', None)] + lst:
            if dt is None:
                e = bytearray(32); e[0:11] = nm.ljust(11).encode(); e[11] = 0x10
                e[26:28] = (dcl if nm == '.' else 0).to_bytes(2, 'little')
            else:
                e = bytearray(dirent(nm, len(dt), place(dt)))
            sub[m * 32:m * 32 + 32] = e; m += 1
        o = p0 + (L['data0'] + (dcl - 2) * SECPCL) * 512
        img[o:o + len(sub)] = sub
        e = bytearray(dirent(d, 0, dcl)); e[11] = 0x10
        root[n * 32:n * 32 + 32] = e; n += 1
    for k in range(2):
        o = p0 + (L['fat0'] + k * L['fatsz']) * 512
        img[o:o + len(fat)] = fat
    o = p0 + L['root0'] * 512
    img[o:o + len(root)] = root
    open(out, 'wb').write(img)

if __name__ == '__main__':
    if len(sys.argv) < 4: sys.exit(__doc__)
    out, sysf, plf = sys.argv[1:4]
    files = []
    for a in sys.argv[4:]:
        path, _, nm = a.partition(':')
        files.append((nm or os.path.basename(path), open(path, 'rb').read()))
    build(out, open(sysf, 'rb').read(), open(plf, 'rb').read(), files)
    L = layout()
    print('wrote %s : partition base %02Xh, SYS_LSN0=%d, clusters=%d' % (out, BASE, L['data0'], L['ncl']))
