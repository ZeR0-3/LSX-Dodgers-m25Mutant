#!/usr/bin/env python3
# coms/{du,df,cp}.asm を生成する (find と同じ「サブディレクトリをたどる部分」を共有する)
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'coms')
src = open(os.path.join(HERE, 'gencoms.py'), encoding='utf-8').read()
LIB = re.search(r"LIB=r'''(.*?)'''\ndef w\(", src, re.S).group(1)
src2 = open(os.path.join(HERE, 'gencoms2.py'), encoding='utf-8').read()
fsrc = re.search(r"w\('find', r'''.*?\nw\('which'", src2, re.S).group(0)
a = fsrc.index('f_walk:')
b = fsrc.index('; 検索結果が条件に合えば出力')
WALK = fsrc[a:b]
old = "\tcall f_app\n\tjr c,f_r4\n\tld a,(dep)\n\tinc a\n\tld (dep),a\n\tcall f_walk\n\tld a,(dep)\n\tdec a\n\tld (dep),a\nf_r4:"
new = "\tcall f_app\n\tjr c,f_r4\n\tcall f_pre\n\tld a,(dep)\n\tinc a\n\tld (dep),a\n\tcall f_walk\n\tld a,(dep)\n\tdec a\n\tld (dep),a\n\tcall f_post\nf_r4:"
assert old in WALK
WALK = WALK.replace(old, new)
HDR = '''	org 0100h
	ld sp,0A000h
'''
LONG = {'du': [], 'cp': [], 'df': []}
def w(name, body):
    open(os.path.join(OUT, name + '.asm'), 'w', encoding='utf-8').write(body + LIB)

# 引数の「パス」(find と同じ処理): HL=トークン先頭 -> pbuf に末尾を \ にして保存、plen 設定。 push/pop で HL を保つ
PATHARG = r'''	ld d,h
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
'''

# ---------------- du ----------------
w('du', r'''; DU.COM - ディレクトリごとのファイルサイズの合計。 du [-s] [-k] [path]   MIT License
;   path 省略=カレント。各ディレクトリ(サブも含む)の合計を、下のディレクトリから順に出す。 -s : 最後の合計だけ  -k : KB単位(切り上げ)。
;   単位は既定でバイト。ファイルの大きさの合計であり、クラスタ単位の使用量ではない。深さ8階層まで、1つのディレクトリにサブディレクトリ40個まで。
'''+HDR+r'''	call tailinit
	xor a
	ld (plen),a
	ld (dep),a
	ld (pbuf),a
	ld (d_s),a
	ld (d_k),a
	ld hl,f_dall
	ld de,patb
	ld bc,4
	ldir
	ld hl,0081h
d_ar:	call sk
	or a
	jp z,d_go
	cp '-'
	jr nz,d_pa
d_op:	inc hl
	ld a,(hl)
	or 20h
	cp 's'
	jr z,d_o1
	cp 'k'
	jp nz,d_us
	ld (d_k),a
	jr d_o2
d_o1:	ld (d_s),a
d_o2:	inc hl
	ld a,(hl)
	cp ' '
	jr z,d_ar
	or a
	jp z,d_go
	jr d_op
d_pa:
'''+PATHARG+r'''	jr d_ar
d_go:	ld de,dtabuf
	ld c,1Ah
	call 5
	ld hl,duacc
	ld (hl),0
	ld de,duacc+1
	ld bc,40
	ldir
	call f_walk
	xor a
	ld (dep),a
	call d_pr
	call flush
	jp 0
d_us:	ld de,d_mus
	ld c,9
	call 5
	jp 0
'''+WALK+r'''
; 深さ dep の合計 -> HL
d_acc:	ld a,(dep)
	add a,a
	add a,a
	ld e,a
	ld d,0
	ld hl,duacc
	add hl,de
	ret
; サブディレクトリに入る前: 次の深さの合計を0に
f_pre:	ld a,(dep)
	inc a
	ld (dep),a
	call d_acc
	ld (hl),0
	inc hl
	ld (hl),0
	inc hl
	ld (hl),0
	inc hl
	ld (hl),0
	ld a,(dep)
	dec a
	ld (dep),a
	ret
; サブディレクトリから戻った後 (dep=親の深さ): 子の合計を出して親に足す
f_post:	ld a,(d_s)
	or a
	jr nz,fp1
	ld a,(dep)
	inc a
	ld (dep),a
	call d_pr
	ld a,(dep)
	dec a
	ld (dep),a
fp1:	ld a,(dep)
	inc a
	ld (dep),a
	call d_acc
	push hl
	ld a,(dep)
	dec a
	ld (dep),a
	call d_acc
	ex de,hl
	pop hl
	ld b,4
	or a
fp2:	ld a,(de)
	adc a,(hl)
	ld (de),a
	inc hl
	inc de
	djnz fp2
	ret
; 深さ dep の合計と pbuf を1行で出す
d_pr:	call d_acc
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	ex de,hl		; HL=下位16 BC=上位16
	ld d,b
	ld e,c			; DEHL
	ld a,(d_k)
	or a
	jr z,dp2
	ld bc,1023
	add hl,bc
	jr nc,dp1
	inc de
dp1:	ld b,10
dp3:	srl d
	rr e
	rr h
	rr l
	djnz dp3
dp2:	ld b,9
	call pnum
	ld a,' '
	call wrb
	ld a,(pbuf)
	or a
	jr nz,dp4
	ld a,'.'
	call wrb
	jp wcrlf
dp4:	ld hl,pbuf
	call wrs
	jp wcrlf
; 検索結果のファイルの大きさを深さ dep の合計に足す
f_ent:	ld a,(dtabuf+12)
	and 18h
	ret nz
	ld a,(dtabuf+1)
	cp '.'
	ret z
	call d_acc
	ld de,dtabuf+29
	ld b,4
	or a
fe1:	ld a,(de)
	adc a,(hl)
	ld (hl),a
	inc hl
	inc de
	djnz fe1
	ret
d_s:	defb 0
d_k:	defb 0
plen:	defb 0
dep:	defb 0
f_dall:	defm "*.*",0
d_mus:	defm "usage: du [-s] [-k] [path]",13,10,"$"
fcb	equ 4400h
dtabuf	equ 4440h
patb	equ 4480h
pbuf	equ 4500h
sbuf	equ 4560h
duacc	equ 4600h
''')

# ---------------- df ----------------
w('df', r'''; DF.COM - ドライブの容量。 df [d: ...]   MIT License
;   引数なし=カレントドライブ。 d: を並べればそれぞれ。 全体・使用中・空き (KB)。 df * で A:-H: のうち使えるもの全部。
'''+HDR+r'''	call tailinit
	ld de,hdr
	ld c,9
	call 5
	call sk
	or a
	jr nz,g_ar
	ld c,19h		; 現在のドライブ
	call 5
	inc a
	call g_one
	jp g_end
g_ar:	call sk
	or a
	jp z,g_end
	cp '*'
	jr z,g_all
	or 20h
	sub 'a'-1
	jp c,g_us
	cp 9
	jp nc,g_us
	call g_one
	inc hl
	ld a,(hl)
	cp ':'
	jr nz,g_ar
	inc hl
	jr g_ar
g_all:	inc hl
	push hl
	ld a,1
g_a1:	push af
	call g_one
	pop af
	inc a
	cp 9
	jr c,g_a1
	pop hl
	jr g_ar
g_end:	call flush
	jp 0
g_us:	ld de,g_mus
	ld c,9
	call 5
	jp 0
; A=ドライブ(1=A) の1行 (使えなければ何も出さない)。HL を保つ
g_one:	push hl
	ld (g_dr),a
	ld e,a
	ld c,1Bh
	call 5
	cp 0FFh
	jp z,g_ret
	or a
	jp z,g_ret
	ld (g_sc),a
	ld a,b
	ld (g_ssz),a		; 論理セクタの大きさ/256
	ld (g_tot),de
	ld (g_fre),hl
	ld a,(g_sc)
	ld b,a
	ld a,(g_ssz)
	ld c,a			; C=セクタ/256
	xor a
	ld d,a
g_m1:	add a,c			; A = クラスタあたりの 256B 単位数
	djnz g_m1
	ld (g_u),a
	ld a,(g_dr)
	add a,'A'-1
	call wrb
	ld a,':'
	call wrb
	ld hl,(g_tot)
	call g_kb		; DEHL = KB
	push de
	push hl
	ld b,9
	call pnum
	ld hl,(g_fre)
	call g_kb		; DEHL = 空きKB
	ld (g_f1),hl
	ld (g_f2),de
	pop hl
	pop de			; DEHL = 全体
	ld bc,(g_f1)
	or a
	sbc hl,bc
	ex de,hl
	ld bc,(g_f2)
	sbc hl,bc
	ex de,hl		; DEHL = 使用中
	ld b,9
	call pnum
	ld hl,(g_f1)
	ld de,(g_f2)
	ld b,9
	call pnum
	call wcrlf
g_ret:	pop hl
	ret
; HL=クラスタ数 -> DEHL = HL * (g_u) / 4
g_kb:	ld de,0
	ld b,h
	ld c,l
	ld hl,0
	ld a,(g_u)
	or a
	jr z,gk2
gk1:	add hl,bc
	jr nc,gk0
	inc de
gk0:	dec a
	jr nz,gk1
gk2:	srl d
	rr e
	rr h
	rr l
	srl d
	rr e
	rr h
	rr l
	ret
g_dr:	defb 0
g_sc:	defb 0
g_ssz:	defb 0
g_u:	defb 0
g_tot:	defw 0
g_fre:	defw 0
g_f1:	defw 0
g_f2:	defw 0
hdr:	defm "KB       Total     Used     Free",13,10,"$"
g_mus:	defm "usage: df [d: ... | *]",13,10,"$"
''')

# ---------------- cp ----------------
w('cp', r'''; CP.COM - ファイルのコピー。 cp [-r] from to   MIT License
;   cp FILE to          : to が既存のディレクトリ(または \ : で終わる)ならその中へ、そうでなければ to という名前へ。既にあれば上書き
;   cp *.TXT dir        : ワイルドカードのファイルを dir (既存、または \ : で終わる)へ。サブディレクトリは対象外
;   cp -r DIR to        : ディレクトリごとコピー。to が既存のディレクトリなら to\DIR、無ければ to という名前で作る。深さ8階層まで、1つのディレクトリにサブディレクトリ40個まで
;   終了コード $? : 全部成功 0 / 失敗あり 1。成功時は何も出さない。 自分自身の中へのコピーはしない(同じ名前なら "same file")。
'''+HDR+r'''	call tailinit
	xor a
	ld (c_r),a
	ld (c_err),a
	ld (c_dd),a
	ld (plen),a
	ld (dep),a
	ld (pbuf),a
	ld hl,0
	ld (c_s),hl
	ld (c_d),hl
	ld hl,f_dall
	ld de,patb
	ld bc,4
	ldir
	ld hl,0081h
c_ar:	call sk
	or a
	jp z,c_go
	cp '-'
	jr nz,c_na
	inc hl
	ld a,(hl)
	or 20h
	cp 'r'
	jp nz,c_us
	ld (c_r),a
	call tokend
	jr c_ar
c_na:	ld d,h
	ld e,l
	call tokend
	ld bc,(c_s)
	ld a,b
	or c
	jr nz,c_n2
	ld (c_s),de
	jr c_ar
c_n2:	ld bc,(c_d)
	ld a,b
	or c
	jp nz,c_us
	ld (c_d),de
	jr c_ar
c_go:	ld hl,(c_s)
	ld a,h
	or l
	jp z,c_us
	ld hl,(c_d)
	ld a,h
	or l
	jp z,c_us
	ld de,dtabuf
	ld c,1Ah
	call 5
; --- 行き先を droot へ。末尾が \ / : なら c_dd=1、既存ディレクトリなら \ を足して c_dd=1
	ld hl,(c_d)
	ld de,droot
	ld b,70
c_d1:	ld a,(hl)
	ld (de),a
	or a
	jr z,c_d2
	inc hl
	inc de
	djnz c_d1
	xor a
	ld (de),a
c_d2:	ld hl,droot
	or a
	sbc hl,de
	jp z,c_us
	dec de
	ld a,(de)
	inc de
	cp 5Ch
	jr z,c_dy
	cp '/'
	jr z,c_dy
	cp ':'
	jr z,c_dy
	ld hl,droot
	call c_find
	or a
	jr nz,c_d3
	ld a,(dtabuf+12)
	and 10h
	jr z,c_d3
	ld a,5Ch
	ld (de),a
	inc de
	xor a
	ld (de),a
c_dy:	ld a,1
	ld (c_dd),a
c_d3:
; --- 元: ワイルドカードの有無と、最後の \ / : の次(名前部分)
	ld hl,(c_s)
	ld (c_sb),hl
	xor a
	ld (c_wc),a
c_w1:	ld a,(hl)
	or a
	jr z,c_w9
	inc hl
	cp '*'
	jr z,c_w2
	cp '?'
	jr z,c_w2
	cp 5Ch
	jr z,c_w3
	cp '/'
	jr z,c_w3
	cp ':'
	jr nz,c_w1
c_w3:	ld (c_sb),hl
	jr c_w1
c_w2:	ld a,1
	ld (c_wc),a
	jr c_w1
c_w9:	ld a,(c_wc)
	or a
	jr z,c_one
; --- ワイルドカード: 一致するファイルを行き先(ディレクトリ)へ
	ld a,(c_dd)
	or a
	jp z,c_ndir
	ld hl,(c_s)
	call c_mk
	ld de,fcb
	ld c,11h
c_wl:	call 5
	or a
	jp nz,c_done
	ld a,(dtabuf+12)
	and 18h
	jr nz,c_wn
	call c_names
	call c_copy
c_wn:	ld de,fcb
	ld c,12h
	jr c_wl
; --- ワイルドカード無し
c_one:	ld hl,(c_s)
	call c_find
	or a
	ld de,c_mnf
	jp nz,c_msg
	ld a,(dtabuf+12)
	and 10h
	jp nz,c_tree
	ld hl,s1buf
	ex de,hl
	ld hl,(c_s)
	call c_str
	ld de,s2buf
	ld hl,droot
	call c_str
	ld a,(c_dd)
	or a
	jr z,c_o2
	ld hl,(c_sb)
	call c_str
c_o2:	call c_chkdir
	ld de,c_mnp
	jp nz,c_pmsg2
	call c_copy
	jp c_done
; 行き先 s2buf の親ディレクトリがあるか。 Z=ある (親が無指定/ドライブ直下ならある)
c_chkdir:
	ld hl,s2buf
	ld de,0
c_k1:	ld a,(hl)
	or a
	jr z,c_k3
	inc hl
	cp 5Ch
	jr z,c_k2
	cp '/'
	jr z,c_k2
	cp ':'
	jr nz,c_k1
	jr c_k1
c_k2:	ld d,h
	ld e,l
	dec de			; DE = 区切りの位置
	jr c_k1
c_k3:	ld a,d
	or e
	ret z			; 区切り無し
	ld hl,s2buf
	or a
	sbc hl,de
	jr z,c_kok		; 先頭の \ : ルート
	push de
	ld hl,s2buf
	ld de,tmpn
	call c_str
	pop de
	ld hl,tmpn
	ld bc,s2buf
	ex de,hl
	or a
	sbc hl,bc		; HL = 区切りの位置のオフセット
	ld de,tmpn
	add hl,de
	dec hl
	ld a,(hl)
	inc hl
	cp ':'
	jr z,c_kok		; "b:" ドライブ直下
	ld (hl),0
	ld hl,tmpn
	call c_find
	or a
	jr nz,c_kng
	ld a,(dtabuf+12)
	and 10h
	jr z,c_kng
c_kok:	xor a
	ret
c_kng:	or 1
	ret
c_pmsg2:	ld hl,s2buf
	ld de,c_mcp
	push hl
	ld c,9
	call 5
	pop hl
c_pq:	ld a,(hl)
	or a
	jr z,c_pr
	ld e,a
	ld c,2
	push hl
	call 5
	pop hl
	inc hl
	jr c_pq
c_pr:	ld de,c_mnp
	jp c_msg
; --- ディレクトリ
c_tree:	ld a,(c_r)
	or a
	ld de,c_mdr
	jp z,c_msg
	ld hl,(c_s)
	ld de,pbuf
	call c_str
	dec de
	ld a,(de)
	inc de
	cp 5Ch
	jr z,c_t1
	cp ':'
	jr z,c_t1
	cp '/'
	jr z,c_t1
	ld a,5Ch
	ld (de),a
	inc de
	xor a
	ld (de),a
c_t1:	ld hl,pbuf
	ex de,hl
	or a
	sbc hl,de
	ld a,l
	ld (plen),a
	ld (c_rb),a
	ld a,(c_dd)
	or a
	jr z,c_t4
; 行き先 + 元のディレクトリ名 (元の末尾の \ は除く)
	ld hl,(c_sb)
	ld a,(hl)
	or a
	jr nz,c_t2
	ld hl,pbuf		; 元が "dir\" の形: 名前は pbuf の最後の \ の前の部分
	ld (c_sb),hl
	ld hl,pbuf
c_t5:	ld a,(hl)
	or a
	jr z,c_t2
	inc hl
	cp 5Ch
	jr z,c_t6
	cp ':'
	jr nz,c_t5
c_t6:	ld a,(hl)
	or a
	jr z,c_t2
	ld (c_sb),hl
	jr c_t5
c_t2:	ld hl,droot
c_t3:	ld a,(hl)
	or a
	jr z,c_t7
	inc hl
	jr c_t3
c_t7:	ex de,hl
	ld hl,(c_sb)
c_t8:	ld a,(hl)
	or a
	jr z,c_t9
	cp 5Ch
	jr z,c_t9
	ld (de),a
	inc hl
	inc de
	jr c_t8
c_t9:	xor a
	ld (de),a
	jr c_ta
c_t4:	ld hl,droot
c_t4a:	ld a,(hl)
	or a
	jr z,c_ta
	inc hl
	jr c_t4a
c_ta:	ld a,(c_rb)
	call c_dsl		; droot の末尾を \ にする
	call c_mkroot
	jp nz,c_done
	call f_walk
	jp c_done
c_ndir:	ld de,c_mnd
c_msg:	ld c,9
	call 5
	ld a,1
	ld (c_err),a
c_done:	ld a,(c_err)
	ld b,a
	ld c,62h
	call 5
	jp 0
c_us:	ld de,c_mus
	ld c,9
	call 5
	ld b,1
	ld c,62h
	call 5
	jp 0
; 元の名前=c_s の \ より後ろ ...
; droot の末尾が \ : / でなければ \ を足す (A は使わない)
c_dsl:	ld hl,droot
c_ds1:	ld a,(hl)
	or a
	jr z,c_ds2
	inc hl
	jr c_ds1
c_ds2:	dec hl
	ld a,(hl)
	inc hl
	cp 5Ch
	ret z
	cp '/'
	ret z
	cp ':'
	ret z
	ld (hl),5Ch
	inc hl
	ld (hl),0
	ret
; ルートの行き先ディレクトリを作る。既にあれば何もしない。Z=成功
c_mkroot:
	ld hl,droot
	ld de,tmpn
	call c_str
	call c_strip
	ld de,tmpn
	jp c_mkd
; DE の ASCIIZ の末尾の \ を消す (":\" の形ならそのまま)
c_strip:
	ld hl,tmpn
c_sp1:	ld a,(hl)
	or a
	jr z,c_sp2
	inc hl
	jr c_sp1
c_sp2:	dec hl
	ld a,(hl)
	cp 5Ch
	ret nz
	dec hl
	ld a,(hl)
	inc hl
	cp ':'
	ret z
	ld (hl),0
	ret
; HL=ASCIIZ をコピー: DE へ。 終了時 DE=終端の0の位置
c_str:	ld a,(hl)
	ld (de),a
	or a
	ret z
	inc hl
	inc de
	jr c_str
; HL=名前の文字列 -> fcb に解析して検索 (属性 F1h)。 A=0 見つかった、結果は dtabuf
c_find:	push de
	push hl
	call c_clr
	pop de
	ld hl,fcb
	ld c,29h
	call 5
	ld a,0F1h
	ld (fcb+13),a
	ld de,fcb
	ld c,11h
	call 5
	pop de
	ret
c_clr:	ld hl,fcb
	ld de,fcb+1
	ld (hl),0
	ld bc,63
	ldir
	ret
; --- ワイルドカードの検索の準備: HL=パターン文字列
c_mk:	ld de,sbuf
	call c_str
	call c_clr
	ld hl,fcb
	ld de,sbuf
	ld c,29h
	call 5
	ld a,0F1h
	ld (fcb+13),a
	ret
; --- ワイルドカード: s1buf = 元のディレクトリ部分 + 名前、s2buf = droot + 名前
c_names:
	ld hl,(c_s)
	ld de,s1buf
c_nm1:	ld bc,(c_sb)
	ld a,h
	cp b
	jr nz,c_nm2
	ld a,l
	cp c
	jr z,c_nm3
c_nm2:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	jr c_nm1
c_nm3:	ld hl,dtabuf+1
	call c_83
	ld hl,droot
	ld de,s2buf
	call c_str
	ld hl,dtabuf+1
	jp c_83
; HL=11バイトの名前 -> DE に NAME.EXT\0 を書く。DE=終端の0
c_83:	ld b,8
c_a1:	ld a,(hl)
	cp ' '
	jr z,c_a2
	ld (de),a
	inc de
	inc hl
	djnz c_a1
c_a2:	ld a,b
	or a
	jr z,c_a3
	ld c,b
	ld b,0
	add hl,bc
c_a3:	ld a,(hl)
	cp ' '
	jr z,c_a5
	ld a,'.'
	ld (de),a
	inc de
	ld b,3
c_a4:	ld a,(hl)
	cp ' '
	jr z,c_a5
	ld (de),a
	inc de
	inc hl
	djnz c_a4
c_a5:	xor a
	ld (de),a
	ret
; --- walker のフック ---
f_pre:	ld hl,droot
	ld de,tmpn
	call c_str
	ld hl,pbuf
	ld a,(c_rb)
	ld c,a
	ld b,0
	add hl,bc
	call c_str
	call c_strip
	ld de,tmpn
	call c_mkd
	ret
f_post:	ret
; 検索結果が通常ファイルなら s1buf=pbuf+名前、s2buf=droot+(pbuf の c_rb 以降)+名前 を作ってコピー
f_ent:	ld a,(dtabuf+12)
	and 18h
	ret nz
	ld a,(dtabuf+1)
	cp '.'
	ret z
	ld hl,pbuf
	ld de,s1buf
	call c_str
	ld hl,dtabuf+1
	call c_83
	ld hl,droot
	ld de,s2buf
	call c_str
	ld a,(c_rb)
	ld c,a
	ld b,0
	ld hl,pbuf
	add hl,bc
	call c_str
	ld hl,dtabuf+1
	call c_83
; s1buf を s2buf へコピー (上書き)。失敗は c_err=1 にして続ける
c_copy:	ld hl,s1buf
	ld de,s2buf
cc0:	ld a,(de)
	xor (hl)
	and 0DFh
	jr nz,cc1
	ld a,(hl)
	or a
	jr z,cc9
	inc hl
	inc de
	jr cc0
cc9:	ld de,c_msm
	jp c_pmsg
cc1:	ld de,s1buf
	ld a,1
	ld c,43h
	call 5
	or a
	jr z,cc2
	ld de,c_mos
	jp c_pmsg
cc2:	ld a,b
	ld (c_h1),a
	ld de,s2buf
	xor a
	ld b,a
	ld c,44h
	call 5
	or a
	jr z,cc3
	ld a,(c_h1)
	ld b,a
	ld c,45h
	call 5
	ld de,c_mcf
	jp c_pmsg
cc3:	ld a,b
	ld (c_h2),a
cc4:	ld a,(c_h1)
	ld b,a
	ld de,cbuf
	ld hl,1024
	ld c,48h
	call 5
	or a
	jr z,cc5
	cp 0C7h
	jr z,cc8
	ld de,c_mre
	jr cc7
cc5:	ld a,h
	or l
	jr z,cc8
	ld a,(c_h2)
	ld b,a
	ld de,cbuf
	ld c,49h
	call 5
	or a
	jr z,cc4
	ld de,c_mwe
cc7:	call cc8
	jp c_pmsg
cc8:	ld a,(c_h1)
	ld b,a
	ld c,45h
	call 5
	ld a,(c_h2)
	ld b,a
	ld c,45h
	jp 5
; DE=メッセージ: 先頭に "cp: " と s1buf を付けて出す。c_err=1
c_pmsg:	push de
	ld de,c_mcp
	ld c,9
	call 5
	ld hl,s1buf
c_pm1:	ld a,(hl)
	or a
	jr z,c_pm2
	ld e,a
	ld c,2
	push hl
	call 5
	pop hl
	inc hl
	jr c_pm1
c_pm2:	pop de
	ld c,9
	call 5
	ld a,1
	ld (c_err),a
	ret
; DE=ディレクトリ名(末尾に \ なし) を作る。すでにあれば成功扱い。 Z=成功
c_mkd:	push de
	ld c,19h
	call 5
	push af
	ld c,0Dh
	call 5
	pop af
	ld e,a
	ld c,0Eh
	call 5
	ld de,dtabuf
	ld c,1Ah
	call 5
	call c_clr
	pop de
	ld hl,fcb
	ld c,29h
	call 5
	ld a,(fcb+1)
	cp ' '
	push af
	ld a,1
	ld (c_ecode),a
	pop af
	jp z,mk_er
	xor a
	ld (fcb+13),a
	ld de,fcb
	ld c,11h
	call 5
	or a
	jr nz,mk_nw
	ld a,(dtabuf+12)
	and 10h
	push af
	ld a,2
	ld (c_ecode),a
	pop af
	jp z,mk_er
	xor a
	ret
mk_nw:	call c_clr2
	ld de,fcb
	ld c,16h
	call 5
	or a
	push af
	ld a,3
	ld (c_ecode),a
	pop af
	jp nz,mk_er
	ld hl,0
	ld (c_par),hl
	ld a,(fcb+29)
	or a
	jr z,mk_r
	ld hl,(fcb+14)
	ld a,h
	or l
	jr z,mk_r
	dec hl
	ld (c_par),hl
mk_r:	ld hl,fcb
	ld e,(hl)
	ld c,1Bh
	call 5
	cp 0FFh
	push af
	ld a,4
	ld (c_ecode),a
	pop af
	jp z,mk_er
	push af
	ld (c_ssz),bc
	ld hl,cbuf
	ld de,cbuf+1
	ld (hl),0
	ld bc,1023
	ldir
	ld hl,mk_sub
	ld de,cbuf
	ld bc,64
	ldir
	ld hl,(c_par)
	ld (cbuf+32+26),hl
	ld hl,0
	ld (fcb+35),hl
	ld (fcb+33),hl
	inc h
	ld (fcb+14),hl
	pop bc
	ld de,cbuf
mk_l1:	push bc
	ld c,1Ah
	call 5
	ld hl,(c_ssz)
	ld de,fcb
	ld c,26h
	call 5
	pop bc
	or a
	push af
	ld a,5
	ld (c_ecode),a
	pop af
	jr nz,mk_er
	ld de,cbuf+64
	djnz mk_l1
	ld hl,(fcb+26)
	ld (cbuf+26),hl
	ld hl,0
	ld (fcb+35),hl
	ld hl,26
	ld (fcb+33),hl
	ld de,cbuf+26
	ld c,1Ah
	call 5
	ld de,fcb
	ld hl,2
	ld c,26h
	call 5
	or a
	push af
	ld a,6
	ld (c_ecode),a
	pop af
	jr nz,mk_er
	ld a,10h
	ld (fcb+13),a
	ld hl,0
	ld (fcb+16),hl
	ld de,fcb
	ld c,10h
	call 5
	ld de,dtabuf
	ld c,1Ah
	call 5
	xor a
	ret
mk_er:	ld de,dtabuf
	ld c,1Ah
	call 5
	ld de,c_mmk
	ld c,9
	call 5
	ld hl,tmpn
	ld a,(c_ecode)
	add a,'0'
	ld e,a
	ld c,2
	call 5
	ld a,' '
	ld e,a
	ld c,2
	call 5
mk_p:	ld a,(hl)
	or a
	jr z,mk_q
	ld e,a
	ld c,2
	push hl
	call 5
	pop hl
	inc hl
	jr mk_p
mk_q:	ld de,c_mcrlf
	ld c,9
	call 5
	ld a,1
	ld (c_err),a
	or a
	ret z
	ret
c_clr2:	xor a
	ld (fcb+13),a
	ret
mk_sub:	defm ".          "
	defb 10h
	defw 0,0,0,0,0,0,0,0,0,0
	defm "..         "
	defb 10h
	defw 0,0,0,0,0,0,0,0,0,0
'''+WALK+r'''
c_r:	defb 0
c_err:	defb 0
c_dd:	defb 0
c_wc:	defb 0
c_rb:	defb 0
c_h1:	defb 0
c_h2:	defb 0
c_s:	defw 0
c_d:	defw 0
c_sb:	defw 0
c_par:	defw 0
c_ecode:	defb 0
c_ssz:	defw 0
plen:	defb 0
dep:	defb 0
f_dall:	defm "*.*",0
c_mus:	defm "usage: cp [-r] from to",13,10,"$"
c_mnf:	defm "cp: source not found",13,10,"$"
c_mdr:	defm "cp: source is a directory (use -r)",13,10,"$"
c_mnd:	defm "cp: target must be a directory",13,10,"$"
c_mcp:	defm "cp: $"
c_mnp:	defm ": no such directory",13,10,"$"
c_msm:	defm ": same file",13,10,"$"
c_mos:	defm ": cannot open",13,10,"$"
c_mcf:	defm ": cannot create target",13,10,"$"
c_mre:	defm ": read error",13,10,"$"
c_mwe:	defm ": write error",13,10,"$"
c_mmk:	defm "cp: cannot create directory $"
c_mcrlf:	defm 13,10,"$"
fcb	equ 4000h
dtabuf	equ 4040h
patb	equ 4080h
pbuf	equ 4100h
sbuf	equ 4180h
s1buf	equ 4200h
s2buf	equ 4280h
droot	equ 4300h
tmpn	equ 4360h
cbuf	equ 4400h
''')
