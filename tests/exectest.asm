; exectest - E5h EXEC(子を新しいページで起動して、終了したら戻る)。親は 8000H-DEFFH にパターンを書き、ページ07h を予約して印を書く。
;   子(CHILD.COM)は 2000H-DEFFH を 0CCH で埋めるので、隔離されていなければ親のパターン/スタックが壊れる。
;   事前に `ramdisk 64` で F: を縮めて空きページを作ること(子は空き7枚を使う)。
	org 0100h
	ld sp,7F00h
	ld a,(0004h)
	ld (drv0),a
	; ページ07h を予約して印(0A5H*)を書く(窓=バンク4)
	ld e,07h
	ld c,0E2h
	call 5
	or a
	jp nz,ng_res
	; パターンを 8000H-DEFFH へ(窓にする前に。窓の外のコードで)
	ld hl,8000h
	ld de,0DEFFh-8000h+1
pf:	ld a,l
	xor h
	add a,5
	ld (hl),a
	inc hl
	dec de
	ld a,d
	or e
	jr nz,pf
	ld a,07h
	call mark_w
	ld de,m_start
	call say

	; 1. 子(正常終了)
	ld de,c_child
	ld c,0E5h
	call 5
	ld (res1),a
	call chk_parent
	ld de,m_back1
	call say
	ld a,(res1)
	or a
	jp nz,ng_r1
	call chk_pat
	jp nz,ng_pat
	call chk_mark
	jp nz,ng_mark
	ld de,m_p1
	call say

	; 2. 子(終了コード 7)
	ld de,c_child_t
	ld c,0E5h
	call 5
	cp 7
	jp nz,ng_r2
	call chk_pat
	jp nz,ng_pat
	ld de,m_p2
	call say

	; 3. 内部コマンド
	ld de,c_dir
	ld c,0E5h
	call 5
	or a
	jp nz,ng_r3
	call chk_pat
	jp nz,ng_pat
	ld de,m_p3
	call say

	; 4. 存在しないコマンド -> A=1
	ld de,c_bad
	ld c,0E5h
	call 5
	cp 1
	jp nz,ng_r4
	call chk_pat
	jp nz,ng_pat
	ld de,m_p4
	call say

	; 5. 予約はそのまま(E1h 07h の所有者=4)。子のページは戻っている(E2h で 07h は取れない、空きの最小が取れる)
	ld e,07h
	ld c,0E2h
	call 5
	cp 0F0h
	jp nz,ng_held
	ld e,0FFh		; 空きがあるか(子が使ったページは返っているはず)
	ld c,0E2h
	call 5
	or a
	jp nz,ng_free
	ld e,b
	ld c,0E3h
	call 5
	ld de,m_p5
	call say

	; 6. 子から IOCS(RST 18H)。IOCS無しのイメージではウォームブートで終わるので、どちらも A=0 で戻る
	ld de,c_child_i
	ld c,0E5h
	call 5
	or a
	jp nz,ng_r6
	call chk_pat
	jp nz,ng_pat
	ld de,m_p6
	call say

	; 7. コマンド行が 9F00H 以上(ゲートのバウンス)。パターンの領域に書くので、これが最後の検査
	ld hl,c_dir
	ld de,0C800h
	ld bc,16
	ldir
	ld de,0C800h
	ld c,0E5h
	call 5
	or a
	jp nz,ng_r7
	ld de,m_p7
	call say

	; 8. リダイレクト: 子の出力がファイル O.TXT へ行き(A=0)、ファイルができている
	ld de,c_redir
	ld c,0E5h
	call 5
	or a
	jp nz,ng_r8
	ld de,fcb_o
	ld c,0Fh
	call 5
	inc a
	jp z,ng_r8
	ld de,fcb_o
	ld c,10h
	call 5
	ld de,fcb_o
	ld c,13h
	call 5
	ld de,m_p8
	call say

	; 9. 親を片づける
	ld e,07h
	ld c,0E3h
	call 5
	ld de,m_done
	call say
	jp 0

ng_res:	ld de,m_ngres
	jr ngx
ng_r1:	ld de,m_ngr1
	jr ngx
ng_r2:	ld de,m_ngr2
	jr ngx
ng_r3:	ld de,m_ngr3
	jr ngx
ng_r4:	ld de,m_ngr4
	jr ngx
ng_r6:	ld de,m_ngr6
	jr ngx
ng_r7:	ld de,m_ngr7
	jr ngx
ng_r8:	ld de,m_ngr8
	jr ngx
ng_pat:	ld de,m_ngpat
	jr ngx
ng_mark: ld de,m_ngmark
	jr ngx
ng_held: ld de,m_nghe
	jr ngx
ng_free: ld de,m_ngfr
ngx:	call say
	jp 0

say:	ld c,9
	call 5
	ret

; 親の状態: カレントドライブ(0004H)、0005H の JP、0006H=E000H
chk_parent:
	ld a,(0004h)
	ld hl,drv0
	cp (hl)
	jr nz,cp_ng
	ld a,(0005h)
	cp 0C3h
	jr nz,cp_ng
	ld a,(0007h)
	cp 0E0h
	jr nz,cp_ng
	ret
cp_ng:	ld de,m_ngzp
	call say
	jp 0

; 8000H-DEFFH のパターンの検査。 Z で一致
chk_pat:
	ld hl,8000h
	ld de,0DEFFh-8000h+1
cpl:	ld a,l
	xor h
	add a,5
	cp (hl)
	jr nz,cpn
	inc hl
	dec de
	ld a,d
	or e
	jr nz,cpl
	xor a
	ret
cpn:	or 1
	ret

; A=ページ。バンク4の窓に出して 0000H.. へ印を書く
mark_w:	ld (mpg),a
	di
	ld a,4
	out (0B4h),a
	in a,(0B5h)
	ld (orig4),a
	ld a,4
	out (0B4h),a
	ld a,(mpg)
	out (0B5h),a
	ld hl,0A000h-2000h	; = 8000H
	ld b,16
mw:	ld (hl),0A5h
	inc hl
	djnz mw
	ld a,4
	out (0B4h),a
	ld a,(orig4)
	out (0B5h),a
	ei
	ret
; 印の検査。Z で一致
chk_mark:
	di
	ld a,4
	out (0B4h),a
	in a,(0B5h)
	ld (orig4),a
	ld a,4
	out (0B4h),a
	ld a,07h
	out (0B5h),a
	ld hl,8000h
	ld b,16
	ld c,0
cm:	ld a,(hl)
	cp 0A5h
	jr z,cm1
	ld c,1
cm1:	inc hl
	djnz cm
	ld a,4
	out (0B4h),a
	ld a,(orig4)
	out (0B5h),a
	ei
	ld a,c
	or a
	ret

drv0:	defb 0
res1:	defb 0
mpg:	defb 0
orig4:	defb 0
c_child:	defm "CHILD",0
c_child_t:	defm "CHILD T",0
c_child_i:	defm "CHILD I",0
c_dir:	defm "DIR CHILD.COM",0
c_redir:	defm "DIR CHILD.COM >O.TXT",0
fcb_o:	defb 0
	defm "O       TXT"
	defs 24,0
c_bad:	defm "NOSUCHCMD",0
m_start:	defm "EXEC-START",13,10,"$"
m_back1:	defm "EXEC-BACK",13,10,"$"
m_p1:	defm "EXEC-P1-OK",13,10,"$"
m_p2:	defm "EXEC-P2-OK",13,10,"$"
m_p3:	defm "EXEC-P3-OK",13,10,"$"
m_p4:	defm "EXEC-P4-OK",13,10,"$"
m_p5:	defm "EXEC-P5-OK",13,10,"$"
m_p6:	defm "EXEC-P6-OK",13,10,"$"
m_p7:	defm "EXEC-P7-OK",13,10,"$"
m_p8:	defm "EXEC-P8-OK",13,10,"$"
m_done:	defm "EXEC-DONE",13,10,"$"
m_ngres:	defm "EXEC-NG reserve",13,10,"$"
m_ngr1:	defm "EXEC-NG r1",13,10,"$"
m_ngr2:	defm "EXEC-NG r2",13,10,"$"
m_ngr3:	defm "EXEC-NG r3",13,10,"$"
m_ngr4:	defm "EXEC-NG r4",13,10,"$"
m_ngr6:	defm "EXEC-NG r6",13,10,"$"
m_ngr7:	defm "EXEC-NG r7",13,10,"$"
m_ngr8:	defm "EXEC-NG r8",13,10,"$"
m_ngpat:	defm "EXEC-NG pattern",13,10,"$"
m_ngmark:	defm "EXEC-NG mark",13,10,"$"
m_nghe:	defm "EXEC-NG held",13,10,"$"
m_ngfr:	defm "EXEC-NG free",13,10,"$"
m_ngzp:	defm "EXEC-NG zeropage",13,10,"$"
