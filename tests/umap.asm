; umap - ゲートが「ユーザマップ表 UMAP(FF17H-FF1DH)」から読んでいるかの確認。
;   バンク6(C000H-)とバンク2(4000H-)を、中身を写した別ページ(07h,08h)に差し替え、UMAP も同じ値に書き換える。
;   BDOS を呼んでも、RST 18H(IOCS)を呼んでも、そのバンクが差し替え後のページのままであること、
;   マーカが差し替え先のページにだけ書かれていて元のページ(05h,02h)には届いていないことを確かめる。
;   コマンド行に n があれば IOCS を呼ばない(IOCS無しのイメージ用)。
	org 0100h
	ld sp,7F00h
	xor a
	ld (noiocs),a
	ld hl,0081h
	ld b,16
scan:	ld a,(hl)
	cp 'n'
	jr z,sn
	cp 'N'
	jr nz,sn2
sn:	ld a,1
	ld (noiocs),a
sn2:	inc hl
	djnz scan

	; 1. UMAP の初期値 = 00 01 02 03 0A 04 05
	ld hl,0FF17h
	ld de,expect
	ld b,7
chk:	ld a,(de)
	cp (hl)
	jp nz,ng1
	inc hl
	inc de
	djnz chk
	ld de,m_init
	call say

	; 2. 差し替え先のページを予約し、中身を写す
	ld e,07h
	ld c,0E2h
	call 5
	or a
	jp nz,ng2
	ld e,08h
	ld c,0E2h
	call 5
	or a
	jp nz,ng2
	ld a,(0C123h)
	ld (v6),a
	ld a,(04123h)
	ld (v2),a
	ld a,07h
	ld hl,0C000h
	call pgput
	ld a,08h
	ld hl,04000h
	call pgput

	; 3. バンク6 -> 07h、バンク2 -> 08h(ハード+UMAP)
	di
	ld a,2
	out (0B4h),a
	ld a,08h
	out (0B5h),a
	ld (0FF19h),a
	ld a,6
	out (0B4h),a
	ld a,07h
	out (0B5h),a
	ld (0FF1Dh),a
	ei
	ld a,0A5h
	ld (0C123h),a
	ld a,05Ah
	ld (04123h),a
	call chkmap
	jp nz,ng3
	ld de,m_sw
	call say

	; 4. BDOS を何度か呼んでも保たれる
	ld de,m_mid
	ld c,9
	call 5
	ld de,05Ch
	ld c,11h
	call 5
	ld c,0Bh
	call 5
	call chkmap
	jp nz,ng4
	ld de,m_bdos
	call say

	; 5. IOCS を呼んでも保たれる
	ld a,(noiocs)
	or a
	jr nz,skipio
	ld a,'Z'
	rst 18h
	db 03h
	call chkmap
	jp nz,ng5
	ld de,m_iocs
	call say
skipio:

	; 6. マーカは差し替え先にだけ届いた(元のページ 05h,02h は元のまま)
	ld a,05h
	ld hl,0123h
	call pgget
	ld b,a
	ld a,(v6)
	cp b
	jp nz,ng6
	ld a,02h
	ld hl,0123h
	call pgget
	ld b,a
	ld a,(v2)
	cp b
	jp nz,ng6
	ld de,m_iso
	call say

	; 7. 元に戻す
	di
	ld a,2
	out (0B4h),a
	ld a,02h
	out (0B5h),a
	ld (0FF19h),a
	ld a,6
	out (0B4h),a
	ld a,05h
	out (0B5h),a
	ld (0FF1Dh),a
	ei
	ld e,07h
	ld c,0E3h
	call 5
	ld e,08h
	ld c,0E3h
	call 5
	ld de,m_done
	call say
	jp 0

; 結果の失敗: 元に戻してから番号を出す
ng1:	ld de,m_ng1
	jr ngend
ng2:	ld de,m_ng2
	jr ngend
ng3:	ld de,m_ng3
	jr ngrest
ng4:	ld de,m_ng4
	jr ngrest
ng5:	ld de,m_ng5
	jr ngrest
ng6:	ld de,m_ng6
ngrest:	push de
	di
	ld a,2
	out (0B4h),a
	ld a,02h
	out (0B5h),a
	ld (0FF19h),a
	ld a,6
	out (0B4h),a
	ld a,05h
	out (0B5h),a
	ld (0FF1Dh),a
	ei
	pop de
ngend:	call say
	jp 0

say:	ld c,9
	call 5
	ret

; バンク6=07h バンク2=08h か、UMAP も同じか、マーカが読めるか。Z で成功
chkmap:	di
	ld a,6
	out (0B4h),a
	in a,(0B5h)
	cp 07h
	jr nz,cm_ng
	ld a,2
	out (0B4h),a
	in a,(0B5h)
	cp 08h
	jr nz,cm_ng
	ld a,(0FF1Dh)
	cp 07h
	jr nz,cm_ng
	ld a,(0FF19h)
	cp 08h
	jr nz,cm_ng
	ld a,(0C123h)
	cp 0A5h
	jr nz,cm_ng
	ld a,(04123h)
	cp 05Ah
	jr nz,cm_ng
	ei
	xor a			; Z=1
	ret
cm_ng:	ei
	or 1			; Z=0
	ret

; A=物理ページ HL=TPA内の元(2000H バイト)を、バンク4の窓でそのページへ書く
pgput:	push af
	di
	ld a,4
	out (0B4h),a
	in a,(0B5h)
	ld (orig4),a
	ld a,4
	out (0B4h),a
	pop af
	out (0B5h),a
	ld de,8000h
	ld bc,2000h
	ldir
	ld a,4
	out (0B4h),a
	ld a,(orig4)
	out (0B5h),a
	ei
	ret

; A=物理ページ HL=ページ内オフセット -> A=その1バイト
pgget:	push af
	di
	ld a,4
	out (0B4h),a
	in a,(0B5h)
	ld (orig4),a
	ld a,4
	out (0B4h),a
	pop af
	out (0B5h),a
	ld de,8000h
	add hl,de
	ld b,(hl)
	ld a,4
	out (0B4h),a
	ld a,(orig4)
	out (0B5h),a
	ei
	ld a,b
	ret

expect:	defb 00h,01h,02h,03h,0Ah,04h,05h
noiocs:	defb 0
orig4:	defb 0
v6:	defb 0
v2:	defb 0
m_init:	defm "UMAP-INIT-OK",13,10,"$"
m_sw:	defm "UMAP-SWITCH-OK",13,10,"$"
m_mid:	defm "UMAP-MID",13,10,"$"
m_bdos:	defm "UMAP-BDOS-OK",13,10,"$"
m_iocs:	defm "UMAP-IOCS-OK",13,10,"$"
m_iso:	defm "UMAP-ISOLATED-OK",13,10,"$"
m_done:	defm "UMAP-DONE",13,10,"$"
m_ng1:	defm "UMAP-NG1 init",13,10,"$"
m_ng2:	defm "UMAP-NG2 alloc",13,10,"$"
m_ng3:	defm "UMAP-NG3 switch",13,10,"$"
m_ng4:	defm "UMAP-NG4 bdos",13,10,"$"
m_ng5:	defm "UMAP-NG5 iocs",13,10,"$"
m_ng6:	defm "UMAP-NG6 isolate",13,10,"$"
