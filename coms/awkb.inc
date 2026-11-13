; AWKB.INC - awk: 出力(print/printf とファイル出力)、組み込み関数、++/--、配列の in/delete。MIT License

; ---- ++ -- ----
inc_do:	ld hl,na
	ld de,inc_old
	ld bc,4
	ldir
	ld hl,1
	ld (nb),hl
	ld hl,0
	ld (nb+2),hl
	ld a,(inc_fl)
	bit 1,a
	jp nz,sub32
	jp add32
inc_res:ld a,(inc_fl)
	bit 0,a
	ret z
	ld hl,inc_old
	ld de,na
	ld bc,4
	ldir
	ret
op_incv:
	call f8
	ld (as_idx),a
	call f8
	ld (inc_fl),a
	ld a,(as_idx)
	call varaddr
	push hl
	pop ix
	call getnum
	call inc_do
	call setnum
	call inc_res
	call vpush
	push hl
	pop ix
	call setnum
	jp vm_lp
op_inca:
	call f8
	ld (as_idx),a
	call f8
	ld (inc_fl),a
	call gettop
	call getstr
	ld a,1
	ld (af_cre),a
	ld a,(as_idx)
	call afind
	ld a,h
	or l
	jr nz,ia1
	ld hl,dummyent
ia1:	ld de,33
	add hl,de
	push hl
	pop ix
	call getnum
	call inc_do
	call setnum
	call inc_res
	call gettop
	call setnum
	jp vm_lp
op_incf:
	call f8
	ld (inc_fl),a
	call gettop
	call getnum
	ld hl,(na)
	ld (inc_n),hl
	call fieldaddr
	call s2n
	call inc_do
	call n2s
	ld de,(inc_n)
	call setfield
	call inc_res
	call gettop
	call setnum
	jp vm_lp
op_in:	call f8
	ld (as_idx),a
	call gettop
	call getstr
	xor a
	ld (af_cre),a
	ld a,(as_idx)
	call afind
	ld a,h
	or l
	ld hl,0
	jr z,in1
	ld hl,1
in1:	ld (na),hl
	ld hl,0
	ld (na+2),hl
	call gettop
	call setnum
	jp vm_lp
op_del:	call f8
	ld (as_idx),a
	call gettop
	call getstr
	xor a
	ld (af_cre),a
	ld a,(as_idx)
	call afind
	ld a,h
	or l
	jr z,dl1
	ld (hl),0
dl1:	call vpop
	jp vm_lp
op_delall:
	call f8
	ld b,a
	ld hl,atab
	ld de,AESZ
	ld c,ASZ
dal:	ld a,(hl)
	cp b
	jr nz,dal2
	ld (hl),0
dal2:	add hl,de
	dec c
	jr nz,dal
	jp vm_lp

; ---- 出力 ----
putch:	cp 0Ah
	jr nz,putraw
	push af
	ld a,(lastc)
	cp 0Dh
	jr z,pc_1
	ld a,0Dh
	call putraw
pc_1:	pop af
putraw:	ld (lastc),a
	push hl
	push de
	ld hl,(op)
	ld (hl),a
	inc hl
	ld (op),hl
	ld de,obuf+250
	or a
	sbc hl,de
	call nc,flush
	pop de
	pop hl
	ret
flush:	push af
	push bc
	push de
	push hl
	ld hl,(op)
	ld de,obuf
	or a
	sbc hl,de
	jr z,fl9
	ld a,(outh)
	ld b,a
	ld de,obuf
	ld c,49h
	call 5
	ld hl,obuf
	ld (op),hl
fl9:	pop hl
	pop de
	pop bc
	pop af
	ret
putstr:	ld a,(hl)
	or a
	ret z
	inc hl
	call putch
	jr putstr
; ファイル出力の準備: 先頭の cell (ファイル名) を捨て、outh をそのファイルにする。 A=1 作り直す 2 追記
redirect:
	ld (rd_mode),a
	call gettop
	call getstr
	ld (rd_name),hl
	call vpop
	ld hl,ofn		; 開いているファイルから探す
	ld b,4
rd_f:	ld a,(hl)
	or a
	jr z,rd_nx
	push hl
	push bc
	inc hl
	ex de,hl
	ld hl,(rd_name)
	call scmp
	pop bc
	pop hl
	jr z,rd_have
rd_nx:	ld de,34
	add hl,de
	djnz rd_f
	ld hl,ofn		; 空きを探す
	ld b,4
rd_e:	ld a,(hl)
	or a
	jr z,rd_open
	ld de,34
	add hl,de
	djnz rd_e
	ld hl,ofn		; 満杯なら最初のを閉じる
	ld b,(hl)
	ld c,45h
	push hl
	call 5
	pop hl
	xor a
	ld (hl),a
rd_open:
	ld (rd_slot),hl
	inc hl
	ex de,hl
	ld hl,(rd_name)
	ld b,32
rd_c:	ld a,(hl)
	ld (de),a
	or a
	jr z,rd_c2
	inc hl
	inc de
	djnz rd_c
	xor a
	ld (de),a
rd_c2:	ld hl,(rd_slot)
	inc hl
	ex de,hl
	ld a,(rd_mode)
	cp 2
	jr nz,rd_new
	push de
	ld a,0
	ld c,43h
	call 5
	pop de
	or a
	jr nz,rd_new
	push bc
	ld a,2
	ld de,0
	ld hl,0
	ld c,4Ah
	call 5
	pop bc
	jr rd_got
rd_new:	ld a,0
	ld b,0
	ld c,44h
	call 5
	or a
	jr z,rd_got
	ld hl,(rd_slot)		; 開けなかった: 標準出力のまま
	ld a,(outh)
	ret
rd_got:	ld hl,(rd_slot)
	ld (hl),b
	ld a,b
	ld (outh),a
	ret
rd_have:
	ld a,(hl)
	ld (outh),a
	ret
; 全部閉じる
closeall:
	call flush
	ld hl,ofn
	ld b,4
ca1:	ld a,(hl)
	or a
	jr z,ca2
	push hl
	push bc
	ld b,a
	ld c,45h
	call 5
	pop bc
	pop hl
ca2:	ld de,34
	add hl,de
	djnz ca1
	ret
; print / printf の共通: 引数 n 個の先頭の番地 -> (pr_first)
pr_setup:
	call f8
	ld (pr_n),a
	call f8
	ld (pr_mode),a
	or a
	jr z,ps1
	call flush
	ld a,(pr_mode)
	call redirect
	jr ps2
ps1:	ld a,1
	ld (outh),a
ps2:	ld a,(pr_n)
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	add hl,hl
	ex de,hl
	ld hl,(vsp)
	or a
	sbc hl,de
	ld (pr_first),hl
	ret
pr_end:	call flush
	ld a,1
	ld (outh),a
	ld hl,(pr_first)
	ld (vsp),hl
	ret
op_print:
	call pr_setup
	ld a,(pr_n)
	or a
	jr nz,pr1
	ld hl,rbuf
	call putstr
	jr pr3
pr1:	ld hl,(pr_first)
	ld a,(pr_n)
	ld b,a
pr2:	push bc
	push hl
	push hl
	pop ix
	call getstr
	call putstr
	pop hl
	ld de,6
	add hl,de
	pop bc
	dec b
	jr z,pr3
	push bc
	push hl
	ld a,4			; OFS
	call varaddr
	push hl
	pop ix
	call getstr
	call putstr
	pop hl
	pop bc
	jr pr2
pr3:	ld a,5			; ORS
	call varaddr
	push hl
	pop ix
	call getstr
	call putstr
	call pr_end
	jp vm_lp
op_printf:
	call pr_setup
	ld hl,(pr_first)
	ld a,(pr_n)
	ld b,a
	call formatc
	ld hl,sfbuf
	call putstr
	call pr_end
	jp vm_lp

; ---- 書式 ----
; HL=最初の引数(書式)の cell、B=個数 -> sfbuf に作る
formatc:ld (fm_arg),hl
	ld a,b
	ld (fm_n),a
	push hl
	pop ix
	call getstr
	ld (fm_fmt),hl
	ld hl,sfbuf
	ld (sf_p),hl
	ld a,1
	ld (fm_i),a
fm_lp:	ld hl,(fm_fmt)
	ld a,(hl)
	inc hl
	ld (fm_fmt),hl
	or a
	jp z,fm_end
	cp '%'
	jr z,fm_pc
	call sf_put
	jr fm_lp
fm_pc:	ld hl,(fm_fmt)
	ld a,(hl)
	cp '%'
	jr nz,fm_f
	inc hl
	ld (fm_fmt),hl
	ld a,'%'
	call sf_put
	jr fm_lp
fm_f:	xor a			; フラグ
	ld (fm_left),a
	ld (fm_zero),a
	ld (fm_prec),a
	ld hl,0
	ld (fm_w),hl
	ld a,0FFh
	ld (fm_pv),a
	ld hl,(fm_fmt)
fm_fl:	ld a,(hl)
	cp '-'
	jr nz,fm_f2
	ld (fm_left),a
	inc hl
	jr fm_fl
fm_f2:	cp '0'
	jr nz,fm_f3
	ld (fm_zero),a
	inc hl
	jr fm_fl
fm_f3:	cp '+'
	jr z,fm_fs
	cp ' '
	jr nz,fm_w1
fm_fs:	inc hl
	jr fm_fl
fm_w1:	xor a
	ld (fm_wt),a
fm_w2:	ld a,(hl)
	call isdig
	jr nc,fm_w3
	ld a,(fm_wt)
	ld c,a
	add a,a
	add a,a
	add a,c
	add a,a
	ld c,a
	ld a,(hl)
	sub '0'
	add a,c
	ld (fm_wt),a
	inc hl
	jr fm_w2
fm_w3:	ld a,(fm_wt)
	ld (fm_wv),a
	ld a,(hl)
	cp '.'
	jr nz,fm_cv
	inc hl
	xor a
	ld (fm_wt),a
fm_p2:	ld a,(hl)
	call isdig
	jr nc,fm_p3
	ld a,(fm_wt)
	ld c,a
	add a,a
	add a,a
	add a,c
	add a,a
	ld c,a
	ld a,(hl)
	sub '0'
	add a,c
	ld (fm_wt),a
	inc hl
	jr fm_p2
fm_p3:	ld a,(fm_wt)
	ld (fm_pv),a
fm_cv:	ld a,(hl)
	inc hl
	ld (fm_fmt),hl
	ld (fm_c),a
	or a
	jp z,fm_end
	; 引数を1つ取る
	ld a,(fm_i)
	ld hl,fm_n
	cp (hl)
	jr c,fm_a1
	ld hl,emptys		; 足りない引数は ""
	ld (fm_s),hl
	xor a
	ld (fm_isn),a
	ld hl,0
	ld (na),hl
	ld (na+2),hl
	jr fm_do
fm_a1:	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	add hl,hl
	ld de,(fm_arg)
	add hl,de
	push hl
	pop ix
	ld a,(fm_i)
	inc a
	ld (fm_i),a
	ld a,(ix+0)
	ld (fm_isn),a
	call getnum
	call getstr
	ld (fm_s),hl
fm_do:	ld a,(fm_c)
	cp 'd'
	jr z,fm_d
	cp 'i'
	jr z,fm_d
	cp 's'
	jp z,fm_str
	cp 'c'
	jp z,fm_chr
	cp 'x'
	jp z,fm_x
	cp 'X'
	jp z,fm_x
	cp 'o'
	jp z,fm_o
	cp 'u'
	jp z,fm_u
	jp fm_lp
fm_d:	ld a,(fm_isn)
	cp T_NUM
	jr z,fm_d2
	ld hl,(fm_s)		; 文字列なら数に直す
	call s2n
fm_d2:	call n2s
	ld (fm_s),hl
	ld a,1
	ld (fm_num),a
	jp fm_pad
fm_u:	ld a,(fm_isn)
	cp T_NUM
	jr z,fm_u2
	ld hl,(fm_s)
	call s2n
fm_u2:	ld a,10
	jr fm_ub
fm_x:	ld a,16
	jr fm_ub
fm_o:	ld a,8
fm_ub:	ld (fm_base),a
	ld a,(fm_isn)
	cp T_NUM
	jr z,fm_ub2
	ld hl,(fm_s)
	call s2n
fm_ub2:	ld hl,dbuf2+14
	ld (n2p),hl
	xor a
	ld (hl),a
fm_ub3:	ld a,(fm_base)
	ld l,a
	ld h,0
	ld (nb),hl
	ld hl,0
	ld (nb+2),hl
	call udiv32
	ld a,(nr)
	cp 10
	jr c,fm_ub4
	add a,7
	ld c,a
	ld a,(fm_c)
	cp 'x'
	ld a,c
	jr nz,fm_ub4
	add a,20h
fm_ub4:	add a,'0'
	ld hl,(n2p)
	dec hl
	ld (hl),a
	ld (n2p),hl
	ld hl,(na)
	ld a,h
	or l
	ld hl,(na+2)
	or h
	or l
	jr nz,fm_ub3
	ld hl,(n2p)
	ld (fm_s),hl
	ld a,1
	ld (fm_num),a
	jr fm_pad
fm_chr:	ld a,(fm_isn)
	cp T_NUM
	jr nz,fm_c2
	ld a,(na)
	ld (cbuf),a
	xor a
	ld (cbuf+1),a
	ld hl,cbuf
	ld (fm_s),hl
	jr fm_c3
fm_c2:	ld hl,(fm_s)
	ld a,(hl)
	ld (cbuf),a
	xor a
	ld (cbuf+1),a
	ld hl,cbuf
	ld (fm_s),hl
fm_c3:	xor a
	ld (fm_num),a
	jr fm_pad
fm_str:	xor a
	ld (fm_num),a
	ld a,(fm_pv)
	cp 0FFh
	jr z,fm_pad
	ld hl,(fm_s)		; 精度で切る
	ld de,pbuf3
	ld b,a
fm_s1:	ld a,b
	or a
	jr z,fm_s2
	ld a,(hl)
	or a
	jr z,fm_s2
	ld (de),a
	inc hl
	inc de
	dec b
	jr fm_s1
fm_s2:	xor a
	ld (de),a
	ld hl,pbuf3
	ld (fm_s),hl
; 幅をそろえて出す
fm_pad:	ld hl,(fm_s)
	call slen
	ld a,(fm_wv)
	ld e,a
	ld a,c
	cp e
	jr nc,fm_p0
	ld a,e
	sub c
	ld (fm_fill),a
	jr fm_p1
fm_p0:	xor a
	ld (fm_fill),a
fm_p1:	ld a,(fm_left)
	or a
	jr nz,fm_pl
	; 右そろえ。ゼロ詰めは数のとき (符号を先に出す)
	ld a,(fm_zero)
	or a
	jr z,fm_pr
	ld a,(fm_num)
	or a
	jr z,fm_pr
	ld hl,(fm_s)
	ld a,(hl)
	cp '-'
	jr nz,fm_pz
	call sf_put
	inc hl
	ld (fm_s),hl
fm_pz:	ld a,(fm_fill)
	ld b,a
	ld a,'0'
	jr fm_pf
fm_pr:	ld a,(fm_fill)
	ld b,a
	ld a,' '
fm_pf:	ld c,a
fm_pf2:	ld a,b
	or a
	jr z,fm_pt
	ld a,c
	call sf_put
	dec b
	jr fm_pf2
fm_pt:	ld hl,(fm_s)
	call sf_puts
	jp fm_lp
fm_pl:	ld hl,(fm_s)
	call sf_puts
	ld a,(fm_fill)
	ld b,a
fm_pl2:	ld a,b
	or a
	jp z,fm_lp
	ld a,' '
	call sf_put
	dec b
	jr fm_pl2
fm_end:	xor a
	call sf_put
	ret
sf_put:	push hl
	ld hl,(sf_p)
	ld (hl),a
	inc hl
	ld (sf_p),hl
	pop hl
	ret
sf_puts:ld a,(hl)
	or a
	ret z
	inc hl
	call sf_put
	jr sf_puts

; ---- 組み込み関数 ----
; 結果を (bf_res) の cell に入れて、引数を捨てて積む
op_call:call f8
	ld (bf_id),a
	call f8
	ld (bf_n),a
	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	add hl,hl
	ex de,hl
	ld hl,(vsp)
	or a
	sbc hl,de
	ld (bf_first),hl
	ld hl,bf_res
	ld (hl),T_UNK
	ld a,(bf_id)
	ld l,a
	ld h,0
	add hl,hl
	ld de,bftab
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	call jphl
	ld hl,(bf_first)	; 引数を捨てて結果を置く
	ld (vsp),hl
	call vpush
	ex de,hl
	ld hl,bf_res
	ld bc,6
	ldir
	jp vm_lp
jphl:	jp (hl)
bftab:	defw bf_length,bf_substr,bf_index,bf_split,bf_toupper,bf_tolower,bf_int,bf_sprintf,bf_sub,bf_gsub,bf_match,bf_rand,bf_srand
; i番目 (0から) の引数の cell -> IX
argix:	ld hl,(bf_first)
	or a
	jr z,ai1
	ld b,a
	ld de,6
ai0:	add hl,de
	djnz ai0
ai1:	push hl
	pop ix
	ret
; 結果に文字列 HL を入れる / 数 na を入れる
res_str:ld a,T_STR
	ld (bf_res),a
	ld (bf_res+1),hl
	ret
res_num:ld ix,bf_res
	jp setnum
bf_length:
	ld a,(bf_n)
	or a
	jr nz,bl1
	ld hl,rbuf
	jr bl2
bl1:	xor a
	call argix
	call getstr
bl2:	call slen
	ld (na),bc
	ld hl,0
	ld (na+2),hl
	jp res_num
bf_int:	xor a
	call argix
	call getnum
	jp res_num
bf_toupper:
	xor a
	call argix
	call getstr
	ld a,1
	jr bt_c
bf_tolower:
	xor a
	call argix
	call getstr
	xor a
bt_c:	ld (bt_up),a
	call slen
	inc bc
	push hl
	call talloc
	ex de,hl
	pop hl
	push de
bt_l:	ld a,(hl)
	or a
	jr z,bt_e
	inc hl
	ld c,a
	call islead
	ld a,c
	jr c,bt_2
	ld b,a
	ld a,(bt_up)
	or a
	ld a,b
	jr z,bt_lo
	call upper
	jr bt_s
bt_lo:	call lower
bt_s:	ld (de),a
	inc de
	jr bt_l
bt_2:	ld (de),a
	inc de
	ld a,(hl)
	or a
	jr z,bt_e
	inc hl
	ld (de),a
	inc de
	jr bt_l
bt_e:	xor a
	ld (de),a
	pop hl
	ld a,T_STR
	ld (bf_res),a
	ld (bf_res+1),hl
	ret
bf_sprintf:
	ld hl,(bf_first)
	ld a,(bf_n)
	or a
	ret z
	ld b,a
	call formatc
	ld hl,sfbuf
	call slen
	inc bc
	call talloc
	push hl
	ex de,hl
	ld hl,sfbuf
	call scpy
	pop hl
	ld a,T_STR
	ld (bf_res),a
	ld (bf_res+1),hl
	ret
bf_index:
	xor a
	call argix
	call getstr
	ld (ix_s),hl
	ld a,1
	call argix
	call getstr
	ld (ix_t),hl
	ld bc,1
	ld hl,(ix_s)
bi1:	ld a,(hl)
	or a
	jr z,bi_no
	push hl
	push bc
	ld de,(ix_t)
bi2:	ld a,(de)
	or a
	jr z,bi_yes
	cp (hl)
	jr nz,bi3
	inc hl
	inc de
	jr bi2
bi3:	pop bc
	pop hl
	inc hl
	inc bc
	jr bi1
bi_yes:	pop bc
	pop hl
	ld (na),bc
	ld hl,0
	ld (na+2),hl
	jp res_num
bi_no:	ld hl,0
	ld (na),hl
	ld (na+2),hl
	jp res_num
bf_substr:
	xor a
	call argix
	call getstr
	ld (ss_s),hl
	call slen
	ld (ss_len),bc
	ld a,1
	call argix
	call getnum
	ld hl,(na)		; 開始 (1から)
	ld a,(na+3)
	bit 7,a
	jr z,ss1
	ld hl,0
ss1:	ld a,h
	or l
	jr nz,ss2
	ld hl,1
ss2:	ld (ss_m),hl
	ld hl,(ss_len)		; 長さ (指定なしは最後まで)
	ld de,(ss_m)
	or a
	sbc hl,de
	inc hl
	jr nc,ss3
	ld hl,0
ss3:	ld (ss_n),hl
	ld a,(bf_n)
	cp 3
	jr c,ss5
	ld a,2
	call argix
	call getnum
	ld a,(na+3)
	bit 7,a
	jr z,ss4
	ld hl,0
	jr ss6
ss4:	ld a,(na+2)
	ld b,a
	ld a,(na+3)
	or b
	ld hl,(na)
	jr z,ss6
	ld hl,0FFFFh
ss6:	ld de,(ss_n)
	push hl
	or a
	sbc hl,de
	pop hl
	jr nc,ss5
	ld (ss_n),hl
ss5:	ld hl,(ss_n)
	inc hl
	ld b,h
	ld c,l
	call talloc
	push hl
	ex de,hl
	ld hl,(ss_s)
	ld bc,(ss_m)
	dec bc
	add hl,bc
	ld bc,(ss_n)
	ld a,b
	or c
	jr z,ss7
	ldir
ss7:	xor a
	ld (de),a
	pop hl
	ld a,T_STR
	ld (bf_res),a
	ld (bf_res+1),hl
	ret
; 区切りで分ける: HL=文字列(破壊しない) DE=区切り文字列 B=区切りの種類... -> 結果は spbuf に0終端の欄 spptr に番地、個数 BC
bf_split:
	xor a
	call argix
	call getstr
	ld (sp_src),hl
	ld a,1
	call argix
	call getnum
	ld a,(na)
	ld (sp_arr),a
	ld a,(bf_n)
	cp 3
	jr c,bs1
	ld a,2
	call argix
	call getstr
	jr bs2
bs1:	ld a,3			; FS
	call varaddr
	push hl
	pop ix
	call getstr
bs2:	ex de,hl
	ld hl,(sp_src)
	ld bc,spbuf
	ld (sp_dst),bc
	ld bc,spptr
	ld (sp_ptr),bc
	ld a,60
	ld (sp_max),a
	call splitter		; BC=個数
	ld a,c
	ld (sp_cnt),a
	ld a,(sp_arr)		; 配列を空にして詰める
	ld b,a
	ld hl,atab
	ld de,AESZ
	ld c,ASZ
bsd:	ld a,(hl)
	cp b
	jr nz,bsd2
	ld (hl),0
bsd2:	add hl,de
	dec c
	jr nz,bsd
	ld a,1
	ld (af_cre),a
	xor a
	ld (sp_i),a
bsl:	ld a,(sp_i)
	ld hl,sp_cnt
	cp (hl)
	jr nc,bsx
	inc a
	ld (sp_i),a
	ld l,a			; 添字 = i (10進)
	ld h,0
	ld (na),hl
	ld hl,0
	ld (na+2),hl
	call n2s
	ld a,(sp_arr)
	call afind
	ld a,h
	or l
	jr z,bsl
	push hl
	ld de,33
	add hl,de
	ld (asg_dc),hl
	ld de,6
	add hl,de
	ld (asg_db),hl
	ld a,31
	ld (asg_cap),a
	ld a,(sp_i)
	dec a
	ld l,a
	ld h,0
	add hl,hl
	ld de,spptr
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld hl,tmpc
	ld (hl),T_SNUM
	inc hl
	ld (hl),e
	inc hl
	ld (hl),d
	ld hl,tmpc
	call assign_cell
	pop hl
	jr bsl
bsx:	ld a,(sp_cnt)
	ld l,a
	ld h,0
	ld (na),hl
	ld hl,0
	ld (na+2),hl
	jp res_num
; 組み込みの sub / gsub / match
bf_sub:	xor a
	jr bg_c
bf_gsub:ld a,1
bg_c:	ld (sg_g),a
	; 引数: 0=正規表現の文字列 1=置換 2=対象 (255=$0 または変数番号を表す数)
	xor a
	call argix
	call getstr
	call rxdyn
	jp c,bg_none
	ld a,1
	call argix
	call getstr
	ld (sg_rep),hl
	ld a,2
	call argix
	call getnum
	ld a,(na)
	ld (sg_tgt),a
	cp 255
	jr nz,bg_v
	ld hl,rbuf
	jr bg_g
bg_v:	call varaddr
	push hl
	pop ix
	call getstr
bg_g:	ld (sg_src),hl
	ld hl,sgbuf
	ld (sg_out),hl
	xor a
	ld (sg_cnt),a
	ld hl,(sg_src)
	ld (rx_ls),hl
bg_lp:	ld hl,(sg_src)
	call rx_from
	jr nc,bg_rest
	ld hl,(mstart)		; 一致の前まで写す
	ld de,(sg_src)
	call sg_copyto
	ld a,(sg_cnt)
	inc a
	ld (sg_cnt),a
	ld hl,(sg_rep)		; 置換 (& は一致した文字列)
bg_r:	ld a,(hl)
	or a
	jr z,bg_r9
	inc hl
	cp 5Ch
	jr nz,bg_r1
	ld a,(hl)
	cp '&'
	jr nz,bg_r0
	inc hl
	jr bg_rl
bg_r0:	cp 5Ch
	jr nz,bg_rl2
	inc hl
bg_rl2:	ld a,5Ch
	jr bg_rl
bg_r1:	cp '&'
	jr nz,bg_rl
	push hl
	ld hl,(mend)
	ld de,(mstart)
	call sg_copyto
	pop hl
	jr bg_r
bg_rl:	call sg_put
	jr bg_r
bg_r9:	ld hl,(mend)
	ld de,(mstart)
	or a
	sbc hl,de
	jr nz,bg_adv
	ld hl,(mend)		; 空の一致: 次の1文字をそのまま出して進む
	ld a,(hl)
	or a
	jr z,bg_done
	call sg_put
	inc hl
	ld (sg_src),hl
	jr bg_chk
bg_adv:	ld hl,(mend)
	ld (sg_src),hl
bg_chk:	ld a,(sg_g)
	or a
	jr z,bg_rest
	ld hl,(sg_src)
	ld a,(hl)
	or a
	jr nz,bg_lp
	jr bg_done
bg_rest:ld hl,(sg_src)		; 残りを写す
bg_rl3:	ld a,(hl)
	or a
	jr z,bg_done
	call sg_put
	inc hl
	jr bg_rl3
bg_done:xor a
	call sg_put
	ld a,(sg_cnt)
	or a
	jr z,bg_none2
	ld hl,sgbuf		; 結果を対象に入れる
	ld a,(sg_tgt)
	cp 255
	jr nz,bg_sv
	ld de,0
	call setfield
	jr bg_none2
bg_sv:	ld a,(sg_tgt)
	call sg_setvar
bg_none2:
	ld a,(sg_cnt)
	ld l,a
	ld h,0
	ld (na),hl
	ld hl,0
	ld (na+2),hl
	jp res_num
bg_none:ld hl,0
	ld (na),hl
	ld (na+2),hl
	jp res_num
; 変数 A に sgbuf の文字列を入れる
sg_setvar:
	ld (as_idx),a
	call varaddr
	ld (asg_dc),hl
	ld a,(as_idx)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ld de,vstrb
	add hl,de
	ld (asg_db),hl
	ld a,63
	ld (asg_cap),a
	ld hl,tmpc
	ld (hl),T_STR
	inc hl
	ld de,sgbuf
	ld (hl),e
	inc hl
	ld (hl),d
	ld hl,tmpc
	jp assign_cell
sg_put:	push hl
	push af
	ld hl,(sg_out)
	ld de,sgbuf+250
	or a
	sbc hl,de
	jr nc,sgp9
	ld hl,(sg_out)
	pop af
	push af
	ld (hl),a
	inc hl
	ld (sg_out),hl
sgp9:	pop af
	pop hl
	ret
; HL(終わり) までを DE(始め) から出力へ写す
sg_copyto:
	or a
	sbc hl,de
	ret z
	ret c
	ld b,h
	ld c,l
	ex de,hl
sgc1:	ld a,(hl)
	call sg_put
	inc hl
	dec bc
	ld a,b
	or c
	jr nz,sgc1
	ret
bf_match:
	xor a
	call argix
	call getstr
	ld (mt_s),hl
	ld a,1
	call argix
	call getstr
	call rxdyn
	jr c,bm_no
	ld hl,(mt_s)
	call rx_find
	jr nc,bm_no
	ld hl,(mstart)
	ld de,(mt_s)
	or a
	sbc hl,de
	inc hl
	ld (na),hl
	push hl
	ld hl,0
	ld (na+2),hl
	ld hl,(mend)
	ld de,(mstart)
	or a
	sbc hl,de
	ld (mt_len),hl
	ld ix,vars+6*7		; RSTART
	call setnum
	ld hl,(mt_len)
	ld (na),hl
	ld ix,vars+6*8		; RLENGTH
	call setnum
	pop hl
	ld (na),hl
	jp res_num
bm_no:	ld hl,0
	ld (na),hl
	ld (na+2),hl
	ld ix,vars+6*7
	call setnum
	ld hl,0FFFFh
	ld (na),hl
	ld (na+2),hl
	ld ix,vars+6*8
	call setnum
	ld hl,0
	ld (na),hl
	ld (na+2),hl
	jp res_num
bf_rand:ld hl,(seed)
	ld (na),hl
	ld hl,(seed+2)
	ld (na+2),hl
	ld hl,1103
	ld (nb),hl
	ld hl,0
	ld (nb+2),hl
	call mul32
	ld hl,12345
	ld (nb),hl
	ld hl,0
	ld (nb+2),hl
	call add32
	ld hl,(na)
	ld (seed),hl
	ld hl,(na+2)
	ld (seed+2),hl
	ld a,(bf_n)
	or a
	jr nz,br1
	ld hl,(seed+2)		; 引数なし: 0..32767
	ld a,h
	and 7Fh
	ld h,a
	ld (na),hl
	ld hl,0
	ld (na+2),hl
	jp res_num
br1:	xor a			; rand(n): 0..n-1
	call argix
	call getnum
	ld hl,(na)
	ld (nb),hl
	ld hl,(seed+2)
	ld a,h
	and 7Fh
	ld h,a
	ld (na),hl
	ld hl,0
	ld (na+2),hl
	ld hl,(nb)
	ld a,h
	or l
	jr z,br2
	call udiv32
	ld hl,nr
	ld de,na
	ld bc,4
	ldir
br2:	jp res_num
bf_srand:
	ld a,(bf_n)
	or a
	jr z,bs_0
	xor a
	call argix
	call getnum
	ld hl,(na)
	ld (seed),hl
	ld hl,(na+2)
	ld (seed+2),hl
bs_0:	jp res_num
