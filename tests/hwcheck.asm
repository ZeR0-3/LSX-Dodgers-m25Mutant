; HWCHECK.COM - LSX-Dodgers MZ-2500 版で「エミュレータでしか確認していない前提」を実機で確かめる診断。
;   画面に出る "HW:" の行を、そのまま(写真かコピーで)報告に使えるようにしてある。何も書き換えない
;   (ページの中身は「E1h で空きのページ」にだけ書く。F: や他のプログラムのページには触らない)。
;   使い方: A> hwcheck     (E5h の項目を見るには先に ramdisk 64 で F: を縮めておく。縮めなくても他の項目は動く)
	org 0100h
	ld sp,3F00h
	ld de,s_title
	call ps
	; ---- LSX か ----
	ld c,6Fh
	call 5
	ld a,l
	ld (v_l),a
	cp 4
	jr z,is_lsx
	ld de,s_nolsx
	call ps
	jp 0
is_lsx:
	ld c,0E0h
	call 5
	ld (si_a),a
	ld a,b
	ld (si_b),a
	ld a,c
	ld (si_c),a
	ld a,d
	ld (si_d),a
	ld a,e
	ld (si_e),a
	ld (si_hl),hl
	ld de,s_si
	call ps
	ld a,(si_a)
	call pb
	ld de,s_feat
	call ps
	ld a,(si_b)
	call pb
	ld de,s_emm
	call ps
	ld a,(si_c)
	call pb
	ld de,s_rdp
	call ps
	ld a,(si_d)
	call pb
	ld de,s_ver
	call ps
	ld a,(si_e)
	call pb
	ld de,s_tpa
	call ps
	ld a,(si_hl+1)
	call pb
	ld a,(si_hl)
	call pb
	call crlf

	; ---- 1. B5h の読み書きで B4h が進むか(進まない機種ならバンク4の値のまま) ----
	di
	ld a,4
	out (0B4h),a
	in a,(0B5h)
	ld (v4),a		; バンク4のページ
	ld a,4
	out (0B4h),a
	in a,(0B5h)		; 読みの1回目
	in a,(0B5h)		; 2回目: 読みで B4 が進むなら バンク5 の値になる
	ld (r2),a
	ld a,4
	out (0B4h),a
	ld a,(v4)
	out (0B5h),a		; 同じ値を書く(無害)
	in a,(0B5h)		; 書きで B4 が進むなら バンク5 の値
	ld (w2),a
	ld a,4
	out (0B4h),a
	ld a,(v4)
	out (0B5h),a
	ei
	ld de,s_b5
	call ps
	ld a,(v4)
	call pb
	ld de,s_r2
	call ps
	ld a,(r2)
	call pb
	ld de,s_w2
	call ps
	ld a,(w2)
	call pb
	ld de,s_readinc
	call ps
	ld a,(r2)
	ld hl,v4
	cp (hl)
	ld de,s_yes
	jr nz,ri1
	ld de,s_no
ri1:	call ps
	ld de,s_writeinc
	call ps
	ld a,(w2)
	ld hl,v4
	cp (hl)
	ld de,s_yes
	jr nz,wi1
	ld de,s_no
wi1:	call ps
	call crlf

	; ---- 2. 空きページ(E1h が 0)を集める ----
	xor a
	ld (pn),a
	ld a,7
	ld (pg),a
col1:	ld a,(pg)
	ld e,a
	ld c,0E1h
	call 5
	ld a,b
	or a
	jr nz,col2
	ld a,(pn)
	ld e,a
	ld d,0
	ld hl,plist
	add hl,de
	ld a,(pg)
	ld (hl),a
	ld a,e
	inc a
	ld (pn),a
col2:	ld a,(pg)
	inc a
	ld (pg),a
	cp 20h
	jr c,col1
	ld de,s_free
	call ps
	ld a,(pn)
	call pb
	call crlf

	; ---- 3. 空きページに固有の値を書いて、まとめて読み戻す(別名・欠けの検出) ----
	call wall
	call vall
	ld de,s_pat
	call ps
	ld a,(nok)
	call pb
	ld de,s_of
	call ps
	ld a,(pn)
	call pb
	ld de,s_bad
	call ps
	call pbad
	call crlf

	; ---- 4. 空きページから実行できるか(最初の 10h 以上の空きと、07h/08h) ----
	call exec_test
	; ---- 5. 時計(BDOS 2Ch / 2Ah。実際の時刻と見比べる) ----
	ld c,2Ch
	call 5
	ld (t_h),hl
	ld a,d
	ld (t_s),a
	ld c,2Ah
	call 5
	ld (d_y),hl
	ld a,d
	ld (d_m),a
	ld a,e
	ld (d_d),a
	ld de,s_clk
	call ps
	ld a,(d_y+1)
	call pb
	ld a,(d_y)
	call pb
	ld a,'-'
	call pc
	ld a,(d_m)
	call pb
	ld a,'-'
	call pc
	ld a,(d_d)
	call pb
	ld a,' '
	call pc
	ld a,(t_h+1)
	call pb
	ld a,':'
	call pc
	ld a,(t_h)
	call pb
	ld a,':'
	call pc
	ld a,(t_s)
	call pb
	ld de,s_cmp
	call ps
	; ---- 6. BDOS を何度か通したあとも、空きページの値が残っているか ----
	call vall
	ld de,s_ret
	call ps
	ld a,(nok)
	call pb
	ld de,s_of
	call ps
	ld a,(pn)
	call pb
	call crlf
	; ---- 7. E5h(外部コマンドの起動)。版3以上で空きが7枚以上のときだけ ----
	ld a,(si_e)
	cp 3
	jr c,e5skip
	ld a,(pn)
	cp 7
	jr c,e5skip
	ld hl,8000h		; 親の 8000H-9FFFH に印を書いて、子が動いたあとも残るか
	ld a,0
e5f:	ld (hl),a
	inc a
	inc l
	jr nz,e5f
	inc h
	ld a,h
	cp 0A0h
	jr c,e5f0
	jr e5go
e5f0:	xor a
	jr e5f
e5go:	ld de,s_e5
	call ps
	ld de,c_dir
	ld c,0E5h
	call 5
	ld (e5a),a
	ld de,s_e5r
	call ps
	ld a,(e5a)
	call pb
	ld hl,8000h
	ld de,0
	ld b,0
e5v:	ld a,e
	cp (hl)
	jr z,e5ok
	ld b,1
e5ok:	inc hl
	inc e
	ld a,h
	cp 0A0h
	jr c,e5v
	ld de,s_e5p
	call ps
	ld de,s_e5good
	ld a,b
	or a
	jr z,e5p1
	ld de,s_e5bad
e5p1:	call ps
	jr fin
e5skip:	ld de,s_e5skip
	call ps
fin:	ld de,s_done
	call ps
	jp 0

; ---------------- 部品 ----------------
crlf:	ld de,s_crlf
ps:	ld c,9
	call 5
	ret
pc:	push bc
	push de
	push hl
	ld e,a
	ld c,2
	call 5
	pop hl
	pop de
	pop bc
	ret
pb:	push af
	rrca
	rrca
	rrca
	rrca
	call nib
	pop af
nib:	and 0Fh
	add a,'0'
	cp '9'+1
	jr c,nb1
	add a,7
nb1:	jp pc

; 窓: バンク3(6000H-7FFFH)に (parg) のページを出す。閉じるまで DI
win_open:
	di
	ld a,3
	out (0B4h),a
	in a,(0B5h)
	ld (orig3),a
	ld a,3
	out (0B4h),a
	ld a,(parg)
	out (0B5h),a
	ret
win_close:
	ld a,3
	out (0B4h),a
	ld a,(orig3)
	out (0B5h),a
	ei
	ret

; 固有の値: ページ xor A5h
wall:	xor a
	ld (idx),a
wa1:	ld a,(idx)
	ld hl,plist
	ld e,a
	ld d,0
	add hl,de
	ld a,(hl)
	ld (parg),a
	xor 0A5h
	ld (pval),a
	call win_open
	ld a,(pval)
	ld (6000h),a
	cpl
	ld (7FFFh),a
	call win_close
	ld a,(idx)
	inc a
	ld (idx),a
	ld hl,pn
	cp (hl)
	jr c,wa1
	ret
; 読み戻して一致数を (nok)、外れたページを pbadl へ
vall:	xor a
	ld (idx),a
	ld (nok),a
	ld (nbad),a
va1:	ld a,(idx)
	ld hl,plist
	ld e,a
	ld d,0
	add hl,de
	ld a,(hl)
	ld (parg),a
	xor 0A5h
	ld (pval),a
	call win_open
	ld a,(6000h)
	ld b,a
	ld a,(7FFFh)
	ld c,a
	call win_close
	ld a,(pval)
	cp b
	jr nz,va_ng
	cpl
	cp c
	jr nz,va_ng
	ld a,(nok)
	inc a
	ld (nok),a
	jr va2
va_ng:	ld a,(nbad)
	ld e,a
	ld d,0
	ld hl,pbadl
	add hl,de
	ld a,(parg)
	ld (hl),a
	ld a,e
	inc a
	ld (nbad),a
va2:	ld a,(idx)
	inc a
	ld (idx),a
	ld hl,pn
	cp (hl)
	jr c,va1
	ret
pbad:	ld a,(nbad)
	or a
	jr nz,pb1
	ld de,s_none
	jp ps
pb1:	ld b,a
	ld hl,pbadl
pb2:	ld a,(hl)
	inc hl
	push bc
	push hl
	call pb
	ld a,' '
	call pc
	pop hl
	pop bc
	djnz pb2
	ret

; 空きページで 3E 5A C9 (ld a,5Ah / ret) を実行: 07h と、10h 以上で最初の空き。バンク2(4000H)に出して call
exec_test:
	ld de,s_ex
	call ps
	xor a
	ld (idx),a
et1:	ld a,(idx)
	ld hl,plist
	ld e,a
	ld d,0
	add hl,de
	ld a,(hl)
	ld (xpg),a
	cp 8+1
	jr c,et_do
	cp 10h
	jr c,et_next		; 09h-0Fh は空きにならないはず
	ld a,(xdone)
	or a
	jr nz,et_next
	ld a,1
	ld (xdone),a
et_do:	ld a,(xpg)
	ld (parg),a
	call win_open		; 3E 5A C9 を書く
	ld hl,6010h		; 先頭(パターンの印)を壊さない位置
	ld (hl),3Eh
	inc hl
	ld (hl),5Ah
	inc hl
	ld (hl),0C9h
	call win_close
	ld a,(xpg)
	call pb
	ld a,'='
	call pc
	di
	ld a,2
	out (0B4h),a
	in a,(0B5h)
	ld (orig2),a
	ld a,2
	out (0B4h),a
	ld a,(xpg)
	out (0B5h),a
	call 4010h
	ld (xres),a
	ld a,2
	out (0B4h),a
	ld a,(orig2)
	out (0B5h),a
	ei
	ld a,(xres)
	call pb
	ld a,' '
	call pc
et_next:
	ld a,(idx)
	inc a
	ld (idx),a
	ld hl,pn
	cp (hl)
	jr c,et1
	ld de,s_ex2
	call ps
	ret

; ---------------- データ ----------------
v_l:	defb 0
si_a:	defb 0
si_b:	defb 0
si_c:	defb 0
si_d:	defb 0
si_e:	defb 0
si_hl:	defw 0
v4:	defb 0
r2:	defb 0
w2:	defb 0
pn:	defb 0
pg:	defb 0
idx:	defb 0
nok:	defb 0
nbad:	defb 0
parg:	defb 0
pval:	defb 0
orig3:	defb 0
orig2:	defb 0
xpg:	defb 0
xres:	defb 0
xdone:	defb 0
e5a:	defb 0
t_h:	defw 0
t_s:	defb 0
d_y:	defw 0
d_m:	defb 0
d_d:	defb 0
plist:	defs 32,0
pbadl:	defs 32,0
c_dir:	defm "DIR HWCHECK.COM",0
s_title: defm "HWCHECK (LSX-Dodgers MZ-2500): please report all HW: lines",13,10,"$"
s_nolsx: defm "HW:NG not LSX (6Fh L<>4)",13,10,"$"
s_si:	defm "HW:SYSINFO a=$"
s_feat:	defm " feat=$"
s_emm:	defm " emm64k=$"
s_rdp:	defm " f_pages=$"
s_ver:	defm " ver=$"
s_tpa:	defm " tpa=$"
s_b5:	defm "HW:B5 bank4=$"
s_r2:	defm " read2=$"
s_w2:	defm " write2=$"
s_readinc:	defm " read-inc=$"
s_writeinc:	defm " write-inc=$"
s_yes:	defm "yes $"
s_no:	defm "no $"
s_free:	defm "HW:free pages(07h-1Fh)=$"
s_pat:	defm "HW:pattern ok=$"
s_of:	defm "/$"
s_bad:	defm " bad:$"
s_none:	defm "none$"
s_ex:	defm "HW:exec from page (page=result 5A is OK): $"
s_ex2:	defm 13,10,"$"
s_clk:	defm "HW:clock $"
s_cmp:	defm "  <- compare with the real time",13,10,"$"
s_ret:	defm "HW:pattern after BDOS calls ok=$"
s_e5:	defm "HW:E5h run DIR...",13,10,"$"
s_e5r:	defm "HW:E5h result A=$"
s_e5p:	defm " parent 8000H-9FFFH $"
s_e5good: defm "intact",13,10,"$"
s_e5bad: defm "BROKEN",13,10,"$"
s_e5skip: defm "HW:E5h skipped (needs ver>=3 and 7 free pages: run ramdisk 64)",13,10,"$"
s_done:	defm "HW:DONE",13,10,"$"
s_crlf:	defm 13,10,"$"
