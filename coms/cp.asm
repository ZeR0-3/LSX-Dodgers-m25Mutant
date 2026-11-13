; CP.COM - ファイルのコピー。 cp [-r] from to   MIT License
;   cp FILE to          : to が既存のディレクトリ(または \ : で終わる)ならその中へ、そうでなければ to という名前へ。既にあれば上書き
;   cp *.TXT dir        : ワイルドカードのファイルを dir (既存、または \ : で終わる)へ。サブディレクトリは対象外
;   cp -r DIR to        : ディレクトリごとコピー。to が既存のディレクトリなら to\DIR、無ければ to という名前で作る。深さ8階層まで、1つのディレクトリにサブディレクトリ40個まで
;   終了コード $? : 全部成功 0 / 失敗あり 1。成功時は何も出さない。 自分自身の中へのコピーはしない(同じ名前なら "same file")。
	org 0100h
	ld sp,0A000h
	call tailinit
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
c_83:	call c_ln2
	ld b,8
c_a1:	ld a,(hl)
	cp ' '
	jr z,c_a2
	ld (de),a
	inc de
	inc hl
	djnz c_a1
c_a2:	ld a,b
	or a
	jr z,c_a2n
	ld c,b
	ld b,0
	add hl,bc
	jr c_a3
c_a2n:	ld a,(c_lh2)		; 8文字そろっていて長い名前(name2)があれば足す
	or a
	jr z,c_a3
	push hl
	ld hl,dtabuf+13
	ld b,10
c_a6:	ld a,(hl)
	or a
	jr z,c_a7
	ld (de),a
	inc de
	inc hl
	djnz c_a6
c_a7:	pop hl
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
; 検索結果(dtabuf)に有効な name2 があるか -> c_lh2 (HL,DE を保つ。ls.asm の n2ok と同じ規則)
c_ln2:	push hl
	push bc
	xor a
	ld (c_lh2),a
	ld a,(dtabuf+8)
	cp ' '
	jr z,c_lx
	ld a,(dtabuf+17)
	cp 0A0h
	jr z,c_lx
	ld hl,dtabuf+13
	ld b,10
	ld a,(hl)
	or a
	jr z,c_lx
c_ll:	ld a,(hl)
	or a
	jr z,c_lz
	cp 20h
	jr c,c_lx
	cp 7Fh
	jr z,c_lx
	cp 0FFh
	jr z,c_lx
	inc hl
	djnz c_ll
	jr c_ly
c_lz:	dec b
	jr z,c_ly
	inc hl
	ld a,(hl)
	or a
	jr nz,c_lx
	jr c_lz
c_ly:	ld a,1
	ld (c_lh2),a
c_lx:	pop bc
	pop hl
	ret
c_lh2:	defb 0
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
	call f_pre
	ld a,(dep)
	inc a
	ld (dep),a
	call f_walk
	ld a,(dep)
	dec a
	ld (dep),a
	call f_post
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

; ===== 共通部品 =====
; 作業領域(ファイルに含めない): ibuf 3C00h(512) obuf 3F00h(256, 256境界) ほか各コマンド固有は 4000h 以降
ibuf	equ 3C00h
obuf	equ 3F00h
tailinit:
	ld hl,0080h
	ld a,(hl)
	inc hl
	ld e,a
	ld d,0
	add hl,de
	ld (hl),0
	ld hl,0081h
	ld a,obuf>>8
	ld (opos+1),a
	xor a
	ld (opos),a
	ld (outh2),a
	ld a,1
	ld (outh),a
	ld hl,0
	ld (icnt),hl
	ld hl,0081h
	ret
; HL の空白を飛ばす (A=次の文字)
sk:	ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr sk
; HL=トークン先頭 -> 終端(空白を0にする)して HL=次
tokend:	ld a,(hl)
	or a
	ret z
	cp ' '
	jr z,te1
	inc hl
	jr tokend
te1:	ld (hl),0
	inc hl
	ret
; HL=10進数 -> DE=値, HL=次
atoi:	ld de,0
at1:	ld a,(hl)
	sub '0'
	cp 10
	ret nc
	push hl
	ld h,d
	ld l,e
	add hl,hl
	add hl,hl
	add hl,de
	add hl,hl
	ld e,a
	ld d,0
	add hl,de
	ex de,hl
	pop hl
	inc hl
	jr at1
; DE=名前: "con" か "-" なら Z
iscon:	push de
	ld a,(de)
	cp '-'
	jr nz,ic0
	inc de
	ld a,(de)
	or a
	jr ic2
ic0:	ld b,3
	ld hl,conn
ic1:	ld a,(de)
	or 20h
	cp (hl)
	jr nz,ic2
	inc de
	inc hl
	djnz ic1
	ld a,(de)
	or a
ic2:	pop de
	ret
conn:	defm "con"
; DE=名前 -> 入力を開く。B=ハンドル、CF=1 エラー。(con/- は標準入力 B=0)
openin:	push de
	call iscon
	pop de
	jr nz,oi1
	ld b,0
	or a
	ret
oi1:	ld a,1
	ld c,43h
	call 5
	or a
	ret z
	scf
	ret
; (inh) の入力を閉じる(B=0 のときは何もしない)
closein:ld a,(inh)
	or a
	ret z
	ld b,a
	ld c,45h
	jp 5
; 1バイト読む: A=バイト, CF=1 EOF。(inh)=ハンドル。全レジスタ破壊
rdb:	ld hl,(icnt)
	ld a,h
	or l
	jr nz,rd2
	ld a,(inh)
	ld b,a
	ld de,ibuf
	ld hl,512
	ld c,48h
	call 5
	or a
	jr nz,rdeof
	ld a,h
	or l
	jr z,rdeof
	ld (icnt),hl
	ld hl,ibuf
	ld (ipos),hl
rd2:	ld hl,(icnt)
	dec hl
	ld (icnt),hl
	ld hl,(ipos)
	ld a,(hl)
	inc hl
	ld (ipos),hl
	or a
	ret
rdeof:	scf
	ret
; 1行読む: DE=バッファ(最大254文字)。CRは捨て、LFで終わり、0終端。CF=1 でデータなしのEOF
rdline:	ld hl,254
	ld (rlmax),hl
	ld (rlp),de
	ld bc,0			; BC=文字数
rl1:	push bc
	call rdb
	pop bc
	jr c,rleof
	cp 0Ah
	jr z,rlend
	cp 0Dh
	jr z,rl1
	ld d,a
	ld a,c
	cp 254
	jr nc,rl1
	ld hl,(rlp)
	ld (hl),d
	inc hl
	ld (rlp),hl
	inc c
	jr rl1
rlend:	ld hl,(rlp)
	ld (hl),0
	or a
	ret
rleof:	ld a,c
	or a
	jr z,rle2
	jr rlend
rle2:	ld hl,(rlp)
	ld (hl),0
	scf
	ret
rlmax:	defw 0
rlp:	defw 0
; 出力(バッファ付き)。A=バイト
wrb:	push hl
	ld hl,(opos)
	ld (hl),a
	inc l
	ld (opos),hl
	pop hl
	ret nz
	push af
	push bc
	push de
	push hl
	ld hl,256
	jr fl0
flush:	push af
	push bc
	push de
	push hl
	ld hl,(opos)
	ld h,0
	ld a,l
	or a
	jr z,flx
fl0:	push hl
	ld a,(outh)
	ld b,a
	ld de,obuf
	ld c,49h
	call 5
	pop hl
	ld a,(outh2)
	or a
	jr z,flx
	ld b,a
	ld de,obuf
	ld c,49h
	call 5
flx:	ld hl,obuf
	ld (opos),hl
	pop hl
	pop de
	pop bc
	pop af
	ret
; HL=0終端文字列を出力
wrs:	ld a,(hl)
	or a
	ret z
	call wrb
	inc hl
	jr wrs
wcrlf:	ld a,0Dh
	call wrb
	ld a,0Ah
	jp wrb
; DEHL(DE=上位) を B桁の右詰め10進で出力
pnum:	push bc
	push hl
	ld hl,nbuf
	ld b,11
	ld a,' '
pn1:	ld (hl),a
	inc hl
	djnz pn1
	pop hl
	ld a,10
	ld (pnp),a
pn2:	xor a
	ld b,32
pn3:	add hl,hl
	rl e
	rl d
	rla
	cp 10
	jr c,pn4
	sub 10
	inc l
pn4:	djnz pn3
	add a,'0'
	push hl
	push af
	ld a,(pnp)
	ld c,a
	ld b,0
	ld hl,nbuf
	add hl,bc
	pop af
	ld (hl),a
	pop hl
	ld a,h
	or l
	or d
	or e
	jr z,pn5
	ld a,(pnp)
	dec a
	ld (pnp),a
	jr pn2
pn5:	pop bc
	ld a,11
	sub b
	jr nc,pn6
	xor a
pn6:	ld c,a
	ld a,(pnp)
	cp c
	jr nc,pn7
	ld c,a
pn7:	ld b,0
	ld hl,nbuf
	add hl,bc
	ld a,11
	sub c
	ld b,a
pn8:	ld a,(hl)
	call wrb
	inc hl
	djnz pn8
	ret
pnp:	defb 0
inh:	defb 0
outh:	defb 1
outh2:	defb 0
opos:	defw 0
icnt:	defw 0
ipos:	defw 0
nbuf	equ 3EE0h
