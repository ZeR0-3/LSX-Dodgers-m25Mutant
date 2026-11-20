"""固定アドレス領域の重なり検査(build.py から呼ぶ)。
M25DEF.ASM の EQU を評価し、領域表(名前, 開始, 大きさ)が重ならないこと・境界を越えないことを確かめる。
領域の大きさは、ソース(M25EDTO の HLBUF など)を読んで手で書いた値。領域を足したら下の表にも足すこと。
重なりが既知で、危険でないと分かっているものだけ WAIVE に理由つきで書く(増やすときは根拠を残す)。"""
import re

def load_equs(path):
    equs = {}
    for l in open(path, encoding='utf-8', errors='replace'):
        l = l.split(';')[0]
        m = re.match(r'^(\w+)\s+EQU\s+(.+?)\s*$', l)
        if m: equs[m.group(1)] = m.group(2)
    return equs

def evaluate(equs, name, memo=None):
    memo = {} if memo is None else memo
    if name in memo: return memo[name]
    expr = equs[name]
    def tok(m):
        t = m.group(0)
        if re.fullmatch(r'0[0-9A-Fa-f]*[Hh]', t) or re.fullmatch(r'[0-9][0-9A-Fa-f]*[Hh]', t): return str(int(t[:-1], 16))
        if t.isdigit(): return t
        return str(evaluate(equs, t, memo))
    v = int(eval(re.sub(r'[A-Za-z_0-9]+', tok, expr), {}, {}))
    memo[name] = v
    return v

# (重なりを許す2領域, 理由)
WAIVE = {
    frozenset(['GVARS vars', 'gate stack']):
        'ゲートの変数(+0..+41 十進、UTGT の終わり=+29H)とゲートのスタック(+10H..+3FH)が重なる(元からの配置)。スタックの上端は+40H なので、変数を壊さずに使えるのは約22B(11段のPUSH)。ゲート中のスタックの最大深さは未計測',
}

def check(def_path, syms, kj_len):
    E = load_equs(def_path); V = lambda n: evaluate(E, n)
    R = []   # (名前, 開始, 大きさ)
    # カーネル時のバンク5(A000H-B005H)
    R += [('EDBUF(行編集のFCB/バッファ)', V('EDBUF'), 0xC0 + 84),
          ('KJ(漢字表示コード)', V('KJBASE'), kj_len),
          ('LDVARS(ローダ変数)', V('LDVARS'), 14),
          ('PXCNT/PXLEN', V('PXCNT'), 2),
          ('PROCS(E5hの記録)', V('PROCS'), 32 * 4),
          ('DTBUF', V('DTBUF'), 0x400),
          ('STAGE', V('STAGE'), V('STAGEL')),
          ('カーネルスタック', V('KSTK') - 0x200, 0x200)]
    # 本体のコードと、その後ろの作業領域(AT_TABLE..TABLEAD の詰め物の中)
    R += [('常駐コード', V('BDOS'), syms['AT_TABLE'] - V('BDOS')),
          ('LNBSS(長いファイル名)', V('LNBSS'), 10 + V('LNSLOTS') * V('LNSZ') + 1 + 4),
          ('ENVBUF', V('ENVBUF'), V('ENVSZ')),
          ('RFNAME', V('RFNAME'), 64),
          ('OUTBUF', V('OUTBUF'), 128),
          ('HSLOTS', V('HSLOTS'), V('NSLOT') * V('SLOTSZ')),
          ('キー表5枚', V('TABLEAD'), 560)]
    # 共通バンク(E000H-FFFFH)の変数
    R += [('GVARS vars', V('GVARS'), 42), ('gate stack', V('GVARS') + 0x10, 0x30)]
    be = V('BOUNCEE')
    R += [('BOUNCE(DMA 128)', V('BOUNCE'), 128), ('BOUNCEF', V('BOUNCEF'), 40), ('BOUNCEG', V('BOUNCEG'), 40),
          ('BOUNCES', V('BOUNCES'), 128), ('BOUNCEX', V('BOUNCEX'), 0x104),
          ('IOCS一時置き場(IOCSOK..UIDE)', be, 19), ('IOCT', V('IOCT'), V('IOCTN') * 2),
          ('UMAP+PDEPTH', V('UMAP'), 8), ('BOOTDEV', V('BOOTDEV'), 1),
          ('KBUF..TRAP38', V('KBUF'), V('TRAP38') - V('KBUF'))]
    R.append(('TRAP38', V('TRAP38'), 0x10000 - V('TRAP38')))
    errs, warns = [], []
    for n, s, z in R:
        if s < 0 or s + z > 0x10000: errs.append('%s が64KBを越える (%04X+%d)' % (n, s, z))
    for i in range(len(R)):
        for j in range(i + 1, len(R)):
            a, b = R[i], R[j]
            if a[1] < b[1] + b[2] and b[1] < a[1] + a[2]:
                w = WAIVE.get(frozenset([a[0], b[0]]))
                msg = '%s (%04X-%04X) と %s (%04X-%04X) が重なる' % (a[0], a[1], a[1] + a[2] - 1, b[0], b[1], b[1] + b[2] - 1)
                (warns if w else errs).append(msg + (' [既知: %s]' % w if w else ''))
    # カーネル時のバンク5は B006H(BDOS)の手前まで
    for n, s, z in R:
        if V('EDBUF') <= s < V('BDOS') and s + z > V('BDOS') and n != '常駐コード': errs.append('%s がBDOS(%04X)に食い込む' % (n, V('BDOS')))
    return errs, warns
