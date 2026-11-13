; RAMDISK.COM - RAMディスク(F:)の大きさを見る/変える(F: のDPBを直接書き換える)。  ramdisk [KB]     MIT License
;   ramdisk      現在の大きさを表示
;   ramdisk 64   64KB にする(8の倍数、0-128。0 で F: を使わない)。 F: はフォーマットされ、中身は消える。
;                使わなくなったページは空きになり、sysinfo / BDOS E1h-E2h で見える・予約できる。
; F: の状態は共通領域(E000H以降)にある DPB(F:) の中にある。 本体は(dn)を所有者表(E1h)に使う。
dfatln	equ 0F2A0h		; DPB_FATLN (0=F:を使わない)
dmaxcl	equ 0F2A8h		; DPB_MAXCL (=16N-8)
dn	equ 0F2B6h		; F:のページ数(未使用領域を使用。0-16)
dext	equ 0F2B8h		; 1:拡張RAMがある(未使用領域)
dsdir	equ 0F2BAh		; DPB_SDIR
	org 0100h
	ld sp,0A000h
	ld a,(0080h)
	ld hl,0081h
	ld b,a
	inc b
rd_sk:	dec b
	jr z,rd_show		; 引数なし
	ld a,(hl)
	cp ' '
	jr nz,rd_num
	inc hl
	jr rd_sk
rd_num:	ld de,0
rd_dg:	ld a,(hl)
	sub '0'
	jr c,rd_dn
	cp 10
	jr nc,rd_dn
	push hl
	ld h,d
	ld l,e
	add hl,hl
	add hl,hl
	add hl,de
	add hl,hl		; x10
	ld e,a
	ld d,0
	add hl,de
	ex de,hl
	pop hl
	ld a,d
	or a
	jp nz,rd_usage
	inc hl
	djnz rd_dg
rd_dn:	ld a,e
	and 7
	jp nz,rd_usage
	ld a,e
	cp 129
	jp nc,rd_usage
	rrca
	rrca
	rrca
	and 1Fh
	ld (newn),a		; ページ数 = KB/8
	ld a,(dext)
	or a
	jp z,rd_none		; 拡張RAMがない
	ld e,10h		; 拡張RAMのページをプログラムが予約中なら変えない
rd_pl:	push de
	ld c,0E1h
	call 5
	pop de
	ld a,b
	cp 4
	jp z,rd_busy
	inc e
	ld a,e
	cp 20h
	jr nz,rd_pl
	ld a,(dn)
	ld (oldn),a
	call fmt		; F: をフォーマットし、DPB(F:)を替える
	ld a,(oldn)
	call kb
	ld de,m_arrow
	call puts
	ld a,(dn)
	call kb
	ld de,m_fmt
	call puts
	jp 0
rd_show:
	ld a,(dext)
	or a
	jr z,rd_none
	ld a,(dn)
	ld de,m_head
	push af
	call puts
	pop af
	call kb
	call crlf
	jp 0
rd_none: ld de,m_none
	call puts
	jp 0
rd_busy: ld de,m_busy
	call puts
	jp 0
rd_usage: ld de,m_usage
	call puts
	jp 0
;F: をフォーマット: ページ10hをバンク3(6000H)へ割り当て、セクタ0-9を0にしてタグ(8B)+ページ数+FAT先頭を書く。 newn=0 ならタグだけ消す。
;窓を開けている間は DI でスタックを使わない(プログラムは 0100H-1FFFH とスタック 9FFFH 以下)。
fmt:	di
	ld a,3
	out (0B4h),a
	in a,(0B5h)
	ld (wp),a
	ld a,3
	out (0B4h),a
	ld a,10h
	out (0B5h),a
	ld a,(newn)
	or a
	jr z,fm_off
	ld hl,6000h
	ld de,6001h
	ld bc,1400h-1
	ld (hl),0
	ldir
	ld hl,tag
	ld de,6000h
	ld bc,8
	ldir
	ld a,(newn)
	ld (6008h),a
	ld hl,6200h
	ld (hl),0FAh
	inc hl
	ld (hl),0FFh
	inc hl
	ld (hl),0FFh
	jr fm_end
fm_off:	ld (6000h),a		; A=0: タグを消す(次の電源投入で 128KB で作り直される)
fm_end:	ld a,3
	out (0B4h),a
	ld a,(wp)
	out (0B5h),a
	ei
	ld hl,0
	ld (dsdir),hl		; F: のカレントディレクトリをルートへ
	ld a,(newn)
	ld (dn),a
	ld l,a
	or a
	jr z,fm_dpb
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl		; 16N セクタ
	ld de,0FFF8h
	add hl,de		; MAXCL = 16N-8
	ld (dmaxcl),hl
	ld hl,1
fm_dpb:	ld (dfatln),hl		; N=0 なら F: を使わない
	ret
; A=ページ数 -> "NNNKB" を表示
kb:	ld l,a
	xor a
	ld (lead),a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl		; x8
	ld bc,-100
	call dg
	ld bc,-10
	call dg
	ld a,l
	add a,'0'
	call putc
	ld de,m_kb
	jp puts
dg:	ld a,'0'-1
dg1:	inc a
	add hl,bc
	jr c,dg1
	sbc hl,bc
	cp '0'
	jr nz,dg2
	ld a,(lead)
	or a
	ld a,'0'
	jr nz,dg2
	ld a,' '
	jr dg3
dg2:	ld (lead),a
dg3:	jp putc
puts:	ld c,9
	jp 5
putc:	ld e,a
	ld c,2
	jp 5
crlf:	ld de,m_crlf
	jp puts
lead:	defb 0
newn:	defb 0
oldn:	defb 0
wp:	defb 0
tag:	defm "LSX25RD",0
m_head:	defm "RAMDISK F: $"
m_none:	defm "no extended RAM (no RAM disk)",13,10,"$"
m_busy:	defm "cannot: size out of range, or extended RAM pages are reserved",13,10,"$"
m_usage: defm "usage: ramdisk [KB]   KB = 0..128, multiple of 8 (0 = no F:). F: is formatted",13,10,"$"
m_arrow: defm " -> $"
m_fmt:	defm " (F: formatted)",13,10,"$"
m_kb:	defm "KB$"
m_crlf:	defm 13,10,"$"
