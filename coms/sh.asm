; SH.COM - シェルスクリプト(zsh/bash のサブセット)を LSX の BAT へ変換する。 MIT License
; 使い方: sh script.sh   → script.BAT を作る(実行は `script`)
; 対応: コメント / NAME=値 / export / unset / echo などのコマンドはそのまま /
;   if [ ... ]; then / elif / else / fi, while [ ... ]; do / done, for V in 語...; do / done(語の数だけ展開) /
;   break / continue(while のみ) / exit / cmd && cmd / cmd || cmd(一行にどちらか片方だけ) / ; 区切り
;   条件: -e -f -d -s -r -w -x -h -L(=存在) -z -n  a = b  a == b  a != b  ! と test / [[ ]]
; 非対応は `rem [sh]` にして警告を出す: $(...) ` $((...)) $# $@ $* $0 case function read shift local 条件の -lt など
	org 0100h

STMT	equ 3000h	; 1文 (最大200文字)
CNDBUF	equ 3100h	; トークン文字列
TOKS	equ 3200h	; トークンへのポインタ (最大24)
FPOOL	equ 3300h	; for の語 (512バイト)
BLK	equ 3500h	; ブロックスタック 16バイト x 8
BLKEND	equ 3580h
ONAME	equ 3600h	; 出力ファイル名
SRC	equ 4000h
SRCEND	equ 7F00h
OUT	equ 8000h
OUTLIM	equ 9E00h

	ld sp,0A000h
	ld hl,0080h
	ld a,(hl)
	inc hl
	ld e,a
	ld d,0
	add hl,de
	ld (hl),0
	ld hl,0081h
	call skipsp
	or a
	jp z,usage
	ld (inname),hl
fnend:	ld a,(hl)
	or a
	jr z,fnok
	cp ' '
	jr z,fnsp
	inc hl
	jr fnend
fnsp:	ld (hl),0
fnok:
; 出力名: 入力名の拡張子を .BAT に (拡張子が無ければ付ける)
	ld hl,(inname)
	ld de,ONAME
	ld bc,0
oname1:	ld a,(hl)
	ld (de),a
	or a
	jr z,oname2
	cp '.'
	jr nz,on_a
	ld (dotp),de
	jr on_n
on_a:	cp 5Ch
	jr z,on_r
	cp ':'
	jr nz,on_n
on_r:	ld bc,0
	ld (dotp),bc
on_n:	inc hl
	inc de
	jr oname1
oname2:	ld hl,(dotp)
	ld a,h
	or l
	jr z,on_app
	ex de,hl
on_app:	ld hl,sBAT
	ld bc,6
	ldir
; 入力と出力が同じ名前なら中止(元のファイルを壊さない)
	ld hl,(inname)
	ld de,ONAME
	call streqi
	jp z,errsame
; 読み込み
	ld de,(inname)
	ld a,1
	ld c,43h
	call 5
	or a
	jp nz,erropen
	ld a,b
	ld (hin),a
	ld hl,SRC
	ld (srcp),hl
rd1:	ld hl,(srcp)
	ex de,hl
	ld hl,SRCEND
	or a
	sbc hl,de
	jp c,errbig
	ld a,h
	cp 10h
	jr c,rd2
	ld hl,1000h
rd2:	ld a,(hin)
	ld b,a
	ld c,48h
	call 5
	or a
	jr nz,rd3
	ld a,h
	or l
	jr z,rd3
	ld de,(srcp)
	add hl,de
	ld (srcp),hl
	jr rd1
rd3:	ld hl,(srcp)
	ld (hl),0
	ld a,(hin)
	ld b,a
	ld c,45h
	call 5
; 初期化
	ld hl,SRC
	ld (srcp),hl
	ld hl,OUT
	ld (outp),hl
	ld (linep),hl
	ld hl,1
	ld (lineno),hl
	ld hl,BLK
	ld (blkp),hl
	ld hl,FPOOL
	ld (fpp),hl
main1:	call nextstmt
	jr c,mdone
	call stmt
	jr main1
mdone:	ld hl,(blkp)
	ld de,BLK
	or a
	sbc hl,de
	jr z,md2
	ld de,mUNTERM
	call warnmsg
md2:	ld a,':'
	call putc
	ld hl,sQIT
	call puts
	call nl
	ld a,(ovf)
	or a
	jp nz,errbig
; 書き出し
	ld de,ONAME
	ld a,0
	ld b,0
	ld c,44h
	call 5
	or a
	jp nz,errcreate
	ld a,b
	ld (hin),a
	ld hl,(outp)
	ld de,OUT
	or a
	sbc hl,de
	ld a,h
	or l
	jr z,wr2
	ld a,(hin)
	ld b,a
	ld de,OUT
	ld c,49h
	call 5
	or a
	jp nz,errcreate
wr2:	ld a,(hin)
	ld b,a
	ld c,45h
	call 5
	ld de,mWROTE
	ld c,9
	call 5
	ld de,ONAME
	call conputs
	ld a,(nwarn)
	or a
	jp z,0
	ld de,mWARN
	ld c,9
	call 5
	jp 0

usage:	ld de,mUSAGE
	jr bye
erropen:ld de,mOPEN
	jr bye
errbig:	ld de,mBIG
	jr bye
errsame:ld de,mSAME
	jr bye
errcreate:
	ld de,mCREATE
bye:	ld c,9
	call 5
	jp 0

;---------------------------------------------------------------- 入力
skipsp:	ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr skipsp

; 次の文を STMT に取り出す。CF=1:終わり
nextstmt:
	ld hl,(srcp)
ns1:	ld a,(hl)
	or a
	jr z,ns_eof
	cp 1Ah
	jr z,ns_eof
	cp 10
	jr z,ns_nl
	cp ' '
	jr z,ns_s
	cp 9
	jr z,ns_s
	cp 13
	jr z,ns_s
	cp ';'
	jr z,ns_s
	cp '#'
	jr z,ns_cm
	jr ns_go
ns_s:	inc hl
	jr ns1
ns_nl:	inc hl
	call incline
	jr ns1
ns_cm:	ld a,(hl)
	or a
	jr z,ns1
	cp 10
	jr z,ns1
	inc hl
	jr ns_cm
ns_eof:	ld (srcp),hl
	scf
	ret
ns_go:	ld de,STMT
	ld b,0			; B=引用符 (0:なし)
ns_c:	ld a,(hl)
	or a
	jr z,ns_end
	cp 1Ah
	jr z,ns_end
	cp 13
	jr z,ns_skip
	ld c,a
	ld a,b
	or a
	jr nz,ns_inq
	ld a,c
	cp 10
	jr z,ns_end
	cp ';'
	jr z,ns_semi
	cp '#'
	jr nz,ns_q1
	ld a,l			; "#" が語頭ならコメント
	ld a,d
	cp STMT/256
	jr nz,ns_hc
	ld a,e
	or a
	jr z,ns_end
ns_hc:	dec de
	ld a,(de)
	inc de
	cp ' '
	jr z,ns_end
	ld a,c
	jr ns_put
ns_q1:	cp '"'
	jr z,ns_oq
	cp 27h
	jr nz,ns_put
ns_oq:	ld b,a
	jr ns_put
ns_inq:	ld a,c
	cp b
	jr nz,ns_put
	ld b,0
ns_put:	ld a,e
	cp 200
	jr nc,ns_skip		; 長すぎる分は捨てる
	ld a,c
	ld (de),a
	inc de
ns_skip:inc hl
	jr ns_c
ns_semi:inc hl			; ';' は読み飛ばす
ns_end:	xor a
	ld (de),a
	ld (srcp),hl
; 末尾の空白を落とす
ns_t:	dec de
	ld a,e
	or a
	jr z,ns_ok		; 先頭まで来たら終わり
	ld a,(de)
	cp ' '
	jr z,ns_t1
	cp 9
	jr nz,ns_ok
ns_t1:	xor a
	ld (de),a
	jr ns_t
ns_ok:	or a
	ret

incline:push hl
	ld hl,(lineno)
	inc hl
	ld (lineno),hl
	pop hl
	ret

;---------------------------------------------------------------- 出力
; A を出力バッファへ (全レジスタ保存)
putc:	push hl
	push de
	push af
	ld hl,(outp)
	ld de,OUTLIM
	or a
	sbc hl,de
	jr nc,putc_o
	pop af
	ld hl,(outp)
	ld (hl),a
	inc hl
	ld (outp),hl
	pop de
	pop hl
	ret
putc_o:	ld a,1
	ld (ovf),a
	pop af
	pop de
	pop hl
	ret

puts:	ld a,(hl)
	or a
	ret z
	call putc
	inc hl
	jr puts

; 行末: 4文字未満なら空白で埋める (LSX のバッチは4文字未満の行で終わるため)
nl:	push hl
	push de
	push bc
	ld hl,(outp)
	ld de,(linep)
	or a
	sbc hl,de
	ld a,h
	or a
	jr nz,nl2
	ld a,l
	cp 4
	jr nc,nl2
	ld b,a
	ld a,4
	sub b
	ld b,a
nl1:	ld a,' '
	call putc
	djnz nl1
nl2:	ld a,13
	call putc
	ld a,10
	call putc
	ld hl,(outp)
	ld (linep),hl
	pop bc
	pop de
	pop hl
	ret

; 3桁の10進 (DE=0..999)
putn3:	push hl
	push de
	ex de,hl
	ld de,100
	call dig
	ld de,10
	call dig
	ld a,l
	add a,'0'
	call putc
	pop de
	pop hl
	ret
dig:	ld a,'0'-1
dg1:	inc a
	or a
	sbc hl,de
	jr nc,dg1
	add hl,de
	jp putc

; ラベル名 (A=文字, DE=番号) を出す
putlbl:	call putc
	jp putn3

; 新しいラベル番号を DE に
newlbl:	ld hl,(labn)
	inc hl
	ld (labn),hl
	ex de,hl
	ret

;---------------------------------------------------------------- 警告
conputs:ld a,(de)		; DE=0終端の文字列を画面へ
	or a
	ret z
	push de
	ld e,a
	ld c,2
	call 5
	pop de
	inc de
	jr conputs

; DE='$'終端のメッセージ。"sh: line N: " を前置きして出す
warnmsg:push de
	ld a,(nwarn)
	inc a
	jr z,wm0
	ld (nwarn),a
wm0:	ld de,mLINE
	ld c,9
	call 5
	ld hl,(lineno)
	call condec
	ld de,mCOLON
	ld c,9
	call 5
	pop de
	ld c,9
	call 5
	ret

condec:	xor a
	ld (cdz),a
	ld bc,10000
	call cd1
	ld bc,1000
	call cd1
	ld bc,100
	call cd1
	ld bc,10
	call cd1
	ld a,l
	add a,'0'
	jr cdout
cd1:	ld a,'0'-1
cd2:	inc a
	or a
	sbc hl,bc
	jr nc,cd2
	add hl,bc
	cp '0'
	jr nz,cd3
	ld e,a
	ld a,(cdz)
	or a
	ret z
	ld a,e
	jr cdout
cd3:	ld e,a
	ld a,1
	ld (cdz),a
	ld a,e
cdout:	push hl
	push bc
	ld e,a
	ld c,2
	call 5
	pop bc
	pop hl
	ret

;---------------------------------------------------------------- 文字列
; HL と DE を比べる (0終端、大文字小文字を区別しない)。Z=等しい
streqi:	ld a,(hl)
	call upc
	ld b,a
	ld a,(de)
	call upc
	cp b
	ret nz
	or a
	ret z
	inc hl
	inc de
	jr streqi
upc:	cp 'a'
	ret c
	cp 'z'+1
	ret nc
	sub 20h
	ret

; HL と DE を比べる (区別する)。Z=等しい
streq:	ld a,(de)
	cp (hl)
	ret nz
	or a
	ret z
	inc hl
	inc de
	jr streq

; HL のキーワードが DE の文の先頭の語と一致するか。Z=一致 (restp=その後ろの空白を飛ばした位置)
kwmatch:ld a,(hl)
	or a
	jr z,km_end
	ld b,a
	ld a,(de)
	cp b
	ret nz
	inc hl
	inc de
	jr kwmatch
km_end:	ld a,(de)
	or a
	jr z,km_ok
	cp ' '
	ret nz
km_ok:	ld a,(de)
	cp ' '
	jr nz,km_f
	inc de
	jr km_ok
km_f:	ld (restp),de
	xor a
	ret

;---------------------------------------------------------------- トークン分割
; HL=文字列 → CNDBUF に語を並べ、TOKS にポインタ、(ntok) に個数。引用符は外す
tokenize:
	xor a
	ld (ntok),a
	ld de,CNDBUF
	ld ix,TOKS
tk1:	call skipsp
	or a
	ret z
	ld a,(ntok)
	cp 24
	ret nc
	inc a
	ld (ntok),a
	ld (ix+0),e
	ld (ix+1),d
	inc ix
	inc ix
tk2:	ld a,(hl)
	or a
	jr z,tk4
	cp ' '
	jr z,tk4
	cp '"'
	jr z,tk3
	cp 27h
	jr z,tk3
	ld (de),a
	inc de
	inc hl
	jr tk2
tk3:	ld b,a
	inc hl
tk3a:	ld a,(hl)
	or a
	jr z,tk4
	cp b
	jr z,tk3b
	ld (de),a
	inc de
	inc hl
	jr tk3a
tk3b:	inc hl
	jr tk2
tk4:	xor a
	ld (de),a
	inc de
	jr tk1

; A=番号 → HL=トークンへのポインタ
gettok:	ld l,a
	ld h,0
	add hl,hl
	ld de,TOKS
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret

;---------------------------------------------------------------- 条件式
; HL=条件のテキスト ("[ ... ]" か "test ..." )。CF=1:対応外。結果: ckind(0 存在/1 文字列一致) carg1 carg2 cneg
parsecond:
	call tokenize
	xor a
	ld (cneg),a
	ld a,(ntok)
	or a
	jp z,pc_bad
	xor a
	call gettok
	ex de,hl
	ld hl,sLB
	call streq
	jr z,pc_br
	ld hl,sLBB
	call streq
	jr z,pc_br
	ld hl,sTEST
	call streq
	jr z,pc_test
	jp pc_bad
pc_br:	ld a,1
	ld (ts),a
	ld a,(ntok)
	dec a
	push af
	call gettok
	ex de,hl
	ld hl,sRB
	call streq
	jr z,pc_rb
	ld hl,sRBB
	call streq
	jr z,pc_rb
	pop af
	jp pc_bad
pc_rb:	pop af
	ld (te),a
	jr pc_body
pc_test:ld a,1
	ld (ts),a
	ld a,(ntok)
	ld (te),a
pc_body:ld a,(ts)
	call gettok
	ex de,hl
	ld hl,sNOT
	call streq
	jr nz,pc_n1
	ld a,1
	ld (cneg),a
	ld hl,ts
	inc (hl)
pc_n1:	ld a,(te)
	ld hl,ts
	sub (hl)
	cp 1
	jr z,pc_r1
	cp 2
	jr z,pc_r2
	cp 3
	jp z,pc_r3
	jp pc_bad
pc_r1:	ld a,(ts)
	call gettok
	ld (carg1),hl
	ld hl,sEMPTY
	ld (carg2),hl
	ld a,1
	ld (ckind),a
	ld hl,cneg
	ld a,(hl)
	xor 1
	ld (hl),a
	or a			; CF=0
	ret
pc_r2:	ld a,(ts)
	inc a
	call gettok
	ld (carg1),hl
	ld a,(ts)
	call gettok
	ex de,hl		; DE=演算子
	ld hl,sZ
	call streq
	jr z,pc_zn
	ld a,(ts)
	call gettok
	ex de,hl
	ld hl,sN
	call streq
	jr nz,pc_ex
	ld hl,cneg
	ld a,(hl)
	xor 1
	ld (hl),a
pc_zn:	ld a,1
	ld (ckind),a
	ld hl,sEMPTY
	ld (carg2),hl
	or a
	ret
pc_ex:	ld a,(ts)
	call gettok
	ld a,(hl)
	cp '-'
	jp nz,pc_bad
	inc hl
	ld c,(hl)
	inc hl
	ld a,(hl)
	or a
	jp nz,pc_bad		; 2文字より長い
	ld a,c
	ld hl,sEXOPS
pc_e1:	cp (hl)
	jr z,pc_e2
	inc hl
	ld b,a
	ld a,(hl)
	or a
	ld a,b
	jr nz,pc_e1
	jp pc_bad
pc_e2:	xor a
	ld (ckind),a
	ret
pc_r3:	ld a,(ts)
	inc a
	call gettok
	ex de,hl
	ld hl,sEQ
	call streq
	jr z,pc_eq
	ld hl,sEQ2
	call streq
	jr z,pc_eq
	ld hl,sNE
	call streq
	jr nz,pc_bad
	ld hl,cneg
	ld a,(hl)
	xor 1
	ld (hl),a
pc_eq:	ld a,(ts)
	call gettok
	ld (carg1),hl
	ld a,(ts)
	add a,2
	call gettok
	ld (carg2),hl
	ld a,1
	ld (ckind),a
	or a
	ret
pc_bad:	scf
	ret

; A=J (条件が J のとき飛ぶ), C=ラベル文字, DE=ラベル番号 で "if [not] ... goto Lnnn" を出す
emitcond:
	push de
	push bc
	ld b,a
	ld a,(cneg)
	xor b
	push af
	ld hl,sIF
	call puts
	pop af
	or a
	jr nz,ec_nn
	ld hl,sNOTSP
	call puts
ec_nn:	ld a,(ckind)
	or a
	jr nz,ec_s
	ld hl,sEXIST
	call puts
	ld hl,(carg1)
	call puts
	jr ec_g
ec_s:	ld a,'_'
	call putc
	ld hl,(carg1)
	call puts
	ld hl,sEQ_
	call puts
	ld hl,(carg2)
	call puts
ec_g:	ld hl,sGOTO
	call puts
	pop bc
	pop de
	ld a,c
	call putlbl
	jp nl

;---------------------------------------------------------------- ブロックスタック
; A=種類 → IX=エントリ。CF=1:いっぱい
pushblk:ld hl,(blkp)
	ld de,BLKEND
	or a
	sbc hl,de
	jr c,pb1
	scf
	ret
pb1:	ld hl,(blkp)
	push hl
	pop ix
	ld (ix+0),a
	ld (ix+1),0
	ld de,16
	add hl,de
	ld (blkp),hl
	or a
	ret

; IX=最上位エントリ。CF=1:空
topblk:	ld hl,(blkp)
	ld de,BLK
	or a
	sbc hl,de
	jr nz,tb1
	scf
	ret
tb1:	ld hl,(blkp)
	ld de,-16
	add hl,de
	push hl
	pop ix
	or a
	ret

popblk:	ld hl,(blkp)
	ld de,-16
	add hl,de
	ld (blkp),hl
	ret

; 一番内側のループ → IX。CF=1:無い
findloop:
	ld hl,(blkp)
fl1:	ld de,BLK
	or a
	sbc hl,de
	jr z,fl_no
	add hl,de
	ld de,-16
	add hl,de
	ld a,(hl)
	cp 1
	jr nz,fl_y
	jr fl1
fl_y:	push hl
	pop ix
	or a
	ret
fl_no:	scf
	ret

;---------------------------------------------------------------- 文
unsup:	ld de,mUNSUP
	call warnmsg
	ld hl,sREMSH
	call puts
	ld hl,STMT
	call puts
	jp nl

; "$(" "`" "$#" "$@" "$*" "$0" を含むか。CF=1:含む
hasunsup:
	ld hl,STMT
hu1:	ld a,(hl)
	or a
	jr z,hu_no
	cp '`'
	jr z,hu_yes
	cp '$'
	jr nz,hu2
	inc hl
	ld a,(hl)
	cp '('
	jr z,hu_yes
	cp '#'
	jr z,hu_yes
	cp '@'
	jr z,hu_yes
	cp '*'
	jr z,hu_yes
	cp '0'
	jr z,hu_yes
	dec hl
hu2:	inc hl
	jr hu1
hu_no:	or a
	ret
hu_yes:	scf
	ret

; 文を処理する (STMT)
stmt:	call hasunsup
	jp c,unsup
	ld ix,kwtab
disp:	ld l,(ix+0)
	ld h,(ix+1)
	ld a,h
	or l
	jp z,chain
	ld de,STMT
	call kwmatch
	jr z,disp_f
	inc ix
	inc ix
	inc ix
	inc ix
	jr disp
disp_f:	ld l,(ix+2)
	ld h,(ix+3)
	jp (hl)

kwtab:	defw kTHEN,h_rest
	defw kDO,h_rest
	defw kEXPORT,h_rest
	defw kIF,h_if
	defw kELIF,h_elif
	defw kELSE,h_else
	defw kFI,h_fi
	defw kWHILE,h_while
	defw kDONE,h_done
	defw kFOR,h_for
	defw kSET,h_set
	defw kCASE,unsup
	defw kESAC,unsup
	defw kFUNCTION,unsup
	defw kREAD,unsup
	defw kSHIFT,unsup
	defw kLOCAL,unsup
	defw kRETURN,unsup
	defw kSOURCE,unsup
	defw kDOT,unsup
	defw 0

; キーワードの後ろを新しい文として処理する
h_rest:	ld hl,(restp)
	ld a,(hl)
	or a
	ret z
	ld de,STMT
hr1:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,hr1
	jp stmt

; set -e などオプションだけの set は何もしない
h_set:	ld hl,(restp)
	ld a,(hl)
	cp '-'
	ret z
	cp '+'
	ret z
	jp chain

h_if:	ld hl,(restp)
	call parsecond
	jp c,unsup
	ld a,1
	call pushblk
	jp c,unsup
	call newlbl
	ld (ix+2),e
	ld (ix+3),d
	call newlbl
	ld (ix+4),e
	ld (ix+5),d
	xor a
	ld c,'E'
	jp emitcond

h_elif:	call topblk
	jp c,unsup
	ld a,(ix+0)
	cp 1
	jp nz,unsup
	push ix
	ld hl,sGOTO2
	call puts
	ld a,'F'
	ld e,(ix+2)
	ld d,(ix+3)
	call putlbl
	call nl
	ld a,':'
	call putc
	ld a,'E'
	ld e,(ix+4)
	ld d,(ix+5)
	call putlbl
	call nl
	call newlbl
	pop ix
	ld (ix+4),e
	ld (ix+5),d
	push ix
	ld hl,(restp)
	call parsecond
	pop ix
	jp c,unsup
	ld e,(ix+4)
	ld d,(ix+5)
	xor a
	ld c,'E'
	jp emitcond

h_else:	call topblk
	jp c,unsup
	ld a,(ix+0)
	cp 1
	jp nz,unsup
	ld a,(ix+1)
	or a
	jp nz,unsup
	ld (ix+1),1
	push ix
	ld hl,sGOTO2
	call puts
	ld a,'F'
	ld e,(ix+2)
	ld d,(ix+3)
	call putlbl
	call nl
	pop ix
	ld a,':'
	call putc
	ld a,'E'
	ld e,(ix+4)
	ld d,(ix+5)
	call putlbl
	call nl
	jp h_rest

h_fi:	call topblk
	jp c,unsup
	ld a,(ix+0)
	cp 1
	jp nz,unsup
	ld a,(ix+1)
	or a
	jr nz,fi1
	ld a,':'
	call putc
	ld a,'E'
	ld e,(ix+4)
	ld d,(ix+5)
	call putlbl
	call nl
fi1:	ld a,':'
	call putc
	ld a,'F'
	ld e,(ix+2)
	ld d,(ix+3)
	call putlbl
	call nl
	jp popblk

h_while:ld hl,(restp)
	call parsecond
	jp c,unsup
	ld a,2
	call pushblk
	jp c,unsup
	call newlbl
	ld (ix+2),e
	ld (ix+3),d
	push ix
	ld a,':'
	call putc
	ld a,'W'
	call putlbl
	call nl
	pop ix
	ld e,(ix+2)
	ld d,(ix+3)
	xor a
	ld c,'X'
	jp emitcond

h_for:	ld hl,(restp)
	call tokenize
	ld a,(ntok)
	cp 3
	jp c,unsup
	ld a,1
	call gettok
	ex de,hl
	ld hl,sIN
	call streq
	jp nz,unsup
; 語を FPOOL へ: VAR 0 語1 0 語2 0 ... 0
	ld de,(fpp)
	ld (poolb),de
	xor a
	push de
	call gettok
	pop de
	call copyz
	ld (itemp),de		; 最初の語の位置
	ld a,2
	ld (tix),a
hf1:	ld a,(tix)
	ld hl,ntok
	cp (hl)
	jr nc,hf2
	push de
	call gettok
	pop de
	call copyz
	ld hl,tix
	inc (hl)
	jr hf1
hf2:	xor a
	ld (de),a
	inc de
	ld (fpp),de
	ld a,3
	call pushblk
	jp c,unsup
	call newlbl
	ld (ix+2),e
	ld (ix+3),d
	ld hl,(srcp)
	ld (ix+6),l
	ld (ix+7),h
	ld hl,(itemp)
	ld (ix+8),l
	ld (ix+9),h
	ld hl,(lineno)
	ld (ix+10),l
	ld (ix+11),h
	ld hl,(poolb)
	ld (ix+12),l
	ld (ix+13),h
	jp for_next

; HL の0終端文字列を DE へコピー (DE は0の次へ進む)
copyz:	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	or a
	jr nz,copyz
	ret

; for の次の語を "set VAR=語" として出す。CF=1:語が無い
for_next:
	ld l,(ix+8)
	ld h,(ix+9)
	ld a,(hl)
	or a
	jr nz,fn1
	scf
	ret
fn1:	push hl
	push ix
	ld hl,sSET
	call puts
	pop ix
	push ix
	ld l,(ix+12)
	ld h,(ix+13)
	call puts
	ld a,'='
	call putc
	pop ix
	pop hl
	push ix
	call puts
	call nl
	pop ix
	inc hl			; 0の次
	ld (ix+8),l
	ld (ix+9),h
	or a
	ret

h_done:	call topblk
	jp c,unsup
	ld a,(ix+0)
	cp 2
	jr z,dn_w
	cp 3
	jp nz,unsup
	call for_next
	jr c,dn_fe
	ld l,(ix+6)
	ld h,(ix+7)
	ld (srcp),hl
	ld l,(ix+10)
	ld h,(ix+11)
	ld (lineno),hl
	ret
dn_fe:	ld l,(ix+12)
	ld h,(ix+13)
	ld (fpp),hl
	jr dn_x
dn_w:	push ix
	ld hl,sGOTO2
	call puts
	ld a,'W'
	ld e,(ix+2)
	ld d,(ix+3)
	call putlbl
	call nl
	pop ix
dn_x:	push ix
	ld a,':'
	call putc
	ld a,'X'
	ld e,(ix+2)
	ld d,(ix+3)
	call putlbl
	call nl
	pop ix
	jp popblk

;---------------------------------------------------------------- && || の連なり / 普通のコマンド
; 戻り A: 0=コマンドを出した 1=条件 2=何も出さない
chain:	ld hl,STMT
	call scanops
	cp 3
	jp z,unsup
	xor a
	ld (gl),a
	ld (gl+1),a
	ld hl,STMT
ch_seg:	ld (segs),hl
	call findop
	ld (opfound),a
	ld (opptr),hl
	or a
	jr z,ch_t
	ld (hl),0
ch_t:	call trimtail
	ld hl,(segs)
	call skipsp
	call segment
	ld b,a
	ld a,(opfound)
	or a
	jr z,ch_last
	ld c,a
	ld a,b
	cp 2
	jr z,ch_adv
	ld hl,(gl)
	ld a,h
	or l
	jr nz,ch_g
	push bc
	call newlbl
	ld (gl),de
	pop bc
ch_g:	ld a,b
	or a
	jr nz,ch_cond
	ld hl,sIF
	call puts
	ld a,c
	cp 1
	jr nz,ch_or
	ld hl,sNOTSP
	call puts
ch_or:	ld hl,sRC0
	call puts
	ld a,'G'
	ld de,(gl)
	call putlbl
	call nl
	jr ch_adv
ch_cond:ld a,c
	cp 1
	ld a,0			; && : 偽のとき飛ぶ
	jr z,ch_c1
	ld a,1			; || : 真のとき飛ぶ
ch_c1:	ld c,'G'
	ld de,(gl)
	call emitcond
ch_adv:	ld hl,(opptr)
	inc hl
	inc hl
	call skipsp
	jp ch_seg
ch_last:ld a,b
	cp 1
	jr nz,ch_end
	ld de,mCONDALONE
	call warnmsg
ch_end:	ld hl,(gl)
	ld a,h
	or l
	ret z
	ld a,':'
	call putc
	ld a,'G'
	ld de,(gl)
	call putlbl
	jp nl

; HL 以降に && || があるか。A bit0=&& bit1=||
scanops:ld b,0		; B=引用符
	ld c,0			; C=結果
so1:	ld a,(hl)
	or a
	jr z,so_e
	ld d,a
	ld a,b
	or a
	jr nz,so_q
	ld a,d
	cp '"'
	jr z,so_oq
	cp 27h
	jr z,so_oq
	cp '&'
	jr nz,so2
	inc hl
	ld a,(hl)
	cp '&'
	jr nz,so1
	ld a,c
	or 1
	ld c,a
	inc hl
	jr so1
so2:	cp '|'
	jr nz,so3
	inc hl
	ld a,(hl)
	cp '|'
	jr nz,so1
	ld a,c
	or 2
	ld c,a
	inc hl
	jr so1
so3:	inc hl
	jr so1
so_oq:	ld b,a
	inc hl
	jr so1
so_q:	ld a,d
	cp b
	jr nz,so3
	ld b,0
	jr so3
so_e:	ld a,c
	ret

; HL から最初の && || を探す。A=0 無し/1 &&/2 ||, HL=その位置(無ければ終端)
findop:	ld b,0
fo1:	ld a,(hl)
	or a
	ret z
	ld d,a
	ld a,b
	or a
	jr nz,fo_q
	ld a,d
	cp '"'
	jr z,fo_oq
	cp 27h
	jr z,fo_oq
	cp '&'
	jr nz,fo2
	inc hl
	ld a,(hl)
	dec hl
	cp '&'
	jr nz,fo3
	ld a,1
	ret
fo2:	cp '|'
	jr nz,fo3
	inc hl
	ld a,(hl)
	dec hl
	cp '|'
	jr nz,fo3
	ld a,2
	ret
fo3:	inc hl
	jr fo1
fo_oq:	ld b,a
	jr fo3
fo_q:	ld a,d
	cp b
	jr nz,fo3
	ld b,0
	jr fo3

; HL=区間の終わり(含まない)。直前の空白を0にする
trimtail:
	ld de,(segs)
tt1:	ld a,h
	cp d
	jr nz,tt2
	ld a,l
	cp e
	ret z
tt2:	dec hl
	ld a,(hl)
	cp ' '
	ret nz
	ld (hl),0
	jr tt1

; HL=コマンド1個のテキスト。A: 0=出力した 1=条件を解析した 2=何も出さない
segment:ld a,(hl)
	or a
	ld a,2
	ret z
	ld (segt),hl
	ld ix,segtab
sg1:	ld l,(ix+0)
	ld h,(ix+1)
	ld a,h
	or l
	jr z,sg_plain
	ld de,(segt)
	call kwmatch
	jr z,sg_f
	inc ix
	inc ix
	inc ix
	inc ix
	jr sg1
sg_f:	ld l,(ix+2)
	ld h,(ix+3)
	jp (hl)
sg_plain:
	ld hl,(segt)
	call isassign
	jr c,sg_cmd
	ld hl,sSET
	call puts
sg_cmd:	ld hl,(segt)
	call puts
	call nl
	xor a
	ret

segtab:	defw sLB,sg_cond
	defw sLBB,sg_cond
	defw sTEST,sg_cond
	defw kEXIT,sg_exit
	defw kBREAK,sg_break
	defw kCONTINUE,sg_cont
	defw kUNSET,sg_unset
	defw kEXPORT,sg_export
	defw 0

sg_cond:ld hl,(segt)
	call parsecond
	jr c,sg_bad
	ld a,1
	ret
sg_bad:	ld de,mUNSUP
	call warnmsg
	ld a,2
	ret

sg_exit:ld hl,sGOTO2
	call puts
	ld a,'Q'
	call putc
	ld hl,sQIT+1
	call puts
	call nl
	xor a
	ret

sg_break:
	call findloop
	jr c,sg_bad
	push ix
	ld hl,sGOTO2
	call puts
	pop ix
	ld a,'X'
	ld e,(ix+2)
	ld d,(ix+3)
	call putlbl
	call nl
	xor a
	ret

sg_cont:call findloop
	jr c,sg_bad
	ld a,(ix+0)
	cp 2
	jr nz,sg_bad
	push ix
	ld hl,sGOTO2
	call puts
	pop ix
	ld a,'W'
	ld e,(ix+2)
	ld d,(ix+3)
	call putlbl
	call nl
	xor a
	ret

sg_unset:
	ld hl,sSET
	call puts
	ld hl,(restp)
	call puts
	ld a,'='
	call putc
	call nl
	xor a
	ret

sg_export:
	ld hl,(restp)
	jp segment

; HL の語が NAME=... なら NC
isassign:
	ld a,(hl)
	cp '_'
	jr z,ia1
	call isalpha
	jr c,ia_no
ia1:	inc hl
	ld a,(hl)
	cp '='
	jr z,ia_yes
	cp '_'
	jr z,ia1
	call isalnum
	jr nc,ia1
ia_no:	scf
	ret
ia_yes:	or a
	ret

isalpha:cp 'A'
	jr c,ial_n
	cp 'Z'+1
	jr c,ial_y
	cp 'a'
	jr c,ial_n
	cp 'z'+1
	jr c,ial_y
ial_n:	scf
	ret
ial_y:	or a
	ret

isalnum:call isalpha
	ret nc
	cp '0'
	jr c,ian_n
	cp '9'+1
	jr nc,ian_n
	or a
	ret
ian_n:	scf
	ret

;---------------------------------------------------------------- データ
inname:	defw 0
dotp:	defw 0
hin:	defb 0
srcp:	defw 0
outp:	defw 0
linep:	defw 0
lineno:	defw 1
blkp:	defw 0
fpp:	defw 0
labn:	defw 0
nwarn:	defb 0
ovf:	defb 0
cdz:	defb 0
restp:	defw 0
ntok:	defb 0
ts:	defb 0
te:	defb 0
ckind:	defb 0
cneg:	defb 0
carg1:	defw 0
carg2:	defw 0
tmpde:	defw 0
gl:	defw 0
segs:	defw 0
segt:	defw 0
opfound:defb 0
opptr:	defw 0
poolb:	defw 0
itemp:	defw 0
tix:	defb 0

sBAT:	defm ".BAT",0,0
sQIT:	defm "QIT",0
sLB:	defm "[",0
sLBB:	defm "[[",0
sRB:	defm "]",0
sRBB:	defm "]]",0
sTEST:	defm "test",0
sNOT:	defm "!",0
sEMPTY:	defb 0
sZ:	defm "-z",0
sN:	defm "-n",0
sEQ:	defm "=",0
sEQ2:	defm "==",0
sNE:	defm "!=",0
sIN:	defm "in",0
sEXOPS:	defm "efdsrwxhL",0
sIF:	defm "if ",0
sNOTSP:	defm "not ",0
sEXIST:	defm "exist ",0
sEQ_:	defm "==_",0
sGOTO:	defm " goto ",0
sGOTO2:	defm "goto ",0
sSET:	defm "set ",0
sREMSH:	defm "rem [sh] ",0
sRC0:	defm "$?==0 goto ",0

kTHEN:	defm "then",0
kDO:	defm "do",0
kEXPORT:defm "export",0
kIF:	defm "if",0
kELIF:	defm "elif",0
kELSE:	defm "else",0
kFI:	defm "fi",0
kWHILE:	defm "while",0
kDONE:	defm "done",0
kFOR:	defm "for",0
kSET:	defm "set",0
kCASE:	defm "case",0
kESAC:	defm "esac",0
kFUNCTION:defm "function",0
kREAD:	defm "read",0
kSHIFT:	defm "shift",0
kLOCAL:	defm "local",0
kRETURN:defm "return",0
kSOURCE:defm "source",0
kDOT:	defm ".",0
kEXIT:	defm "exit",0
kBREAK:	defm "break",0
kCONTINUE:defm "continue",0
kUNSET:	defm "unset",0

mUSAGE:	defm "usage: sh script.sh   (writes script.BAT)",13,10,"$"
mOPEN:	defm "sh: cannot open input file",13,10,"$"
mBIG:	defm "sh: file too big",13,10,"$"
mSAME:	defm "sh: input and output are the same file",13,10,"$"
mCREATE:defm "sh: cannot write output file",13,10,"$"
mWROTE:	defm "sh: wrote $"
mWARN:	defm 13,10,"sh: there were warnings (lines not translated start with 'rem [sh]')",13,10,"$"
mLINE:	defm "sh: line $"
mCOLON:	defm ": $"
mUNSUP:	defm "unsupported",13,10,"$"
mUNTERM:defm "unterminated if/while/for",13,10,"$"
mCONDALONE:defm "condition used alone is ignored",13,10,"$"
