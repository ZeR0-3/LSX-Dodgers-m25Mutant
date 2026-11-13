#!/usr/bin/env python3
# coms/{tr,cmp,diff,find,which,mv}.asm を gencoms.py と同じ共通部品つきで生成する
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'coms')
src = open(os.path.join(HERE, 'gencoms.py'), encoding='utf-8').read()
LIB = re.search(r"LIB=r'''(.*?)'''\ndef w\(", src, re.S).group(1)
HDR = '''	org 0100h
	ld sp,0A000h
'''
LONG = {'cmp': ['c_oe1', 'c_oe2'], 'diff': ['d_oe1', 'd_oe2'], 'find': ['f_ar'], 'which': ['w_nx'],
        'mv': ['m_msg', 'm_ok']}
def w(name, body):
    for lab in LONG.get(name, []):      # 届かない JR を JP にする
        body = re.sub(r'\bjr (nz,|z,|c,|nc,)?%s\b' % lab, lambda m: 'jp ' + (m.group(1) or '') + lab, body)
    open(os.path.join(OUT, name + '.asm'), 'w', encoding='utf-8').write(body + LIB)

# ---------------- tr ----------------
w('tr', r'''; TR.COM - 文字の置き換え・削除(標準入力 -> 標準出力)。 tr [-d] SET1 [SET2]   MIT License
;   SET は文字の並びと a-z 形式の範囲(空白は書けない)。SET1 の i 番目を SET2 の i 番目へ(SET2 が短ければ最後の文字)。 -d : SET1 の文字を消す
'''+HDR+r'''	call tailinit
	xor a
	ld (t_d),a
	call sk
	cp '-'
	jr nz,t_a
	inc hl
	ld a,(hl)
	or 20h
	cp 'd'
	jp nz,t_us
	ld a,1
	ld (t_d),a
	inc hl
	call sk
t_a:	or a
	jp z,t_us
	ld d,h
	ld e,l
	call tokend
	push hl
	ex de,hl
	ld de,l1buf
	ld a,46h
	ld (t_lim),a
	call t_exp
	ld (t_n1),bc
	pop hl
	call sk
	ld c,a
	ld a,(t_d)
	or a
	jr nz,t_init
	ld a,c
	or a
	jp z,t_us
	ld d,h
	ld e,l
	call tokend
	ex de,hl
	ld de,l2buf
	ld a,4Ah
	ld (t_lim),a
	call t_exp
	ld (t_n2),bc
	ld a,b
	or c
	jp z,t_us
t_init:	ld hl,tbl
	ld b,0
	xor a
t_i1:	ld (hl),a
	inc hl
	inc a
	djnz t_i1
	ld hl,del
	ld (hl),0
	ld de,del+1
	ld bc,255
	ldir
	ld bc,(t_n1)
	ld a,b
	or c
	jp z,t_us
	ld a,(t_d)
	or a
	jr nz,t_dl
	ld hl,(t_n1)
	ld de,(t_n2)
	or a
	sbc hl,de
	jr c,t_np
	jr z,t_np
	ld b,h
	ld c,l
	ld hl,l2buf
	add hl,de
	dec hl
	ld d,(hl)
	inc hl
t_pad:	ld (hl),d
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,t_pad
t_np:	ld hl,l1buf
	ld de,l2buf
	ld bc,(t_n1)
t_m:	ld a,(hl)
	inc hl
	push hl
	ld l,a
	ld h,tbl>>8
	ld a,(de)
	ld (hl),a
	pop hl
	inc de
	dec bc
	ld a,b
	or c
	jr nz,t_m
	jr t_run
t_dl:	ld hl,l1buf
t_dl1:	ld a,(hl)
	inc hl
	push hl
	ld l,a
	ld h,del>>8
	ld (hl),1
	pop hl
	dec bc
	ld a,b
	or c
	jr nz,t_dl1
t_run:	call rdb
	jr c,t_end
	ld l,a
	ld h,del>>8
	ld a,(hl)
	or a
	jr nz,t_run
	ld h,tbl>>8
	ld a,(hl)
	call wrb
	jr t_run
t_end:	call flush
	jp 0
t_us:	ld de,t_mus
	ld c,9
	call 5
	jp 0
; HL=文字列 DE=出力先 -> BC=個数(範囲 a-z を展開)
t_exp:	push de
t_e1:	ld a,(hl)
	or a
	jr z,t_ed
	ld c,a
	inc hl
	ld a,(hl)
	cp '-'
	jr nz,t_es
	inc hl
	ld a,(hl)
	or a
	jr z,t_eh
	cp c
	jp c,t_us
	inc hl
	ld b,a
t_er:	ld a,c
	call t_em
	ld a,c
	cp b
	jr z,t_e1
	inc c
	jr t_er
t_eh:	ld a,c
	call t_em
	ld a,'-'
	call t_em
	jr t_ed
t_es:	ld a,c
	call t_em
	jr t_e1
t_ed:	pop hl
	ex de,hl
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ret
t_em:	push af
	ld a,(t_lim)
	cp d
	jr z,t_em1
	jr c,t_em1
	pop af
	ld (de),a
	inc de
	ret
t_em1:	pop af
	ret
t_d:	defb 0
t_lim:	defb 0
t_n1:	defw 0
t_n2:	defw 0
t_mus:	defm "usage: tr [-d] set1 [set2]   (ranges like a-z)",13,10,"$"
tbl	equ 4000h
del	equ 4100h
l1buf	equ 4200h
l2buf	equ 4600h
''')

# ---------------- cmp ----------------
w('cmp', r'''; CMP.COM - 2つのファイルをバイト単位で比べる。 cmp file1 file2   (終了コード $? : 同じ 0 / 違う 1 / 開けない 2)   MIT License
'''+HDR+r'''	call tailinit
	call sk
	or a
	jp z,c_us
	ld d,h
	ld e,l
	call tokend
	ld (c_n1),de
	call sk
	or a
	jp z,c_us
	ld d,h
	ld e,l
	call tokend
	ld (c_n2),de
	ld de,(c_n1)
	ld a,1
	ld c,43h
	call 5
	or a
	jr nz,c_oe1
	ld a,b
	ld (c_h1),a
	ld de,(c_n2)
	ld a,1
	ld c,43h
	call 5
	or a
	jr nz,c_oe2
	ld a,b
	ld (c_h2),a
	ld hl,0
	ld (c_blk),hl
	inc hl
	ld (c_ln),hl
c_lp:	ld a,(c_h1)
	ld b,a
	ld de,b1
	call c_rd
	ld (c_c1),hl
	ld a,(c_h2)
	ld b,a
	ld de,b2
	call c_rd
	ld (c_c2),hl
	ld hl,(c_c1)
	ld de,(c_c2)
	or a
	sbc hl,de
	jr c,c_m1
	ld bc,(c_c2)
	jr c_m2
c_m1:	ld bc,(c_c1)
c_m2:	ld a,b
	or c
	jr z,c_cd
	ld hl,b1
	ld de,b2
c_cl:	ld a,(de)
	cp (hl)
	jr nz,c_df
	ld a,(hl)
	cp 0Ah
	jr nz,c_c3
	push hl
	ld hl,(c_ln)
	inc hl
	ld (c_ln),hl
	pop hl
c_c3:	inc hl
	inc de
	dec bc
	ld a,b
	or c
	jr nz,c_cl
c_cd:	ld hl,(c_c1)
	ld de,(c_c2)
	or a
	sbc hl,de
	jr z,c_eq
	jr c,c_s1
	ld hl,(c_n2)
	jr c_s2
c_s1:	ld hl,(c_n1)
c_s2:	push hl
	ld hl,c_meof
	call wrs
	pop hl
	call wrs
	call wcrlf
	ld b,1
	jr c_ex
c_eq:	ld hl,(c_c1)
	ld a,h
	cp 1
	jr nz,c_ok
	ld hl,(c_blk)
	inc hl
	ld (c_blk),hl
	jp c_lp
c_ok:	ld b,0
c_ex:	call flush
	ld c,62h
	call 5
	jp 0
c_df:	ld bc,b1
	or a
	sbc hl,bc
	ld c,l
	ld hl,(c_blk)
	ld a,h
	ld h,l
	ld l,c
	inc hl
	ld e,a
	ld a,h
	or l
	jr nz,c_d1
	inc e
c_d1:	ld d,0
	push de
	push hl
	ld hl,(c_n1)
	call wrs
	ld a,' '
	call wrb
	ld hl,(c_n2)
	call wrs
	ld hl,c_mdif
	call wrs
	pop hl
	pop de
	ld b,1
	call pnum
	ld hl,c_mln
	call wrs
	ld hl,(c_ln)
	ld de,0
	ld b,1
	call pnum
	call wcrlf
	ld b,1
	jr c_ex
c_oe1:	ld hl,(c_n1)
	jr c_oe
c_oe2:	ld hl,(c_n2)
c_oe:	push hl
	ld hl,c_mop
	call wrs
	pop hl
	call wrs
	call wcrlf
	ld b,2
	jr c_ex
c_us:	ld de,c_mus
	ld c,9
	call 5
	jp 0
c_rd:	ld hl,256
	ld c,48h
	call 5
	or a
	ret z
	ld hl,0
	ret
c_n1:	defw 0
c_n2:	defw 0
c_h1:	defb 0
c_h2:	defb 0
c_blk:	defw 0
c_ln:	defw 0
c_c1:	defw 0
c_c2:	defw 0
c_mdif:	defm " differ: byte ",0
c_mln:	defm ", line ",0
c_meof:	defm "cmp: EOF on ",0
c_mop:	defm "cmp: cannot open ",0
c_mus:	defm "usage: cmp file1 file2",13,10,"$"
b1	equ 3C00h
b2	equ 3D00h
''')

# ---------------- diff ----------------
w('diff', r'''; DIFF.COM - 2つのテキストファイルを1行ずつ突き合わせ、違う行を出す。 diff file1 file2   MIT License
;   出力: "< 行番号: file1の行" / "> 行番号: file2の行"。行の挿入・削除を探し直さない簡易版(ずれると以降すべて違う行になる)。同じなら何も出さない。
;   終了コード $? : 同じ 0 / 違う 1 / 開けない 2。1行は250文字まで。
'''+HDR+r'''	call tailinit
	call sk
	or a
	jp z,d_us
	ld d,h
	ld e,l
	call tokend
	ld (d_n1),de
	call sk
	or a
	jp z,d_us
	ld d,h
	ld e,l
	call tokend
	ld (d_n2),de
	ld de,(d_n1)
	ld a,1
	ld c,43h
	call 5
	or a
	jr nz,d_oe1
	ld a,b
	ld (s1),a
	ld de,(d_n2)
	ld a,1
	ld c,43h
	call 5
	or a
	jr nz,d_oe2
	ld a,b
	ld (s2),a
	ld hl,s1buf
	ld (s1+5),hl
	ld hl,s2buf
	ld (s2+5),hl
	ld hl,0
	ld (d_ln),hl
d_lp:	ld ix,s1
	ld de,l1
	call d_rl
	sbc a,a
	ld (d_e1),a
	ld ix,s2
	ld de,l2
	call d_rl
	sbc a,a
	ld b,a
	ld (d_e2),a
	ld a,(d_e1)
	and b
	jr nz,d_end
	ld hl,(d_ln)
	inc hl
	ld (d_ln),hl
	ld a,(d_e1)
	or b
	jr nz,d_pr
	ld hl,l1
	ld de,l2
d_cm:	ld a,(de)
	cp (hl)
	jr nz,d_pr
	or a
	jr z,d_lp
	inc hl
	inc de
	jr d_cm
d_pr:	ld a,1
	ld (d_any),a
	ld a,(d_e1)
	or a
	jr nz,d_p2
	ld a,'<'
	ld hl,l1
	call d_out
d_p2:	ld a,(d_e2)
	or a
	jr nz,d_lp
	ld a,'>'
	ld hl,l2
	call d_out
	jr d_lp
d_out:	push hl
	call wrb
	ld a,' '
	call wrb
	ld hl,(d_ln)
	ld de,0
	ld b,1
	call pnum
	ld a,':'
	call wrb
	ld a,' '
	call wrb
	pop hl
	call wrs
	jp wcrlf
d_end:	call flush
	ld a,(d_any)
	ld b,a
d_ex:	ld c,62h
	call 5
	jp 0
d_oe1:	ld de,(d_n1)
	jr d_oe
d_oe2:	ld de,(d_n2)
d_oe:	push de
	ld de,d_mop
	ld c,9
	call 5
	pop hl
d_oe3:	ld a,(hl)
	or a
	jr z,d_oe4
	ld e,a
	ld c,2
	push hl
	call 5
	pop hl
	inc hl
	jr d_oe3
d_oe4:	ld de,d_mcr
	ld c,9
	call 5
	ld b,2
	jr d_ex
d_us:	ld de,d_mus
	ld c,9
	call 5
	jp 0
; IX=入力構造体 DE=行バッファ。CR は捨て、LF で終わり、0終端。CF=1:データなしの EOF
d_rl:	ld c,0
d_r1:	call d_rc
	jr c,d_re
	cp 0Ah
	jr z,d_rend
	cp 0Dh
	jr z,d_r1
	ld b,a
	ld a,c
	cp 250
	jr nc,d_r1
	ld a,b
	ld (de),a
	inc de
	inc c
	jr d_r1
d_rend:	xor a
	ld (de),a
	ret
d_re:	ld a,c
	or a
	jr nz,d_rend
	ld (de),a
	scf
	ret
; IX=入力構造体 -> A=1バイト、CF=1:EOF
d_rc:	ld l,(ix+1)
	ld h,(ix+2)
	ld a,h
	or l
	jr nz,d_c2
	push bc
	push de
	ld b,(ix+0)
	ld e,(ix+5)
	ld d,(ix+6)
	ld hl,256
	ld c,48h
	call 5
	pop de
	pop bc
	or a
	jr nz,d_ceof
	ld a,h
	or l
	jr z,d_ceof
	ld a,(ix+5)
	ld (ix+3),a
	ld a,(ix+6)
	ld (ix+4),a
d_c2:	dec hl
	ld (ix+1),l
	ld (ix+2),h
	ld l,(ix+3)
	ld h,(ix+4)
	ld a,(hl)
	inc hl
	ld (ix+3),l
	ld (ix+4),h
	or a
	ret
d_ceof:	scf
	ret
; 入力構造体: +0 ハンドル +1 残り(2) +3 位置(2) +5 バッファ(2)
s1:	defs 7
s2:	defs 7
d_n1:	defw 0
d_n2:	defw 0
d_ln:	defw 0
d_e1:	defb 0
d_e2:	defb 0
d_any:	defb 0
d_mop:	defm "diff: cannot open $"
d_mcr:	defm 13,10,"$"
d_mus:	defm "usage: diff file1 file2",13,10,"$"
s1buf	equ 3C00h
s2buf	equ 3D00h
l1	equ 4000h
l2	equ 4100h
''')

# ---------------- find ----------------
w('find', r'''; FIND.COM - サブディレクトリをたどってファイルを探す。 find [path] [-name pattern] [-type d|f]   MIT License
;   path 省略=カレント。pattern は DIR と同じワイルドカード(既定 *.*)。-type d:ディレクトリだけ f:ファイルだけ。
;   各行は path からの相対名(ディレクトリは \ つき)。深さは path から8階層、1つのディレクトリにつきサブディレクトリ40個まで。
'''+HDR+r'''	call tailinit
	xor a
	ld (f_ty),a
	ld (plen),a
	ld (dep),a
	ld (pbuf),a
	ld hl,f_dall
	ld de,patb
	ld bc,4
	ldir
	ld hl,0081h
f_ar:	call sk
	or a
	jp z,f_go
	cp '-'
	jr z,f_op
	ld d,h
	ld e,l
	call tokend
	push hl
	ex de,hl
	ld de,pbuf
	ld b,70
f_cp:	ld a,(hl)
	or a
	jr z,f_cd
	ld (de),a
	inc hl
	inc de
	djnz f_cp
f_cd:	ld hl,pbuf
	or a
	sbc hl,de
	jr z,f_pe
	dec de
	ld a,(de)
	inc de
	cp 5Ch
	jr z,f_pe
	cp ':'
	jr z,f_pe
	cp '/'
	jr z,f_pe
	ld a,5Ch
	ld (de),a
	inc de
f_pe:	xor a
	ld (de),a
	ld a,e
	ld (plen),a
	pop hl
	jr f_ar
f_op:	inc hl
	ld a,(hl)
	or 20h
	cp 'n'
	jr z,f_nm
	cp 't'
	jp nz,f_us
	call tokend
	call sk
	or 20h
	ld b,1
	cp 'd'
	jr z,f_t1
	inc b
	cp 'f'
	jp nz,f_us
f_t1:	ld a,b
	ld (f_ty),a
	call tokend
	jr f_ar
f_nm:	call tokend
	call sk
	or a
	jp z,f_us
	ld d,h
	ld e,l
	call tokend
	push hl
	ex de,hl
	ld de,patb
	ld b,30
f_n1:	ld a,(hl)
	ld (de),a
	or a
	jr z,f_n2
	inc hl
	inc de
	djnz f_n1
	xor a
	ld (de),a
f_n2:	pop hl
	jr f_ar
f_go:	ld de,dtabuf
	ld c,1Ah
	call 5
	call f_walk
	call flush
	jp 0
f_us:	ld de,f_mus
	ld c,9
	call 5
	jp 0
f_walk:	ld hl,patb
	call f_mk
	ld de,fcb
	ld c,11h
f_s1:	call 5
	or a
	jr nz,f_s1d
	call f_ent
	ld de,fcb
	ld c,12h
	jr f_s1
f_s1d:	call f_lvp
	ld (hl),0
	ld hl,f_dall
	call f_mk
	ld de,fcb
	ld c,11h
f_s2:	call 5
	or a
	jr nz,f_s2d
	call f_col
	ld de,fcb
	ld c,12h
	jr f_s2
f_s2d:	ld a,(dep)
	cp 8
	ret nc
	call f_lvp
	ld a,(hl)
	or a
	ret z
	ld b,a
	ld c,0
f_r1:	push bc
	call f_lvp
	inc hl
	ld de,11
	ld a,c
	or a
	jr z,f_r2
f_r3:	add hl,de
	dec a
	jr nz,f_r3
f_r2:	ld a,(plen)
	push af
	call f_app
	jr c,f_r4
	ld a,(dep)
	inc a
	ld (dep),a
	call f_walk
	ld a,(dep)
	dec a
	ld (dep),a
f_r4:	pop af
	ld (plen),a
	ld l,a
	ld h,pbuf>>8
	ld (hl),0
	pop bc
	inc c
	ld a,c
	cp b
	jr c,f_r1
	ret
; 現在の深さの収集領域 -> HL
f_lvp:	ld a,(dep)
	add a,a
	add a,50h
	ld h,a
	ld l,0
	ret
; HL=11バイト名 -> pbuf の後ろへ "NAME.EXT\" を足す。CF=1:長すぎ
f_app:	ld a,(plen)
	cp 70
	ccf
	ret c
	ld e,a
	ld d,pbuf>>8
	push hl
	ld b,8
f_a1:	ld a,(hl)
	cp ' '
	jr z,f_a3
	ld (de),a
	inc de
	inc hl
	djnz f_a1
f_a3:	pop hl
	push de
	ld de,8
	add hl,de
	pop de
	ld a,(hl)
	cp ' '
	jr z,f_a5
	ld a,'.'
	ld (de),a
	inc de
	ld b,3
f_a4:	ld a,(hl)
	cp ' '
	jr z,f_a5
	ld (de),a
	inc de
	inc hl
	djnz f_a4
f_a5:	ld a,5Ch
	ld (de),a
	inc de
	xor a
	ld (de),a
	ld a,e
	ld (plen),a
	or a
	ret
; HL=接尾の文字列: sbuf = pbuf + HL を FCB に解析して検索の準備
f_mk:	push hl
	ld hl,pbuf
	ld de,sbuf
f_m1:	ld a,(hl)
	ld (de),a
	or a
	jr z,f_m2
	inc hl
	inc de
	jr f_m1
f_m2:	pop hl
f_m3:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,f_m3
	ld hl,fcb
	ld de,fcb+1
	ld (hl),0
	ld bc,47
	ldir
	ld hl,fcb
	ld de,sbuf
	ld c,29h
	call 5
	ld a,0F1h
	ld (fcb+13),a
	ld hl,sbuf
f_m4:	ld a,(hl)
	or a
	jr z,f_m6
	inc hl
	cp '*'
	jr nz,f_m4
	ld a,(fcb+9)
	cp ' '
	jr nz,f_m6
	ld hl,fcb+9
	ld (hl),'?'
	inc hl
	ld (hl),'?'
	inc hl
	ld (hl),'?'
f_m6:	ld a,(fcb+1)
	cp ' '
	ret nz
	ld hl,fcb+1
	ld de,fcb+2
	ld (hl),'?'
	ld bc,10
	ldir
	ret
; 現在のサブディレクトリ(検索結果 dtabuf)を収集領域へ
f_col:	ld a,(dtabuf+12)
	and 10h
	ret z
	ld a,(dtabuf+1)
	cp '.'
	ret z
	call f_lvp
	ld a,(hl)
	cp 40
	ret nc
	ld c,a
	inc a
	ld (hl),a
	inc hl
	ld de,11
	ld a,c
	or a
	jr z,f_c2
f_c1:	add hl,de
	dec a
	jr nz,f_c1
f_c2:	ex de,hl
	ld hl,dtabuf+1
	ld bc,11
	ldir
	ret
; 検索結果が条件に合えば出力
f_ent:	ld a,(dtabuf+12)
	and 08h
	ret nz
	ld a,(dtabuf+1)
	cp '.'
	ret z
	ld a,(f_ty)
	or a
	jr z,f_e1
	ld b,a
	ld a,(dtabuf+12)
	and 10h
	jr z,f_e0
	ld a,b
	cp 2
	ret z
	jr f_e1
f_e0:	ld a,b
	cp 1
	ret z
f_e1:	ld hl,pbuf
	call wrs
	ld hl,dtabuf+1
	push hl
	ld b,8
f_f1:	ld a,(hl)
	cp ' '
	jr z,f_f3
	call wrb
	inc hl
	djnz f_f1
f_f3:	pop hl
	ld de,8
	add hl,de
	ld a,(hl)
	cp ' '
	jr z,f_f5
	ld a,'.'
	call wrb
	ld b,3
f_f4:	ld a,(hl)
	cp ' '
	jr z,f_f5
	call wrb
	inc hl
	djnz f_f4
f_f5:	ld a,(dtabuf+12)
	and 10h
	jr z,f_e2
	ld a,5Ch
	call wrb
f_e2:	jp wcrlf
f_ty:	defb 0
plen:	defb 0
dep:	defb 0
f_dall:	defm "*.*",0
f_mus:	defm "usage: find [path] [-name pattern] [-type d|f]",13,10,"$"
fcb	equ 4400h
dtabuf	equ 4440h
patb	equ 4480h
pbuf	equ 4500h
sbuf	equ 4560h
''')

# ---------------- which ----------------
w('which', r'''; WHICH.COM - コマンドがどこにあるか。 which name ...   MIT License
;   内蔵コマンドか、カレントディレクトリか、PATH のどのディレクトリの .COM / .BAT か(コマンドの探し順と同じ)。終了コード $? : 全部見つかった 0 / 無いものがあった 1
'''+HDR+r'''	call tailinit
	ld de,dtabuf
	ld c,1Ah
	call 5
	xor a
	ld (w_bad),a
	ld (w_any),a
	ld hl,w_pn
	ld de,penv
	ld c,6Bh
	call 5
w_nx:	ld hl,0081h
	ld a,(w_any)
	or a
	jr z,w_f
	ld hl,(w_nxt)
w_f:	call sk
	or a
	jp z,w_end
	ld a,1
	ld (w_any),a
	ld d,h
	ld e,l
	call tokend
	ld (w_nxt),hl
	ex de,hl
	ld de,nm
	ld b,12
	xor a
	ld (w_dot),a
w_c1:	ld a,(hl)
	or a
	jr z,w_c3
	cp 'a'
	jr c,w_c2
	cp '{'
	jr nc,w_c2
	sub 20h
w_c2:	cp '.'
	jr nz,w_c4
	ld (w_dot),a
w_c4:	ld (de),a
	inc hl
	inc de
	djnz w_c1
w_c3:	xor a
	ld (de),a
	ld a,(nm)
	or a
	jr z,w_nx
	ld a,(w_dot)
	or a
	jr nz,w_cwd
	ld hl,nm
	ld de,w_pad
	ld b,4
w_p1:	ld a,(hl)
	or a
	jr z,w_p2
	ld (de),a
	inc hl
	inc de
	djnz w_p1
	ld a,(hl)
	or a
	jr nz,w_cwd
	jr w_p3
w_p2:	ld a,' '
w_p4:	ld (de),a
	inc de
	djnz w_p4
w_p3:	ld hl,w_tbl
	ld b,14
w_t1:	push bc
	ld de,w_pad
	ld b,4
w_t2:	ld a,(de)
	cp (hl)
	jr nz,w_t3
	inc de
	inc hl
	djnz w_t2
	pop bc
	ld hl,nm
	call w_pr
	ld hl,w_mbi
	call wrs
	call wcrlf
	jr w_nx
w_t3:	ld a,b
	ld c,a
	ld b,0
	add hl,bc
	pop bc
	djnz w_t1
w_cwd:	xor a
	ld (pfx),a
	call w_srch
	jr c,w_pth
	ld hl,w_mcw
	call wrs
	call wcrlf
	jp w_nx
w_pth:	ld hl,penv
w_e1:	ld a,(hl)
	cp ';'
	jr nz,w_e2
	inc hl
	jr w_e1
w_e2:	or a
	jr z,w_nf
	ld de,pfx
	ld b,70
w_e3:	ld a,(hl)
	or a
	jr z,w_e4
	cp ';'
	jr z,w_e4
	ld (de),a
	inc hl
	inc de
	djnz w_e3
w_e4:	push hl
	ld hl,pfx
	or a
	sbc hl,de
	jr z,w_e6
	dec de
	ld a,(de)
	inc de
	cp 5Ch
	jr z,w_e6
	cp ':'
	jr z,w_e6
	ld a,5Ch
	ld (de),a
	inc de
w_e6:	xor a
	ld (de),a
	call w_srch
	pop hl
	jr c,w_e1
	call wcrlf
	jp w_nx
w_nf:	ld hl,w_mnf1
	call wrs
	ld hl,nm
	call wrs
	ld hl,w_mnf2
	call wrs
	call wcrlf
	ld a,1
	ld (w_bad),a
	jp w_nx
w_end:	call flush
	ld a,(w_bad)
	ld b,a
	ld c,62h
	call 5
	jp 0
; 出力: HL=0終端文字列を出して ": " を足す
w_pr:	call wrs
	ld a,':'
	call wrb
	ld a,' '
	jp wrb
; pfx + nm (拡張子なしなら .???) を検索。見つかれば (名前を出力して) CF=0 / 無ければ CF=1
w_srch:	ld hl,pfx
	ld de,sbuf
w_s1:	ld a,(hl)
	ld (de),a
	or a
	jr z,w_s2
	inc hl
	inc de
	jr w_s1
w_s2:	ld hl,nm
w_s3:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,w_s3
	ld a,(w_dot)
	or a
	jr nz,w_s5
	dec de
	ld hl,w_ext
	ld bc,5
	ldir
w_s5:	ld hl,fcb
	ld de,fcb+1
	ld (hl),0
	ld bc,47
	ldir
	ld hl,fcb
	ld de,sbuf
	ld c,29h
	call 5
	ld a,0F1h
	ld (fcb+13),a
	ld de,fcb
	ld c,11h
w_s6:	call 5
	or a
	jr nz,w_sn
	ld a,(dtabuf+12)
	and 18h
	jr nz,w_s7
	ld a,(w_dot)
	or a
	jr nz,w_s8
	ld a,(dtabuf+9)
	or 20h
	cp 'b'
	jr z,w_s8
	cp 'c'
	jr z,w_s8
w_s7:	ld de,fcb
	ld c,12h
	jr w_s6
w_s8:	ld hl,pfx
	call wrs
	ld hl,dtabuf+1
	push hl
	ld b,8
w_f1:	ld a,(hl)
	cp ' '
	jr z,w_f3
	call wrb
	inc hl
	djnz w_f1
w_f3:	pop hl
	ld de,8
	add hl,de
	ld a,(hl)
	cp ' '
	jr z,w_f5
	ld a,'.'
	call wrb
	ld b,3
w_f4:	ld a,(hl)
	cp ' '
	jr z,w_f5
	call wrb
	inc hl
	djnz w_f4
w_f5:	ld a,(pfx)
	or a
	jr nz,w_f6
	ld a,' '
	call wrb
w_f6:	or a
	ret
w_sn:	scf
	ret
w_pn:	defm "PATH",0
w_ext:	defm ".???",0
w_tbl:	defm "D   DIR COPYCD  DEL PATHREN REM MON SET ENV GOTOIF  MODE"
w_mbi:	defm "built-in command",0
w_mcw:	defm "(current directory)",0
w_mnf1:	defm "which: ",0
w_mnf2:	defm " not found",0
w_bad:	defb 0
w_any:	defb 0
w_dot:	defb 0
w_nxt:	defw 0
w_pad:	defm "    "
nm	equ 4400h
pfx	equ 4410h
penv	equ 4460h
sbuf	equ 44B0h
fcb	equ 4520h
dtabuf	equ 4550h
''')

# ---------------- mv ----------------
w('mv', r'''; MV.COM - ファイルの名前変更・移動。 mv from to     MIT License
;   from にも to にも \ : / が無ければ同じディレクトリ内の名前変更(内蔵 REN と同じで * ? は不可。ディレクトリ名も変えられる)。どちらかにあれば to へコピーして from を消す(* ? 不可)。
;   to が \ か : で終わるときはその中へ(名前は from のまま)。to が既にあるときは何もしない。
'''+HDR+r'''	call tailinit
	call sk
	or a
	jp z,m_us
	ld d,h
	ld e,l
	call tokend
	ld (m_s),de
	call sk
	or a
	jp z,m_us
	ld d,h
	ld e,l
	call tokend
	ld (m_d),de
	ld de,dtabuf
	ld c,1Ah
	call 5
	ld hl,(m_s)
	call m_pth
	jr c,m_cp
	ld hl,(m_d)
	call m_pth
	jr c,m_cp
m_rn:	call m_clr
	ld hl,fcb
	ld de,(m_s)
	ld c,29h
	call 5
	ld hl,fcb+16
	ld de,(m_d)
	ld c,29h
	call 5
	ld a,10h
	ld (fcb+13),a
	ld de,fcb
	ld c,17h
	call 5
	or a
	ld de,m_mrf
	jr nz,m_msg
m_ok:	ld b,0
	jr m_fin
m_msg:	ld c,9
	call 5
	ld b,1
m_fin:	ld c,62h
	call 5
	jp 0
; HL=文字列に \ / : があれば CF=1
m_pth:	ld a,(hl)
	or a
	ret z
	cp 5Ch
	jr z,m_p1
	cp '/'
	jr z,m_p1
	cp ':'
	jr z,m_p1
	inc hl
	jr m_pth
m_p1:	scf
	ret
m_clr:	ld hl,fcb
	ld de,fcb+1
	ld (hl),0
	ld bc,63
	ldir
	ret
m_cp:	ld hl,(m_d)
	ld de,tbuf
m_c1:	ld a,(hl)
	ld (de),a
	or a
	jr z,m_c2
	inc hl
	inc de
	jr m_c1
m_c2:	dec de
	ld a,(de)
	inc de
	cp 5Ch
	jr z,m_ap
	cp '/'
	jr z,m_ap
	cp ':'
	jr nz,m_c4
m_ap:	ld hl,(m_s)
	ld b,h
	ld c,l
m_b1:	ld a,(hl)
	or a
	jr z,m_b2
	inc hl
	cp 5Ch
	jr z,m_bs
	cp '/'
	jr z,m_bs
	cp ':'
	jr nz,m_b1
m_bs:	ld b,h
	ld c,l
	jr m_b1
m_b2:	ld h,b
	ld l,c
m_b3:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,m_b3
m_c4:	ld de,tbuf
	ld a,1
	ld c,43h
	call 5
	or a
	jr nz,m_c5
	ld c,45h
	call 5
	ld de,m_mex
	jr m_msg
m_c5:	ld de,(m_s)
	ld a,1
	ld c,43h
	call 5
	or a
	ld de,m_mos
	jr nz,m_msg
	ld a,b
	ld (m_h1),a
	ld de,tbuf
	xor a
	ld b,a
	ld c,44h
	call 5
	or a
	ld de,m_mcf
	jr nz,m_msg
	ld a,b
	ld (m_h2),a
m_lp:	ld a,(m_h1)
	ld b,a
	ld de,buf
	ld hl,1024
	ld c,48h
	call 5
	or a
	jr z,m_rk
	cp 0C7h
	jr z,m_dn
	ld de,m_mre
	jr m_msg
m_rk:	ld a,h
	or l
	jr z,m_dn
	ld a,(m_h2)
	ld b,a
	ld de,buf
	ld c,49h
	call 5
	or a
	jr z,m_lp
	ld de,m_mwe
	jr m_msg
m_dn:	ld a,(m_h1)
	ld b,a
	ld c,45h
	call 5
	ld a,(m_h2)
	ld b,a
	ld c,45h
	call 5
	call m_clr
	ld hl,fcb
	ld de,(m_s)
	ld c,29h
	call 5
	ld de,fcb
	ld c,13h
	call 5
	or a
	jr z,m_ok
	ld de,m_mdf
	jr m_msg
m_us:	ld de,m_mus
	ld c,9
	call 5
	jp 0
m_s:	defw 0
m_d:	defw 0
m_h1:	defb 0
m_h2:	defb 0
m_mus:	defm "usage: mv from to",13,10,"$"
m_mrf:	defm "mv: cannot rename",13,10,"$"
m_mex:	defm "mv: target exists",13,10,"$"
m_mos:	defm "mv: cannot open source",13,10,"$"
m_mcf:	defm "mv: cannot create target",13,10,"$"
m_mre:	defm "mv: read error (source kept)",13,10,"$"
m_mwe:	defm "mv: write error (source kept)",13,10,"$"
m_mdf:	defm "mv: copied, but cannot delete source",13,10,"$"
fcb	equ 4400h
dtabuf	equ 4440h
tbuf	equ 4470h
buf	equ 4500h
''')

# ---------------- date ----------------
w('date', r'''; DATE.COM - 日付と時刻の表示・設定 (RP5C15)。 date | date YYYY-MM-DD | date HH:MM[:SS] | 両方   MIT License
;   表示は YYYY-MM-DD HH:MM:SS。設定は 2000-2099 年のみ。24時間表示の前提 (実機は未確認)
'''+HDR+r'''	call tailinit
	call sk
	or a
	jp z,da_sh
da_lp:	call sk
	or a
	jp z,da_fin
	call atoi
	ld a,(hl)
	cp '-'
	jr z,da_d
	cp ':'
	jp z,da_t
da_us:	ld de,da_mus
	ld c,9
	call 5
	jp 0
da_d:	ld (da_y),de
	inc hl
	call atoi
	ld a,e
	ld (da_m),a
	ld a,(hl)
	cp '-'
	jr nz,da_us
	inc hl
	call atoi
	ld a,e
	ld (da_dd),a
	ld a,1
	ld (da_sd),a
	jr da_lp
da_t:	ld a,e
	ld (da_h),a
	inc hl
	call atoi
	ld a,e
	ld (da_mi),a
	xor a
	ld (da_s),a
	ld a,(hl)
	cp ':'
	jr nz,da_t2
	inc hl
	call atoi
	ld a,e
	ld (da_s),a
da_t2:	ld a,1
	ld (da_st),a
	jr da_lp
da_fin:	ld a,(da_sd)
	or a
	jr z,da_f2
	ld hl,(da_y)
	ld de,2000
	or a
	sbc hl,de
	jp c,da_us
	ld de,100
	or a
	sbc hl,de
	jp nc,da_us
	add hl,de
	ld a,l
	ld (da_yy),a
	ld a,(da_m)
	or a
	jp z,da_us
	cp 13
	jp nc,da_us
	ld a,(da_dd)
	or a
	jp z,da_us
	cp 32
	jp nc,da_us
da_f2:	ld a,(da_st)
	or a
	jr z,da_f3
	ld a,(da_h)
	cp 24
	jp nc,da_us
	ld a,(da_mi)
	cp 60
	jp nc,da_us
	ld a,(da_s)
	cp 60
	jp nc,da_us
da_f3:	call rtcbk0
	ld a,(da_sd)
	or a
	jp z,da_f4
	ld a,(da_yy)
	ld b,11
	call wr2
	ld a,(da_m)
	ld b,9
	call wr2
	ld a,(da_dd)
	ld b,7
	call wr2
	call dow
	ld b,6
	ld c,0CCh
	out (c),a
da_f4:	ld a,(da_st)
	or a
	jp z,da_sh
	ld a,(da_h)
	ld b,4
	call wr2
	ld a,(da_mi)
	ld b,2
	call wr2
	ld a,(da_s)
	ld b,0
	call wr2
da_sh:	ld c,2Ah
	call 5
	ld (da_yv),hl
	ld a,d
	ld (da_m),a
	ld a,e
	ld (da_dd),a
	ld c,2Ch
	call 5
	ld a,h
	ld (da_h),a
	ld a,l
	ld (da_mi),a
	ld a,d
	ld (da_s),a
	call da_pyr
	ld a,'-'
	call wrb
	ld a,(da_m)
	call p2
	ld a,'-'
	call wrb
	ld a,(da_dd)
	call p2
	ld a,' '
	call wrb
	ld a,(da_h)
	call p2
	ld a,':'
	call wrb
	ld a,(da_mi)
	call p2
	ld a,':'
	call wrb
	ld a,(da_s)
	call p2
	call wcrlf
	call flush
	jp 0
da_pyr:	ld hl,(da_yv)
	ld de,0
	ld b,4
	call pnum
	ret
; A=0..99 を2桁で出力
p2:	ld b,0
p2a:	cp 10
	jr c,p2b
	sub 10
	inc b
	jr p2a
p2b:	push af
	ld a,b
	add a,'0'
	call wrb
	pop af
	add a,'0'
	jp wrb
; A=0..99 を B=下位桁レジスタ(+1が上位桁)へ書く
wr2:	ld d,0
wr2a:	cp 10
	jr c,wr2b
	sub 10
	inc d
	jr wr2a
wr2b:	ld c,0CCh
	out (c),a
	inc b
	ld a,d
	out (c),a
	ret
rtcbk0:	ld b,0Dh
	ld c,0CCh
	in a,(c)
	and 0Eh
	out (c),a
	ret
; 曜日 A (0=日) を da_yy,da_m,da_dd から
dow:	ld a,(da_yy)
	ld b,a
	ld a,(da_m)
	cp 3
	jr nc,dw1
	ld a,b
	or a
	jr nz,dw0
	ld b,0FFh		; 1999 (a=-1): a+a/4 = -2 = 5 (mod 7)
	ld c,5
	jr dw2
dw0:	dec b
dw1:	ld a,b
	rrca
	rrca
	and 3Fh
	add a,b
	ld c,a
dw2:	ld a,(da_m)
	ld e,a
	ld d,0
	ld hl,da_tt-1
	add hl,de
	ld a,(hl)
	add a,c
	ld hl,da_dd
	add a,(hl)
	ld b,7
dw3:	cp 7
	jr c,dw4
	sub 7
	jr dw3
dw4:	ret
da_tt:	defb 0,3,2,5,0,3,5,1,4,6,2,4
da_y:	defw 0
da_yv:	defw 0
da_yy:	defb 0
da_m:	defb 0
da_dd:	defb 0
da_h:	defb 0
da_mi:	defb 0
da_s:	defb 0
da_sd:	defb 0
da_st:	defb 0
da_mus:	defm "usage: date [YYYY-MM-DD] [HH:MM[:SS]]",13,10,"$"
''')
