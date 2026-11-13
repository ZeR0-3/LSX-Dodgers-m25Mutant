; ハンドル層のエラー系・境界のテスト
	org 0100h
	ld sp,0A000h
	ld de,mhead
	ld c,9
	call 5
; 1 存在しないファイルを開く -> D7
	call step
	defb 1
	ld de,fnx
	ld a,0
	ld c,43h
	call 5
	cp 0D7h
	call chkz
; 2 不正ハンドル(200) read -> C3
	call step
	defb 2
	ld b,200
	ld de,buf
	ld hl,1
	ld c,48h
	call 5
	cp 0C3h
	call chkz
; 3 未使用ハンドル7 close -> C2
	call step
	defb 3
	ld b,7
	ld c,45h
	call 5
	cp 0C2h
	call chkz
; 4 ファイル準備 T2.TXT = 0123456789
	call step
	defb 4
	ld de,fn2
	ld a,0
	ld b,0
	ld c,44h
	call 5
	call chk0
	ld a,b
	ld (h1),a
	ld de,dig
	ld hl,10
	ld c,49h
	call 5
	call chk0
	ld a,(h1)
	ld b,a
	ld c,45h
	call 5
	call chk0
; 5 create-new(b7) で既存 -> CB
	call step
	defb 5
	ld de,fn2
	ld a,0
	ld b,80h
	ld c,44h
	call 5
	cp 0CBh
	call chkz
; 6 書き込み禁止で開いて write -> C6, 読みは可
	call step
	defb 6
	ld de,fn2
	ld a,1
	ld c,43h
	call 5
	call chk0
	ld a,b
	ld (h1),a
	ld de,dig
	ld hl,1
	ld c,49h
	call 5
	cp 0C6h
	call chkz
	ld a,(h1)
	ld b,a
	ld de,buf
	ld hl,3
	ld c,48h
	call 5
	call chk0
	ld hl,buf
	ld de,dig
	ld b,3
	call cmpn
; 7 SEEK 末尾-4 (オフセット 0FFFF:FFFC) -> 6 ; read 4 -> 6789 ; ioctl EOF bit6
	call step
	defb 7
	ld a,(h1)
	ld b,a
	ld a,2
	ld de,0FFFFh
	ld hl,0FFFCh
	ld c,4Ah
	call 5
	call chk0
	ld a,l
	cp 6
	call chkz
	ld a,(h1)
	ld b,a
	ld de,buf
	ld hl,4
	ld c,48h
	call 5
	call chk0
	ld hl,buf
	ld de,dig+6
	ld b,4
	call cmpn
	ld a,(h1)
	ld b,a
	ld a,0
	ld c,4Bh
	call 5
	ld a,e
	and 40h
	cp 40h
	call chkz
; 8 末尾を越えてSEEK(100) -> read は EOF
	call step
	defb 8
	ld a,(h1)
	ld b,a
	ld a,0
	ld de,0
	ld hl,100
	ld c,4Ah
	call 5
	call chk0
	ld a,(h1)
	ld b,a
	ld de,buf
	ld hl,1
	ld c,48h
	call 5
	cp 0C7h
	call chkz
; 9 close ; 7個オープンで NHAND (6個目まで可)
	call step
	defb 9
	ld a,(h1)
	ld b,a
	ld c,45h
	call 5
	call chk0
	ld b,6
op6:	push bc
	ld de,fn2
	ld a,0
	ld c,43h
	call 5
	call chk0
	pop bc
	djnz op6
	ld de,fn2
	ld a,0
	ld c,43h
	call 5
	cp 0C4h
	call chkz
; 10 stderr(2) へ書く
	call step
	defb 10
	ld b,2
	ld de,msg2
	ld hl,7
	ld c,49h
	call 5
	call chk0
	ld a,l
	cp 7
	call chkz
; 11 開きっぱなしで終了(コマンド行に戻ったら閉じられること)
	ld de,mdone
	ld c,9
	call 5
	jp 0
	include "hndlib.inc"
mhead:	defm "HT2:",13,10,"$"
mdone:	defm "HT2 DONE",13,10,"$"
fnx:	defm "NOSUCH.XYZ",0
fn2:	defm "T2.TXT",0
dig:	defm "0123456789"
msg2:	defm "stderr",10
h1:	defb 0
buf:	defs 64
