; RE.INC - 正規表現エンジン(egrep.asm / awk.asm から INCLUDE する)。MIT License
;   re_comp : HL=パターン(0終端) -> CF=1:構文エラー。プログラム(中間コード)を rx_prog に作る
;   rx_find : HL=行頭(0終端) -> CF=1:見つかった。 (mstart)=一致の始め (mend)=終わり(最左・貪欲=優先順位つきバックトラック)
;   rx_from : HL=探索の開始位置(行頭は rx_ls に設定済み)。 -o の続きの探索用
; 構文: 文字 . [..] [^..] (範囲 a-z) ^ $ * + ? | ( ) \< \> と \x(x を普通の文字として)。Shift_JIS の全角は2バイトで1文字。
; 中間コード(相対番地): 01 c / 02 任意 / 03 +32バイトのビット表 / 04 rel1 rel2 (SPLIT: 先に rel1 を試す) / 05 rel (JMP) / 06 一致 / 07 行頭 / 08 行末 / 09 単語の始め / 0A 単語の終わり
; rel は「その命令の先頭」からの符号付き16ビット。だから断片は動かしても壊れない。
	ifndef RX_PMAX
RX_PMAX	equ	2000
	endif

; ---------------- コンパイル ----------------
re_comp:
	ld (rp),hl
	ifdef RX_CAPS
	xor a
	ld (ncap),a
	endif
	ld hl,rx_prog
	ld (rx_cur),hl
	xor a
	ld (haslsp),a
	ld hl,rx_prog
	ld (rcp),hl
	xor a
	ld (anch),a
	call c_alt
	ret c
	ld hl,(rp)
	ld a,(hl)
	or a
	scf
	ret nz			; 余分な ')'
	ld a,06h
	call emb
	ret c
	ld a,(rx_prog)
	cp 07h
	jr nz,rc1
	ld (anch),a		; 先頭が ^ なら行頭だけ試す
rc1:	and a
	ret

; A を1バイト追加 (範囲外なら CF=1)。A 以外のレジスタは保存
emb:	push hl
	push bc
	ld c,a
	ld hl,(rcp)
	ld a,h
	cp (rx_prog+RX_PMAX)/256
	jr nc,emb_e
	ld (hl),c
	inc hl
	ld (rcp),hl
	ld a,c
	pop bc
	pop hl
	and a
	ret
emb_e:	ld a,c
	pop bc
	pop hl
	scf
	ret
emw:	ld a,e			; DE を2バイト
	call emb
	ret c
	ld a,d
	jp emb
em5:	ld b,5			; 0 を5バイト
em5l:	xor a
	call emb
	ret c
	djnz em5l
	ret
; ratg なら LSPLIT(0B: 空の繰り返しを防ぐ) 、そうでなければ SPLIT を書く
wsp:	ld a,(ratg)
	or a
	jp z,wsplit
wlsplit:
	ld (hl),0Bh
	inc hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	ld b,32			; 通った位置の印(ビット表)
	xor a
wl1:	ld (hl),a
	inc hl
	djnz wl1
	ld a,1
	ld (haslsp),a
	ret
; HL=番地 DE=rel1 BC=rel2 : SPLIT を書く
wsplit:	ld (hl),04h
	inc hl
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	ld (hl),c
	inc hl
	ld (hl),b
	ret
; HL=位置: そこに (insn_n) バイト空ける (rcp+=n)。 CF=1 で溢れ
ins5:	ld a,5
	ld (insn_n),a
insn:	push hl
	ld hl,(rcp)
	ld de,rx_prog+RX_PMAX-12
	or a
	sbc hl,de
	jr nc,i5e
	ld hl,(rcp)
	pop de
	push de
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ld a,b
	or c
	jr z,i5n
	ld hl,(rcp)
	dec hl
	ld d,h
	ld e,l
	ld a,(insn_n)
	add a,e
	ld e,a
	jr nc,i5m
	inc d
i5m:	lddr
i5n:	ld hl,(rcp)
	ld a,(insn_n)
	ld e,a
	ld d,0
	add hl,de
	ld (rcp),hl
	pop hl
	and a
	ret
i5e:	pop hl
	scf
	ret
; 選択  seq ( '|' alt )?
c_alt:	ld hl,(rcp)
	push hl			; S = このレベルの先頭
	call c_seq
	jr c,ca_er
	ld hl,(rp)
	ld a,(hl)
	cp '|'
	jr nz,ca_ok
	inc hl
	ld (rp),hl
	pop hl
	push hl
	call ins5		; S に SPLIT の場所
	jr c,ca_er
	ld hl,(rcp)
	pop de
	push de
	or a
	sbc hl,de		; rcp - S
	inc hl
	inc hl
	inc hl			; + JMP の3バイト
	ld b,h
	ld c,l			; BC = rel2
	ex de,hl		; HL = S
	ld de,5
	call wsplit
	ld a,05h
	call emb		; JMP
	jr c,ca_er
	ld hl,(rcp)
	push hl			; rel の書き込み先
	ld de,0
	call emw
	jr c,ca_er2
	call c_alt
	jr c,ca_er2
	pop hl
	push hl
	dec hl			; J
	ex de,hl
	ld hl,(rcp)
	or a
	sbc hl,de		; rel = rcp - J
	ex de,hl
	pop hl
	ld (hl),e
	inc hl
	ld (hl),d
ca_ok:	pop hl
	and a
	ret
ca_er2:	pop hl
ca_er:	pop hl
	scf
	ret

; 並び  (atom quant)*
c_seq:	ld a,1
	ld (sqs),a
cs1:	ld hl,(rp)
	ld a,(hl)
	or a
	ret z
	cp '|'
	ret z
	cp ')'
	ret z
	call c_atom
	ret c
	call c_quant
	ret c
	xor a
	ld (sqs),a
	jr cs1

; 全角の1バイト目か (A保存, CF=1:そう)
islead:	cp 81h
	jr c,il0
	cp 0A0h
	jr c,il1
	cp 0E0h
	jr c,il0
	cp 0FDh
	jr c,il1
il0:	and a
	ret
il1:	scf
	ret

c_atom:	xor a
	ld (ratg),a
	ld hl,(rcp)
	ld (ras),hl
	ld hl,(rp)
	ld a,(hl)
	inc hl
	ld (rp),hl
	cp '('
	jp z,at_grp
	cp '['
	jp z,at_cls
	cp '.'
	jr z,at_any
	cp '^'
	jr z,at_bol
	cp '$'
	jr z,at_eol
	cp 5Ch
	jr z,at_esc
at_lit:	ld c,a
	ld a,01h
	call emb
	ret c
	ld a,c
	call emb
	ret c
	ld a,c
	call islead
	jr nc,at_ok
	ld hl,(rp)
	ld a,(hl)
	or a
	jr z,at_ok
	inc hl
	ld (rp),hl
	ld c,a
	ld a,01h
	call emb
	ret c
	ld a,c
	jp emb
at_ok:	and a
	ret
at_any:	ld a,02h
	jp emb
at_bol:	ld a,(sqs)
	or a
	ld a,'^'
	jr z,at_lit
	ld a,07h
	jp emb
at_eol:	ld hl,(rp)
	ld a,(hl)
	or a
	jr z,ae_e
	cp ')'
	jr z,ae_e
	cp '|'
	jr z,ae_e
	ld a,'$'
	jr at_lit
ae_e:	ld a,08h
	jp emb
at_esc:	ld hl,(rp)
	ld a,(hl)
	or a
	jr z,es_l
	inc hl
	ld (rp),hl
	cp '<'
	jr z,es_b
	cp '>'
	jr z,es_e
	jr at_lit
es_l:	ld a,5Ch
	jr at_lit
es_b:	ld a,09h
	jp emb
es_e:	ld a,0Ah
	jp emb
at_grp:	ld hl,(ras)
	push hl
	call cap_open		; C = 取り込み番号 (0=なし)
	jr c,ag_e
	push bc
	call c_alt
	pop bc
	jr c,ag_e
	ld hl,(rp)
	ld a,(hl)
	cp ')'
	jr nz,ag_e
	inc hl
	ld (rp),hl
	call cap_close
	jr c,ag_e
	pop hl
	ld (ras),hl
	ld a,1
	ld (ratg),a
	and a
	ret
ag_e:	pop hl
	scf
	ret
; ( の直後に 0C n(=2k) を出す。 RX_CAPS が無ければ何もしない
cap_open:
	ld c,0
	ifdef RX_CAPS
	ld a,(ncap)
	inc a
	ld (ncap),a
	cp 10
	jr nc,co9
	ld c,a
	ld a,0Ch
	call emb
	ret c
	ld a,c
	add a,a
	call emb
	ret c
co9:	endif
	and a
	ret
cap_close:
	ifdef RX_CAPS
	ld a,c
	or a
	jr z,cc9
	ld a,0Ch
	call emb
	ret c
	ld a,c
	add a,a
	inc a
	call emb
	ret c
cc9:	endif
	and a
	ret
; [..]
at_cls:	ld a,03h
	call emb
	ret c
	ld b,32
ac0:	xor a
	call emb
	ret c
	djnz ac0
	xor a
	ld (cneg),a
	inc a
	ld (cfirst),a
	ld hl,(rp)
	ld a,(hl)
	cp '^'
	jr nz,acl
	inc hl
	ld (rp),hl
	ld a,1
	ld (cneg),a
acl:	ld hl,(rp)
	ld a,(hl)
	or a
	jr z,ac_e
	inc hl
	ld (rp),hl
	cp ']'
	jr nz,acx
	ld c,a
	ld a,(cfirst)
	or a
	ld a,c
	jr nz,acx
	jr ac_done
acx:	ld e,a
	xor a
	ld (cfirst),a
	ld hl,(rp)
	ld a,(hl)
	cp '-'
	jr nz,ac_s
	inc hl
	ld a,(hl)
	or a
	jr z,ac_s
	cp ']'
	jr z,ac_s
	inc hl
	ld (rp),hl
	ld d,a
	ld a,d
	cp e
	jr nc,acr
	ld a,e			; 範囲が逆なら入れ替え
	ld e,d
	ld d,a
acr:	ld a,e
	call setbit
	ld a,e
	cp d
	jr z,acl
	inc e
	jr acr
ac_s:	ld a,e
	call setbit
	jr acl
ac_e:	scf
	ret
ac_done:
	ld a,(cneg)
	or a
	jr z,acd2
	ld hl,(rcp)
	ld de,-32
	add hl,de
	ld b,32
acn:	ld a,(hl)
	cpl
	ld (hl),a
	inc hl
	djnz acn
acd2:	and a
	ret
; A の文字のビットを、直前に作ったビット表(rcp-32)に立てる
setbit:	push hl
	push de
	push bc
	ld c,a
	ld hl,(rcp)
	ld de,-32
	add hl,de
	ld a,c
	rrca
	rrca
	rrca
	and 1Fh
	ld e,a
	ld d,0
	add hl,de
	ld a,c
	and 7
	ld b,a
	ld a,1
	inc b
sb1:	dec b
	jr z,sb2
	add a,a
	jr sb1
sb2:	or (hl)
	ld (hl),a
	pop bc
	pop de
	pop hl
	ret

; 量指定  * + ?
c_quant:
	ld hl,(rp)
	ld a,(hl)
	cp '*'
	jp z,q_star
	cp '+'
	jp z,q_plus
	cp '?'
	jp z,q_opt
	and a
	ret
q_star:	inc hl
	ld (rp),hl
	ld a,(ratg)
	or a
	ld a,5
	jr z,qs1
	ld a,37
qs1:	ld (insn_n),a
	ld hl,(ras)
	call insn
	ret c
	ld hl,(rcp)
	ld de,(ras)
	or a
	sbc hl,de
	inc hl
	inc hl
	inc hl
	ld b,h
	ld c,l
	ld hl,(ras)
	ld a,(insn_n)
	ld e,a
	ld d,0
	call wsp
	ld a,05h
	call emb
	ret c
	ld hl,(ras)
	ld de,(rcp)
	or a
	sbc hl,de		; ras - (J+1)
	inc hl			; ras - J
	ex de,hl
	jp emw
q_plus:	inc hl
	ld (rp),hl
	ld a,(ratg)
	or a
	ld a,5
	jr z,qp1
	ld a,37
qp1:	ld (insn_n),a
	ld hl,(rcp)
	push hl
	ld a,(insn_n)
	ld b,a
qpl:	xor a
	call emb
	jr c,qp_e
	djnz qpl
	pop bc			; BC = SPLIT の位置
	ld hl,(ras)
	or a
	sbc hl,bc
	ex de,hl		; DE = rel1 (戻る)
	ld h,b
	ld l,c
	ld a,(insn_n)
	ld c,a
	ld b,0
	call wsp
	and a
	ret
qp_e:	pop hl
	scf
	ret
q_opt:	inc hl
	ld (rp),hl
	ld hl,(ras)
	call ins5
	ret c
	ld hl,(rcp)
	ld de,(ras)
	or a
	sbc hl,de
	ld b,h
	ld c,l
	ld hl,(ras)
	ld de,5
	call wsplit
	and a
	ret

; ---------------- 照合 ----------------
; 単語を作る文字か (A保存, CF=1:そう)。80h以上(全角・半角カナ)も単語扱い
isword:	cp '0'
	jr c,iw0
	cp '9'+1
	jr c,iw1
	cp 'A'
	jr c,iw0
	cp 'Z'+1
	jr c,iw1
	cp '_'
	jr z,iw1
	cp 'a'
	jr c,iw0
	cp 'z'+1
	jr c,iw1
	cp 80h
	jr c,iw0
iw1:	scf
	ret
iw0:	and a
	ret
; HL の1つ前が単語文字か (CF=1:そう。行頭は「いいえ」)
prevw:	push de
	push hl
	ld de,(rx_ls)
	or a
	sbc hl,de
	pop hl
	pop de
	jr z,pw0
	dec hl
	ld a,(hl)
	inc hl
	jp isword
pw0:	and a
	ret

; 探索: HL=行頭 -> CF=1 (mstart,mend)
rx_find:
	ld (rx_ls),hl
rx_from:
	ifdef RX_CAPS
	call cap_clr
	endif
	ld a,(anch)
	or a
	jr z,rf1
	ld de,(rx_ls)
	push hl
	or a
	sbc hl,de
	pop hl
	ret nz
rf1:	ld (mstart),hl
	ld bc,50000
	ld (rx_bud),bc
	push hl
	call rx_run
	pop hl
	ret c
	ld a,(anch)
	or a
	ret nz
	ld a,(hl)
	or a
	ret z
	inc hl
	call islead
	jr nc,rf1
	ld a,(hl)
	or a
	jr z,rf1
	inc hl
	jr rf1

; HL=開始位置  -> CF=1:一致 (mend=終わり)
rx_run:	ld a,(haslsp)
	or a
	call nz,rx_clr		; 空の繰り返し防止の印を消す
	ld (rx_sp),sp
	ld de,0
	push de
	push de			; 番兵
	ld de,(rx_cur)
xloop:	ld a,(de)
	inc de
	cp 01h
	jr z,x_chr
	cp 04h
	jr z,x_spl
	cp 02h
	jr z,x_any
	cp 03h
	jp z,x_cls
	cp 05h
	jr z,x_jmp
	cp 07h
	jp z,x_bol
	cp 08h
	jp z,x_eol
	cp 09h
	jp z,x_wb
	cp 0Ah
	jp z,x_we
	cp 0Bh
	jp z,x_lsp
	ifdef RX_CAPS
	cp 0Ch
	jp z,x_sv
	cp 0Dh
	jp z,x_rs
	endif
	ld (mend),hl		; 06: 一致
	ld sp,(rx_sp)
	scf
	ret
x_chr:	ld a,(de)
	inc de
	cp (hl)
	jr nz,x_fail
	inc hl
	jr xloop
x_fail:	pop de
	pop hl
	ld a,d
	or e
	jr nz,xloop
x_dead:	ld sp,(rx_sp)
	and a
	ret
x_any:	ld a,(hl)
	or a
	jr z,x_fail
	inc hl
	call islead
	jr nc,xloop
	ld a,(hl)
	or a
	jr z,xloop
	inc hl
	jr xloop
x_jmp:	ld a,(de)
	inc de
	ld c,a
	ld a,(de)
	ld b,a
	dec de
	dec de
	push hl
	ex de,hl
	add hl,bc
	ex de,hl
	pop hl
	jr xloop
x_spl:	ld bc,(rx_bud)
	dec bc
	ld (rx_bud),bc
	ld a,b
	or c
	jr z,x_dead
	ld (rx_t),hl
	push hl			; 戻り用のテキスト位置
	ex de,hl		; HL = I+1
	dec hl
	ld c,l
	ld b,h			; BC = I
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)		; DE = rel1
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a			; HL = rel2
	add hl,bc		; pc2
	push hl
	ld h,b
	ld l,c
	add hl,de		; pc1
	ex de,hl
	ld hl,(rx_t)
	jp xloop
; LSPLIT: この繰り返しの先頭に同じ位置で2度来たら、繰り返しの中へは入らず抜ける側へ(位置ごとの印で、空の繰り返しの無限ループを防ぐ)
x_lsp:	ld (rx_t),hl
	push de
	ld bc,(rx_ls)
	or a
	sbc hl,bc		; HL = 行頭からの位置
	ld a,h
	or a
	jr nz,xl_n		; 256以上は印をつけない
	ld a,l
	ld b,a
	rrca
	rrca
	rrca
	and 1Fh
	ld c,a
	ld a,b
	and 7
	ld b,a
	ld hl,4
	add hl,de		; HL = 印の表(I+5)
	ld e,c
	ld d,0
	add hl,de
	ld a,1
	inc b
xl1:	dec b
	jr z,xl2
	add a,a
	jr xl1
xl2:	ld c,a
	and (hl)
	jr nz,xl_same
	ld a,c
	or (hl)
	ld (hl),a
xl_n:	pop de
	ld hl,(rx_t)
	jp x_spl
xl_same:
	pop de			; I+1
	inc de
	inc de
	ld a,(de)
	ld c,a
	inc de
	ld a,(de)
	ld b,a
	dec de
	dec de
	dec de
	dec de			; I
	ex de,hl
	add hl,bc
	ex de,hl
	ld hl,(rx_t)
	jp xloop
	ifdef RX_CAPS
; SAVE n : caps[n] = 今の位置。失敗で戻るとき元の値に戻す(スタブ 0D n を戻り先にして積む)
x_sv:	ld (rx_t),hl
	ld (rx_pc),de
	ld a,(de)
	ld l,a
	ld h,0
	add hl,hl
	ld de,caps
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)		; DE = 元の値
	ld bc,(rx_t)
	ld (hl),b
	dec hl
	ld (hl),c
	push de			; 戻ったときの「テキスト位置」= 元の値
	ld l,a
	ld h,0
	add hl,hl
	ld de,capstub
	add hl,de
	push hl			; 戻り先 = スタブ
	ld de,(rx_pc)
	inc de
	ld hl,(rx_t)
	jp xloop
x_rs:	ld (rx_t),hl		; 元の値
	ld a,(de)
	ld l,a
	ld h,0
	add hl,hl
	ld de,caps
	add hl,de
	ld de,(rx_t)
	ld (hl),e
	inc hl
	ld (hl),d
	jp x_fail
cap_clr:
	push hl
	push de
	push bc
	ld hl,caps
	ld de,caps+1
	ld bc,39
	ld (hl),0
	ldir
	pop bc
	pop de
	pop hl
	ret
	endif
; 全 LSPLIT の印を消す
rx_clr:	push hl
	ld hl,(rx_cur)
rcl:	ld a,(hl)
	inc hl
	cp 06h
	jr z,rcd
	cp 01h
	jr z,rc_1
	cp 03h
	jr z,rc_3
	cp 04h
	jr z,rc_4
	cp 05h
	jr z,rc_2
	ifdef RX_CAPS
	cp 0Ch
	jr z,rc_1
	endif
	cp 0Bh
	jr nz,rcl
	inc hl
	inc hl
	inc hl
	inc hl
	ld b,32
	xor a
rc_z:	ld (hl),a
	inc hl
	djnz rc_z
	jr rcl
rc_1:	inc hl
	jr rcl
rc_2:	inc hl
	inc hl
	jr rcl
rc_4:	inc hl
	inc hl
	inc hl
	inc hl
	jr rcl
rc_3:	ld de,32
	add hl,de
	jr rcl
rcd:	pop hl
	ret
x_cls:	ld a,(hl)
	or a
	jp z,x_fail
	push hl
	push de
	ld c,a
	rrca
	rrca
	rrca
	and 1Fh
	ld l,a
	ld h,0
	add hl,de
	ld a,c
	and 7
	ld b,a
	ld a,(hl)
	inc b
xc1:	dec b
	jr z,xc2
	rrca
	jr xc1
xc2:	and 1
	pop de
	pop hl
	jp z,x_fail
	ld bc,32
	ex de,hl
	add hl,bc
	ex de,hl
	ld a,(hl)
	inc hl
	call islead
	jp nc,xloop
	ld a,(hl)
	or a
	jp z,xloop
	inc hl
	jp xloop
x_bol:	push de
	ld de,(rx_ls)
	or a
	sbc hl,de
	add hl,de
	pop de
	jp z,xloop
	jp x_fail
x_eol:	ld a,(hl)
	or a
	jp z,xloop
	jp x_fail
x_wb:	call prevw
	jp c,x_fail
	ld a,(hl)
	call isword
	jp nc,x_fail
	jp xloop
x_we:	call prevw
	jp nc,x_fail
	ld a,(hl)
	call isword
	jp c,x_fail
	jp xloop

; ---------------- 変数・バッファ ----------------
rp:	defw 0
rcp:	defw 0
ras:	defw 0
sqs:	defb 0
cneg:	defb 0
cfirst:	defb 0
anch:	defb 0
rx_sp:	defw 0
rx_bud:	defw 0
rx_t:	defw 0
rx_cur:	defw 0
rx_i:	defw 0
haslsp:	defb 0
insn_n:	defb 5
ratg:	defb 0
rx_ls:	defw 0
mstart:	defw 0
mend:	defw 0
rx_prog:	defs RX_PMAX+512
	ifdef RX_CAPS
rx_pc:	defw 0
ncap:	defb 0
caps:	defs 40			; caps[2k]=k番目の ( の位置  caps[2k+1]=その ) の位置 (0=なし)
capstub:
	defb 0Dh,0
	defb 0Dh,1
	defb 0Dh,2
	defb 0Dh,3
	defb 0Dh,4
	defb 0Dh,5
	defb 0Dh,6
	defb 0Dh,7
	defb 0Dh,8
	defb 0Dh,9
	defb 0Dh,10
	defb 0Dh,11
	defb 0Dh,12
	defb 0Dh,13
	defb 0Dh,14
	defb 0Dh,15
	defb 0Dh,16
	defb 0Dh,17
	defb 0Dh,18
	defb 0Dh,19
	endif
