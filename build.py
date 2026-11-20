#!/usr/bin/env python3
"""LSX-Dodgers MZ-2500 ビルド (z88dk-z80asm 使用)
  [LSX_IMPORT=<原本のシステムD88>] python3 build.py <LSX-Dodgers原本dir(LD*.ASMのあるフォルダ)> <z88dk-z80asm> <出力dir> [USE_TINIT] [COLS80] [KEEP_ENV]
"""
import os, re, shutil, subprocess, sys
orig, Z, out = sys.argv[1:4]
flags = sys.argv[4:]          # 例: COLS80 DEBUG_MARK
PRE = ''.join('%s\tEQU\t1\n' % f for f in flags)
here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(out, exist_ok=True)
work = os.path.join(out, 'src'); conv = os.path.join(out, 'conv')
for d in (work, conv): shutil.rmtree(d, ignore_errors=True); os.makedirs(d)
for f in os.listdir(orig):   # 原本はCP932 -> UTF-8
    if f.upper().endswith('.ASM'):
        raw = open(os.path.join(orig, f), 'rb').read()
        try: txt = raw.decode('cp932')
        except UnicodeDecodeError: txt = raw.decode('cp932', errors='replace')
        open(os.path.join(work, f), 'w', encoding='utf-8').write(txt)
for f in os.listdir(os.path.join(here, 'src')): shutil.copy(os.path.join(here, 'src', f), work)

# ---- 原本への差し込み(最小限。必ず1箇所だけ一致すること) ----
def patch_src(fn, old, new):
    p = os.path.join(work, fn); t = open(p, encoding='utf-8').read()
    o = old.replace('\n', '\r\n') if '\r\n' in t else old
    n = new.replace('\n', '\r\n') if '\r\n' in t else new
    assert t.count(o) == 1, 'patch not unique: %s %r' % (fn, old)
    open(p, 'w', encoding='utf-8').write(t.replace(o, n))
patch_src('LDOS.ASM', '_DOS2:\n\tCP\t05AH', '_DOS2:\n\tJP\tHND_DOS2\n_DOS2B:\n\tCP\t05AH')
# COPY等のバッファ(S27BUF)は SP から逆算するので、カーネルのスタックが B000H 付近だと 0100H-A8FFH になり、カーネル時のバンク5の空き
# (A000H-: 行編集バッファ・漢字表示のコード・ローダの変数・ディスクバッファ)を踏む。A000H の手前(最大 9800H バイト=0100H-98FFH)で止める
patch_src('LDCCP.ASM', '\tLD\tL,0\n\tLD\tA,H\n\tAND\t0F8H\n\tLD\tH,A\nS27DTA:', '\tLD\tL,0\n\tLD\tA,H\n\tAND\t0F8H\n\tCP\t098H\n\tJR\tC,S27C\n\tLD\tA,098H\nS27C:\tLD\tH,A\nS27DTA:')
patch_src('LDCCP.ASM', 'COMMAND:\n\tLD\tA,(FCB_BAT)', 'COMMAND:\n\tCALL\tHND_RESET\n\tCALL\tHND_PIPEK\n\tLD\tA,(FCB_BAT)')
patch_src('LDWORK.ASM', '_PRINT:\tJP\tPRINT', '_PRINT:\tJP\tHND_PRINT')
# 拡張BIOS表(F0CAH-)をユーザ/カーネル両用のスタブ経由にする(M25GATE.ASM の UXG)
patch_src('LDWORK.ASM', '_INKEY:\tJP\tINKEY', '_INKEY:\tJP\tUX_INKEY')
patch_src('LDWORK.ASM', '_PRINT:\tJP\tHND_PRINT', '_PRINT:\tJP\tUX_PRINT')
patch_src('LDWORK.ASM', '_SCRN:\tJP\tSCRN', '_SCRN:\tJP\tUX_SCRN')
patch_src('LDWORK.ASM', '_POS:\tJP\tPOS', '_POS:\tJP\tUX_POS')
patch_src('LDWORK.ASM', '_LOC:\tJP\tLOC', '_LOC:\tJP\tUX_LOC')
patch_src('LDWORK.ASM', '_CHGDRV:\n\tJP\tCHGDRV', '_CHGDRV:\n\tJP\tUX_CHGDRV')
patch_src('LDWORK.ASM', '_GETDPB:\n\tJP\tGETDPB', '_GETDPB:\n\tJP\tUX_GETDPB')
patch_src('LDWORK.ASM', '_FFLUSH:\n\tJP\tFFLUSH', '_FFLUSH:\n\tJP\tUX_FFLUSH')
patch_src('LDWORK.ASM', '_RDFATX:\n\tJP\tRDFATX', '_RDFATX:\n\tJP\tUX_RDFATX')
patch_src('LDWORK.ASM', '_RDFAT:\tJP\tRDFAT', '_RDFAT:\tJP\tUX_RDFAT')
patch_src('LDWORK.ASM', '_WTTRK:\tJP\tWTTRK', '_WTTRK:\tJP\tUX_WTTRK')
patch_src('LDWORK.ASM', '_FDRD:\tJP\tFDRD', '_FDRD:\tJP\tUX_FDRD')
patch_src('LDWORK.ASM', '_FDWT:\tJP\tFDWT', '_FDWT:\tJP\tUX_FDWT')
patch_src('LDWORK.ASM', '_BPB2DPB:\n\tJP\tBPB2DPB', '_BPB2DPB:\n\tJP\tUX_BPB2DPB')
patch_src('LDWORK.ASM', '_BREAK:\n\tJP\tEND_BATCH', '_BREAK:\n\tJP\tUX_BREAK')
patch_src('LDWORK.ASM', '_COMANL:\n\tJP\tCOMANL', '_COMANL:\n\tJP\tUX_COMANL')
patch_src('LDWORK.ASM', 'CPM_CONIN:\n\tJP\tFLGET', 'CPM_CONIN:\n\tJP\tHND_FLGET')
patch_src('M25IO.ASM', '\tJP\tZ,_INKEY\n', '\tJP\tZ,HND_INKEY\n')
patch_src('M25IO.ASM', '_SYS0A:\t\t;(BDOS)文字列入力\n', '_SYS0A:\t\t;(BDOS)文字列入力\n\tJP\tHND_SYS0A\n_SYS0A_ORG:\n')
patch_src('M25IO.ASM', '_SYS0B:\t\t;(BDOS)コンソール状態のチェック\n', '_SYS0B:\t\t;(BDOS)コンソール状態のチェック\n\tJP\tHND_SYS0B\n_SYS0B_ORG:\n')
patch_src('LDOS.ASM', 'SHOW_ERROR:\t\t\t;(9)\n', 'SHOW_ERROR:\t\t\t;(9)\n\tCALL\tHND_SCR\n')
# 長いファイル名(Human68k/TwentyOne 方式。src/M25LN.ASM): 解析で name2 を拾い、検索の一致・作成・名前変更・ワイルドカード判定で使う
patch_src('LDFILE.ASM', 'FILED:\n\tCALL\tFILEI\n', 'FILED:\n\tCALL\tFILEI\n\tCALL\tLNCLR\n')
patch_src('LDFILE.ASM', "FILE3:\n\tCALL\tCCHKF\n\tRET\tZ\n\tCP\t'.'\n\tJR\tNZ,FILE3\n", 'FILE3:\n\tCALL\tLNCAP\n\tRET\tZ\n')
patch_src('LDFILE.ASM', '\tPUSH\tHL\n\tCALL\tCPFILE\n\tCALL\tZ,CPFILE2\n\tPOP\tHL\n', '\tPUSH\tHL\n\tCALL\tCPFILE\n\tCALL\tZ,LNMAT\n\tCALL\tZ,CPFILE2\n\tPOP\tHL\n')
patch_src('LDFILE.ASM', '\tCALL\tCPFILE\n\tJR\tNZ,SOPEN\n\n\tLD\tHL,(SCDIR)\n', '\tCALL\tCPFILE\n\tJR\tNZ,SOPEN\n\tCALL\tLNMAT\n\tJR\tNZ,SOPEN\n\n\tLD\tHL,(SCDIR)\n')
patch_src('LDFILE.ASM', '\tCALL\tFKAN\n\tDJNZ\tSNAME1\nWTDB:', '\tCALL\tFKAN\n\tDJNZ\tSNAME1\n\tCALL\tLNREN\nWTDB:')
patch_src('LDFILE.ASM', '\tDJNZ\tCHKWIL1\n\tXOR\tA\n\tRET\n', '\tDJNZ\tCHKWIL1\n\tJP\tLNWILD\n')
patch_src('LDFILE.ASM', '\tXOR\tA\n\tLD\tB,10\nSDE1:\n\tLD\t(DE),A\n\tINC\tDE\n\tDJNZ\tSDE1\n', '\tCALL\tLNFILL\n')
patch_src('LDOS.ASM', '\tLD\tBC,16\n\tLDIR\n\tPOP\tHL\n\tPOP\tDE\n\tPOP\tBC\n\tRET\n\n_SYS30:', '\tLD\tBC,16\n\tLDIR\n\tCALL\tLNREC\n\tPOP\tHL\n\tPOP\tDE\n\tPOP\tBC\n\tRET\n\n_SYS30:')
# DIR の名前表示に name2(Human68k/TwentyOne 方式の長い名前)を含める
patch_src('LDCCP.ASM', '\tCALL\tPUTDRV\n\tLD\tHL,DTA_CCP+1\n\tCALL\tFPRNT\n\nLTNL:', '\tCALL\tPUTDRV\n\tLD\tHL,DTA_CCP+1\n\tCALL\tHND_DIRNAME\n\nLTNL:')
patch_src('LDCCP.ASM', 'COMMAND2:\n\tLD\tDE,DTA1+2\n', 'COMMAND2:\n\tCALL\tHND_EXPAND\nCOMMAND2P:\n\tCALL\tHND_PIPE\n\tCALL\tHND_REDIR\n\tJR\tC,COMMAND\n\tLD\tDE,DTA1+2\n')
# プロンプトにカレントディレクトリ (環境変数 PROMPT が定義されているとき) と、CD の成功時にパスを管理
patch_src('LDCCP.ASM', "\tADD\tA,'A'\n\tCALL\tMSG_A\n\tLD\tA,'>'\n\tCALL\tMSG_A\n\tLD\tA,80\n", "\tADD\tA,'A'\n\tCALL\tMSG_A\n\tCALL\tHND_PROMPT\n\tLD\tA,'>'\n\tCALL\tMSG_A\n\tLD\tA,80\n")
patch_src('LDCCP.ASM', 'C_CD:\n\tLD\tC,05AH\n\tJR\tSYSTEM0\n', 'C_CD:\n\tPUSH\tDE\n\tLD\tC,05AH\n\tCALL\tSYSTEM0\n\tPOP\tDE\n\tJP\tHND_CDT\n')
# 終了コード: コマンド実行を HND_RUN 経由に (実行前に $?=0、内部コマンドのエラーは 1)
patch_src('LDCCP.ASM', '\tLD\tDE,DTA1+2\n\tCALL\t_COMANL\n\tCALL\tC,SHOW_ERROR\n', '\tLD\tDE,DTA1+2\n\tCALL\tHND_RUN\n\tCALL\tC,SHOW_ERROR\n')
# バッチ引数 ($1-$9) と ":label" 行の読み飛ばし
patch_src('LDCCP.ASM', '\tSBC\tHL,DE\n\tJR\tNZ,CEXE6\n\n\tCALL\tDEFCB\n', '\tSBC\tHL,DE\n\tJR\tNZ,CEXE6\n\n\tCALL\tHND_BARGS\n\tCALL\tDEFCB\n')
patch_src('LDCCP.ASM', '\tLD\t(HL),0\n\tJP\tCOMMAND2\nEND_BATCH:', '\tLD\t(HL),0\n\tLD\tA,(DTA1+2)\n\tCP\t\':\'\n\tJP\tNZ,COMMAND2\n\tJR\tC_BAT1\nEND_BATCH:')
# 行編集の拡張(TAB補完・履歴): GETL の開始位置を ESTART 相当(EDT_START)に持たせ、キー入力をフックする。CCPのプロンプト行入力だけ HND_CCPIN 経由にする
patch_src('M25IO.ASM', 'GETL:\n\tCALL\t_POS\n\tPUSH\tHL\n', 'GETL:\n\tCALL\t_POS\n\tCALL\tED_BEGIN\n')
patch_src('M25IO.ASM', 'GETL1:\n\tCALL\t_SYS08\n\tCP\t9\n', 'GETL1:\n\tCALL\t_SYS08\n\tCALL\tED_KEY\n\tJR\tC,GETL1\n\tCP\t9\n')
patch_src('M25IO.ASM', '\n\tPOP\tDE\n\tCALL\t_POS\n\tLD\tL,E\n', '\n\tLD\tDE,(EDT_START)\n\tCALL\t_POS\n\tLD\tL,E\n')
patch_src('LDCCP.ASM', '\tLD\t(DE),A\n\tCALL\t_SYS0A\t\t;(BDOS)文字列入力\n\tCALL\tLTNL\nCOMMAND2:', '\tLD\t(DE),A\n\tCALL\tHND_CCPIN\n\tCALL\tLTNL\nCOMMAND2:')
# ---- MMU再設計 ステージ1(ユーザ/カーネルのマップ切替。docs/mmu-stage1.md) ----
patch_src('LDDEF.ASM', 'SYSTEM\tEQU\t00005H', 'SYSTEM\tEQU\tBDOS')           # CCPはカーネルのBDOSを直接呼ぶ(0005Hはユーザ用のゲート)
patch_src('LDCCP.ASM', '\tLD\tSP,(SYSTEM+1)\n\tLD\tH,A\t\t\t\t; A=0 in SETDTA1(_SYS1A)\n\tLD\tL,A\n\tPUSH\tHL\t\t\t\t; push $0000 (reboot address)\n\tINC\tH\n\tPUSH\tHL\t\t\t\t; push $0100 (TPA address)\n\tJP\tSETFCB\t\t\t\t; and JP $0100\n',
          '\tLD\tSP,KSTK\n\tLD\tHL,ULAUNCH\n\tPUSH\tHL\n\tJP\tSETFCB\t\t\t\t; SETFCB の RET で ULAUNCH(ユーザマップで0100Hへ)\n')
_p = os.path.join(work, 'LDWORK.ASM'); _t = open(_p, encoding='utf-8').read()
_t, _n = re.subn(r'_SYS07:[^\r\n]*(\r?\n)CPM_CONIN:(\r?\n)\tJP\tHND_FLGET', r'CPM_CONIN:\2\tJP\tUB_CONIN', _t); assert _n == 1
for _a, _b in (('CPM_WBOOT:\n\tJP\tWBOOT1', 'CPM_WBOOT:\n\tJP\tUWBOOT'), ('CPM_CONST:\n\tJP\tCONSTX', 'CPM_CONST:\n\tJP\tUB_CONST'), ('CPM_CONOUT:\n\tJP\tCONOUT1', 'CPM_CONOUT:\n\tJP\tUB_CONOUT')):
    if '\r\n' in _t: _a = _a.replace('\n', '\r\n'); _b = _b.replace('\n', '\r\n')
    assert _t.count(_a) == 1, _a; _t = _t.replace(_a, _b)
open(_p, 'w', encoding='utf-8').write(_t)
subprocess.check_call([sys.executable, os.path.join(here, 'tools', 'ld2z80asm.py'), work, conv])
env = dict(os.environ)
env.setdefault('Z80_OZFILES', os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(Z)))), 'lib'))
def asm(name, src):
    p = os.path.join(conv, name + '.asm'); open(p, 'w', encoding='utf-8').write(PRE + src)
    r = subprocess.run([Z, '-b', '-m=z80', '-m', name + '.asm'], cwd=conv, env=env, capture_output=True, text=True)
    if r.returncode: print(r.stdout, r.stderr); sys.exit('assemble failed: ' + name)
    for l in r.stdout.splitlines():
        if 'warning' in l: print('  ', l)
    return open(os.path.join(conv, name + '.bin'), 'rb').read()

# ---- 本体 (ORG BDOS) ----
inc = ['M25BANK','M25CCP','LDCCP','M25CCP2','M25LOAD','LDOS','M25IO','LDFILE','LDFILE2','LDDIO','M25DISK','M25MEM',
       'M25HND','M25LN','M25RES','M25ENV','M25RTC','M25BAT','M25EDT','M25OVL','LDCCPWK','M25TABLE','LDWORK','LDCALL','M25DPB']
body_src = '\tINCLUDE "M25DEF.ASM"\n\tINCLUDE "LDDEF.ASM"\nORG_BASE EQU BDOS\n\tORG BDOS\n\tJP IO_BDOS\n' + \
           ''.join('\tINCLUDE "%s.ASM"\n' % n for n in inc)
body_full = asm('body25', body_src)
syms = {}
for l in open(os.path.join(conv, 'body25.map'), encoding='utf-8', errors='replace'):
    m = re.match(r'^(\w+)\s*=\s*\$([0-9A-Fa-f]+)', l)
    if m: syms[m.group(1)] = int(m.group(2), 16)
# 本体はコードの前半(BDOS..AT_TABLE)と、キー表以降(TABLEAD..)の2つに分けてイメージに入れる。間は詰め物(0)で、イメージには入れない
m_bdos = int(re.search(r'^\s*BDOS\s+EQU\s+0([0-9A-F]+)H', open(os.path.join(here,'src','M25DEF.ASM'),encoding='utf-8').read(), re.M).group(1), 16)
m_tab = int(re.search(r'^\s*TABLEAD\s+EQU\s+0([0-9A-F]+)H', open(os.path.join(here,'src','M25DEF.ASM'),encoding='utf-8').read(), re.M).group(1), 16)
a_len = syms['AT_TABLE'] - m_bdos
assert not any(body_full[a_len:m_tab - m_bdos]), 'AT_TABLE..TABLEAD の詰め物が0でない'
_addr = {}
for l in open(os.path.join(conv, 'body25.map'), encoding='utf-8', errors='replace'):
    m = re.match(r'^(\w+)\s*=\s*\$([0-9A-Fa-f]+)\s*;\s*addr', l)
    if m: _addr[m.group(1)] = int(m.group(2), 16)
m_ed = int(re.search(r'^\s*EDBUF\s+EQU\s+0([0-9A-F]+)H', open(os.path.join(here,'src','M25DEF.ASM'),encoding='utf-8').read(), re.M).group(1), 16)
_bl = syms['LNBSS']                                  # 作業領域の一番下(ENVBUF の下の LNBSS。以前は LN の分を数え忘れていて、常駐の空きを108B多く見積もっていた)
assert syms['AT_TABLE'] <= _bl, '作業領域(RFNAME..HSLOTS)がコードに食い込んだ (AT_TABLE=%04X > %04X)' % (syms['AT_TABLE'], _bl)
assert syms['AT_TABLE'] <= m_tab, '本体のコードがTABLEADに食い込んだ (AT_TABLE=%04X)' % syms['AT_TABLE']
#assert 0xEC40 + 0x080 + 0x28 + 0x28 + 0x80 + 0x104 <= m_tab, 'バウンスバッファがTABLEADを越えた'
assert not [n for n, v in _addr.items() if syms['AT_TABLE'] < v < m_tab], 'AT_TABLE..TABLEAD にラベルがある'
body_a = body_full[:a_len]; body_b = body_full[m_tab - m_bdos:]
open(os.path.join(conv, 'body25a.bin'), 'wb').write(body_a); open(os.path.join(conv, 'body25b.bin'), 'wb').write(body_b)
print('resident body free before E000H:', 0xE000 - syms['BODYEND'], 'bytes')
print('body', len(body_full), 'bytes (image %d+%d)  code end %04X  free %d bytes' % (len(body_a), len(body_b), syms['AT_TABLE'], _bl - syms['AT_TABLE']))
# ---- オーバーレイ (ORG 8000H。先頭に入口のJP表。本体のシンボルは使われているものだけ自動で取り込む) ----
OVLS = [(['M25MODE', 'M25ENVC', 'M25PIPE', 'M25CWD', 'M25EDTO', 'M25LNAME'], ['C_MODE', 'C_SET', 'C_ENV', 'HND_PIPE', 'HND_PIPEK', 'HND_CDT', 'HND_PROMPT', 'EDO_KEY', 'EDT_ADD', 'C_HIST', 'HND_DIRNAME']), (['M25PROC'], ['PR_EXEC', 'PR_EXIT', 'PR_RST'])]                  # (ソース, 入口ラベル...) オーバーレイ番号は並び順
_defs = ''.join(open(os.path.join(conv, f), encoding='utf-8').read() for f in ('M25DEF.ASM', 'LDDEF.ASM'))
_defnames = set(re.findall(r'^\s*(\w+)\s+EQU', _defs, re.M))
ovl_bins = []
for k, (osrc, entries) in enumerate(OVLS):
    otxt = ''.join(open(os.path.join(conv, f + '.ASM'), encoding='utf-8').read() + '\n' for f in osrc)
    code = '\n'.join(l.split(';')[0] for l in otxt.splitlines())
    own = set(re.findall(r'^(\w+):', code, re.M)) | set(re.findall(r'^(\w+)\s+EQU', code, re.M))
    used = sorted(n for n in set(re.findall(r'[A-Za-z_]\w*', code)) if n in _addr and n not in own and n not in _defnames)
    eq = ''.join('%s\tEQU\t0%04XH\n' % (n, _addr[n]) for n in used)
    head = '\tINCLUDE "M25DEF.ASM"\n\tINCLUDE "LDDEF.ASM"\n' + eq + '\tORG\t08000H\n' + ''.join('\tJP\t%s\n' % e for e in entries)
    ob = asm('ovl%d' % k, head + otxt)
    assert len(ob) <= 8192, 'オーバーレイ%dが8KBを超えた(%d)' % (k, len(ob))
    ovl_bins.append(ob + bytes(8192 - len(ob)))
    print('overlay', k, '+'.join(osrc), len(ob), 'bytes (imports %d)' % len(used))
# ---- 漢字表示モジュール (ORG KJBASE。カーネル時のバンク5の空きへINITが写す。本体のシンボルは使われているものだけ自動で取り込む) ----
_kjtxt = open(os.path.join(conv, 'M25KJ.ASM'), encoding='utf-8').read()
_kjcode = '\n'.join(l.split(';')[0] for l in _kjtxt.splitlines())
_kjown = set(re.findall(r'^(\w+):', _kjcode, re.M)) | set(re.findall(r'^(\w+)\s+EQU', _kjcode, re.M))
_kjused = sorted(n for n in set(re.findall(r'[A-Za-z_]\w*', _kjcode)) if n in syms and n not in _kjown and n not in _defnames)
_kjeq = ''.join('%s\tEQU\t0%04XH\n' % (n, syms[n]) for n in _kjused)
kj_bin = asm('kj', '\tINCLUDE "M25DEF.ASM"\n\tINCLUDE "LDDEF.ASM"\n' + _kjeq + '\tORG\tKJBASE\n' + _kjtxt)
_kjb = int(re.search(r'^\s*KJBASE\s+EQU\s+0([0-9A-F]+)H', open(os.path.join(here,'src','M25DEF.ASM'),encoding='utf-8').read(), re.M).group(1), 16)
assert _kjb + len(kj_bin) <= 0xA560, '漢字表示のコードがLDVARS(A560H)に食い込んだ (%d bytes)' % len(kj_bin)
open(os.path.join(conv, 'kj.bin'), 'wb').write(kj_bin)
print('kanji module', len(kj_bin), 'bytes @%04X (imports %d)' % (_kjb, len(_kjused)))
sys.path.insert(0, os.path.join(here, 'tools'))
import layout
_errs, _warns = layout.check(os.path.join(here, 'src', 'M25DEF.ASM'), syms, len(kj_bin))
for w in _warns: print('layout WARN:', w)
if _errs: sys.exit('layout ERROR:\n  ' + '\n  '.join(_errs))
print('layout check: %d warn, ok' % len(_warns))
need = ['FILL_MEMORY','ZERO_MEMORY_DE','MSX','MSG_A','_COMANL','CPM_WBOOT','IO_INT8253','_DISKE',
        '_BREAK','CPM_BOOT','CHKEY','S27BUF','_DEVICE','UENTRY','UMSGA','UIOCS','UI_CRT','SASRD','SASBASE','SASBOOT','EMMN']
miss = [n for n in need if n not in syms]
if miss: sys.exit('missing symbols: %s' % miss)
open(os.path.join(conv, 'body_syms.inc'), 'w').write(
    ''.join('%s\tEQU\t0%04XH\n' % (n, syms[n]) for n in need) + 'BODYLEN_A\tEQU\t%d\nBODYLEN_B\tEQU\t%d\nBODYLEN_K\tEQU\t%d\n' % (len(body_a), len(body_b), len(kj_bin)))

# ---- TRAP38 (ORG TRAP38) ----
trap = open(os.path.join(here, 'src', 'TRAP38.ASM'), encoding='utf-8').read()
trap_bin = asm('trap38', 'TRAP38\tEQU\t0FFD9H\n\tINCLUDE "body_syms.inc"\n' + trap)

# ---- ステージ1 + IPLヘッダ ----
st = open(os.path.join(conv, 'M25INIT.ASM'), encoding='utf-8').read()
open(os.path.join(conv, 'body25.bin.inc'), 'w').write('')
img = asm('ipl', '\tINCLUDE "M25DEF.ASM"\n\tINCLUDE "LDDEF.ASM"\n\tINCLUDE "body_syms.inc"\n' + st)
sysbin = img[:]                                   # LD2500.BIN の先頭 (ORG 8000H で組んだシステム。START から始まる)
nsec = -(-len(sysbin) // 512); assert nsec <= 48, 'LD2500.BINのシステム部は24KB以下'
# LD2500.BIN = システム部(512の倍数に詰める) + オーバーレイ(8KBずつ。ローダがRAMページ OVL_PAGES へ読む)
open(os.path.join(out, 'LD2500.BIN'), 'wb').write(sysbin + bytes(nsec * 512 - len(sysbin)) + b''.join(ovl_bins))
# ---- ブートローダ(IPLが読む8KBページ) ----
RSV, FATSZ, NFAT, ROOTSEC = 36, 3, 2, 7
sys_lsn0 = RSV + FATSZ * NFAT + ROOTSEC          # = 49 : 先頭クラスタの論理セクタ
boot_src = open(os.path.join(conv, 'M25BOOT.ASM'), encoding='utf-8').read()
OVL_PAGES = [0x0E, 0x09][:len(ovl_bins)]   # オーバーレイ0=ページ0Eh、1=ページ09h(M25OVL.ASM の OVLPGT と同じ並び)
boot = asm('boot', 'SYS_LSN0\tEQU\t%d\nSYS_NSEC\tEQU\t%d\nOVL_N\tEQU\t%d\n' % (sys_lsn0, nsec, len(ovl_bins)) + boot_src +
           'OVLPG:\tDB\t' + ','.join('0%02XH' % p for p in OVL_PAGES + [0]) + '\n')
open(os.path.join(out, 'boot_payload.bin'), 'wb').write(boot)
# HDD(SASI)ブート用ローダ(同じソースを HDDBOOT 付きで。SYS_LSN0 は make_hdd.py のレイアウト)
sys.path.insert(0, os.path.join(here, 'tools'))
import make_hdd
bootH = asm('bootH', 'HDDBOOT\tEQU\t1\nBOOTDEV\tEQU\t0FF20H\nSYS_LSN0\tEQU\t%d\nSYS_NSEC\tEQU\t%d\nOVL_N\tEQU\t%d\n' % (make_hdd.layout()['data0'], nsec, len(ovl_bins)) + boot_src +
            'OVLPG:\tDB\t' + ','.join('0%02XH' % p for p in OVL_PAGES + [0]) + '\n')
open(os.path.join(out, 'boot_payload_hdd.bin'), 'wb').write(bootH)
print('HDD boot loader', len(bootH), 'bytes')
print('LD2500.BIN', len(sysbin), 'bytes (%d sectors @LSN %d) / boot loader' % (nsec, sys_lsn0), len(boot), 'bytes')
# ---- 起動ディスク(標準LSX形式のD88)。LSX_IMPORT=<原本のシステムD88> で FORMAT.COM 等のツールも取り込む ----
cmd = [sys.executable, os.path.join(here, 'tools', 'make_boot_disk.py'), os.path.join(out, 'LSX2500.d88'),
       os.path.join(out, 'LD2500.BIN'), os.path.join(out, 'boot_payload.bin')]
if os.environ.get('LSX_IMPORT'): cmd += ['--import', os.environ['LSX_IMPORT']]
subprocess.check_call(cmd)
# ---- 付属コマンド(coms/*.asm = 本移植のオリジナル小物: cat など)を起動ディスクへ入れる ----
import glob
for src in sorted(glob.glob(os.path.join(here, 'coms', '*.asm'))):
    nm = os.path.splitext(os.path.basename(src))[0]
    wd = os.path.join(out, '_coms'); os.makedirs(wd, exist_ok=True)
    _t = open(src, encoding='utf-8').read()
    if ';@cp932' in _t[:400]:       # 先頭に ;@cp932 があるソースは文字列を Shift_JIS に直してから組む(日本語メッセージ用)
        open(os.path.join(wd, os.path.basename(src)), 'wb').write(_t.encode('cp932', errors='replace'))
    else:
        shutil.copy(src, wd)
    for inc in glob.glob(os.path.join(here, 'coms', '*.inc')): shutil.copy(inc, wd)
    subprocess.check_call([Z, '-b', '-m=z80', os.path.basename(src)], cwd=wd, stdout=subprocess.DEVNULL)
    subprocess.check_call([sys.executable, os.path.join(here, 'tools', 'd88_put.py'), os.path.join(out, 'LSX2500.d88'),
                           os.path.join(wd, nm + '.bin'), 'BIN/' + nm.upper() + '.COM'], stdout=subprocess.DEVNULL)
    print('added BIN/' + nm.upper() + '.COM')
# ---- 簡易マニュアル: man/*.txt (UTF-8) を Shift_JIS + CRLF にして MAN/NAME.TXT へ ----
mandir = os.path.join(out, '_man'); os.makedirs(mandir, exist_ok=True)
manfiles = []
for src in sorted(glob.glob(os.path.join(here, 'man', '*.txt'))):
    nm = os.path.splitext(os.path.basename(src))[0].upper()
    dst = os.path.join(mandir, nm + '.TXT')
    t = open(src, encoding='utf-8').read().replace('\r\n', '\n').replace('\n', '\r\n')
    open(dst, 'wb').write(t.encode('cp932', errors='replace'))
    subprocess.check_call([sys.executable, os.path.join(here, 'tools', 'd88_put.py'), os.path.join(out, 'LSX2500.d88'),
                           dst, 'MAN/' + nm + '.TXT'], stdout=subprocess.DEVNULL)
    manfiles.append(dst + ':MAN/' + nm + '.TXT')
print('added MAN/*.TXT x%d' % len(manfiles))
# AUTOEXEC.BAT: 付属コマンドは \BIN に入れてあるので PATH を設定する(起動時に実行される)
def _bat(path, drv):
    f = os.path.join(out, '_coms', 'AUTOEXEC.' + drv)
    open(f, 'wb').write(('path %s:\\bin\r\n' % drv + ('hist h:\\history.txt\r\n' if drv == 'h' else '')).encode())
    return f
subprocess.check_call([sys.executable, os.path.join(here, 'tools', 'd88_put.py'), os.path.join(out, 'LSX2500.d88'),
                       _bat(out, 'a'), 'AUTOEXEC.BAT'], stdout=subprocess.DEVNULL)
# ---- HDD(SASI)イメージ: LD2500.BIN + 付属コマンド。--hdf で与えるとエミュレータの簡易IPLが優先起動パーティションから起動する ----
hfiles = [os.path.join(out, '_coms', os.path.splitext(os.path.basename(f))[0] + '.bin') + ':BIN/' + os.path.splitext(os.path.basename(f))[0].upper() + '.COM'
          for f in sorted(glob.glob(os.path.join(here, 'coms', '*.asm')))]
hfiles.append(_bat(out, 'h') + ':AUTOEXEC.BAT')
hfiles += manfiles
subprocess.check_call([sys.executable, os.path.join(here, 'tools', 'make_hdd.py'), os.path.join(out, 'LSX2500.hdf'),
                       os.path.join(out, 'LD2500.BIN'), os.path.join(out, 'boot_payload_hdd.bin')] + hfiles)
