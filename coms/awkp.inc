; AWKP.INC - awk の字句解析と構文解析(命令列を作る)。MIT License
; トークン: 0=終わり 1=数 2=文字列 3=/正規表現/ 4=名前 5=組み込み関数 6=改行 7=; 8=BEGIN 9=END 10=if 11=else 12=while 13=for 14=do
;   15=break 16=continue 17=next 18=exit 19=print 20=printf 21=delete 22=in 23=getline  それ以外の1文字の記号はその文字
;   40=++ 41=-- 42=+= 43=-= 44=*= 45=/= 46=%= 47=^= 48=== 49=!= 50=<= 51=>= 52=&& 53=|| 54=!~ 55=>>
TK_EOF	equ	0
TK_NUM	equ	1
TK_STR	equ	2
TK_ERE	equ	3
TK_NAME	equ	4
TK_FUNC	equ	5
TK_NL	equ	6
TK_SEMI	equ	7
TK_BEGIN equ	8
TK_END	equ	9
TK_IF	equ	10
TK_ELSE	equ	11
TK_WHILE equ	12
TK_FOR	equ	13
TK_DO	equ	14
TK_BREAK equ	15
TK_CONT	equ	16
TK_NEXT	equ	17
TK_EXIT	equ	18
TK_PRINT equ	19
TK_PRINTF equ	20
TK_DELETE equ	21
TK_IN	equ	22
TK_GETL	equ	23
TK_INCR	equ	128
TK_DECR	equ	129
TK_ADDA	equ	130
TK_SUBA	equ	131
TK_MULA	equ	132
TK_DIVA	equ	133
TK_MODA	equ	134
TK_POWA	equ	135
TK_EQ	equ	136
TK_NE	equ	137
TK_LE	equ	138
TK_GE	equ	139
TK_AND	equ	140
TK_OR	equ	141
TK_NMATCH equ	142
TK_APPEND equ	143

; ---- 字句解析 ----
; 次のトークンを (tok) と (tokv) に
lex:	ld a,(tok)		; 前のトークンを覚える(/ が割り算か正規表現かの判断用)
	ld (ptok),a
lex2:	ld hl,(src)
lx0:	ld a,(hl)
	cp ' '
	jr z,lx1
	cp 09h
	jr z,lx1
	cp 0Dh
	jr z,lx1
	cp 5Ch			; 行末の \ は次の行へ続く
	jr nz,lx2
	inc hl
	ld a,(hl)
	cp 0Ah
	jr z,lx1
	dec hl
	ld a,5Ch
	jr lx2
lx1:	inc hl
	jr lx0
lx2:	or a
	jr nz,lx3
	ld (src),hl
	ld a,TK_EOF
	jp lx_ret
lx3:	cp '#'
	jr nz,lx4
lx3a:	inc hl
	ld a,(hl)
	or a
	jr z,lx0
	cp 0Ah
	jr nz,lx3a
	jr lx0
lx4:	cp 0Ah
	jr nz,lx5
	inc hl
	ld (src),hl
	ld a,TK_NL
	jp lx_ret
lx5:	cp ';'
	jr nz,lx6
	inc hl
	ld (src),hl
	ld a,TK_SEMI
	jp lx_ret
lx6:	call isdig
	jr c,lx_num
	cp '.'
	jr nz,lx7
	inc hl
	ld a,(hl)
	dec hl
	call isdig
	jr c,lx_num
	ld a,'.'
lx7:	cp '"'
	jp z,lx_str
	cp 27h
	jp z,lx_str
	call isalpha
	jp c,lx_word
	jp lx_op
lx_num:	ld (src),hl
	call s2n		; 整数部分
	ld a,(hl)
	cp '.'
	jr nz,lxn2
	inc hl
lxn1:	ld a,(hl)
	call isdig
	jr nc,lxn2
	inc hl
	jr lxn1
lxn2:	ld (src),hl
	ld hl,(na)
	ld (tokv),hl
	ld hl,(na+2)
	ld (tokv+2),hl
	ld a,TK_NUM
	jp lx_ret
; 文字列: " か ' で始まり同じもので終わる。 \n \t \" \\ \/ などの \ 指定
lx_str:	ld b,a
	inc hl
	ld de,(spp)
	ld (tokv),de
lxs1:	ld a,(hl)
	or a
	jr z,lxs9
	inc hl
	cp b
	jr z,lxs9
	cp 5Ch
	jr nz,lxs3
	ld a,(hl)
	inc hl
	cp 'n'
	jr nz,lxs2
	ld a,0Ah
	jr lxs3
lxs2:	cp 't'
	jr nz,lxs2b
	ld a,09h
	jr lxs3
lxs2b:	cp 'r'
	jr nz,lxs3
	ld a,0Dh
lxs3:	ld (de),a
	inc de
	jr lxs1
lxs9:	xor a
	ld (de),a
	inc de
	ld (spp),de
	ld (src),hl
	ld a,TK_STR
	jp lx_ret
lx_word:
	ld de,wbuf
	ld b,12
lxw1:	ld a,(hl)
	call isalnum
	jr nc,lxw2
	ld (de),a
	inc hl
	inc de
	djnz lxw1
lxw2:	xor a
	ld (de),a
	ld (src),hl
	ld hl,kwtab		; 予約語・組み込み関数
lxw3:	ld a,(hl)
	or a
	jr z,lxw_name
	ld de,wbuf
	push hl
	call scmp
	pop hl
	jr z,lxw4
lxw3b:	ld a,(hl)		; 次へ
	inc hl
	or a
	jr nz,lxw3b
	inc hl
	inc hl
	jr lxw3
lxw4:	call slen
	add hl,bc
	inc hl
	ld a,(hl)		; トークンの種類
	inc hl
	ld c,(hl)		; 値 (関数番号)
	ld b,0
	ld (tokv),bc
	jp lx_ret
lxw_name:
	call lookvar
	ld l,a
	ld h,0
	ld (tokv),hl
	ld a,TK_NAME
	jp lx_ret
; 変数名 wbuf -> A=番号 (なければ追加)
lookvar:ld hl,nmtab
	ld b,0
lv1:	ld a,(hl)
	or a
	jr z,lv_add
	push hl
	push bc
	ld de,wbuf
	call scmp
	pop bc
	pop hl
	jr z,lv_ok
	ld de,14
	add hl,de
	inc b
	jr lv1
lv_ok:	ld a,b
	ret
lv_add:	ld a,b
	cp NVARS
	jr c,lv_a2
	ld hl,msgvars
	jp fatal
lv_a2:	ld a,b
	ld (lvidx),a
	ld de,wbuf
	ex de,hl
	ld bc,13
	ldir
	ld a,(lvidx)
	ret
isalpha:cp '_'
	jr z,ia_y
	cp 'A'
	jr c,ia_n
	cp 'Z'+1
	jr c,ia_y
	cp 'a'
	jr c,ia_n
	cp 'z'+1
	jr c,ia_y
ia_n:	and a
	ret
ia_y:	scf
	ret
isalnum:call isalpha
	ret c
	jp isdig
; 記号
lx_op:	ld c,a
	inc hl
	ld b,(hl)		; 次の文字
	ld a,c
	cp '/'
	jr nz,lo1
	ld a,(ptok)		; 前が値なら割り算、そうでなければ正規表現
	call isoperand
	jr c,lo_div
	jp lx_ere
lo_div:	ld a,b
	cp '='
	jp nz,lo_single
	inc hl
	ld a,TK_DIVA
	jp lo_set
lo1:	ld a,c
	cp '+'
	jr nz,lo2
	ld a,b
	cp '+'
	jr nz,lo1b
	ld a,TK_INCR
	jp lo_two
lo1b:	cp '='
	jp nz,lo_single
	ld a,TK_ADDA
	jp lo_two
lo2:	cp '-'
	jr nz,lo3
	ld a,b
	cp '-'
	jr nz,lo2b
	ld a,TK_DECR
	jp lo_two
lo2b:	cp '='
	jp nz,lo_single
	ld a,TK_SUBA
	jp lo_two
lo3:	cp '*'
	jr nz,lo4
	ld a,b
	cp '*'
	jr nz,lo3b
	inc hl
	ld c,'^'
	jp lo_single
lo3b:	cp '='
	jp nz,lo_single
	ld a,TK_MULA
	jp lo_two
lo4:	cp '%'
	jr nz,lo5
	ld a,b
	cp '='
	jp nz,lo_single
	ld a,TK_MODA
	jp lo_two
lo5:	cp '^'
	jr nz,lo6
	ld a,b
	cp '='
	jp nz,lo_single
	ld a,TK_POWA
	jp lo_two
lo6:	cp '='
	jr nz,lo7
	ld a,b
	cp '='
	jp nz,lo_single
	ld a,TK_EQ
	jp lo_two
lo7:	cp '!'
	jr nz,lo8
	ld a,b
	cp '='
	jr nz,lo7b
	ld a,TK_NE
	jp lo_two
lo7b:	cp '~'
	jp nz,lo_single
	ld a,TK_NMATCH
	jp lo_two
lo8:	cp '<'
	jr nz,lo9
	ld a,b
	cp '='
	jp nz,lo_single
	ld a,TK_LE
	jp lo_two
lo9:	cp '>'
	jr nz,lo10
	ld a,b
	cp '='
	jr nz,lo9b
	ld a,TK_GE
	jp lo_two
lo9b:	cp '>'
	jp nz,lo_single
	ld a,TK_APPEND
	jp lo_two
lo10:	cp '&'
	jr nz,lo11
	ld a,b
	cp '&'
	jp nz,lo_single
	ld a,TK_AND
	jp lo_two
lo11:	cp '|'
	jp nz,lo_single
	ld a,b
	cp '|'
	jp nz,lo_single
	ld a,TK_OR
lo_two:	inc hl
lo_set:	ld (src),hl
	jr lx_ret
lo_single:
	ld (src),hl
	ld a,c
lx_ret:	ld (tok),a
	ret
; A が「値の終わり」になる種類か (CF=1:そう)
isoperand:
	cp TK_NUM
	jr z,io_y
	cp TK_STR
	jr z,io_y
	cp TK_NAME
	jr z,io_y
	cp TK_ERE
	jr z,io_y
	cp ')'
	jr z,io_y
	cp ']'
	jr z,io_y
	cp TK_INCR
	jr z,io_y
	cp TK_DECR
	jr z,io_y
	and a
	ret
io_y:	scf
	ret
; 正規表現リテラル  /.../  (HL は最初の / の次ではなく / の位置の次)
lx_ere:	ld de,(spp)
	ld (tokv2),de
lre1:	ld a,(hl)
	or a
	jr z,lre9
	inc hl
	cp '/'
	jr z,lre9
	cp 5Ch
	jr nz,lre2
	ld a,(hl)
	cp '/'
	jr z,lre1b
	ld a,5Ch
	ld (de),a
	inc de
	ld a,(hl)
	inc hl
	jr lre2
lre1b:	inc hl
	ld a,'/'
lre2:	ld (de),a
	inc de
	jr lre1
lre9:	xor a
	ld (de),a
	inc de
	ld (spp),de
	ld (src),hl
	ld hl,(tokv2)
	call re_comp		; 組んで rpool に写す
	jr nc,lre_ok
	ld hl,msgre
	jp fatal
lre_ok:	ld hl,(rcp)
	ld de,rx_prog
	or a
	sbc hl,de
	ld b,h
	ld c,l			; BC = 長さ
	ld hl,(rpp)
	ld de,rpool+RPSZ-4
	push hl
	add hl,bc
	or a
	sbc hl,de
	pop hl
	jr c,lre_s
	ld hl,msgre
	jp fatal
lre_s:	ld a,(nrx)
	cp NRX
	jr c,lre_s2
	ld hl,msgre
	jp fatal
lre_s2:	ld e,a
	ld d,0
	push hl
	ld hl,rtab
	add hl,de
	add hl,de
	pop de			; DE = 部品の置き場
	ld (hl),e
	inc hl
	ld (hl),d
	ex de,hl
	ld a,(anch)
	ld (hl),a
	inc hl
	ld a,(haslsp)
	ld (hl),a
	inc hl
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	push bc
	ex de,hl
	ld hl,rx_prog
	pop bc
	ldir
	ld (rpp),de
	ld a,(nrx)
	ld l,a
	ld h,0
	ld (tokv),hl
	inc a
	ld (nrx),a
	ld a,TK_ERE
	jp lx_ret

; 予約語・組み込み関数の表: "名前",0, 種類, 値
kwtab:	defm "BEGIN",0
	defb TK_BEGIN,0
	defm "END",0
	defb TK_END,0
	defm "if",0
	defb TK_IF,0
	defm "else",0
	defb TK_ELSE,0
	defm "while",0
	defb TK_WHILE,0
	defm "for",0
	defb TK_FOR,0
	defm "do",0
	defb TK_DO,0
	defm "break",0
	defb TK_BREAK,0
	defm "continue",0
	defb TK_CONT,0
	defm "next",0
	defb TK_NEXT,0
	defm "exit",0
	defb TK_EXIT,0
	defm "print",0
	defb TK_PRINT,0
	defm "printf",0
	defb TK_PRINTF,0
	defm "delete",0
	defb TK_DELETE,0
	defm "in",0
	defb TK_IN,0
	defm "getline",0
	defb TK_GETL,0
	defm "length",0
	defb TK_FUNC,0
	defm "substr",0
	defb TK_FUNC,1
	defm "index",0
	defb TK_FUNC,2
	defm "split",0
	defb TK_FUNC,3
	defm "toupper",0
	defb TK_FUNC,4
	defm "tolower",0
	defb TK_FUNC,5
	defm "int",0
	defb TK_FUNC,6
	defm "sprintf",0
	defb TK_FUNC,7
	defm "sub",0
	defb TK_FUNC,8
	defm "gsub",0
	defb TK_FUNC,9
	defm "match",0
	defb TK_FUNC,10
	defm "rand",0
	defb TK_FUNC,11
	defm "srand",0
	defb TK_FUNC,12
	defb 0

; ---- 命令の出力 ----
em8:	push hl
	push de
	ld hl,(cptr)
	ld (hl),a
	inc hl
	ld (cptr),hl
	ld de,code+CODESZ
	or a
	sbc hl,de
	pop de
	pop hl
	ret c
	ld hl,msgbig
	jp fatal
em16:	ld a,e
	call em8
	ld a,d
	jp em8
; ジャンプ命令 A を出して、 操作数の番地を DE... HL=操作数の番地 (あとで patch)。連鎖: 操作数にはつながりの前の番地を入れる
emjmp:	call em8
	ld hl,(cptr)
	push hl
	ld de,0
	call em16
	pop hl
	ret
; HL=操作数の番地 : 今の位置へ飛ぶように書く
patch:	ld de,(cptr)
	ld (hl),e
	inc hl
	ld (hl),d
	ret
; HL=連鎖の先頭 (0=なし) : 全部を DE の番地へ向ける
patchall:
pa1:	ld a,h
	or l
	ret z
	ld c,(hl)		; 次の番地
	ld (hl),e
	inc hl
	ld b,(hl)
	ld (hl),d
	ld h,b
	ld l,c
	jr pa1
; 連鎖の先頭 HL に新しい操作数 DE... : 操作数の番地 HL を連鎖 (cur) に加える
chain:	ld de,(chead)
	ld (hl),e
	inc hl
	ld (hl),d
	dec hl
	ld (chead),hl
	ret
; HL=連鎖の先頭: 今の位置へ向ける
patchhere:
	ld de,(cptr)
	jr patchall

; ---- 構文 ----
expect:	ld b,a			; A=記号 : 今のトークンがそれなら次へ、違えばエラー
	ld a,(tok)
	cp b
	jr nz,ex_err
	jp lex
ex_err:	ld hl,msgsyn
	jp fatal
skipnl:	ld a,(tok)
	cp TK_NL
	ret nz
	call lex
	jr skipnl
; 文の終わり: ; 改行 } 終わり
endstmt:ld a,(tok)
	cp TK_SEMI
	jr z,es1
	cp TK_NL
	jr z,es1
	cp '}'
	ret z
	cp TK_EOF
	ret z
	jr ex_err
es1:	jp lex

; ---- プログラム ----
parse_prog:
	call lex
pp0:	ld a,(tok)
	cp TK_NL
	jr z,pp_skip
	cp TK_SEMI
	jr z,pp_skip
	cp TK_EOF
	ret z
	cp TK_BEGIN
	jr z,pp_begin
	cp TK_END
	jp z,pp_end
	cp '{'
	jr z,pp_main0
	; パターン
	call newrule1
	call noGt0
	call p_expr
	ld a,O_JZ
	call emjmp
	ld (rul_j),hl
	ld a,(tok)
	cp '{'
	jr z,pp_act
	ld a,O_PRINT
	call em8
	xor a
	call em8
	xor a
	call em8
	jr pp_fin
pp_act:	call lex
	call p_stmts
	ld a,'}'
	call expect
pp_fin:	ld hl,(rul_j)
	call patch
	ld a,O_END
	call em8
	jp pp0
pp_skip:call lex
	jp pp0
pp_begin:
	ld a,0
	jr pp_blk
pp_end:	ld a,2
pp_blk:	push af
	call lex
	call skipnl
	ld a,'{'
	call expect
	pop af
	call newrule
	call p_stmts
	ld a,'}'
	call expect
	ld a,O_END
	call em8
	jp pp0
pp_main0:
	call newrule1
	call lex
	call p_stmts
	ld a,'}'
	call expect
	ld a,O_END
	call em8
	jp pp0
newrule1:
	ld a,1
; A=種類: 規則を1つ登録(今のコード位置から)
newrule:ld b,a
	ld a,(nrules)
	cp NRULES
	jr c,nr1
	ld hl,msgbig
	jp fatal
nr1:	ld l,a
	ld h,0
	ld d,h
	ld e,l
	add hl,hl
	add hl,de
	ld de,rules
	add hl,de
	ld (hl),b
	inc hl
	ld de,(cptr)
	ld (hl),e
	inc hl
	ld (hl),d
	ld hl,nrules
	inc (hl)
	ret
noGt0:	xor a
	ld (nogt),a
	ret

; ---- 文 ----
p_stmts:call skipnl
ps0:	ld a,(tok)
	cp '}'
	ret z
	cp TK_EOF
	ret z
	cp TK_SEMI
	jr z,ps_s
	cp TK_NL
	jr z,ps_s
	call p_stmt
	jr ps0
ps_s:	call lex
	jr ps0
p_stmt:	ld a,(tok)
	cp '{'
	jr nz,pst1
	call lex
	call p_stmts
	ld a,'}'
	jp expect
pst1:	cp TK_IF
	jp z,s_if
	cp TK_WHILE
	jp z,s_while
	cp TK_FOR
	jp z,s_for
	cp TK_DO
	jp z,s_do
	cp TK_BREAK
	jp z,s_break
	cp TK_CONT
	jp z,s_cont
	cp TK_NEXT
	jp z,s_next
	cp TK_EXIT
	jp z,s_exit
	cp TK_PRINT
	jp z,s_print
	cp TK_PRINTF
	jp z,s_print
	cp TK_DELETE
	jp z,s_delete
	; 式の文
	call noGt0
	call p_expr
	ld a,O_POP
	call em8
	jp endstmt
s_next:	call lex
	ld a,O_NEXT
	call em8
	jp endstmt
s_exit:	call lex
	ld a,(tok)
	cp TK_SEMI
	jr z,se1
	cp TK_NL
	jr z,se1
	cp '}'
	jr z,se1
	cp TK_EOF
	jr z,se1
	call noGt0
	call p_expr
	ld a,O_EXIT
	call em8
	ld a,1
	call em8
	jp endstmt
se1:	ld a,O_EXIT
	call em8
	xor a
	call em8
	jp endstmt
s_delete:
	call lex
	ld a,(tok)
	cp TK_NAME
	jp nz,ex_err
	ld hl,(tokv)
	ld a,l
	inc a
	ld (arrtmp),a
	call lex
	ld a,(tok)
	cp '['
	jr nz,sdl1
	call lex
	call noGt0
	call p_expr
	ld a,']'
	call expect
	ld a,O_DEL
	call em8
	ld a,(arrtmp)
	call em8
	jp endstmt
sdl1:	ld a,O_DELALL
	call em8
	ld a,(arrtmp)
	call em8
	jp endstmt
; ---- ループ文脈: lpstk の 4バイト [break 連鎖][continue 連鎖] ----
lp_push:ld a,(lpsp)
	cp 8
	jr c,lpp1
	ld hl,msgbig
	jp fatal
lpp1:	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	ld de,lpstk
	add hl,de
	xor a
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	inc hl
	ld (hl),a
	ld hl,lpsp
	inc (hl)
	ret
lp_top:	ld a,(lpsp)
	dec a
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	ld de,lpstk
	add hl,de
	ret
; DE=continue の行き先: ループを閉じる(break はここ=今の位置へ)
lp_end:	push de
	call lp_top
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld hl,lpsp
	dec (hl)
	push bc
	ex de,hl
	ld de,(cptr)
	call patchall
	pop hl
	pop de
	jp patchall
; HL=連鎖の頭の変数 A=命令: 飛び先未定のジャンプを出して連鎖につなぐ
jchain:	push hl
	call em8
	pop hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	dec hl
	push hl
	ld hl,(cptr)
	ex (sp),hl
	pop bc
	ld (hl),c
	inc hl
	ld (hl),b
	jp em16
ch_new:	ld a,(cdep)
	cp 16
	jr c,chn1
	ld hl,msgbig
	jp fatal
chn1:	ld l,a
	ld h,0
	add hl,hl
	ld de,cstk
	add hl,de
	xor a
	ld (hl),a
	inc hl
	ld (hl),a
	dec hl
	ld a,(cdep)
	inc a
	ld (cdep),a
	ret
ch_free:ld hl,cdep
	dec (hl)
	ret
s_break:call lex
	ld a,(lpsp)
	or a
	jp z,ex_err
	call lp_top
	ld a,O_JMP
	call jchain
	jp endstmt
s_cont:	call lex
	ld a,(lpsp)
	or a
	jp z,ex_err
	call lp_top
	inc hl
	inc hl
	ld a,O_JMP
	call jchain
	jp endstmt
s_if:	call lex
	ld a,'('
	call expect
	call noGt0
	call p_expr
	ld a,')'
	call expect
	ld a,O_JZ
	call emjmp
	push hl
	call skipnl
	call p_stmt
	call skipnl
	ld a,(tok)
	cp TK_ELSE
	jr z,si_else
	pop hl
	jp patch
si_else:call lex
	ld a,O_JMP
	call emjmp
	ex (sp),hl
	call patch
	call skipnl
	call p_stmt
	pop hl
	jp patch
s_while:call lex
	ld a,'('
	call expect
	ld hl,(cptr)
	push hl
	call noGt0
	call p_expr
	ld a,')'
	call expect
	ld a,O_JZ
	call emjmp
	push hl
	call lp_push
	call skipnl
	call p_stmt
	pop bc			; JZ の操作数
	pop de			; 先頭
	push bc
	push de
	ld a,O_JMP
	call em8
	pop de
	push de
	call em16
	pop de
	pop hl
	push de
	call patch
	pop de
	jp lp_end
s_do:	call lex
	call lp_push
	call skipnl
	ld hl,(cptr)
	push hl
	call p_stmt
	call skipnl
	ld a,(tok)
	cp TK_WHILE
	jp nz,ex_err
	call lex
	ld a,'('
	call expect
	ld hl,(cptr)
	ld (do_c),hl
	call noGt0
	call p_expr
	ld a,')'
	call expect
	ld a,O_JNZ
	call em8
	pop de
	call em16
	call endstmt
	ld de,(do_c)
	jp lp_end
lex_save:
	ld hl,src
	ld de,lxsv
	ld bc,8
	ldir
	ret
lex_rest:
	ld hl,lxsv
	ld de,src
	ld bc,8
	ldir
	ret
s_for:	call lex
	ld a,'('
	call expect
	ld a,(tok)
	cp TK_NAME
	jr nz,sf_c
	ld hl,(tokv)
	ld (fi_var),hl
	call lex_save
	call lex
	ld a,(tok)
	cp TK_IN
	jr z,sf_in
	call lex_rest
	jr sf_c
sf_in:	call lex
	ld a,(tok)
	cp TK_NAME
	jp nz,ex_err
	ld a,(tokv)
	inc a
	ld (fi_arr),a
	call lex
	ld a,')'
	call expect
	ld a,O_FORI
	call em8
	ld hl,(cptr)
	push hl
	ld a,O_FORN
	call em8
	ld a,(fi_arr)
	call em8
	ld a,(fi_var)
	call em8
	ld hl,(cptr)
	push hl
	ld de,0
	call em16
	call lp_push
	call skipnl
	call p_stmt
	pop bc			; FORN の終わり番地の操作数
	pop de			; 先頭
	push bc
	push de
	ld a,O_JMP
	call em8
	pop de
	push de
	call em16
	pop de
	call lp_end
	ld a,O_POP
	call em8
	pop hl
	jp patch
sf_c:	ld a,(tok)
	cp TK_SEMI
	jr z,sf1
	call noGt0
	call p_expr
	ld a,O_POP
	call em8
sf1:	ld a,TK_SEMI
	call expect
	ld hl,(cptr)
	push hl			; 条件の先頭
	ld a,(tok)
	cp TK_SEMI
	jr z,sf2
	call noGt0
	call p_expr
	ld a,O_JZ
	call emjmp
	push hl
	jr sf3
sf2:	ld hl,0
	push hl
sf3:	ld a,TK_SEMI
	call expect
	ld a,O_JMP
	call emjmp
	push hl			; 本体へ飛ぶ操作数
	ld hl,(cptr)
	push hl			; 増分の先頭
	ld a,(tok)
	cp ')'
	jr z,sf4
	call noGt0
	call p_expr
	ld a,O_POP
	call em8
sf4:	ld a,')'
	call expect
	pop bc			; 増分
	pop de			; 本体へ
	pop hl			; JZ
	ex (sp),hl		; HL=条件の先頭 スタック=JZ
	push bc
	push de
	ld a,O_JMP
	call em8
	ex de,hl
	call em16
	pop hl
	call patch
	call lp_push
	call skipnl
	call p_stmt
	pop bc			; 増分
	pop hl			; JZ
	push hl
	push bc
	ld a,O_JMP
	call em8
	pop de
	push de
	call em16
	pop de
	call lp_end
	pop hl
	ld a,h
	or l
	ret z
	jp patch
; ---- print / printf ----
s_print:ld a,(tok)
	ld (pr_kind),a
	call lex
	ld a,1
	ld (nogt),a
	xor a
	ld (pr_cnt),a
	ld a,(tok)
	cp '('
	jr nz,sp_list
	ld hl,(src)
	call scan_group
	jr nc,sp_list
	call lex
sp_grp:	xor a
	ld (nogt),a
	call p_expr
	ld hl,pr_cnt
	inc (hl)
	ld a,(tok)
	cp ','
	jr nz,sp_gend
	call lex
	call skipnl
	jr sp_grp
sp_gend:ld a,')'
	call expect
	jr sp_redir
sp_list:ld a,(tok)
	cp TK_SEMI
	jr z,sp_redir
	cp TK_NL
	jr z,sp_redir
	cp '}'
	jr z,sp_redir
	cp TK_EOF
	jr z,sp_redir
	cp '>'
	jr z,sp_redir
	cp TK_APPEND
	jr z,sp_redir
sp_l2:	ld a,1
	ld (nogt),a
	call p_expr
	ld hl,pr_cnt
	inc (hl)
	ld a,(tok)
	cp ','
	jr nz,sp_redir
	call lex
	call skipnl
	jr sp_l2
sp_redir:
	xor a
	ld (pr_md),a
	ld a,(tok)
	cp '>'
	jr nz,spr1
	ld a,1
	jr spr2
spr1:	cp TK_APPEND
	jr nz,spr9
	ld a,2
spr2:	ld (pr_md),a
	call lex
	ld a,1
	ld (nogt),a
	call p_concat
spr9:	xor a
	ld (nogt),a
	ld a,(pr_kind)
	cp TK_PRINTF
	ld a,O_PRINT
	jr nz,spr10
	ld a,O_PRINTF
spr10:	call em8
	ld a,(pr_cnt)
	call em8
	ld a,(pr_md)
	call em8
	jp endstmt
; HL=( の次: 対応する ) の次が 文の終わり/リダイレクトなら CF=1
scan_group:
	ld b,1
sg1:	ld a,(hl)
	or a
	jr z,sg_n
	inc hl
	cp '"'
	jr z,sg_q
	cp 27h
	jr z,sg_q
	cp '('
	jr nz,sg2
	inc b
	jr sg1
sg2:	cp ')'
	jr nz,sg1
	dec b
	jr nz,sg1
sg3:	ld a,(hl)
	cp ' '
	jr z,sg4
	cp 09h
	jr nz,sg5
sg4:	inc hl
	jr sg3
sg5:	or a
	jr z,sg_y
	cp 0Ah
	jr z,sg_y
	cp 0Dh
	jr z,sg_y
	cp ';'
	jr z,sg_y
	cp '}'
	jr z,sg_y
	cp '>'
	jr z,sg_y
sg_n:	and a
	ret
sg_y:	scf
	ret
sg_q:	ld c,a
sgq1:	ld a,(hl)
	or a
	jr z,sg_n
	inc hl
	cp c
	jr nz,sgq1
	jr sg1

; ---- 式 (代入が一番弱い) ----
em_val4:call em8
	xor a
	call em8
	call em8
	jp em8
em_zero4:
	xor a
	jr em_val4
lv_chk:	ld a,(lv_kind)
	or a
	jp z,ex_err
	ld hl,(lv_end)
	ld de,(cptr)
	or a
	sbc hl,de
	jp nz,ex_err
	ret
p_expr:	call p_tern
	ld a,(tok)
	cp '='
	jr z,pe_a
	cp TK_ADDA
	ret c
	cp TK_POWA+1
	ret nc
pe_a:	ld c,a
	call lv_chk
	ld d,0
	ld a,c
	cp '='
	jr z,pe_b
	sub TK_ADDA
	ld e,a
	ld d,0
	ld hl,arithtab
	add hl,de
	ld d,(hl)
pe_b:	ld a,(lv_kind)
	ld e,a
	ld a,(lv_idx)
	ld b,a
	push de
	push bc
	ld a,e
	cp 1
	jr nz,pe_k
	ld a,d
	or a
	jr nz,pe_lex
	ld hl,(lv_ld)
	ld (cptr),hl
	jr pe_lex
pe_k:	ld hl,(lv_ld)
	ld (cptr),hl
	ld a,d
	or a
	jr z,pe_lex
	ld a,O_DUP
	call em8
	ld a,e
	cp 2
	jr nz,pe_ra
	ld a,O_LOADF
	call em8
	jr pe_lex
pe_ra:	ld a,O_LOADA
	call em8
	ld a,b
	call em8
pe_lex:	xor a
	ld (lv_kind),a
	call lex
	call skipnl
	call p_expr
	pop bc
	pop de
	ld a,d
	or a
	jr z,pe_st
	call em8
pe_st:	ld a,e
	cp 1
	jr nz,pe_s2
	ld a,O_STOREV
	call em8
	ld a,b
	jp em8
pe_s2:	cp 2
	jr nz,pe_s3
	ld a,O_STOREF
	jp em8
pe_s3:	ld a,O_STOREA
	call em8
	ld a,b
	jp em8
arithtab:
	defb O_ADD,O_SUB,O_MUL,O_DIV,O_MOD,O_POW
p_tern:	call p_or
	ld a,(tok)
	cp '?'
	ret nz
	call lex
	call skipnl
	ld a,O_JZ
	call emjmp
	push hl
	call p_tern
	ld a,':'
	call expect
	call skipnl
	ld a,O_JMP
	call emjmp
	ex (sp),hl
	call patch
	call p_tern
	pop hl
	jp patch
p_or:	call p_and
	ld a,(tok)
	cp TK_OR
	ret nz
	call ch_new
	push hl
po1:	pop hl
	push hl
	ld a,O_JNZ
	call jchain
	call lex
	call skipnl
	call p_and
	ld a,(tok)
	cp TK_OR
	jr z,po1
	pop hl
	ld a,O_JNZ
	ld b,0
	jp lg_fin
p_and:	call p_in
	ld a,(tok)
	cp TK_AND
	ret nz
	call ch_new
	push hl
pand1:	pop hl
	push hl
	ld a,O_JZ
	call jchain
	call lex
	call skipnl
	call p_in
	ld a,(tok)
	cp TK_AND
	jr z,pand1
	pop hl
	ld a,O_JZ
	ld b,1
; HL=連鎖の頭の変数 A=ジャンプ命令 B=全部通ったときの値
lg_fin:	ld (lg_h),hl
	ld c,a
	ld a,b
	ld (lg_v),a
	ld a,c
	call jchain
	ld a,O_PUSHN
	call em8
	ld a,(lg_v)
	call em_val4
	ld a,O_JMP
	call emjmp
	push hl
	ld hl,(lg_h)
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	call patchhere
	call ch_free
	ld a,O_PUSHN
	call em8
	ld a,(lg_v)
	xor 1
	call em_val4
	pop hl
	jp patch
p_in:	call p_match
pin1:	ld a,(tok)
	cp TK_IN
	ret nz
	call lex
	ld a,(tok)
	cp TK_NAME
	jp nz,ex_err
	ld a,(tokv)
	inc a
	ld (arrtmp),a
	call lex
	ld a,O_IN
	call em8
	ld a,(arrtmp)
	call em8
	jr pin1
p_match:call p_cmp
pm1:	ld a,(tok)
	cp '~'
	jr z,pm2
	cp TK_NMATCH
	ret nz
pm2:	push af
	call lex
	ld a,(tok)
	cp TK_ERE
	jr nz,pm_dyn
	ld a,(tokv)
	ld (pm_n),a
	call lex
	pop af
	cp '~'
	ld a,O_MATCH
	jr z,pm3
	ld a,O_NMATCH
pm3:	call em8
	ld a,(pm_n)
	call em8
	jr pm1
pm_dyn:	call p_cmp
	pop af
	cp '~'
	ld a,O_DMATCH
	jr z,pm4
	ld a,O_NDMATCH
pm4:	call em8
	jr pm1
p_cmp:	call p_concat
	ld a,(tok)
	ld hl,cmptab
pc2:	ld b,(hl)
	inc hl
	ld c,(hl)
	inc hl
	inc b
	dec b
	ret z
	cp b
	jr nz,pc2
	cp '>'
	jr nz,pc3
	ld a,(nogt)
	or a
	ret nz
pc3:	push bc
	call lex
	call p_concat
	pop bc
	ld a,c
	jp em8
cmptab:	defb '<',O_LT,TK_LE,O_LE,TK_EQ,O_EQ,TK_NE,O_NE,'>',O_GT,TK_GE,O_GE,0,0
p_concat:
	call p_add
pcc1:	ld a,(tok)
	cp TK_NUM
	jr z,pcc2
	cp TK_STR
	jr z,pcc2
	cp TK_NAME
	jr z,pcc2
	cp TK_FUNC
	jr z,pcc2
	cp '$'
	jr z,pcc2
	cp '('
	jr z,pcc2
	cp '!'
	ret nz
	jr pcc2
pcc2:	call p_add
	ld a,O_CAT
	call em8
	jr pcc1
p_add:	call p_mul
pad1:	ld a,(tok)
	cp '+'
	jr z,pad2
	cp '-'
	ret nz
pad2:	push af
	call lex
	call p_mul
	pop af
	cp '+'
	ld a,O_ADD
	jr z,pad3
	ld a,O_SUB
pad3:	call em8
	jr pad1
p_mul:	call p_unary
pml1:	ld a,(tok)
	cp '*'
	ld b,O_MUL
	jr z,pml2
	cp '/'
	ld b,O_DIV
	jr z,pml2
	cp '%'
	ld b,O_MOD
	ret nz
pml2:	push bc
	call lex
	call p_unary
	pop bc
	ld a,b
	call em8
	jr pml1
p_unary:ld a,(tok)
	ld b,O_NEG
	cp '-'
	jr z,pu1
	ld b,O_PLUS
	cp '+'
	jr z,pu1
	ld b,O_NOT
	cp '!'
	jr z,pu1
	jp p_pow
pu1:	push bc
	call lex
	call p_unary
	pop bc
	ld a,b
	jp em8
p_pow:	call p_post
	ld a,(tok)
	cp '^'
	ret nz
	call lex
	call p_unary
	ld a,O_POW
	jp em8
p_post:	call p_prim
	ld a,(tok)
	cp TK_INCR
	ld b,1
	jr z,pp_1
	cp TK_DECR
	ret nz
	ld b,3
pp_1:	push bc
	call lex
	pop bc
	ld a,b
	jp emit_inc
; A=フラグ: 直前の左辺値を ++/-- に変える
emit_inc:
	ld (inc_f),a
	call lv_chk
	ld hl,(lv_ld)
	ld (cptr),hl
	ld a,(lv_kind)
	ld b,a
	xor a
	ld (lv_kind),a
	ld a,b
	cp 1
	jr z,ei1
	cp 3
	jr z,ei3
	ld a,O_INCF
	call em8
	ld a,(inc_f)
	jp em8
ei1:	ld a,O_INCV
	jr ei4
ei3:	ld a,O_INCA
ei4:	call em8
	ld a,(lv_idx)
	call em8
	ld a,(inc_f)
	jp em8
p_prim:	ld a,(tok)
	cp TK_NUM
	jr z,pr_num
	cp TK_STR
	jr z,pr_str
	cp TK_NAME
	jp z,pr_name
	cp '$'
	jp z,pr_dollar
	cp '('
	jp z,pr_par
	cp TK_FUNC
	jp z,p_func
	cp TK_ERE
	jp z,pr_ere
	cp TK_INCR
	jr z,pr_pre
	cp TK_DECR
	jr z,pr_pre
	cp TK_GETL
	jr z,pr_getl
	jp ex_err
pr_num:	ld a,O_PUSHN
	call em8
	ld hl,tokv
	ld b,4
pn1:	ld a,(hl)
	call em8
	inc hl
	djnz pn1
	jp lex
pr_str:	ld a,O_PUSHS
	call em8
	ld de,(tokv)
	call em16
	jp lex
pr_ere:	ld a,(tokv)
	push af
	ld a,O_PUSHN
	call em8
	call em_zero4
	ld a,O_LOADF
	call em8
	ld a,O_MATCH
	call em8
	pop af
	call em8
	jp lex
pr_getl:ld a,O_GETL
	call em8
	jp lex
pr_pre:	ld a,(tok)
	cp TK_INCR
	ld a,0
	jr z,pre1
	ld a,2
pre1:	push af
	call lex
	call p_prim
	pop af
	jp emit_inc
pr_par:	call lex
	ld a,(nogt)
	push af
	xor a
	ld (nogt),a
	call skipnl
	call p_expr
	pop af
	ld (nogt),a
	ld a,')'
	jp expect
pr_dollar:
	call lex
	call p_prim
	ld hl,(cptr)
	ld (lv_ld),hl
	ld a,O_LOADF
	call em8
	ld hl,(cptr)
	ld (lv_end),hl
	ld a,2
	ld (lv_kind),a
	ret
pr_name:ld a,(tokv)
	push af
	call lex
	ld a,(tok)
	cp '['
	jr z,pn_arr
	ld hl,(cptr)
	ld (lv_ld),hl
	ld a,O_LOADV
	call em8
	pop af
	ld (lv_idx),a
	call em8
	ld hl,(cptr)
	ld (lv_end),hl
	ld a,1
	ld (lv_kind),a
	ret
pn_arr:	call lex
	call skipnl
	ld a,(nogt)
	push af
	xor a
	ld (nogt),a
	call p_expr
	pop af
	ld (nogt),a
	ld a,']'
	call expect
	pop af
	inc a
	push af
	ld hl,(cptr)
	ld (lv_ld),hl
	ld a,O_LOADA
	call em8
	pop af
	ld (lv_idx),a
	call em8
	ld hl,(cptr)
	ld (lv_end),hl
	ld a,3
	ld (lv_kind),a
	ret
; ---- 組み込み関数 ----
; 引数: 正規表現リテラルが , か ) の前に1個だけ置かれていたら 元の文字列を積む
p_arg:	ld a,(tok)
	cp TK_ERE
	jr nz,pa_x
	ld hl,(tokv2)
	ld (ar_s),hl
	call lex
	ld a,(tok)
	cp ','
	jr z,par1
	cp ')'
	jp nz,ex_err
par1:	ld a,O_PUSHS
	call em8
	ld de,(ar_s)
	jp em16
pa_x:	xor a
	ld (nogt),a
	jp p_expr
em_pn1:	push af
	ld a,O_PUSHN
	call em8
	pop af
	call em8
	xor a
	call em8
	call em8
	jp em8
p_func:	ld a,(tokv)
	push af
	call lex
	ld a,(tok)
	cp '('
	jr z,pf_a
	pop af
	or a
	jp nz,ex_err
	ld a,O_CALL
	call em8
	xor a
	call em8
	jp em8
pf_a:	call lex
	pop af
	push af
	cp 3
	jp z,pf_split
	cp 8
	jr z,pf_sub
	cp 9
	jr z,pf_sub
	ld b,0
pg1:	ld a,(tok)
	cp ')'
	jr z,pg9
	push bc
	call p_arg
	pop bc
	inc b
	ld a,(tok)
	cp ','
	jr nz,pg9
	push bc
	call lex
	call skipnl
	pop bc
	jr pg1
pg9:	push bc
	ld a,')'
	call expect
	pop bc
	pop af
	ld c,a
	ld a,O_CALL
	call em8
	ld a,c
	call em8
	ld a,b
	jp em8
; sub(re, repl [, 変数]) : 引数は常に3個 (3つ目 255=$0 / 変数番号)
pf_sub:	call p_arg
	ld a,','
	call expect
	call p_arg
	ld a,(tok)
	cp ','
	jr nz,ps_d
	call lex
	ld a,(tok)
	cp TK_NAME
	jr nz,ps_f
	ld a,(tokv)
	call em_pn1
	call lex
	jr ps_e
ps_f:	cp '$'
	jp nz,ex_err
	call lex
	call lex
	ld a,255
	call em_pn1
	jr ps_e
ps_d:	ld a,255
	call em_pn1
ps_e:	ld a,')'
	call expect
	pop af
	ld c,a
	ld a,O_CALL
	call em8
	ld a,c
	call em8
	ld a,3
	jp em8
; split(s, 配列 [, 区切り])
pf_split:
	call p_arg
	ld a,','
	call expect
	ld a,(tok)
	cp TK_NAME
	jp nz,ex_err
	ld a,(tokv)
	inc a
	call em_pn1
	call lex
	ld b,2
	ld a,(tok)
	cp ','
	jr nz,psp1
	push bc
	call lex
	call p_arg
	pop bc
	inc b
psp1:	push bc
	ld a,')'
	call expect
	pop bc
	pop af
	ld c,a
	ld a,O_CALL
	call em8
	ld a,c
	call em8
	ld a,b
	jp em8
