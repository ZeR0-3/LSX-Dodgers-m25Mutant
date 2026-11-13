; CAT.COM  - ファイルを連結して標準出力(ハンドル1)へ出す。引数なしなら標準入力(ハンドル0)から EOF まで。
; 使い方: cat [file ...]      例) cat a.txt b.txt > c.txt     type x | cat (パイプ実装後)
; MSX-DOS2 風ハンドル呼び出し(BDOS 43h-4Ah)を使う。MIT License
	org 0100h
	ld sp,0A000h
	ld hl,0080h
	ld a,(hl)
	inc hl
	ld e,a
	ld d,0
	add hl,de
	ld (hl),0		; 引数文字列を 0 で終端
	ld hl,0081h
	call skip
	or a
	jr nz,files
	ld b,0			; 引数なし: 標準入力
	call copy
	jp 0
files:	call skip
	or a
	jp z,0
	push hl
fe:	ld a,(hl)		; 次の空白/終端まで進めて 0 を置く
	or a
	jr z,fend
	cp ' '
	jr z,fend
	inc hl
	jr fe
fend:	ld c,a
	ld (hl),0
	ld a,c
	ld (more),a
	pop de			; DE=ファイル名
	push hl
	call iscon		; "con" は標準入力(Ctrl-Z で終わる)
	jr nz,opn
	ld b,0
	call copy
	jr cdone
opn:	ld a,1			; 読み込み専用
	ld c,43h
	call 5
	or a
	jr nz,operr
	push bc
	call copy		; B=ハンドル
	pop bc
	ld c,45h		; close
	call 5
cdone:	pop hl
	ld a,(more)
	or a
	jp z,0
	inc hl
	jr files
operr:	pop hl
	ld de,mopen
	ld c,9
	call 5
	jp 0
; DE が "con"(大文字小文字不問、拡張子なし)なら Z
iscon:	push de
	ld b,3
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
skip:	ld a,(hl)
	cp ' '
	ret nz
	inc hl
	jr skip
; B=入力ハンドル。EOF/エラーまで読んで標準出力へ
copy:	push bc
	ld de,buf
	ld hl,1024
	ld c,48h
	call 5
	pop bc
	or a
	ret nz
	ld a,h
	or l
	ret z
	push bc
	ld b,1
	ld de,buf
	ld c,49h
	call 5
	pop bc
	or a
	ret nz
	jr copy
more:	defb 0
mopen:	defm "cat: cannot open file",13,10,"$"
buf:	defs 1024
