; SYSINFO.COM - システム情報(BDOS E0h)と物理ページの所有者表(E1h)。  sysinfo [t|c]     MIT License
;   c = 空きを1つ予約したまま終わる(次のプログラム起動で解放される)
;   t = ページ予約の試験(E2h/E3h): 空きを1つ取る -> 同じページをもう一度 -> 解放。 結果を表示する。
	org 0100h
	ld sp,0A000h
	ld a,(0080h)
	or a
	jr z,si_info
	ld hl,0081h
	ld a,(hl)
	cp ' '
	jr nz,si_chk
	inc hl
si_chk:	ld a,(hl)
	or 20h
	cp 't'
	jp z,si_test
	cp 'c'
	jp z,si_claim
si_info:
	ld de,m_title
	call puts
	ld e,0
	ld c,0E0h
	call 5
	push hl
	push bc
	ld a,d
	ld (rdn),a
	ld a,b
	ld (fl),a
	ld de,m_iocs
	ld b,0
	call flag
	ld de,m_emm
	ld b,1
	call flag
	ld de,m_rd
	ld b,2
	call flag
	ld de,m_sasi
	ld b,3
	call flag
	ld de,m_kj
	ld b,4
	call flag
	ld de,m_pg
	ld b,6
	call flag
	ld de,m_emmn
	call puts
	pop bc
	ld a,c
	call hexb
	ld de,m_tpa
	call puts
	pop hl
	ld a,h
	call hexb
	ld a,l
	call hexb
	call crlf
	ld de,m_rdp
	call puts
	ld a,(rdn)
	call hexb
	call crlf
	ld de,m_pages
	call puts
	ld e,0
si_lp:	push de
	ld c,0E1h
	call 5
	ld a,b
	ld hl,owner
	add a,l
	ld l,a
	ld a,(hl)
	ld e,a
	ld c,2
	call 5
	pop de
	inc e
	ld a,e
	cp 10h
	jr nz,si_s1
	ld e,e
	push de
	ld e,' '
	ld c,2
	call 5
	pop de
si_s1:	ld a,e
	cp 20h
	jr nz,si_lp
	call crlf
	ld de,m_leg
	call puts
	jp 0
; c = 空きを1つ予約して、解放せずに終わる(次のプログラムの起動で解放されることの確認用)
si_claim:
	ld de,m_t1
	call puts
	ld e,0FFh
	ld c,0E2h
	call 5
	ld a,b
	call hexb
	call crlf
	jp 0
; 試験
si_test:
	ld de,m_t1
	call puts
	ld e,0FFh
	ld c,0E2h
	call 5
	ld (res),a
	ld a,b
	ld (pgn),a
	ld a,(res)
	call hexb
	ld a,' '
	call putc
	ld a,(pgn)
	call hexb
	call crlf
	ld de,m_t2
	call puts
	ld a,(pgn)
	ld e,a
	ld c,0E1h
	call 5
	ld a,b
	call hexb
	call crlf
	ld de,m_t3
	call puts
	ld a,(pgn)
	ld e,a
	ld c,0E2h
	call 5
	call hexb
	call crlf
	ld de,m_t4
	call puts
	ld a,(pgn)
	ld e,a
	ld c,0E3h
	call 5
	call hexb
	call crlf
	ld de,m_t5
	call puts
	ld a,(pgn)
	ld e,a
	ld c,0E1h
	call 5
	ld a,b
	call hexb
	call crlf
	ld de,m_t6
	call puts
	ld a,(pgn)
	ld e,a
	ld c,0E3h
	call 5
	call hexb
	call crlf
	ld de,m_t7
	call puts
	ld e,3
	ld c,0E2h
	call 5
	call hexb
	call crlf
	jp 0
flag:	push de
	call puts
	pop de
	ld a,(fl)
	ld c,b
	inc c
fg1:	rrca
	dec c
	jr nz,fg1
	jr c,fg_y
	ld de,m_n
	jp puts
fg_y:	ld de,m_y
	jp puts
puts:	ld c,9
	jp 5
putc:	ld e,a
	ld c,2
	jp 5
crlf:	ld de,m_crlf
	jp puts
hexb:	push af
	rrca
	rrca
	rrca
	rrca
	call hexn
	pop af
hexn:	and 0Fh
	add a,'0'
	cp '9'+1
	jr c,hx1
	add a,7
hx1:	jp putc
owner:	defm ".OTRU-"
fl:	defb 0
rdn:	defb 0
res:	defb 0
pgn:	defb 0
m_title: defm "LSX2500 system info (ext v2)",13,10,"$"
m_iocs:	defm "IOCS:$"
m_emm:	defm " EMM(E:):$"
m_rd:	defm " RAMDISK(F:):$"
m_sasi:	defm " SASI(H:):$"
m_kj:	defm " KANJI:$"
m_pg:	defm " PAGEMGR:$"
m_emmn:	defm 13,10,"EMM 64KB blocks: $"
m_tpa:	defm "  TPA top+1: $"
m_rdp:	defm "RAMDISK 8KB pages: $"
m_pages: defm "pages 00-0F / 10-1F: $"
m_leg:	defm ". free  O OS  T TPA  R ramdisk  U reserved  - none",13,10,"$"
m_y:	defm "Y$"
m_n:	defm "N$"
m_crlf:	defm 13,10,"$"
m_t1:	defm "alloc any: $"
m_t2:	defm "owner now: $"
m_t3:	defm "alloc same: $"
m_t4:	defm "free: $"
m_t5:	defm "owner after: $"
m_t6:	defm "free again: $"
m_t7:	defm "alloc TPA page 3: $"
