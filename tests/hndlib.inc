step:	pop hl
	ld a,(hl)
	inc hl
	push hl
	ld (curn),a
	ret
; A==0 なら OK、そうでなければ NG 表示(Z フラグ判定ではなく A の値を見る)
chk0:	push af
	or a
	jr z,c0ok
	call ng
c0ok:	pop af
	ret
; Z フラグが立っていれば OK
chkz:	ret z
ng:	push af
	push bc
	push de
	push hl
	ld de,mng
	ld c,9
	call 5
	ld a,(curn)
	call phex
	ld e,' '
	ld c,2
	call 5
	pop hl
	pop de
	pop bc
	pop af
	push af
	call phex
	call crlf
	pop af
	ret
; cmpn: HL と DE を B バイト比較 (一致で OK)
cmpn:	ld a,(de)
	cp (hl)
	jr nz,cmpng
	inc hl
	inc de
	djnz cmpn
	ret
cmpng:	ld a,0EEh
	jr ng
phex:	push af
	rrca
	rrca
	rrca
	rrca
	call phn
	pop af
phn:	and 0Fh
	add a,'0'
	cp '9'+1
	jr c,phn2
	add a,7
phn2:	ld e,a
	ld c,2
	push bc
	push de
	push hl
	call 5
	pop hl
	pop de
	pop bc
	ret
crlf:	push bc
	push de
	push hl
	ld de,mcrlf
	ld c,9
	call 5
	pop hl
	pop de
	pop bc
	ret
mng:	defm "NG $"
mcrlf:	defm 13,10,"$"
curn:	defb 0
