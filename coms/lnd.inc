; 長いファイル名(docs/longname.md): 検索結果(dtabuf)の name2 を扱う共通部品。
; 使う側で dtabuf を定義しておくこと。
; ln_ok : 検索結果に有効な name2 があるか。Z=なし NZ=あり。HL,DE,BC を保つ(ls.asm の n2ok と同じ規則)
ln_ok:	push hl
	push bc
	ld a,(dtabuf+8)
	cp ' '
	jr z,ln_no
	ld a,(dtabuf+17)
	cp 0A0h
	jr z,ln_no
	ld hl,dtabuf+13
	ld b,10
	ld a,(hl)
	or a
	jr z,ln_no
ln_l:	ld a,(hl)
	or a
	jr z,ln_z
	cp 20h
	jr c,ln_no
	cp 7Fh
	jr z,ln_no
	cp 0FFh
	jr z,ln_no
	inc hl
	djnz ln_l
	jr ln_yes
ln_z:	dec b
	jr z,ln_yes
	inc hl
	ld a,(hl)
	or a
	jr nz,ln_no
	jr ln_z
ln_yes:	ld a,1
	or a
	jr ln_x
ln_no:	xor a
ln_x:	pop bc
	pop hl
	ret
; ln_app: name1 の8文字を書いたあと(DE=出力位置)に name2 を足す。有効でなければ何もしない。HL,BC を保つ
ln_app:	call ln_ok
	ret z
	push hl
	push bc
	ld hl,dtabuf+13
	ld b,10
ln_a1:	ld a,(hl)
	or a
	jr z,ln_a2
	ld (de),a
	inc de
	inc hl
	djnz ln_a1
ln_a2:	pop bc
	pop hl
	ret
