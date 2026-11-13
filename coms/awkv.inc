; AWKV.INC - awk の仮想機械(スタックマシン)。MIT License
; 命令 (バイト列):  op [引数]。 値は 6バイトの cell (awku.inc) で vstk に積む。
O_END	equ	0
O_PUSHN	equ	1	; +4  数
O_PUSHS	equ	2	; +2  文字列の番地
O_LOADV	equ	3	; +1  変数
O_STOREV equ	4	; +1  変数 <- 先頭 (先頭は残る)
O_LOADF	equ	5	; 先頭(番号) -> $番号
O_STOREF equ	6	; [番号][値] -> 値
O_LOADA	equ	7	; +1  配列: 先頭(添字) -> 要素
O_STOREA equ	8	; +1  [添字][値] -> 値
O_ADD	equ	9
O_SUB	equ	10
O_MUL	equ	11
O_DIV	equ	12
O_MOD	equ	13
O_POW	equ	14
O_NEG	equ	15
O_NOT	equ	16
O_PLUS	equ	17
O_LT	equ	18
O_LE	equ	19
O_EQ	equ	20
O_NE	equ	21
O_GT	equ	22
O_GE	equ	23
O_CAT	equ	24
O_MATCH	equ	25	; +1 正規表現番号: 先頭の文字列が一致するか
O_NMATCH equ	26
O_DMATCH equ	27	; [文字列][正規表現の文字列]
O_NDMATCH equ	28
O_JMP	equ	29	; +2 番地
O_JZ	equ	30
O_JNZ	equ	31
O_POP	equ	32
O_DUP	equ	33
O_PRINT	equ	34	; +1 個数 +1 出力先(0=標準出力 1=ファイル 2=追記)
O_PRINTF equ	35	; +1 個数 +1 出力先
O_CALL	equ	36	; +1 関数番号 +1 引数の数
O_INCV	equ	37	; +1 変数 +1 (bit0=後置 bit1=減らす)
O_INCA	equ	38	; +1 配列 +1 同上: 先頭=添字
O_INCF	equ	39	; +1 同上: 先頭=番号
O_IN	equ	40	; +1 配列: 先頭(添字) -> 0/1
O_DEL	equ	41	; +1 配列: 先頭(添字) を消す
O_DELALL equ	42	; +1 配列を全部消す
O_NEXT	equ	43
O_EXIT	equ	44	; +1 (1=先頭が終了コード)
O_FORI	equ	45	; 反復用の数 0 を積む
O_FORN	equ	46	; +1 配列 +1 変数 +2 終わりの番地
O_GETL	equ	47	; getline: 次の入力行を $0 へ。結果 1/0
O_NF	equ	48

VSZ	equ	24		; 値スタックの深さ

; ---- 値スタック ----
; 新しい cell を積む -> HL=その番地 (DE, BC 保存)
vpush:	push de
	ld hl,(vsp)
	push hl
	ld de,6
	add hl,de
	ld (vsp),hl
	pop hl
	pop de
	ret
; 先頭を捨てる -> HL=捨てた cell
vpop:	push de
	ld hl,(vsp)
	ld de,-6
	add hl,de
	ld (vsp),hl
	pop de
	ret
; IX=先頭の cell (DE, BC, HL 保存)
gettop:	push hl
	push de
	ld ix,(vsp)
	ld de,-6
	add ix,de
	pop de
	pop hl
	ret

; ---- cell の変換 (IX=cell) ----
; 数にして na へ (cell は変えない)
getnum:	ld a,(ix+0)
	or a
	jr nz,gn_1
	ld l,(ix+1)
	ld h,(ix+2)
	ld (na),hl
	ld l,(ix+3)
	ld h,(ix+4)
	ld (na+2),hl
	ret
gn_1:	cp T_UNK
	jr nz,gn_2
	ld hl,0
	ld (na),hl
	ld (na+2),hl
	ret
gn_2:	ld l,(ix+1)
	ld h,(ix+2)
	jp s2n
; na から数の cell を作る (IX=cell)
setnum:	ld (ix+0),T_NUM
	ld hl,(na)
	ld (ix+1),l
	ld (ix+2),h
	ld hl,(na+2)
	ld (ix+3),l
	ld (ix+4),h
	ret
; 文字列の番地 -> HL (数なら10進に)
getstr:	ld a,(ix+0)
	cp T_NUM
	jr z,gs_n
	cp T_UNK
	jr z,gs_u
	ld l,(ix+1)
	ld h,(ix+2)
	ret
gs_u:	ld hl,emptys
	ret
gs_n:	call getnum
	jp n2s
; cell を文字列(T_STR)にする
tostr:	ld a,(ix+0)
	cp T_STR
	ret z
	call getstr
	ld (ix+0),T_STR
	ld (ix+1),l
	ld (ix+2),h
	ret
; 真偽 -> Z=偽 NZ=真
istrue:	ld a,(ix+0)
	cp T_NUM
	jr z,it_n
	cp T_UNK
	jr z,it_f
	ld l,(ix+1)
	ld h,(ix+2)
	cp T_SNUM
	jr nz,it_s
	push hl			; 数に見える文字列は数として
	call looksnum
	pop hl
	jr nc,it_s
	call s2n
	jr it_n2
it_s:	ld a,(hl)
	or a
	ret
it_f:	xor a
	ret
it_n:	call getnum
it_n2:	ld hl,(na)
	ld a,h
	or l
	ld hl,(na+2)
	or h
	or l
	ret
; 数として比べるか: A=0 文字列 1 数 2 どちらでも (IX=cell)
numlike:ld a,(ix+0)
	or a
	jr z,nl_1
	cp T_UNK
	jr z,nl_2
	cp T_SNUM
	jr nz,nl_0
	ld l,(ix+1)
	ld h,(ix+2)
	call looksnum
	jr nc,nl_0
nl_1:	ld a,1
	ret
nl_2:	ld a,2
	ret
nl_0:	xor a
	ret
; 先頭2つを比べる -> A=-1/0/1。 ix は壊れる
cmpcells:
	call gettop		; B
	call numlike
	ld (nlb),a
	push ix
	ld de,-6
	add ix,de
	call numlike		; A
	ld b,a
	ld a,(nlb)
	or a
	jr z,cc_s
	ld a,b
	or a
	jr z,cc_s
	pop ix
	call getnum		; B -> nb
	ld hl,na
	ld de,nb
	ld bc,4
	ldir
	ld de,-6
	add ix,de
	call getnum		; A -> na
	jp cmp32
cc_s:	pop ix
	call getstr		; B
	ld (cmp_b),hl
	ld de,-6
	add ix,de
	call getstr		; A
	ld de,(cmp_b)
	jp scmp

; ---- 命令の取り出し ----
f8:	ld hl,(vpc)
	ld a,(hl)
	inc hl
	ld (vpc),hl
	ret
f16:	ld hl,(vpc)
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld (vpc),hl
	ret

; ---- 実行 ----
; HL=命令列の先頭。 vflag: 0 終わりまで / 1 next / 2 exit
vm_run:	ld (vpc),hl
	ld hl,vstk
	ld (vsp),hl
	xor a
	ld (vflag),a
vm_lp:	ld a,(vflag)
	or a
	ret nz
	ld hl,(vpc)
	ld a,(hl)
	inc hl
	ld (vpc),hl
	ld l,a
	ld h,0
	add hl,hl
	ld de,optab
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	jp (hl)

optab:	defw op_end,op_pushn,op_pushs,op_loadv,op_storev,op_loadf,op_storef,op_loada,op_storea
	defw op_add,op_sub,op_mul,op_div,op_mod,op_pow,op_neg,op_not,op_plus
	defw op_lt,op_le,op_eq,op_ne,op_gt,op_ge,op_cat
	defw op_match,op_nmatch,op_dmatch,op_ndmatch
	defw op_jmp,op_jz,op_jnz,op_pop,op_dup,op_print,op_printf,op_call
	defw op_incv,op_inca,op_incf,op_in,op_del,op_delall,op_next,op_exit,op_fori,op_forn,op_getl,op_end

op_end:	ret
op_pushn:
	call vpush
	ex de,hl
	ld hl,(vpc)
	xor a
	ld (de),a
	inc de
	ld bc,4
	ldir
	ld (vpc),hl
	jp vm_lp
op_pushs:
	call f16
	call vpush
	ld (hl),T_STR
	inc hl
	ld (hl),e
	inc hl
	ld (hl),d
	jp vm_lp
; A=変数番号 -> HL=cell の番地
varaddr:ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	add hl,hl
	ld de,vars
	add hl,de
	ret
op_loadv:
	call f8
	call varaddr
	push hl
	call vpush
	ex de,hl
	pop hl
	ld bc,6
	ldir
	jp vm_lp
op_storev:
	call f8
	ld (as_idx),a
	call varaddr
	ld (asg_dc),hl
	ld a,(as_idx)
	ld l,a			; バッファ = vstrb + 番号*64
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
	call gettop
	push ix
	pop hl
	call assign_cell
	jp vm_lp
; HL=元の cell : (asg_dc)=先の cell (asg_db)=文字のバッファ (asg_cap)=最大文字数
assign_cell:
	ld a,(hl)
	ld (asg_t),a
	cp T_STR
	jr z,as1
	cp T_SNUM
	jr z,as1
	ld de,(asg_dc)
	ld bc,6
	ldir
	ret
as1:	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld de,(asg_db)
	ld a,(asg_cap)
	ld b,a
as2:	ld a,(hl)
	ld (de),a
	or a
	jr z,as3
	inc hl
	inc de
	djnz as2
	xor a
	ld (de),a
as3:	ld hl,(asg_dc)
	ld a,(asg_t)
	ld (hl),a
	inc hl
	ld de,(asg_db)
	ld (hl),e
	inc hl
	ld (hl),d
	ret

; n(0..) の欄 -> HL=文字列の番地
fieldaddr:
	ld a,h
	or a
	jr nz,fa_e
	ld a,l
	or a
	jr nz,fa_1
	ld hl,rbuf
	ret
fa_1:	ld de,(nfld)
	cp e
	jr z,fa_2
	jr nc,fa_e
fa_2:	ld l,a
	ld h,0
	add hl,hl
	ld de,fptr-2
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ret
fa_e:	ld hl,emptys
	ret
op_loadf:
	call gettop
	call getnum
	ld hl,(na)
	ld a,(na+2)
	ld b,a
	ld a,(na+3)
	or b
	jr z,lf1
	ld hl,0FFFFh		; 範囲外
lf1:	call fieldaddr
	call gettop
	ld (ix+0),T_SNUM
	ld (ix+1),l
	ld (ix+2),h
	jp vm_lp
op_storef:
	call gettop		; 値
	call getstr
	push hl
	push ix
	ld de,-6
	add ix,de
	call getnum		; 番号
	pop ix
	pop hl
	push ix
	ld de,(na)
	call setfield
	pop ix
	call dropbelow
	jp vm_lp
; 先頭の cell を1つ下へずらして1つ捨てる (IX=先頭)
dropbelow:
	push ix
	pop hl
	ld d,h
	ld e,l
	ld bc,-6
	add hl,bc
	ex de,hl
	ld bc,6
	ldir
	call vpop
	ret

; 配列 A、添字文字列 HL -> HL=要素(なければ作る)。 いっぱいなら HL=0
afind:	ld (af_a),a
	ld (af_k),hl
	ld hl,0
	ld (af_free),hl
	ld hl,atab
	ld bc,ASZ
af1:	ld a,(hl)
	or a
	jr nz,af2
	ld (af_free),hl
	jr af5
af2:	ld a,(af_a)
	cp (hl)
	jr nz,af5
	push hl
	push bc
	inc hl
	ex de,hl
	ld hl,(af_k)
	call scmp
	pop bc
	pop hl
	ret z
af5:	ld de,AESZ
	add hl,de
	dec bc
	ld a,b
	or c
	jr nz,af1
	ld a,(af_cre)
	or a
	jr nz,af_mk
	ld hl,0
	ret
af_mk:	ld hl,(af_free)		; 無ければ作る
	ld a,h
	or l
	ret z
	ld a,(af_a)
	ld (hl),a
	push hl
	inc hl
	ex de,hl
	ld hl,(af_k)
	ld b,31
af6:	ld a,(hl)
	ld (de),a
	or a
	jr z,af7
	inc hl
	inc de
	djnz af6
	xor a
	ld (de),a
af7:	pop hl
	push hl
	ld de,33
	add hl,de
	ld (hl),T_UNK
	pop hl
	ret
op_loada:
	call f8
	ld (as_idx),a
	ld a,1
	ld (af_cre),a
	call gettop
	call getstr
	ld a,(as_idx)
	call afind
	ld a,h
	or l
	jr nz,la1
	ld hl,dummyent
la1:	ld de,33
	add hl,de
	call gettop
	push ix
	pop de
	ld bc,6
	ldir
	jp vm_lp
op_storea:
	call f8
	ld (as_idx),a
	ld a,1
	ld (af_cre),a
	call gettop
	push ix
	ld de,-6
	add ix,de
	call getstr
	ld a,(as_idx)
	call afind
	pop ix
	ld a,h
	or l
	jr nz,sa1
	call dropbelow
	jp vm_lp
sa1:	push hl
	ld de,33
	add hl,de
	ld (asg_dc),hl
	ld de,6
	add hl,de
	ld (asg_db),hl
	ld a,31
	ld (asg_cap),a
	push ix
	pop hl
	call assign_cell
	pop hl
	call gettop
	call dropbelow
	jp vm_lp

; ---- 算術 ----
; 先頭2つを数にして na=A nb=B
binprep:call gettop
	call getnum
	ld hl,na
	ld de,nb
	ld bc,4
	ldir
	ld de,-6
	add ix,de
	jp getnum
; 結果 na を A の位置に置いて B を捨てる
binend:	call vpop
	call gettop
	call setnum
	ret
op_add:	call binprep
	call add32
	call binend
	jp vm_lp
op_sub:	call binprep
	call sub32
	call binend
	jp vm_lp
op_mul:	call binprep
	call mul32
	call binend
	jp vm_lp
chk0:	ld hl,(nb)
	ld a,h
	or l
	ld hl,(nb+2)
	or h
	or l
	ret nz
	ld hl,msgdiv
	jp fatal
op_div:	call binprep
	call chk0
	call sdiv32
	call binend
	jp vm_lp
op_mod:	call binprep
	call chk0
	call sdiv32
	ld hl,nr
	ld de,na
	ld bc,4
	ldir
	call binend
	jp vm_lp
op_pow:	call binprep
	ld hl,na
	ld de,pw_a
	ld bc,4
	ldir
	ld hl,nb
	ld de,pw_c
	ld bc,4
	ldir
	ld hl,1
	ld (pw_r),hl
	ld hl,0
	ld (pw_r+2),hl
	ld a,(pw_c+3)
	bit 7,a
	jr nz,pw_e
pw1:	ld hl,(pw_c)
	ld de,(pw_c+2)
	ld a,h
	or l
	or d
	or e
	jr z,pw_e
	ld hl,pw_c
	ld a,(hl)
	sub 1
	ld (hl),a
	inc hl
	ld a,(hl)
	sbc a,0
	ld (hl),a
	inc hl
	ld a,(hl)
	sbc a,0
	ld (hl),a
	inc hl
	ld a,(hl)
	sbc a,0
	ld (hl),a
	ld hl,pw_r
	ld de,na
	ld bc,4
	ldir
	ld hl,pw_a
	ld de,nb
	ld bc,4
	ldir
	call mul32
	ld hl,na
	ld de,pw_r
	ld bc,4
	ldir
	jr pw1
pw_e:	ld hl,pw_r
	ld de,na
	ld bc,4
	ldir
	call binend
	jp vm_lp
op_neg:	call gettop
	call getnum
	call neg32
	call setnum
	jp vm_lp
op_plus:call gettop
	call getnum
	call setnum
	jp vm_lp
op_not:	call gettop
	call istrue
	ld hl,0
	jr z,on1
	ld hl,0
	jr on2
on1:	ld hl,1
on2:	ld (na),hl
	ld hl,0
	ld (na+2),hl
	call setnum
	jp vm_lp
; 比較: A に -1/0/1 が入って来る。 HL=条件の表の番地は呼び元が決める
cmpend:	push af
	call vpop
	call gettop
	pop af
	ret
op_lt:	call cmpcells
	call cmpend
	cp 0FFh
	jr z,cm_t
	jr cm_f
op_le:	call cmpcells
	call cmpend
	cp 1
	jr nz,cm_t
	jr cm_f
op_eq:	call cmpcells
	call cmpend
	or a
	jr z,cm_t
	jr cm_f
op_ne:	call cmpcells
	call cmpend
	or a
	jr nz,cm_t
	jr cm_f
op_gt:	call cmpcells
	call cmpend
	cp 1
	jr z,cm_t
	jr cm_f
op_ge:	call cmpcells
	call cmpend
	cp 0FFh
	jr nz,cm_t
cm_f:	ld hl,0
	jr cm_s
cm_t:	ld hl,1
cm_s:	ld (na),hl
	ld hl,0
	ld (na+2),hl
	call setnum
	jp vm_lp
op_cat:	call gettop
	call getstr
	ld (cat_b),hl
	ld de,-6
	add ix,de
	call getstr
	ld (cat_a),hl
	call slen
	ld (cat_la),bc
	ld hl,(cat_b)
	call slen
	ld hl,(cat_la)
	add hl,bc
	inc hl
	ld b,h
	ld c,l
	call talloc
	push hl
	ex de,hl
	ld hl,(cat_a)
	call scpy
	ld hl,(cat_b)
	call scpy
	pop hl
	push hl
	call vpop
	call gettop
	pop hl
	ld (ix+0),T_STR
	ld (ix+1),l
	ld (ix+2),h
	jp vm_lp

; ---- 正規表現 ----
; A=番号の正規表現を使う設定にする
rxuse:	ld l,a
	ld h,0
	add hl,hl
	ld de,rtab
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)		; DE = 正規表現の部品
	ex de,hl
	ld a,(hl)
	ld (anch),a
	inc hl
	ld a,(hl)
	ld (haslsp),a
	inc hl
	inc hl
	inc hl
	ld (rx_cur),hl
	ret
; HL=正規表現の文字列: 組んで使う設定にする (CF=1 エラー)。同じ文字列は組み直さない
rxdyn:	push hl
	ld de,dynpat
	call scmp
	pop hl
	jr nz,rd1
	ld a,(dynok)
	or a
	jr z,rd_err
	ld hl,rx_prog
	ld (rx_cur),hl
	ld a,(dynanch)
	ld (anch),a
	ld a,(dynlsp)
	ld (haslsp),a
	and a
	ret
rd1:	push hl
	ld de,dynpat
	ld b,79
rd2:	ld a,(hl)
	ld (de),a
	or a
	jr z,rd3
	inc hl
	inc de
	djnz rd2
	xor a
	ld (de),a
rd3:	pop hl
	call re_comp
	jr c,rd_err
	ld a,(anch)
	ld (dynanch),a
	ld a,(haslsp)
	ld (dynlsp),a
	ld a,1
	ld (dynok),a
	and a
	ret
rd_err:	xor a
	ld (dynok),a
	scf
	ret
; 先頭の文字列に正規表現(使う設定済み)が一致するか -> CF。 HL=文字列
rxtest:	push hl
	call rx_find
	pop hl
	ret
op_match:
	call f8
	call rxuse
	call mt_do
	jp vm_lp
op_nmatch:
	call f8
	call rxuse
	call mt_do
	ld a,(na)
	xor 1
	ld (na),a
	call gettop
	call setnum
	jp vm_lp
mt_do:	call gettop
	call getstr
	call rx_find
	ld a,0
	rla
	ld (na),a
	xor a
	ld (na+1),a
	ld hl,0
	ld (na+2),hl
	call gettop
	jp setnum
op_dmatch:
	call dm_common
	jp vm_lp
op_ndmatch:
	call dm_common
	ld hl,na
	ld a,(hl)
	xor 1
	ld (hl),a
	call gettop
	call setnum
	jp vm_lp
dm_common:
	call gettop
	call getstr		; 正規表現の文字列
	call rxdyn
	push af
	call vpop
	call gettop
	call getstr
	pop af
	jr c,dmc_e
	call rx_find
	ld a,0
	rla
	jr dmc_s
dmc_e:	xor a
dmc_s:	ld (na),a
	xor a
	ld (na+1),a
	ld hl,0
	ld (na+2),hl
	call gettop
	call setnum
	ret

; ---- 流れ ----
op_jmp:	call f16
	ld (vpc),de
	jp vm_lp
op_jz:	call f16
	push de
	call gettop
	call istrue
	call vpop
	pop de
	jr nz,vm_l2
	ld (vpc),de
vm_l2:	jp vm_lp
op_jnz:	call f16
	push de
	call gettop
	call istrue
	call vpop
	pop de
	jr z,vm_l2
	ld (vpc),de
	jp vm_lp
op_pop:	call vpop
	jp vm_lp
op_dup:	call gettop
	push ix
	call vpush
	ex de,hl
	pop hl
	ld bc,6
	ldir
	jp vm_lp
op_next:ld a,1
	ld (vflag),a
	ret
op_exit:call f8
	or a
	jr z,ex1
	call gettop
	call getnum
	ld hl,(na)
	ld (exitcode),hl
ex1:	ld a,2
	ld (vflag),a
	ret
op_fori:call vpush
	ld (hl),T_NUM
	inc hl
	xor a
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	jp vm_lp
; FORN 配列 変数 終わり: 先頭(カウンタ)から次の使用中の要素を探す
op_forn:call f8
	ld (as_idx),a
	call f8
	ld (fn_var),a
	call f16
	ld (fn_end),de
	call gettop
	ld l,(ix+1)
	ld h,(ix+2)		; 次に調べる番号
	ld (fn_i),hl
fn1:	ld hl,(fn_i)
	ld de,ASZ
	or a
	sbc hl,de
	jr nc,fn_done
	ld hl,(fn_i)		; エントリの番地 = atab + i*AESZ
	ld de,AESZ
	call mul16
	ld de,atab
	add hl,de
	ld a,(as_idx)
	cp (hl)
	jr z,fn_got
	ld hl,(fn_i)
	inc hl
	ld (fn_i),hl
	jr fn1
fn_got:	ld (fn_ent),hl
	ld hl,(fn_i)
	inc hl
	ld (ix+1),l
	ld (ix+2),h
	ld hl,(fn_ent)
	inc hl			; 添字の文字列
	ld (fn_key),hl
	ld a,(fn_var)
	call varaddr
	ld (asg_dc),hl
	ld a,(fn_var)
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
	ld hl,fn_tmpc		; 添字を文字列の cell にして代入
	ld (hl),T_STR
	inc hl
	ld de,(fn_key)
	ld (hl),e
	inc hl
	ld (hl),d
	ld hl,fn_tmpc
	call assign_cell
	jp vm_lp
fn_done:call vpop
	ld de,(fn_end)
	ld (vpc),de
	jp vm_lp
; HL = HL*DE (16ビット)
mul16:	ld b,h
	ld c,l
	ld hl,0
	ld a,16
m16l:	add hl,hl
	rl c
	rl b
	jr nc,m16s
	add hl,de
m16s:	dec a
	jr nz,m16l
	ret
op_getl:call readrec
	ld hl,0
	jr nc,gl1
	ld hl,1
gl1:	ld (na),hl
	ld hl,0
	ld (na+2),hl
	call vpush
	push hl
	pop ix
	call setnum
	jp vm_lp
